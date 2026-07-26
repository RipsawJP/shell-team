#!/usr/bin/env bash
# bin/check-acs.sh — run the machine-checkable acceptance criteria of a spec.
#
# A spec (docs/specs/T-NNN-*.md) lists acceptance criteria as lines like:
#   - [ ] **AC2** <description> *(scriptable)*
#     - check: bash tests/check-run/run.sh
# The hyphenated numbering form **AC-N** (e.g. `- [ ] **AC-2** ...`) is also
# accepted — both `**ACn**` and `**AC-N**` are recognized, INCLUDING the form
# where the bold wraps the whole title before the closing `**`, e.g.
# `- [ ] **AC-1 — some title.** <description>` (T-085's convention).
# Each scriptable AC carries a `check:` sub-bullet whose shell command verifies
# it (exit 0 = PASS). A runtime AC simply omits `check:` and is reported SKIP.
# This turns the spec's scriptable ACs into a mechanical QA gate.
#
# TRUST BOUNDARY (important): `check:` lines are shell commands embedded in a
# spec, so running them is arbitrary code execution. This is safe only because:
#   - the tool is invoked explicitly by a human / QA (never a hook / auto-run);
#   - specs are trusted, committed, reviewed artifacts authored by the team
#     (same trust boundary as discover-work.sh refusing to read PR bodies);
#   - `check:` commands MUST be read-only verification (run tests, grep, exit
#     codes) — destructive commands must never be written (convention, advisory).
#     The one named exception (T-048, #126): an IDEMPOTENT FRESHNESS CHECK — a
#     command that only ever reproduces already-committed, already-reviewed
#     content (e.g. regenerating a derived file, then `git diff --quiet`
#     against it) and is a no-op once the repo is already fresh. This pattern
#     already ships in production specs (T-045's own AC3, T-046's AC4) — it
#     never introduces NEW content, only confirms committed content still
#     matches its generator, so it is not itself a violation of "read-only
#     verification" in spirit, even though it technically writes a file;
#   - `--dry-run` previews the exact commands WITHOUT executing any of them.
# Each command is echoed before it runs, so the operator sees what executed.
#
# `check:` VALUES MUST NEVER BE WRAPPED IN A MARKDOWN BACKTICK PAIR (T-048,
# #126, per tasks/reviews/T-046.md round1's Major finding): a value like
# `` `bash foo.sh && echo ok` `` (backtick at both the first and last
# character) is executed via `bash -c "$cmd"` below, which makes bash treat
# the WHOLE backtick-wrapped text as a bare command substitution — it runs
# the enclosed command, then tries to execute whatever that command printed
# to stdout as a NEW command line. This produces a false FAIL for any check
# whose successful branch prints a confirmation message, even though the
# underlying check genuinely passed. Write `check:` as a raw command with no
# wrapping backticks (see agents/pm-spec.md's spec-authoring rule) — this
# script rejects a backtick-wrapped value fail-closed before ever running it
# (see the first-char/last-char check in the main loop below).
#
# External dependencies: bash + standard POSIX tools. No jq/yq/python.
#
# Usage:
#   check-acs.sh [--dry-run] [--root <dir>] <spec.md>
#   check-acs.sh --help
#
# Exit codes:
#   0  all AC checks passed (runtime ACs SKIP, scriptable ACs PASS)
#   1  at least one AC check failed
#   2  argument / usage error, spec unreadable, or an unrecognized AC label
#      line was found (T-110, fail-closed — see CANDIDATE_RE below)

set -euo pipefail

# `check:` commands run from the caller's current working directory by default,
# so an adopted/target repo is checked against ITSELF — not against the repo this
# script happens to live in (it is on PATH when the plugin is loaded, so its own
# location is the plugin repo, not the repo under test). `--root <dir>` overrides
# the directory explicitly. Self-host CI invokes from the repo root, so the
# default (cwd) equals the repo root there — unchanged behavior.
DRY_RUN=0
SPEC=""
ROOT=""

die() { printf 'ERROR: %s\n' "$*" >&2 || true; exit 2; }

print_help() {
  cat <<'EOF'
Usage: check-acs.sh [--dry-run] [--root <dir>] <spec.md>

Run the machine-checkable acceptance criteria of a spec. Each scriptable AC
carries a `- check: <command>` sub-bullet; the command runs from the current
working directory (or --root <dir>) and exit 0 means the AC passes. Runtime ACs
(no `check:`) are reported SKIP.

Options:
  --dry-run    List the commands that WOULD run, without executing any of them.
  --root <dir> Run each `check:` command from <dir> instead of the cwd.
  --help, -h   Show this help and exit.

Exit: 0 = all passed, 1 = a check failed, 2 = usage / unreadable spec /
unrecognized AC label line found.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)  print_help; exit 0 ;;
    --dry-run)  DRY_RUN=1; shift ;;
    --root)     shift; { [ "$#" -ge 1 ] && [ -n "$1" ]; } || die "--root requires a non-empty <dir> argument"; ROOT="$1"; shift ;;
    --) shift; [ "$#" -ge 1 ] && { SPEC="$1"; shift; } ;;
    --*) die "unknown flag: $1" ;;
    *)
      [ -z "$SPEC" ] || die "expected exactly one <spec.md>, got extra: $1"
      SPEC="$1"; shift
      ;;
  esac
done

[ -n "$SPEC" ]  || die "missing required <spec.md> (see --help)"
[ -r "$SPEC" ]  || die "cannot read spec file: $SPEC"

# Directory the `check:` commands run in: --root if given (must exist), else the
# caller's cwd. The <spec.md> path above is resolved relative to cwd BEFORE this,
# so only the check-exec directory is affected, not where the spec is read from.
if [ -n "$ROOT" ]; then
  [ -d "$ROOT" ] || die "--root is not a directory: $ROOT"
else
  ROOT="$PWD"
fi

# ---------------------------------------------------------------------------
# Parse the spec into parallel arrays: each `- [ ] **ACn** ...` (or the
# hyphenated `- [ ] **AC-N** ...` form) is associated with the FIRST
# `- check:` sub-bullet that follows it (before the next AC line or a `## `
# heading). Pure-bash regex (BASH_REMATCH) — no gawk-only features, so it
# runs on BSD/macOS and GNU/Linux alike (same posture as check-handoff.sh).
# ---------------------------------------------------------------------------
# shellcheck disable=SC2016  # these are regex strings, not shell expansions.
# The trailing `([^0-9A-Za-z_:.-]|$)` delimiter group requires the digit run to
# be followed by a character that is NEITHER alphanumeric NOR one of the four
# ASCII word-continuation puncts `_ : . -`, or end-of-line, so:
#   - `**AC12abc**` (digits glued to more letters) is correctly NOT recognized
#     as AC 12 — dropping the old `\*\*`-adjacency requirement without this
#     delimiter would otherwise falsely accept it (T-088 / #286, Codex round1
#     Major);
#   - `**AC1_foo**` / `**AC1:foo**` / `**AC1.foo**` / `**AC1-foo**` (digits
#     glued to more text by an ASCII word-continuation punctuation) are also
#     correctly NOT recognized as AC 1 (T-089 / #295, Codex T-088 round2
#     Minor — a narrower variant of the same false-positive class);
#   - `*`, whitespace, and end-of-line remain valid boundaries (`**AC1**`,
#     `**AC-1 — title.**`), as does any OTHER non-alphanumeric character such
#     as the full-width `（` (`docs/specs/T-054-...md`'s real
#     `**AC4（負系・維持されるべきプロパティ）**`) — only the four reported
#     ASCII puncts are excluded, not an allow-list of `*`/whitespace only.
AC_RE='^- \[[ xX]\] \*\*AC-?([0-9]+)([^0-9A-Za-z_:.-]|$)'
# CANDIDATE_RE (T-110, DP-3): a "candidate" AC-label line is ANY column-0
# `- [ ] **AC...` bullet, whether or not AC_RE above goes on to recognize it.
# Deliberately broader than AC_RE (no digit-run requirement at all), so a
# label with NO digits (`**AC**` / `**ACfoo**`) is not silently dropped
# either — only AC_RE's own delimiter narrowing (T-088/T-089) decides
# recognition; CANDIDATE_RE only decides "is this even AC-label-shaped".
# Column-0 anchoring is load-bearing and is NOT loosened here: it is what
# keeps real, committed, INDENTED example/illustration AC lines out of
# scope (docs/specs/T-088-ac-lock-hardening.md:376,378,
# docs/specs/T-089-checker-hardening.md:394-400) — loosening the anchor
# would make this repo's own specs report false unrecognized-label
# diagnostics against themselves.
CANDIDATE_RE='^- \[[ xX]\] \*\*AC'
# CHECK_RE deliberately captures EVERYTHING after `check:` (including nothing at
# all), not `[[:space:]]*(.+)$` (1+ char) — a `check:` line with zero or only
# whitespace characters after it must still be recognized as "a check: line was
# present" (see the `curseen`/`acseen` tracking below), so it can be told apart
# from an AC that has no check: sub-bullet at all (T-050, #132, AC1). Leading
# whitespace is stripped manually below (mirrors the old regex's `[[:space:]]*`).
# shellcheck disable=SC2016
CHECK_RE='^[[:space:]]+- check:(.*)$'

acnums=(); accmds=(); acseen=()
cur=""; curcmd=""; curseen=0
unrecognized=0
lineno=0
flush() { [ -n "$cur" ] && { acnums+=("$cur"); accmds+=("$curcmd"); acseen+=("$curseen"); }; return 0; }

while IFS= read -r line || [ -n "$line" ]; do
  lineno=$((lineno + 1))
  line="${line%$'\r'}"   # tolerate CRLF
  if [[ "$line" =~ $AC_RE ]]; then
    flush; cur="${BASH_REMATCH[1]}"; curcmd=""; curseen=0
  elif [[ "$line" =~ $CANDIDATE_RE ]]; then
    # T-110 fail-closed unrecognized-label detection (DP-1/DP-2/DP-6): a
    # column-0 `- [ ] **AC...` bullet CANDIDATE_RE matched but AC_RE did NOT
    # (a glued suffix, no digits, etc.) is no longer silently dropped. It
    # resets `cur` the same way a `## ` heading does (DP-6), so a `check:`
    # sub-bullet that follows is never misattributed to the PRECEDING
    # recognized AC. It is surfaced on stderr only (DP-8), with its exact
    # spec:line location, its verbatim text, and the two supported canonical
    # forms. These two printf calls are an ACCUMULATOR — the loop continues
    # afterward, there is no immediate `exit` tied to this specific write —
    # but unlike the CHECK_ACS_TIMEOUT / empty-check / backtick-wrap
    # diagnostics elsewhere in this file (whose eventual contract exit is 1,
    # matching errexit's own fallback, so a stripped guard cannot change the
    # observable outcome), THIS accumulator's downstream contract exit is 2
    # (DP-1) — a write failure here (stderr closed/unwritable) would abort
    # the whole script via errexit BEFORE the loop ever reaches the
    # `unrecognized>0 -> exit 2` checks below, landing on errexit's fallback
    # of 1 instead. That is a real, non-vacuous contract break (2 -> 1), so
    # these two writes ARE `|| true`-guarded (T-110 rework1, Codex round1
    # Major) and get a dedicated `2>&-` behavioral row in
    # tests/errexit-safe/run.sh instead of a NOT_APPLY entry.
    flush; cur=""; curcmd=""; curseen=0
    unrecognized=$((unrecognized + 1))
    printf 'check-acs: unrecognized AC label at %s:%s: %s\n' "$SPEC" "$lineno" "$line" >&2 || true
    printf 'check-acs: an AC label must be exactly **ACn** or **AC-N** (no character glued to the digits — not a letter, and not _ : . -); this line was not parsed as an acceptance criterion and no check: was run for it\n' >&2 || true
  elif [[ "$line" == "## "* ]]; then
    flush; cur=""; curcmd=""; curseen=0
  elif [ -n "$cur" ] && [ "$curseen" -eq 0 ] && [[ "$line" =~ $CHECK_RE ]]; then
    curseen=1
    raw="${BASH_REMATCH[1]}"
    # Strip leading whitespace only (trailing whitespace is preserved verbatim —
    # see the backtick-detection comment below for why trailing whitespace on
    # $cmd itself must never be silently rewritten).
    curcmd="${raw#"${raw%%[![:space:]]*}"}"
  fi
done < "$SPEC"
flush

if [ "${#acnums[@]}" -eq 0 ]; then
  printf 'check-acs: no acceptance criteria (- [ ] **ACn** / **AC-N**) found in %s\n' "$SPEC" >&2 || true
  exit 2
fi

# ---------------------------------------------------------------------------
# Run (or preview) each AC's check.
#
# Checks MUST be non-interactive and bounded (read-only verification). To stop a
# hanging/interactive check from blocking forever (notably in CI), wrap it in
# `timeout` when available (GNU coreutils; macOS lacks it by default, so we fall
# back to a plain run there). Override the cap with CHECK_ACS_TIMEOUT.
# ---------------------------------------------------------------------------
TIMEOUT_PREFIX=""
if command -v timeout >/dev/null 2>&1; then
  acs_timeout="${CHECK_ACS_TIMEOUT:-120}"
  # Validate: a `timeout` duration is digits with an optional s/m/h/d suffix.
  # Reject empty / flag-like / junk so a hostile CHECK_ACS_TIMEOUT cannot inject
  # a flag into the `timeout` invocation.
  case "$acs_timeout" in
    ''|[!0-9]*|*[!0-9smhd]*)
      printf 'check-acs: ignoring invalid CHECK_ACS_TIMEOUT=%s, using 120\n' "$acs_timeout" >&2
      acs_timeout=120
      ;;
  esac
  TIMEOUT_PREFIX="timeout $acs_timeout"
fi

pass=0; fail=0; skip=0; failed_acs=""

for idx in "${!acnums[@]}"; do
  acnum="${acnums[$idx]}"; cmd="${accmds[$idx]}"; seen="${acseen[$idx]}"
  if [ "$seen" -eq 0 ]; then
    printf 'AC%s: SKIP (runtime — no check:)\n' "$acnum"
    skip=$((skip + 1))
    continue
  fi
  # T-050 (#132) fail-closed reject: a check: sub-bullet that IS present but
  # whose extracted value is empty or contains only whitespace is a malformed
  # spec-authoring mistake, not a runtime AC — distinct from an AC with no
  # check: sub-bullet at all (SKIP, above, where `seen` is 0). Left unchecked,
  # this would silently reach `bash -c ""` / `bash -c "   "` below, which exits
  # 0, producing a false PASS with no warning (tasks/reviews/T-048.md round1
  # Minor: a check: line with a single trailing space extracts as cmd=" ",
  # which is neither empty nor backtick-wrapped, and used to evaluate to
  # exit 0 silently).
  if [ -z "${cmd//[[:space:]]/}" ]; then
    printf 'AC%s: FAIL (check: sub-bullet is present but its value is empty or whitespace-only — write a real command, or remove the check: line entirely if this AC is runtime-only)\n' "$acnum" >&2
    fail=$((fail + 1))
    failed_acs="${failed_acs} AC${acnum}"
    continue
  fi
  # T-048 (#126) fail-closed reject: a check: value wrapped in a single
  # matching pair of backticks (the FIRST character AND the LAST character
  # are both a backtick) would be run below via `bash -c "$cmd"` as a bare
  # command substitution — bash runs the enclosed command, then tries to
  # execute whatever it printed to stdout as a NEW command line, producing a
  # false FAIL for any check whose success path prints a confirmation
  # message (see the TRUST BOUNDARY note above; tasks/reviews/T-046.md
  # round1's Major finding). Deliberately narrow (first-char AND last-char
  # only) so a check: value that legitimately contains a backtick somewhere
  # in the MIDDLE of an otherwise-unwrapped command (e.g.
  # docs/specs/T-037-review-response.md's regex-alternation check) is never
  # rejected. No automatic stripping — reject and surface the authoring
  # mistake instead of silently rewriting the author's text.
  #
  # T-048 rework1 (#126, tasks/reviews/T-048.md round1 Major): CHECK_RE's
  # own `(.+)$` capture keeps any TRAILING whitespace on $cmd verbatim (only
  # LEADING whitespace after `check:` is stripped by the regex itself) — a
  # backtick-wrapped value with so much as one trailing space/tab (markdown
  # hard-break convention, editor auto-format, accidental copy/paste) had
  # `${cmd: -1}` land on that whitespace, not a backtick, so the check above
  # used to silently miss it and fall through to `bash -c`, reproducing the
  # exact false-FAIL bug this task exists to close. The detection below runs
  # against `cmd_detect`, a RIGHT-TRIMMED COPY used ONLY for this backtick
  # check — `cmd` itself (what actually reaches `bash -c "$cmd"` below) is
  # never modified, so a genuinely non-wrapped command with trailing
  # whitespace still executes byte-identical to what the author wrote (no
  # automatic stripping of the executed text — see the Non-goals note above).
  cmd_detect="${cmd%"${cmd##*[![:space:]]}"}"
  if [ "${cmd_detect:0:1}" = '`' ] && [ "${cmd_detect: -1}" = '`' ]; then
    printf 'AC%s: FAIL (check: value is wrapped in a single matching backtick pair, which bash would run as command substitution and misevaluate — write a raw command with no wrapping backticks, per the T-044/T-045 convention; see bin/check-acs.sh TRUST BOUNDARY note)\n' "$acnum" >&2
    fail=$((fail + 1))
    failed_acs="${failed_acs} AC${acnum}"
    continue
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'AC%s: DRY-RUN would execute: %s\n' "$acnum" "$cmd"
    continue
  fi
  printf 'AC%s: running: %s\n' "$acnum" "$cmd"
  set +e
  # Intentional arbitrary execution of the spec's vetted, read-only check
  # command, run from $ROOT (the caller's cwd, or --root). See the TRUST BOUNDARY note above.
  # shellcheck disable=SC2086  # TIMEOUT_PREFIX is "timeout N" or empty — intentional split.
  out="$( cd "$ROOT" && $TIMEOUT_PREFIX bash -c "$cmd" 2>&1 )"
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    printf 'AC%s: PASS (exit 0)\n' "$acnum"
    pass=$((pass + 1))
  else
    printf 'AC%s: FAIL (exit %s)\n' "$acnum" "$rc"
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/  | /'
    fail=$((fail + 1))
    failed_acs="${failed_acs} AC${acnum}"
  fi
done

# ---------------------------------------------------------------------------
# Summary.
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 1 ]; then
  printf '\ncheck-acs: dry-run only — nothing executed, %d unrecognized (%s)\n' "$unrecognized" "$SPEC"
  # T-054 (#135): malformed check: values (empty/whitespace-only, backtick-
  # wrapped) are detected and counted into `fail` ABOVE, before this summary —
  # see the two fail-closed reject blocks in the main loop. A well-formed or
  # runtime-only (all-SKIP) spec must still exit 0 here (the "preview only"
  # guarantee is unchanged); only a genuinely malformed spec-authoring mistake
  # makes --dry-run non-zero, matching normal-mode's existing fail-closed exit.
  #
  # T-110 (DP-1/DP-2): an unrecognized AC label line takes priority over the
  # malformed-check: fail path below and is reported as exit 2 (not 1) —
  # even under --dry-run, matching T-054's own posture ("dry-run does not
  # hide malformed specs").
  if [ "$unrecognized" -gt 0 ]; then
    printf 'check-acs: dry-run FAILED (unrecognized AC label line(s) detected — see diagnostics above)\n' >&2 || true
    exit 2
  fi
  if [ "$fail" -gt 0 ]; then
    printf 'check-acs: dry-run FAILED (malformed check: value(s) detected):%s\n' "$failed_acs" >&2 || true
    exit 1
  fi
  exit 0
fi

printf '\ncheck-acs: %d passed, %d failed, %d skipped, %d unrecognized (%s)\n' "$pass" "$fail" "$skip" "$unrecognized" "$SPEC"
# T-110 (DP-1): an unrecognized AC label line takes priority over a plain
# check: FAIL and is reported as exit 2 regardless of $fail's value.
if [ "$unrecognized" -gt 0 ]; then
  printf 'check-acs: FAILED (unrecognized AC label line(s) detected — see diagnostics above)\n' >&2 || true
  exit 2
fi
if [ "$fail" -gt 0 ]; then
  printf 'check-acs: FAILED:%s\n' "$failed_acs" >&2 || true
  exit 1
fi
exit 0
