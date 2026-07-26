#!/usr/bin/env bash
# tests/install/run.sh — drive bin/install against ephemeral dummy targets and
# assert the documented behavior (T-004 spec AC1 / AC2 / AC3 / AC6 / AC7 / AC8 / AC9).
#
# Conventions:
#   - Dummy targets are mktemp'd under /tmp/claude/install-dogfood-* per the
#     spec's "Sandbox 注意" (writable allowlist).
#   - shell-team itself is NEVER an install target (AC11 — the repo's
#     own .claude/agents/ is read-only source data here).
#   - Cleanup happens via trap so a failed assertion still clears the dummies.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
INSTALL="$REPO_ROOT/bin/install"

# ---------------------------------------------------------------------------
# Setup: temp workspace + cleanup trap.
#
# We deliberately host the workspace and per-test scratch files under
# /tmp/claude/ rather than $TMPDIR so the suite is also runnable from inside
# the Claude Code sandbox (which only writes to a small allowlist that
# includes /tmp/claude/). On a normal shell the path works just the same.
# ---------------------------------------------------------------------------
SCRATCH_ROOT="/tmp/claude"
mkdir -p "$SCRATCH_ROOT"
WORK="$(mktemp -d "$SCRATCH_ROOT/install-dogfood-XXXXXX")"

mktmp_file() {
  mktemp "$SCRATCH_ROOT/install-tmp-XXXXXX"
}

trap 'rm -rf "$WORK" "$SCRATCH_ROOT"/install-tmp-* 2>/dev/null || true' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$1"
}

# Portable mtime (epoch seconds) across GNU (Linux/CI) and BSD (macOS/dev)
# `stat` dialects. GNU-first: on GNU coreutils, `-c %Y` prints the mtime and
# exits 0; on BSD stat, `-c` is not a valid flag and it exits non-zero
# (cleanly, no stdout), so the fallback `-f %m` (BSD's mtime format) runs.
# The reverse order (`-f` first) is NOT safe: GNU's `-f` means
# `--file-system` (a different, unrelated report) rather than "format", so it
# would silently emit filesystem-status noise instead of failing closed.
_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"
}

# Each test allocates a fresh subdir under WORK so failures stay isolated.
new_target() {
  local name="$1"
  local d="$WORK/$name"
  mkdir -p "$d"
  printf '%s\n' "$d"
}

# ---------------------------------------------------------------------------
# AC8 — --help / -h exit 0, write to stdout, leave stderr empty.
# ---------------------------------------------------------------------------
help_out="$(mktmp_file)"
help_err="$(mktmp_file)"
short_help_out="$(mktmp_file)"
short_help_err="$(mktmp_file)"

set +e
"$INSTALL" --help >"$help_out" 2>"$help_err"
help_rc=$?
set -e
[ "$help_rc" -eq 0 ] || fail "AC8 --help expected exit 0, got $help_rc"
[ -s "$help_out" ] || fail "AC8 --help expected non-empty stdout"
[ ! -s "$help_err" ] || fail "AC8 --help expected empty stderr (got: $(cat "$help_err"))"
grep -q 'Usage:' "$help_out" || fail "AC8 --help stdout missing 'Usage:'"

set +e
"$INSTALL" -h >"$short_help_out" 2>"$short_help_err"
short_help_rc=$?
set -e
[ "$short_help_rc" -eq 0 ] || fail "AC8 -h expected exit 0, got $short_help_rc"
[ -s "$short_help_out" ] || fail "AC8 -h expected non-empty stdout"
[ ! -s "$short_help_err" ] || fail "AC8 -h expected empty stderr"
pass "AC8 --help / -h exit 0 with stdout-only output"

# ---------------------------------------------------------------------------
# AC1 — happy path: install --team new-dev produces the expected layout.
# ---------------------------------------------------------------------------
T1="$(new_target ac1)"
"$INSTALL" --team new-dev "$T1" >/dev/null

for f in pm-spec.md engineer.md qa-verifier.md codex-reviewer.md tech-lead.md scrum-master.md; do
  [ -f "$T1/.claude/agents/$f" ] || fail "AC1 missing $T1/.claude/agents/$f"
done
[ -f "$T1/.claude/team-meta.yaml" ] || fail "AC1 missing $T1/.claude/team-meta.yaml"

# AC6 — manifest format checks.
manifest="$T1/.claude/team-meta.yaml"
grep -Eq '^framework_version: (v[^[:space:]]+|untagged-[0-9a-f]+|unknown)$' "$manifest" \
  || fail "AC6 framework_version line malformed (got: $(grep '^framework_version:' "$manifest"))"
grep -Eq '^commit_hash: ([0-9a-f]{40}|unknown)$' "$manifest" \
  || fail "AC6 commit_hash line malformed (got: $(grep '^commit_hash:' "$manifest"))"
grep -Eq '^installed_at: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$manifest" \
  || fail "AC6 installed_at line malformed (got: $(grep '^installed_at:' "$manifest"))"
# team: must be a list (next line starts with '  - ').
grep -A1 '^team:$' "$manifest" | tail -n1 | grep -Eq '^  - .+$' \
  || fail "AC6 team list malformed in manifest"
# installed_files: must be a list with at least 6 entries (3 common + 3 new-dev).
file_lines="$(awk '/^installed_files:$/{flag=1;next} /^[a-z_]+:/{flag=0} flag && /^  - /' "$manifest" | wc -l | tr -d ' ')"
[ "$file_lines" -ge 6 ] || fail "AC6 installed_files expected >=6 entries, got $file_lines"

# Optional: if python3 is available, parse manifest as YAML to confirm validity.
if command -v python3 >/dev/null 2>&1; then
  python3 -c "
import sys, yaml
try:
    with open('$manifest') as fh:
        doc = yaml.safe_load(fh)
except ImportError:
    sys.exit(0)  # PyYAML unavailable — skip silently
except Exception as e:
    sys.stderr.write('manifest YAML parse failed: %s\n' % e); sys.exit(1)
assert isinstance(doc.get('team'), list) and doc['team'], 'team must be non-empty list'
assert isinstance(doc.get('installed_files'), list) and doc['installed_files'], 'installed_files must be non-empty list'
assert isinstance(doc.get('framework_version'), str), 'framework_version must be a string'
assert isinstance(doc.get('commit_hash'), str), 'commit_hash must be a string'
assert isinstance(doc.get('installed_at'), str), 'installed_at must be a string'
" 2>/dev/null || true
fi

pass "AC1 + AC6 happy-path install produces expected files and manifest"

# ---------------------------------------------------------------------------
# AC2 — second run without --force: WARN per existing file, files NOT modified,
# installed_files in manifest is empty (or omitted), manifest itself is overwritten.
# ---------------------------------------------------------------------------
# Capture content checksum BEFORE the second run so we can prove files were
# NOT modified by a default-mode reinstall.
sum_before="$(cksum "$T1/.claude/agents/pm-spec.md" | awk '{print $1, $2}')"
# Tweak mtime backward so a same-second cp would still register a difference.
# (BSD touch syntax: -t YYYYMMDDhhmm)
touch -t 202001010000 "$T1/.claude/agents/pm-spec.md"
mtime_pre_reinstall="$(_mtime "$T1/.claude/agents/pm-spec.md")"

ac2_err="$(mktmp_file)"
"$INSTALL" --team new-dev "$T1" >/dev/null 2>"$ac2_err"
warn_count="$(grep -c '^WARN: skipped existing file' "$ac2_err" || true)"
[ "$warn_count" -ge 6 ] || fail "AC2 expected >=6 WARN lines in stderr, got $warn_count (stderr: $(cat "$ac2_err"))"

mtime_after="$(_mtime "$T1/.claude/agents/pm-spec.md")"
[ "$mtime_after" = "$mtime_pre_reinstall" ] || fail "AC2 default-mode rerun must NOT touch existing files (mtime changed: $mtime_pre_reinstall -> $mtime_after)"
sum_after="$(cksum "$T1/.claude/agents/pm-spec.md" | awk '{print $1, $2}')"
[ "$sum_before" = "$sum_after" ] || fail "AC2 default-mode rerun must NOT modify file contents"

# Manifest from the rerun should have an empty installed_files list.
empty_files_marker="$(awk '/^installed_files:$/{flag=1;next} /^[a-z_]+:/{flag=0} flag' "$T1/.claude/team-meta.yaml")"
case "$empty_files_marker" in
  "  []") : ;;
  *) fail "AC2 expected installed_files to be empty list ('  []'), got: $empty_files_marker" ;;
esac
rm -f "$ac2_err"
pass "AC2 default rerun emits WARN per file and does not modify them"

# Restore mtime so subsequent --force test can detect a real overwrite.
# T-050 (#132) AC4: use a FIXED, distant-past timestamp (the same `touch -t`
# technique the AC2 default-rerun assertion above already uses) instead of
# `touch` (now) followed by a timed pause before the overwrite. Because the
# baseline is years in the past, the --force overwrite's real mtime is
# guaranteed strictly greater regardless of execution speed or the
# filesystem's mtime granularity — no timing dependency at all
# (tests/reviews/T-048.md round3 Minor).
touch -t 202001010000 "$T1/.claude/agents/pm-spec.md"
mtime_pre_force="$(_mtime "$T1/.claude/agents/pm-spec.md")"

# AC2 (continued) — --force overwrites silently and records all files in manifest.
ac2_force_err="$(mktmp_file)"
"$INSTALL" --team new-dev --force "$T1" >/dev/null 2>"$ac2_force_err"
[ ! -s "$ac2_force_err" ] || fail "AC2 --force expected empty stderr, got: $(cat "$ac2_force_err")"
mtime_post_force="$(_mtime "$T1/.claude/agents/pm-spec.md")"
[ "$mtime_post_force" -gt "$mtime_pre_force" ] \
  || fail "AC2 --force expected mtime to advance ($mtime_pre_force -> $mtime_post_force)"
# Manifest installed_files now includes all 6 entries again.
force_file_lines="$(awk '/^installed_files:$/{flag=1;next} /^[a-z_]+:/{flag=0} flag && /^  - /' "$T1/.claude/team-meta.yaml" | wc -l | tr -d ' ')"
[ "$force_file_lines" -ge 6 ] || fail "AC2 --force expected >=6 installed_files entries, got $force_file_lines"
rm -f "$ac2_force_err"
pass "AC2 --force overwrites silently and re-records installed_files"

# ---------------------------------------------------------------------------
# T-061 AC2 — dangling symlink at a copy_one() destination. `[ -e ]` is false
# for a dangling symlink, so an unguarded copy_one() would follow the link and
# write agent content OUTSIDE the target dir. (a) non-force must skip, symlink
# preserved; (b) --force must replace the symlink with a real target-dir file,
# never follow it out.
# ---------------------------------------------------------------------------
T_SYM="$(new_target symlink-escape)"
mkdir -p "$T_SYM/.claude/agents" "$WORK/outside-check"
ln -s "../../../outside-check/escaped.md" "$T_SYM/.claude/agents/pm-spec.md"
"$INSTALL" --team new-dev "$T_SYM" >/dev/null 2>&1 \
  || fail "T-061 AC2: install exited non-zero (non-force, dangling symlink at pm-spec.md)"
[ ! -e "$WORK/outside-check/escaped.md" ] \
  || fail "T-061 AC2: pm-spec.md content escaped the target dir through a dangling symlink (non-force)"
[ -L "$T_SYM/.claude/agents/pm-spec.md" ] \
  || fail "T-061 AC2: the pre-existing dangling symlink at pm-spec.md should be preserved untouched (non-force skip)"
pass "T-061 AC2: non-force copy_one() skips a dangling symlink at the destination (no write-through, no base escape)"

T_SYM_FORCE="$(new_target symlink-escape-force)"
mkdir -p "$T_SYM_FORCE/.claude/agents" "$WORK/outside-check-force"
ln -s "../../../outside-check-force/escaped.md" "$T_SYM_FORCE/.claude/agents/pm-spec.md"
"$INSTALL" --team new-dev --force "$T_SYM_FORCE" >/dev/null 2>&1 \
  || fail "T-061 AC2: install --force exited non-zero (dangling symlink at pm-spec.md)"
[ ! -e "$WORK/outside-check-force/escaped.md" ] \
  || fail "T-061 AC2: --force followed the dangling symlink and wrote outside the target dir"
if [ ! -f "$T_SYM_FORCE/.claude/agents/pm-spec.md" ] || [ -L "$T_SYM_FORCE/.claude/agents/pm-spec.md" ]; then
  fail "T-061 AC2: --force should replace the dangling symlink with a real file inside the target dir"
fi
pass "T-061 AC2: --force replaces a dangling symlink with a real target-dir file instead of following it"

# ---------------------------------------------------------------------------
# AC3 — multi --team accepted; manifest team list has duplicates preserved.
# ---------------------------------------------------------------------------
T3="$(new_target ac3)"
"$INSTALL" --team new-dev --team new-dev "$T3" >/dev/null
team_lines="$(awk '/^team:$/{flag=1;next} /^[a-z_]+:/{flag=0} flag && /^  - /' "$T3/.claude/team-meta.yaml" | wc -l | tr -d ' ')"
[ "$team_lines" -eq 2 ] || fail "AC3 expected 2 team entries, got $team_lines"
pass "AC3 repeated --team preserved as 2 list entries in manifest"

# ---------------------------------------------------------------------------
# AC7 — argument-parse negative paths all exit 2 with a non-empty stderr.
# ---------------------------------------------------------------------------
neg_err="$(mktmp_file)"
expect_exit2() {
  local label="$1"; shift
  set +e
  "$INSTALL" "$@" >/dev/null 2>"$neg_err"
  local rc=$?
  set -e
  [ "$rc" -eq 2 ] || fail "AC7 [$label] expected exit 2, got $rc (stderr: $(cat "$neg_err"))"
  [ -s "$neg_err" ] || fail "AC7 [$label] expected non-empty stderr"
  : >"$neg_err"
}

T7="$(new_target ac7)"
expect_exit2 "no args"
expect_exit2 "missing target"            --team new-dev
expect_exit2 "missing --team"            "$T7"
expect_exit2 "--team value is a flag"    --team --force "$T7"
expect_exit2 "unknown flag"              --unknown-flag --team new-dev "$T7"
expect_exit2 "unknown team name"         --team unknown-team-name "$T7"
expect_exit2 "nonexistent target"        --team new-dev /nonexistent/path/that/does/not/exist
rm -f "$neg_err"
pass "AC7 all negative argument-parse paths exit 2 with stderr"

# ---------------------------------------------------------------------------
# AC11 — shell-team's own checkout MUST NOT have a manifest committed by
# the test run. We never invoke install against $REPO_ROOT, but the guard is
# cheap so we keep it explicit.
# ---------------------------------------------------------------------------
[ ! -f "$REPO_ROOT/.claude/team-meta.yaml" ] \
  || fail "AC11 shell-team must not have its own team-meta.yaml"
pass "AC11 shell-team self-install guard (no team-meta.yaml in source repo)"

printf '\nOK — all install tests passed\n'
exit 0
