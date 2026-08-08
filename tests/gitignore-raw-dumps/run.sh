#!/usr/bin/env bash
# run.sh — lock suite for this repo's raw-review-dump ignore coverage (T-112,
# GitHub issue #6 Layer 1 item 2; docs/specs/T-112-commit-identity-and-ignore-lock.md).
#
# Item 2 is a LOCK, not a design (spec Non-goals): the raw-review-dump and
# `.codex-review.json` ignore coverage already ships in this repo's own
# `/.gitignore`, alongside the pre-existing `runs/` / `.codex-capture.*`
# coverage in `.shell-team/.gitignore` that tests/rollup-track/run.sh already
# locks (this suite deliberately does not duplicate that — spec Non-goals).
# Both `.gitignore` files stay byte-unchanged; this suite only proves that if
# someone removes a pattern, a suite fails.
#
# Structure mirrors tests/rollup-track/run.sh's existing three-check idiom
# (this repo's real config under a hostile core.excludesFile, a control
# proving the hostile file has teeth, plus the negative "curated notes are
# NOT ignored" check) applied to the reviews dir instead of the rollups dir.
#
# Operating paths are resolved through bin/team-paths.sh — the reviews dir is
# never hardcoded as `.shell-team/reviews`. The raw-review-dump patterns this
# suite locks are specific to THIS repo's own default-layout root .gitignore
# (a self-hosting addition, not part of the shared, layout-agnostic
# `templates/shell-team.gitignore`, which only ships `runs/` and
# `reviews/.codex-capture.*`). So the legacy-layout coverage below is a
# resolver-correctness check — proving the suite derives the reviews dir
# dynamically per layout rather than assuming one hardcoded string — not a
# claim that a legacy-layout repo ships the same raw-dump patterns; inventing
# a new legacy ignore file is out of scope (spec Non-goals: "Designing new
# .gitignore patterns").
#
# Uses mktemp under $TMPDIR (repo lesson, 2026-06-16 / T-038) — no process
# substitution, cmp -s instead of diff <(...).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
TEAM_PATHS="$REPO_ROOT/bin/team-paths.sh"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/gitignore-raw-dumps.XXXXXX")"
# shellcheck disable=SC2329  # invoked indirectly via the EXIT trap below
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# =============================================================================
# resolver derivation (AC19): never hardcode `.shell-team/reviews` — derive it
# from bin/team-paths.sh for the default layout (this repo, as checked out),
# and separately for a legacy-layout fixture.
# =============================================================================
REVIEWS_DIR="$(bash "$TEAM_PATHS" --root "$REPO_ROOT" --get reviews)"
if [ "$REVIEWS_DIR" = ".shell-team/reviews" ]; then
  pass "resolver: team-paths.sh reports the default-layout reviews dir (.shell-team/reviews)"
else
  fail "resolver: expected default-layout reviews dir .shell-team/reviews, got: $REVIEWS_DIR"
fi

LEGACY_ROOT="$WORK/legacy-layout"
mkdir -p "$LEGACY_ROOT/tasks/loops"
: > "$LEGACY_ROOT/tasks/loops/shell-team.contract.yaml"
LEGACY_REVIEWS_DIR="$(bash "$TEAM_PATHS" --root "$LEGACY_ROOT" --get reviews)"
if [ "$LEGACY_REVIEWS_DIR" = "tasks/reviews" ]; then
  pass "legacy layout: team-paths.sh resolves the reviews dir to tasks/reviews"
else
  fail "legacy layout: expected tasks/reviews, got: $LEGACY_REVIEWS_DIR"
fi

# =============================================================================
# lock: raw review dumps are ignored / lock: codex-review json dump is
# ignored / lock: curated review notes are NOT ignored (AC18)
#
# `git check-ignore` consults the operator's global core.excludesFile, so
# every assertion below pins that input explicitly instead of inheriting it
# (same reasoning tests/rollup-track/run.sh documents): an operator who
# ignores `.shell-team/` globally — a reasonable thing to do — must still see
# these patterns survive via the root .gitignore's `!.shell-team/`
# re-include, and this suite must be meaningful on a bare CI runner too.
# =============================================================================
printf '.shell-team/\n' > "$WORK/hostile-excludes"

if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  raw_dump_ok=1
  for ext in txt json jsonl; do
    if ! git -C "$REPO_ROOT" -c core.excludesFile="$WORK/hostile-excludes" \
         check-ignore -q "$REVIEWS_DIR/dummy.$ext"; then
      raw_dump_ok=0
      fail "lock: raw review dumps are ignored ($REVIEWS_DIR/dummy.$ext should be ignored, is not)"
    fi
  done
  if [ "$raw_dump_ok" -eq 1 ]; then
    pass "lock: raw review dumps are ignored ($REVIEWS_DIR/*.txt, *.json, *.jsonl)"
  fi

  if git -C "$REPO_ROOT" -c core.excludesFile="$WORK/hostile-excludes" \
       check-ignore -q ".codex-review.json"; then
    pass "lock: codex-review json dump is ignored"
  else
    fail "lock: codex-review json dump is ignored (.codex-review.json should be ignored, is not)"
  fi

  if git -C "$REPO_ROOT" -c core.excludesFile="$WORK/hostile-excludes" \
       check-ignore -q "$REVIEWS_DIR/T-100.md"; then
    fail "lock: curated review notes are NOT ignored ($REVIEWS_DIR/T-100.md must not be ignored, but is)"
  else
    pass "lock: curated review notes are NOT ignored ($REVIEWS_DIR/*.md)"
  fi
else
  printf 'SKIP: this repo .gitignore check (no .git dir found at %s)\n' "$REPO_ROOT"
fi

# =============================================================================
# control: hostile excludesFile has teeth (proves the checks above are not
# vacuously true because the hostile file was silently ineffective) —
# mirrors tests/rollup-track/run.sh's control repo, with NO re-include.
# =============================================================================
CONTROL_REPO="$WORK/gitignore-control"
mkdir -p "$CONTROL_REPO"
( cd "$CONTROL_REPO" && git init -q )
CONTROL_REVIEWS_DIR="$(bash "$TEAM_PATHS" --root "$CONTROL_REPO" --get reviews)"

if git -C "$CONTROL_REPO" -c core.excludesFile="$WORK/hostile-excludes" \
     check-ignore -q "$CONTROL_REVIEWS_DIR/dummy.md"; then
  pass "control: hostile excludesFile has teeth (so the re-include checks above are not vacuous)"
else
  fail "control: the hostile excludesFile did not ignore $CONTROL_REVIEWS_DIR — the checks above would pass vacuously"
fi

# =============================================================================
# AC18 (second half): both .gitignore files stay byte-unchanged against
# <base> is asserted at the AC level itself
# (`git diff --quiet develop -- .gitignore .shell-team/.gitignore`), not
# re-asserted here — this suite's job is the ignore-behavior lock above.
# =============================================================================

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'gitignore-raw-dumps suite: all assertions passed\n'
  exit 0
else
  printf 'gitignore-raw-dumps suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
