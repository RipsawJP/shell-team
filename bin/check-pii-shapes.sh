#!/usr/bin/env bash
# bin/check-pii-shapes.sh — diff-scoped PII shape checker (T-111, GitHub issue
# #6 Layer 2 items 4-5; .shell-team/specs/T-111-pii-shape-checker.md, v4).
#
# Development on this repository happens in the open, so a PII-shaped byte
# (an email-shaped string, a home-directory absolute path, a private-key
# header, a credential-token prefix) is a per-commit risk. This script gives
# that risk a mechanical gate: by default it looks at the full committed
# content of each path a change touches (change-scoped, never the whole
# tree), and it is fail-closed — a run that cannot evaluate its input never
# reports clean.
#
# Five shapes are matched, each identified by a stable pattern id used in
# every finding line:
#   home-path         a POSIX home-directory absolute path with a real name
#                     segment (e.g. the placeholder shape /Users/<name>/ —
#                     written here with angle brackets precisely so this
#                     file, this spec, and the docs pair can discuss the
#                     shape without becoming a finding themselves; see AC9).
#                     Matched only at a boundary that cannot continue a host
#                     name (see DP-5 below) — a URL authority is therefore
#                     never a match.
#   home-path-win     the Windows C: user-directory form (same placeholder
#                     convention, C:\Users\<name>\). Not boundary-guarded:
#                     a backslash-delimited path never appears as a URL
#                     authority, so the false-positive class DP-5 closes for
#                     home-path does not reach this form.
#   email-nonnoreply  a mailbox-shaped string at a real, deliverable domain.
#                     Every mailbox-shaped candidate on a line is judged
#                     (AC26), not just the first. Excluded, by domain
#                     (never by local-part shape — DP-9): the GitHub noreply
#                     identity domain (end-anchored) and the plain web-flow
#                     noreply@github.com address; and by domain (DP-7): the
#                     RFC 2606 / 6761 reserved documentation/testing names.
#   private-key       a PEM private-key header line (named by id only in
#                     this file's prose; never transcribed literally here,
#                     since a document that transcribed a real match would
#                     red its own gate — see the spec's DP-1).
#   token             a credential-token prefix (GitHub gh[oprs]_, AWS AKIA,
#                     an OpenAI-style sk- key) long enough to be a real key
#                     body, not a short lookalike such as this project's own
#                     `task-0NN` label convention.
#
# Mechanism (DP-4, v4's premise change): this script NEVER parses git's
# textual diff rendering. A rendering is a human-facing format whose framing
# is configuration-dependent (colour, external diff, textconv, a -diff
# gitattribute) and whose escape syntax collides with content (a line whose
# real content starts with "++ " renders as "+++ "). Two rounds of a
# hand-rolled diff-text parser landed real blockers here, so the mechanism
# changed instead of patching the parser a third time:
#   - Changed paths are enumerated from NUL-separated `git diff --raw -z
#     --no-renames` output — never from a textual patch. --raw (rather than
#     --name-status) also carries each entry's new file MODE, which is what
#     lets a gitlink (a submodule reference, mode 160000) be recognised and
#     skipped explicitly rather than only discovered by `git cat-file`
#     failing.
#   - Each surviving path's content is read through `git cat-file`, plumbing
#     that returns the raw committed blob (for a symlink, the target string
#     git itself stores — never a followed link) with no framing, no colour,
#     no escape grammar to get wrong.
#   - The scanned unit is the FULL committed content of each changed path
#     (DP-6), not "added lines" — there is no base-blob comparison. A
#     one-time measurement found every currently tracked path that carries a
#     shape carries a false positive or a deliberate fixture, never a real
#     value, so the noise a per-path diff would have suppressed is handled
#     at the pattern level (DP-5, DP-7) and by name (DP-8) instead.
#   - Text vs binary is decided by the presence of a NUL byte (git's own
#     convention), never a printable-character heuristic — see AC27.
# Every `git` invocation below still pins its rendering (--no-color); under
# this mechanism that can no longer change a verdict, so it is free
# insurance, not a defence this script depends on.
#
# DP-5 (home-path boundary, final narrow form) / DP-10 (bias toward firing):
# the home-path shape is suppressed ONLY when the character immediately
# before its leading `/` can continue a host name — an ASCII letter, digit,
# dot, or hyphen. A bare documentation URL authority
# (https://example.com/home/products, preceded by a letter) therefore
# suppresses — the one false-positive class actually measured in this
# tree. Everything else FIRES: a quoted path, a path after a space, a path
# at line start, a path after a bracket (`]`), and a path after another `/`
# all still match. Round 3 widened the suppression to also exclude `/` and
# `]`, aiming to quiet a file://-style triple-slash authority, that same
# URL in a Markdown link, and an IPv6 literal authority — round 4 found
# that widening silences genuine true positives that are mechanically
# reachable (a doubled-leading-slash path bash's own diagnostics emit, and
# a bracket-adjacent path an xtrace prefix emits), so it is reverted. A
# one-character lookbehind cannot cleanly separate "inside a URL" from "in
# prose or a log line", and DP-10 is the ratified answer to that
# convergence failure: for a PII gate a false positive costs a moment of
# review, a false negative is a silent, second-chance-less exposure, so
# where the rule cannot separate the populations it prefers firing. The
# three accepted noisy classes are declared in the documents (AC18/AC19)
# instead of chased in the regex.
#
# DP-7 (reserved-domain exclusion): a mailbox shape at the RFC 2606 /
# RFC 6761 reserved documentation/testing names (example.com/.org/.net, and
# any domain ending in .example/.invalid/.test/.localhost) is not a finding
# — those domains cannot route to a real mailbox by construction.
#
# DP-9 (noreply exclusion, domain-anchored): a mailbox shape whose domain is
# EXACTLY the GitHub noreply identity domain — full-string equality, anchored
# at both ends — is not a finding, regardless of what the local part looks
# like: a login, a numeric id plus a login, or a printf format placeholder
# assembled at runtime. The exclusion never inspects the local part, and it
# never treats a DOTTED SUBDOMAIN of the noreply domain as equivalent to the
# domain itself — GitHub never hands out subdomains of its noreply zone, so
# `anything.users.noreply.github.com` is not excluded and still fires (round
# 3 cross-provider review found the domain regex admitted exactly this
# dotted-subdomain class via a `(^|\.)` prefix alternative; fixed to a bare
# `^...$` equality). A concatenated (no separating dot) suffix-confusable
# lookalike domain still fires for the same reason. The plain web-flow
# noreply@github.com address is its own, separate, full-address exclusion.
#
# DP-8 (known-shapes list): a short, per-file (never a directory or glob)
# list of paths that deliberately carry a shape as a fixture FOR ANOTHER
# GUARD's own suite. It is not an exemption for this task's own files —
# this script's own path and any path under tests/check-pii-shapes/ are
# never listed and stay runtime-generated (DP-1); a shape in either is still
# reported (AC13).
#
# DP-1: no PII-shaped byte enters this tree. Every fixture the test suite
# uses is assembled at runtime, under mktemp, from fragments — never
# written here as a completed literal. There is no path allowlist beyond
# DP-8's narrow, test-locked, other-guard-only list, and no inline allow
# marker anywhere in this file.
#
# A finding never echoes the matched text — only the pattern id, the path,
# and a line number (when available) are reported — so a public CI log
# never carries the byte that tripped the gate (AC14).
#
# This is a discipline aid for a trusted, reviewed artifact, not a security
# boundary against an author editing this checker itself in the same commit
# (same trust boundary as bin/check-acs.sh's TRUST BOUNDARY note and
# bin/check-intent.sh's ledger note) — PR review is that layer.
#
# Usage:
#   check-pii-shapes.sh [--base <ref>]     change-scoped (default)
#   check-pii-shapes.sh --all              full-tree audit (never in CI)
#   check-pii-shapes.sh --help
#
# Exit codes:
#   0  clean (no findings)
#   1  one or more findings
#   2  usage or structural error (unresolvable base ref, unreadable input,
#      unknown flag, --all combined with --base) — a check that cannot
#      evaluate its input never exits 0.

set -euo pipefail

die() {  # $1 = classification (usage|structural), $2 = message; exit 2
  printf 'check-pii-shapes: %s: %s\n' "$1" "$2" >&2 || true
  exit 2
}
fail_usage()      { die usage "$1"; }
fail_structural() { die structural "$1"; }

# Resolve this script's own file, following symlinks (a plugin install may
# expose bin/ scripts on PATH via a symlink). Ported from
# bin/check-provenance.sh's bootstrap (2026-07-14 lesson: reuse the proven
# resolver rather than hand-rolling one). Every external command here is
# guarded — a failure falls closed as a classified usage(2) error.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")" \
    || fail_usage "readlink failed to resolve the symlink target of: $script_path"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)
      link_dir_raw="$(dirname "$script_path")" \
        || fail_usage "dirname failed to resolve the directory of relative symlink target for: $script_path"
      link_dir="$(cd "$link_dir_raw" && pwd)" \
        || fail_usage "cd/pwd failed to resolve the directory of relative symlink target for: $script_path"
      script_path="$link_dir/$link_target"
      ;;
  esac
done
script_dir_raw="$(dirname "$script_path")" \
  || fail_usage "dirname failed to resolve this script's own directory for: $script_path"
SCRIPT_DIR="$(cd "$script_dir_raw" && pwd)" \
  || fail_usage "cd/pwd failed to resolve this script's own directory for: $script_path"
self_name="$(basename "$script_path")" \
  || fail_usage "basename failed to resolve this script's own file name for: $script_path"
SELF="$SCRIPT_DIR/$self_name"

print_help() {
  # The header comment's end is found dynamically (the line right before
  # `set -euo pipefail`) rather than hardcoded, so a future edit that grows
  # or shrinks the header comment cannot silently truncate --help output
  # again — a hardcoded line-range boundary going stale as the file grows is
  # exactly the "boundary that admits more/less than intended" class round 3
  # review found elsewhere in this file, and this one bit --help itself
  # during that same rework (a hardcoded '2,124p' left --all/--base out of
  # --help's output after the header grew past line 124).
  local header_end
  header_end="$(grep -n '^set -euo pipefail$' "$SELF" | head -1 | cut -d: -f1)" \
    || fail_usage "failed to locate this script's own 'set -euo pipefail' line (--help) in: $SELF"
  [ -n "$header_end" ] || fail_usage "could not find 'set -euo pipefail' in: $SELF (--help would be empty)"
  header_end=$((header_end - 2))
  sed -n "2,${header_end}p" "$SELF" | sed 's/^# \{0,1\}//' \
    || fail_usage "failed to read this script's own header comment (--help) from: $SELF"
}

# --- argument parsing --------------------------------------------------------
MODE="diff"
BASE_REF=""
HAVE_BASE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --all) MODE="all"; shift ;;
    --base)
      [ "$#" -ge 2 ] || fail_usage "--base requires a value"
      BASE_REF="$2"; HAVE_BASE=1; shift 2 ;;
    --) shift; break ;;
    -*) fail_usage "unknown flag: $1" ;;
    *)  fail_usage "unexpected argument: $1" ;;
  esac
done
[ "$#" -eq 0 ] || fail_usage "unexpected extra argument: $1"

if [ "$MODE" = "all" ] && [ "$HAVE_BASE" -eq 1 ]; then
  fail_usage "--all and --base are mutually exclusive"
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || fail_structural "not inside a git working tree (check-pii-shapes.sh must be run from inside a git repository)"

# --- pattern + exclusion definitions -----------------------------------------
# Each rule lives on its own assignment line so a fixture suite can
# neutralise exactly one at a time by rewriting that one line. There are
# nine independently load-bearing rules: five patterns, plus four
# exclusions (the domain-anchored noreply rule, the plain web-flow address,
# the reserved-domain rule, and the home-path boundary rule).
#
# Anchoring/boundary inventory (round 3 review requirement — every regex
# this script ships, audited mechanically): how each end is anchored, what
# that admits, and whether this round applied a fix.
#
#   RE_HOME_PATH_BOUNDARY  left-anchored: start-of-line, OR one character
#     that is NOT a letter, digit, dot, or hyphen. Suppresses only when
#     preceded by a host-name-continuing character (the one measured
#     false-positive class, a bare URL authority); a bracket, another `/`,
#     a space, a quote or full-width punctuation all still FIRE. Round 3
#     widened this to also suppress on `/` and `]` (closing file://,
#     Markdown-wrapped file://, and IPv6-literal-authority noise); round 4
#     REVERTED that widening — it silenced two mechanically reachable true
#     positives (a doubled-leading-slash path, a bracket-adjacent path) —
#     per DP-10's ratified bias-toward-firing: a false positive costs a
#     review, a false negative is a silent, second-chance-less exposure.
#     The reverted noisy classes are declared in the documents (AC18/AC19)
#     instead of suppressed in this regex, and AC28's two positive fixtures
#     lock the fail-noisy direction against a future re-widening.
#   RE_HOME_PATH_RAW  not end-anchored (greedy through the whole ASCII name
#     class). Not applicable to this round — it is the base SHAPE, not an
#     exclusion; unaffected by boundary/anchoring findings.
#   RE_HOME_PATH_WIN  NOT boundary-guarded at all (any preceding character
#     admitted). Re-examined under this round's "boundary/anchoring" lens
#     and left unchanged: a Windows path uses backslashes, which never
#     appear as a URL authority separator, so there is no reachable
#     false-positive class analogous to the POSIX form's — a file:// URI
#     encoding a Windows path uses forward slashes, which this pattern's
#     literal backslash requirement already rejects regardless of any
#     boundary. Not applied.
#   RE_EMAIL_BASE  not anchored at either end (deliberate: `grep -o`
#     enumerates every non-overlapping candidate on a line, AC26). Being a
#     PATTERN rather than an EXCLUSION, an unanchored match is safe-directed
#     (more candidates considered, never fewer) — the asymmetry this round's
#     blocker turns on: an unanchored EXCLUSION is dangerous (admits a
#     bypass), an unanchored PATTERN is not. Not applicable.
#   RE_NOREPLY_DOMAIN  now anchored at BOTH ends (`^...$`, full-string
#     equality) against the extracted domain. APPLIED the blocker fix this
#     round: was `(^|\.)users\.noreply\.github\.com$`, which admitted any
#     dotted subdomain prefix as an alternative to start-of-string — a
#     genuine required-check bypass, since GitHub never hands out
#     subdomains of this zone (unlike RE_RESERVED_DOMAIN below).
#   RE_NOREPLY_PLAIN  anchored at both ends against the whole candidate
#     address (not just the domain) — full-string equality already, no
#     dotted-prefix alternative exists to admit. Not applicable.
#   RE_RESERVED_DOMAIN  end-anchored per alternative, start is either
#     string-start or a literal preceding dot (`(^|\.)example\.(com|org|net)
#     $`, and `\.(example|invalid|test|localhost)$`) — deliberately admits a
#     dotted subdomain, re-examined and left unchanged: RFC 2606 reserves
#     the WHOLE zone under these names, so any subdomain of example.com is
#     equally non-routable, unlike the noreply case just above. Not applied.
#   RE_PRIVATE_KEY  not anchored at either end (a substring match for a
#     fixed header literal) — no host/domain concept applies; a false
#     positive would require the literal header text to appear
#     coincidentally, which is not a boundary/anchoring question. Not
#     applicable.
#   RE_TOKEN  not anchored at either end — same asymmetry as RE_EMAIL_BASE:
#     this is a PATTERN, so an unanchored match only widens detection
#     (safe-directed), never creates a bypass. Not applicable.
#
# shellcheck disable=SC2016  # single-quoted regex text, not a variable expansion
RE_HOME_PATH_BOUNDARY='(^|[^A-Za-z0-9.-])'
# shellcheck disable=SC2016
RE_HOME_PATH_RAW='/(Users|home)/[A-Za-z0-9_.-]+'
RE_HOME_PATH="${RE_HOME_PATH_BOUNDARY}${RE_HOME_PATH_RAW}"
# shellcheck disable=SC2016
RE_HOME_PATH_WIN='C:\\{1,2}Users\\{1,2}[A-Za-z0-9_.-]+'
# shellcheck disable=SC2016
RE_EMAIL_BASE='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
# shellcheck disable=SC2016  # full-string equality, anchored at both ends —
# never a "same domain or a dotted subdomain of it" match (round 3 fix)
RE_NOREPLY_DOMAIN='^users\.noreply\.github\.com$'
# shellcheck disable=SC2016
RE_NOREPLY_PLAIN='^noreply@github\.com$'
# shellcheck disable=SC2016
RE_RESERVED_DOMAIN='(^|\.)example\.(com|org|net)$|\.(example|invalid|test|localhost)$'
# shellcheck disable=SC2016
RE_PRIVATE_KEY='-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----'
# shellcheck disable=SC2016
RE_TOKEN='gh[oprs]_[A-Za-z0-9]{20,}|AKIA[A-Z0-9]{12,}|sk-[A-Za-z0-9_-]{16,}'

# --- known-shapes list (DP-8) ------------------------------------------------
# Per-file only — no directory entry, no glob, no pattern. Fixtures that
# deliberately carry a PII shape FOR ANOTHER GUARD's own suite
# (tests/rollup-track/run.sh). Never this script's own path, never a path
# under tests/check-pii-shapes/ — those stay runtime-generated (DP-1) and a
# shape in them is always reported (AC13).
KNOWN_SHAPE_PATHS=(
  "tests/rollup-track/fixtures/winpath.jsonl"
  "tests/rollup-track/fixtures/secret-aws.jsonl"
  "tests/rollup-track/fixtures/secret-github.jsonl"
  "tests/rollup-track/fixtures/secret-openai.jsonl"
)

is_known_shape() {  # $1 = path (repo-root-relative)
  local p="$1" k
  for k in "${KNOWN_SHAPE_PATHS[@]}"; do
    [ "$p" = "$k" ] && return 0
  done
  return 1
}

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/check-pii-shapes.XXXXXX")" \
  || fail_structural "failed to create a scratch directory under mktemp"
# shellcheck disable=SC2329  # invoked indirectly via the EXIT trap below
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

FINDINGS_FILE="$WORKDIR/findings"
CONTENT_FILE="$WORKDIR/content"
: > "$FINDINGS_FILE"

# is_binary_file <file> — true (0) iff <file> contains a NUL byte (git's own
# text/binary convention — never a printable-character heuristic, AC27).
is_binary_file() {
  LC_ALL=C tr -d '\000' < "$1" > "$WORKDIR/stripped" 2>/dev/null || return 1
  ! cmp -s "$WORKDIR/stripped" "$1"
}

# report_pattern_lines <id> <path> <contentfile> <regex> — one FINDING line
# per matching line number. grep's own "N:content" output is read but only
# the N field is ever used; the content half is discarded before it can be
# written anywhere (AC14: a finding never echoes the matched text).
report_pattern_lines() {
  local id="$1" path="$2" file="$3" re="$4" ln rest
  # `--` guards against a regex that itself begins with a literal `-`
  # (RE_PRIVATE_KEY does) being parsed as a grep option instead of a
  # pattern argument.
  grep -nE -- "$re" "$file" > "$WORKDIR/matches" 2>/dev/null || true
  while IFS=: read -r ln rest; do
    [ -n "${ln:-}" ] || continue
    printf 'FINDING pattern=%s path=%s line=%s\n' "$id" "$path" "$ln" >> "$FINDINGS_FILE"
  done < "$WORKDIR/matches"
}

# scan_email_candidates <path> <contentfile> — every mailbox-shaped
# candidate on every line is judged individually (AC26), never only the
# leftmost: an excluded noreply/reserved-domain address earlier on a line
# never masks a real mailbox shape later on the same line. At most one
# FINDING line is emitted per (path, line) pair even if several candidates
# on that line survive exclusion.
scan_email_candidates() {
  local path="$1" file="$2" ln cand domain excluded last_ln=""
  grep -noE -- "$RE_EMAIL_BASE" "$file" > "$WORKDIR/emails" 2>/dev/null || true
  while IFS=: read -r ln cand; do
    [ -n "${ln:-}" ] || continue
    domain="${cand#*@}"
    excluded=0
    if [[ "$cand" =~ $RE_NOREPLY_PLAIN ]]; then
      excluded=1
    elif [[ "$domain" =~ $RE_NOREPLY_DOMAIN ]]; then
      excluded=1
    elif [[ "$domain" =~ $RE_RESERVED_DOMAIN ]]; then
      excluded=1
    fi
    if [ "$excluded" -eq 0 ] && [ "$ln" != "$last_ln" ]; then
      printf 'FINDING pattern=email-nonnoreply path=%s line=%s\n' "$path" "$ln" >> "$FINDINGS_FILE"
      last_ln="$ln"
    fi
  done < "$WORKDIR/emails"
}

# scan_content_file <path> <contentfile> — runs all five pattern checks
# against already-materialized, already-confirmed-non-binary content.
scan_content_file() {
  local path="$1" file="$2"
  report_pattern_lines home-path "$path" "$file" "$RE_HOME_PATH"
  report_pattern_lines home-path-win "$path" "$file" "$RE_HOME_PATH_WIN"
  report_pattern_lines private-key "$path" "$file" "$RE_PRIVATE_KEY"
  report_pattern_lines token "$path" "$file" "$RE_TOKEN"
  scan_email_candidates "$path" "$file"
}

announce_skip() {  # $1 = path, $2 = mode label (blob|file)
  printf 'check-pii-shapes: skip: binary %s (NUL byte present), not scanned: %s\n' "$2" "$1" >&2 || true
}

if [ "$MODE" = "all" ]; then
  # --- full-tree audit: repo-root scope regardless of invoking directory,
  # tracked + untracked-but-not-ignored files, symlinks scanned by their
  # stored target string rather than followed, never a silent skip (AC29).
  TOPLEVEL="$(git rev-parse --show-toplevel)" \
    || fail_structural "git rev-parse --show-toplevel failed — cannot resolve the repository root for --all"
  cd "$TOPLEVEL" || fail_structural "failed to change into the repository root ($TOPLEVEL) for --all"

  FILELIST="$WORKDIR/filelist"
  : > "$FILELIST"

  # Tracked files via `ls-files -s` (not the plain `--cached` form used
  # below for untracked), because `-s` carries each entry's MODE — needed to
  # recognise and skip a gitlink (a submodule reference, mode 160000, no
  # blob of its own to scan) explicitly, the same class round 3 review found
  # falling through to a raw, unclassified `cp` failure otherwise. Each `-z`
  # record is "<mode> <sha> <stage>\t<path>\0" — one NUL-terminated read,
  # then split once on the (single, literal) tab.
  TRACKED_S_Z="$WORKDIR/tracked-s-z"
  git ls-files -s -z --cached > "$TRACKED_S_Z" \
    || fail_structural "git ls-files -s failed — cannot enumerate tracked files for --all"
  while IFS= read -r -d '' rec; do
    [ -n "$rec" ] || continue
    meta="${rec%%$'\t'*}"
    p="${rec#*$'\t'}"
    mode="${meta%% *}"
    if [ "$mode" = "160000" ]; then
      printf 'check-pii-shapes: skip: gitlink (submodule reference, no scannable content): %s\n' "$p" >&2 || true
      continue
    fi
    printf '%s\n' "$p" >> "$FILELIST"
  done < "$TRACKED_S_Z"

  # Untracked-but-not-ignored files never carry a git mode at all (they are
  # not gitlinks by construction — a gitlink only exists as a tracked index
  # entry), so no mode filtering applies here.
  OTHERS_Z="$WORKDIR/others-z"
  git ls-files -z --others --exclude-standard > "$OTHERS_Z" \
    || fail_structural "git ls-files --others failed — cannot enumerate untracked files for --all"
  while IFS= read -r -d '' p; do
    printf '%s\n' "$p" >> "$FILELIST"
  done < "$OTHERS_Z"

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    is_known_shape "$path" && continue

    if [ -L "$path" ]; then
      # A tracked/untracked symbolic link: scan the target string git
      # itself stores, never the file the link points at (which need not
      # even exist on this machine) — the classic --all blind spot.
      target="$(readlink "$path")" \
        || fail_structural "cannot read symlink target for: $path"
      printf '%s' "$target" > "$CONTENT_FILE"
      scan_content_file "$path" "$CONTENT_FILE"
      continue
    fi

    [ -e "$path" ] || fail_structural "path listed by git ls-files no longer exists on disk: $path"
    [ -r "$path" ] || fail_structural "cannot read file listed by git ls-files: $path"
    if is_binary_file "$path"; then
      announce_skip "$path" file
      continue
    fi
    cp "$path" "$CONTENT_FILE" 2>/dev/null \
      || fail_structural "failed to read file listed by git ls-files: $path"
    scan_content_file "$path" "$CONTENT_FILE"
  done < "$FILELIST"
else
  # --- change-scoped: resolve the comparison point, then read the FULL
  # committed content of each changed path (DP-4/DP-6) — never a diff
  # rendering, never a base-blob comparison.
  resolve_ref() {
    git rev-parse --verify --quiet "${1}^{commit}" >/dev/null 2>&1
  }

  CHOSEN=""
  if [ "$HAVE_BASE" -eq 1 ]; then
    resolve_ref "$BASE_REF" || fail_structural "unresolvable base ref: $BASE_REF"
    CHOSEN="$BASE_REF"
  else
    CANDIDATES=()
    if [ -n "${PII_CHECK_BASE:-}" ]; then CANDIDATES+=("$PII_CHECK_BASE"); fi
    if [ -n "${GITHUB_BASE_REF:-}" ]; then CANDIDATES+=("origin/$GITHUB_BASE_REF"); fi
    CANDIDATES+=("origin/develop" "develop")
    for c in "${CANDIDATES[@]}"; do
      if resolve_ref "$c"; then CHOSEN="$c"; break; fi
    done
    [ -n "$CHOSEN" ] || fail_structural "unresolvable base ref: no candidate in the default chain resolved (tried \$PII_CHECK_BASE, origin/\$GITHUB_BASE_REF, origin/develop, develop) — pass --base explicitly"
  fi

  POINT="$(git merge-base "$CHOSEN" HEAD 2>/dev/null || true)"
  [ -n "$POINT" ] || POINT="$CHOSEN"

  RAW_Z="$WORKDIR/raw-z"
  # --no-color pins the rendering (free insurance under DP-4, since --raw is
  # never colourised regardless); --no-renames disables rename detection so
  # every entry below is exactly two NUL-separated records (metadata, path)
  # — never the three-record rename/copy form. --raw (not --name-status) is
  # used specifically so the NEW MODE field is available: it is what lets a
  # gitlink (a submodule reference, mode 160000 — no blob, so `git cat-file`
  # cannot read it as content) be recognised and skipped explicitly, rather
  # than only discovered by cat-file failing (round 3 fix: that failure used
  # to be dead code under errexit — see below).
  git diff --no-color --no-renames --raw -z "$POINT" HEAD > "$RAW_Z" 2>/dev/null \
    || fail_structural "git diff --raw failed against resolved point ($POINT)"

  CHANGED_PATHS="$WORKDIR/changed-paths"
  : > "$CHANGED_PATHS"
  {
    while IFS= read -r -d '' meta && IFS= read -r -d '' path; do
      [ -n "$meta" ] || continue
      # meta is ":<old-mode> <new-mode> <old-sha> <new-sha> <status>" — only
      # the new mode and the status are needed.
      # shellcheck disable=SC2086  # intentional word-splitting on spaces
      set -- ${meta#:}
      new_mode="${2:-}"
      diff_status="${5:-}"
      [ "$diff_status" = "D" ] && continue
      if [ "$new_mode" = "160000" ]; then
        # A gitlink (submodule reference) has no blob of its own in this
        # repository — there is no content to scan, and reading one via
        # `git cat-file` risks returning an unrelated commit object that
        # happens to share the reference's SHA in this repo's object
        # database (round 3 finding) rather than failing outright. Skipped
        # explicitly, announced, never silently and never scanned.
        printf 'check-pii-shapes: skip: gitlink (submodule reference, no scannable content): %s\n' "$path" >&2 || true
        continue
      fi
      printf '%s\n' "$path" >> "$CHANGED_PATHS"
    done
  } < "$RAW_Z"

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    is_known_shape "$path" && continue

    # Same-line `||` (round 3 fix): under `set -e`, a failing simple command
    # NOT in an `if`/`&&`/`||` position triggers errexit immediately, so a
    # separate `rc=$?; if [ "$rc" -ne 0 ]; then ...` on the NEXT line never
    # runs — the script would exit with git's own raw exit code (128) and no
    # classified token. An ordinary `git submodule add` reproduces this via
    # a gitlink entry, but the gitlink skip above already routes that case
    # away from cat-file entirely; this guard is the general fail-closed net
    # for any other reason `cat-file` might fail on a surviving path.
    git cat-file -p "HEAD:$path" > "$CONTENT_FILE" 2>/dev/null \
      || fail_structural "failed to read committed content via git cat-file for: $path"
    if is_binary_file "$CONTENT_FILE"; then
      announce_skip "$path" blob
      continue
    fi
    scan_content_file "$path" "$CONTENT_FILE"
  done < "$CHANGED_PATHS"
fi

if [ -s "$FINDINGS_FILE" ]; then
  cat "$FINDINGS_FILE"
  exit 1
fi

printf 'check-pii-shapes: clean (no PII-shaped bytes found)\n' || true
exit 0
