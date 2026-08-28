#!/usr/bin/env bash
# run.sh — assert bin/check-oversight.sh (T-1103, issue #343) against the
# real script: profile resolution, the occupancy lattice, the approval
# record grammar, the two per-seam anchor comparisons and the sticky
# enrollment scan.
#
# Exit: 0 = every assertion passed; non-zero = a FAIL line was printed.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO_ROOT/bin/check-oversight.sh"

if [ -n "${TMPDIR:-}" ]; then
  T="$(mktemp -d "${TMPDIR%/}/check-oversight-test.XXXXXX")"
else
  T="$(mktemp -d "$HERE/tmp-roots.XXXXXX")"
fi
trap 'rm -rf "$T"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

EM="—"
BT='`'

# bd BASE FILE LINE... — a fixture board at $T/$FILE with one T-000 Active
# entry (flag READY_FOR_ARCH), each LINE as an indented sub-bullet.
bd() {
  local file="$1"; shift
  {
    printf '# Tasks\n\n## Active\n\n'
    printf -- '- [ ] **T-000** Fixture %s %sREADY_FOR_ARCH%s %s spec: docs/specs/fixture.md\n' "$EM" "$BT" "$BT" "$EM"
    for l in "$@"; do printf '  %s\n' "$l"; done
    printf '\n## Done\n'
  } > "$T/$file"
}

# bd_done FILE ACTIVE_LINE... -- DONE_ENTRY... — like bd() but with an
# additional closed T-999 entry under ## Done carrying DONE_LINEs.
bd_done() {
  local file="$1"; shift
  local -a active=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do active+=("$1"); shift; done
  shift || true
  {
    printf '# Tasks\n\n## Active\n\n'
    printf -- '- [ ] **T-000** Fixture %s %sREADY_FOR_ARCH%s %s spec: docs/specs/fixture.md\n' "$EM" "$BT" "$BT" "$EM"
    for l in "${active[@]}"; do printf '  %s\n' "$l"; done
    printf '\n## Done\n\n'
    printf -- '- [x] **T-999** Closed fixture %s %sREADY_FOR_MERGE%s %s spec: docs/specs/other.md\n' "$EM" "$BT" "$BT" "$EM"
    for l in "$@"; do printf '  %s\n' "$l"; done
    printf '\n'
  } > "$T/$file"
}

rec() {  # $1=seam $2=approver $3=producer $4=approves
  printf -- '- oversight-approval (%s): approver=%s %s producer=%s %s approves=%s %s date=2026-08-27 %s record=docs/specs/fixture.md' \
    "$1" "$2" "$EM" "$3" "$EM" "$4" "$EM" "$EM"
}

invoke() {  # remaining args passed straight to the script
  bash "$SCRIPT" "$@" >"$T/out" 2>"$T/err"
  printf '%s' "$?"
}

chk() {  # desc expect_rc [expect_silent(0|1, default: not asserted)]
  local desc="$1" expect="$2" got="$3"
  [ "$got" = "$expect" ] \
    || fail "$desc (expected exit $expect, got $got; stderr: $(cat "$T/err" 2>/dev/null))"
  pass "$desc"
}

conf() {  # DIR LINE... — write $T/DIR/oversight.conf with LINEs
  local dir="$1"; shift
  mkdir -p "$T/$dir"
  {
    for l in "$@"; do printf '%s\n' "$l"; done
  } > "$T/$dir/oversight.conf"
}

# =============================================================================
# 1. The shipped default validates.
# =============================================================================
rc=$(invoke --config "$REPO_ROOT/templates/oversight-default.conf" --print-profile)
[ "$rc" = "0" ] || fail "shipped default: expected exit 0, got $rc"
[ "$(cat "$T/out")" = "profile autonomous" ] || fail "shipped default: stdout must be exactly 'profile autonomous'"
pass "the shipped templates/oversight-default.conf validates and prints 'profile autonomous'"

# =============================================================================
# 2. autonomous is silent at both seams when no declaration exists at all.
# =============================================================================
mkdir -p "$T/absent"
bd board-never.md "- entry-mode: pm-authored"
rc=$(invoke --base "$T/absent" --seam specify-seam --task T-000 --board "$T/board-never.md")
chk "never-enrolled: specify-seam silent under the absent arm" 0 "$rc"
[ ! -s "$T/err" ] || fail "never-enrolled specify-seam must write nothing to stderr"
rc=$(invoke --base "$T/absent" --seam pre-merge --task T-000 --board "$T/board-never.md")
chk "never-enrolled: pre-merge silent under the absent arm" 0 "$rc"
[ ! -s "$T/err" ] || fail "never-enrolled pre-merge must write nothing to stderr"

# =============================================================================
# 3. Occupancy lattice.
# =============================================================================
mkdir -p "$T/occ"
conf occ/regular "schema 1" "profile governance-controlled" "seam specify-seam"
rec_ok="$(rec specify-seam reviewer-01 author-02 v1)"
bd board-occ-yes.md "$rec_ok"
bd board-occ-no.md "- entry-mode: pm-authored"

rc=$(invoke --base "$T/occ/regular" --seam specify-seam --task T-000 --board "$T/board-occ-no.md")
chk "occupancy: a regular governance-controlled file with no record refuses" 1 "$rc"
rc=$(invoke --base "$T/occ/regular" --seam specify-seam --task T-000 --board "$T/board-occ-yes.md")
chk "occupancy: a regular governance-controlled file with a conformant record passes" 0 "$rc"

mkdir -p "$T/occ/real"
conf occ/real "schema 1" "profile governance-controlled" "seam specify-seam"
mv "$T/occ/real/oversight.conf" "$T/occ/real-conf"
mkdir -p "$T/occ/link"
ln -s "$T/occ/real-conf" "$T/occ/link/oversight.conf"
rc=$(invoke --base "$T/occ/link" --seam specify-seam --task T-000 --board "$T/board-occ-yes.md")
chk "occupancy: a live symlink resolving to a regular file is read exactly like a regular file (accepts)" 0 "$rc"

mkdir -p "$T/occ/dir"; mkdir -p "$T/occ/dir/oversight.conf"
rc=$(invoke --base "$T/occ/dir" --seam specify-seam --task T-000 --board "$T/board-occ-no.md")
chk "occupancy: a directory at the config path refuses declaration-occupancy" 2 "$rc"
grep -qF -- 'declaration-occupancy' "$T/err" || fail "directory occupant must name declaration-occupancy"

mkdir -p "$T/occ/dangling"
ln -s "$T/occ/dangling/absent-target" "$T/occ/dangling/oversight.conf"
rc=$(invoke --base "$T/occ/dangling" --seam specify-seam --task T-000 --board "$T/board-occ-no.md")
chk "occupancy: a dangling symlink at the config path refuses declaration-occupancy" 2 "$rc"

if command -v mkfifo >/dev/null 2>&1; then
  mkdir -p "$T/occ/fifo"
  mkfifo "$T/occ/fifo/oversight.conf" 2>/dev/null || true
  if [ -p "$T/occ/fifo/oversight.conf" ]; then
    rc=$(invoke --base "$T/occ/fifo" --seam specify-seam --task T-000 --board "$T/board-occ-no.md")
    chk "occupancy: a FIFO at the config path refuses declaration-occupancy" 2 "$rc"
  else
    pass "occupancy: FIFO case skipped (mkfifo unavailable in this environment)"
  fi
else
  pass "occupancy: FIFO case skipped (mkfifo not on PATH)"
fi

if [ "$(id -u)" != "0" ]; then
  mkdir -p "$T/occ/unreadable"
  conf occ/unreadable "schema 1" "profile governance-controlled" "seam specify-seam"
  chmod 000 "$T/occ/unreadable/oversight.conf"
  rc=$(invoke --base "$T/occ/unreadable" --seam specify-seam --task T-000 --board "$T/board-occ-no.md")
  chmod 644 "$T/occ/unreadable/oversight.conf"
  chk "occupancy: an unreadable regular file refuses declaration-unreadable" 2 "$rc"
  grep -qF -- 'declaration-unreadable' "$T/err" || fail "unreadable occupant must name declaration-unreadable"
else
  pass "occupancy: unreadable-file case skipped (running as root defeats chmod 000)"
fi

# =============================================================================
# 4. Grammar / vocabulary refusals (exit 1), and the closed vocabulary values.
# =============================================================================
mkdir -p "$T/grammar"
grammar_case() {  # desc content expect_token
  local desc="$1"; shift
  local content="$1"; shift
  local token="$1"; shift
  printf '%s' "$content" > "$T/grammar/oversight.conf"
  rc=$(invoke --base "$T/grammar" --seam specify-seam --task T-000 --board "$T/board-occ-no.md")
  [ "$rc" = "1" ] || fail "$desc (expected exit 1, got $rc)"
  grep -qF -- "$token" "$T/err" || fail "$desc (expected token '$token' on stderr, got: $(cat "$T/err"))"
  pass "$desc"
}
grammar_case "grammar: no schema line refuses missing-schema" $'profile autonomous\n' "missing-schema"
grammar_case "grammar: two schema lines refuse duplicate-schema" $'schema 1\nschema 1\nprofile autonomous\n' "duplicate-schema"
grammar_case "grammar: a profile line before schema refuses schema-not-first" $'profile autonomous\nschema 1\n' "schema-not-first"
grammar_case "grammar: an unsupported schema version refuses unsupported-schema" $'schema 2\nprofile autonomous\n' "unsupported-schema"
grammar_case "grammar: an out-of-vocabulary seam name refuses unknown-seam" $'schema 1\nprofile governance-controlled\nseam pre-commit\n' "unknown-seam"
grammar_case "grammar: governance-controlled with zero seam rows refuses no-seam-declared" $'schema 1\nprofile governance-controlled\n' "no-seam-declared"
grammar_case "grammar: a seam row under autonomous refuses seam-under-autonomous" $'schema 1\nprofile autonomous\nseam specify-seam\n' "seam-under-autonomous"
grammar_case "grammar: a duplicated seam row refuses duplicate-seam" $'schema 1\nprofile governance-controlled\nseam specify-seam\nseam specify-seam\n' "duplicate-seam"
grammar_case "grammar: an unknown profile value refuses unknown-profile" $'schema 1\nprofile hybrid\n' "unknown-profile"
grammar_case "grammar: two profile lines refuse duplicate-profile" $'schema 1\nprofile autonomous\nprofile autonomous\n' "duplicate-profile"

# =============================================================================
# 5. Approval-record refusals under a governance-controlled declaration.
# =============================================================================
conf approvalbase "schema 1" "profile governance-controlled" "seam specify-seam"
bd board-noprod.md "- oversight-approval (specify-seam): approver=reviewer-01 $EM approves=v1 $EM date=2026-08-27 $EM record=docs/specs/fixture.md"
bd board-noapp.md  "- oversight-approval (specify-seam): approver=reviewer-01 $EM producer=author-02 $EM date=2026-08-27 $EM record=docs/specs/fixture.md"
bd board-dup.md "$rec_ok" "$rec_ok"
bd board-same.md "- oversight-approval (specify-seam): approver=author-02 $EM producer=author-02 $EM approves=v1 $EM date=2026-08-27 $EM record=docs/specs/fixture.md"

rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-occ-no.md")
chk "approval: no record at all refuses approval-missing" 1 "$rc"
grep -qF -- 'approval-missing' "$T/err" || fail "expected approval-missing token"

rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-noprod.md")
chk "approval: a record missing producer= refuses" 1 "$rc"

rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-noapp.md")
chk "approval: a record missing approves= refuses" 1 "$rc"

rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-dup.md")
chk "approval: two records for the same seam refuse approval-duplicate" 1 "$rc"
grep -qF -- 'approval-duplicate' "$T/err" || fail "expected approval-duplicate token"

rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-same.md")
chk "approval: approver equal to producer refuses approver-equals-producer" 1 "$rc"
grep -qF -- 'approver-equals-producer' "$T/err" || fail "expected approver-equals-producer token"

# =============================================================================
# 6. Case-toggle and padding evasion, and the non-ASCII refusal.
# =============================================================================
bd board-case.md "- oversight-approval (specify-seam): approver=Alice $EM producer=alice $EM approves=v1 $EM date=2026-08-27 $EM record=docs/specs/fixture.md"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-case.md")
chk "handle: case-toggled approver/producer still refuses (ASCII-lowercase normalization)" 1 "$rc"

bd board-pad.md "- oversight-approval (specify-seam): approver=alice $EM producer=alice    $EM approves=v1 $EM date=2026-08-27 $EM record=docs/specs/fixture.md"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-pad.md")
chk "handle: trailing-padded producer still refuses after whitespace stripping" 1 "$rc"

NA="$(printf 'caf\303\251-01')"
bd board-nonascii.md "- oversight-approval (specify-seam): approver=$NA $EM producer=author-02 $EM approves=v1 $EM date=2026-08-27 $EM record=docs/specs/fixture.md"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-nonascii.md")
chk "handle: a non-ASCII byte in a handle refuses bad-handle (never folded)" 1 "$rc"
grep -qF -- 'bad-handle' "$T/err" || fail "expected bad-handle token"
grep -qF -- "$NA" "$T/err" && fail "a refusal must never echo the rejected handle's bytes"

# =============================================================================
# 7. Two-seam plural case with two records on one entry.
# =============================================================================
conf twoseam "schema 1" "profile governance-controlled" "seam specify-seam" "seam pre-merge"
HC="$(cd "$REPO_ROOT" && git rev-parse HEAD)"
bd board-two.md "$(rec specify-seam reviewer-01 author-02 v1)" "$(rec pre-merge reviewer-01 author-02 "$HC")"
rc=$(invoke --base "$T/twoseam" --seam specify-seam --task T-000 --board "$T/board-two.md")
chk "two-seam entry: specify-seam record satisfied independently of the pre-merge record" 0 "$rc"
rc=$(invoke --base "$T/twoseam" --seam pre-merge --task T-000 --board "$T/board-two.md")
chk "two-seam entry: pre-merge record satisfied independently of the specify-seam record" 0 "$rc"

# =============================================================================
# 8. Sticky enrollment: both directions, repository-wide reach, and
#    seam-agnosticism in both directions.
# =============================================================================
bd board-enrolled.md "$rec_ok"

rc=$(invoke --base "$T/absent" --seam specify-seam --task T-000 --board "$T/board-enrolled.md")
chk "sticky: enrolled-then-absent refuses enrollment-vanished" 2 "$rc"
grep -qF -- 'enrollment-vanished' "$T/err" || fail "expected enrollment-vanished token"

conf explicit-auto "schema 1" "profile autonomous"
rc=$(invoke --base "$T/explicit-auto" --seam specify-seam --task T-000 --board "$T/board-enrolled.md")
chk "sticky: an explicit 'profile autonomous' declaration authorizes de-enrollment (passes)" 0 "$rc"

bd_done board-other.md "- entry-mode: pm-authored" -- "$rec_ok"
rc=$(invoke --base "$T/absent" --seam specify-seam --task T-000 --board "$T/board-other.md")
chk "sticky: a record on another (closed) task's entry still refuses for a task carrying none" 2 "$rc"

rc=$(invoke --base "$T/absent" --seam pre-merge --task T-000 --board "$T/board-enrolled.md")
chk "sticky: seam-agnostic direction 1 — a specify-seam record protects the pre-merge absent arm" 2 "$rc"

bd board-pm-only.md "$(rec pre-merge reviewer-01 author-02 "$HC")"
rc=$(invoke --base "$T/absent" --seam specify-seam --task T-000 --board "$T/board-pm-only.md")
chk "sticky: seam-agnostic direction 2 — a pre-merge record protects the specify-seam absent arm" 2 "$rc"

# =============================================================================
# 9. Neither shipped caller passes --base or --config to check-oversight.sh.
# =============================================================================
for f in "$REPO_ROOT/skills/run/SKILL.md" "$REPO_ROOT/bin/close-out.sh"; do
  if grep -F -- 'check-oversight.sh' "$f" | grep -qE -- '--base |--config '; then
    fail "a shipped caller ($f) must never pass --base or --config to check-oversight.sh"
  fi
done
pass "neither shipped caller (skills/run/SKILL.md, bin/close-out.sh) passes --base or --config"

# =============================================================================
# 10. specify-seam anchor: current / stale / ahead, distinct tokens.
# =============================================================================
bd board-v1.md "- intent-hash (v1): $HC" "$(rec specify-seam reviewer-01 author-02 v2)"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-v1.md")
chk "anchor: a ratified re-freeze's current approves=v2 (recorded max + 1) passes" 0 "$rc"

bd board-stale.md "- intent-hash (v1): $HC" "$(rec specify-seam reviewer-01 author-02 v1)"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-stale.md")
chk "anchor: an outdated approves=v1 at a v1->v2 re-freeze refuses approval-stale" 1 "$rc"
grep -qF -- 'approval-stale' "$T/err" || fail "expected approval-stale token"
cp "$T/err" "$T/err-stale"

bd board-ahead.md "$(rec specify-seam reviewer-01 author-02 v999)"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-ahead.md")
chk "anchor: an inflated approves=v999 refuses approval-anchor-ahead under its own distinct token" 1 "$rc"
grep -qF -- 'approval-anchor-ahead' "$T/err" || fail "expected approval-anchor-ahead token"
cmp -s "$T/err-stale" "$T/err" && fail "approval-stale and approval-anchor-ahead must produce distinct stderr"

# =============================================================================
# 11. pre-merge anchor: both reachability arms.
# =============================================================================
conf pmbase "schema 1" "profile governance-controlled" "seam pre-merge"
bd board-pm-ok.md "$(rec pre-merge reviewer-01 author-02 "$HC")"
rc=$(invoke --base "$T/pmbase" --seam pre-merge --task T-000 --board "$T/board-pm-ok.md")
chk "pre-merge anchor: HEAD's own commit id passes" 0 "$rc"

ZC="$(printf '0%.0s' $(seq 1 40))"
bd board-pm-absent.md "$(rec pre-merge reviewer-01 author-02 "$ZC")"
rc=$(invoke --base "$T/pmbase" --seam pre-merge --task T-000 --board "$T/board-pm-absent.md")
chk "pre-merge anchor: an object absent from this repository refuses approval-stale" 1 "$rc"

SHORT="$(printf '%s' "$HC" | cut -c1-39)"
bd board-pm-short.md "$(rec pre-merge reviewer-01 author-02 "$SHORT")"
rc=$(invoke --base "$T/pmbase" --seam pre-merge --task T-000 --board "$T/board-pm-short.md")
chk "pre-merge anchor: a 39-character truncation refuses approval-anchor-malformed" 1 "$rc"
grep -qF -- 'approval-anchor-malformed' "$T/err" || fail "expected approval-anchor-malformed token"

# --- genuine non-ancestor commit: a second commit graph in a scratch repo --
GITROOT="$T/scratch-repo"
mkdir -p "$GITROOT"
(
  cd "$GITROOT"
  git init -q -b trunk .
  git config user.email 'fixture@example.com'
  git config user.name 'fixture'
  printf 'a\n' > a.txt; git add a.txt; git commit -q -m base
  git checkout -q -b side
  printf 'b\n' > b.txt; git add b.txt; git commit -q -m side-branch
  git checkout -q trunk
) >/dev/null 2>&1
OTHER_HC="$(cd "$GITROOT" && git rev-parse side)"
bd board-pm-nonancestor.md "$(rec pre-merge reviewer-01 author-02 "$OTHER_HC")"
(
  cd "$GITROOT"
  rc=$(bash "$SCRIPT" --base "$T/pmbase" --seam pre-merge --task T-000 --board "$T/board-pm-nonancestor.md" >"$T/out" 2>"$T/err"; echo $?)
  printf '%s' "$rc" > "$T/nonancestor-rc"
)
NARC="$(cat "$T/nonancestor-rc")"
[ "$NARC" = "1" ] || fail "pre-merge anchor: a real but non-ancestor commit must refuse approval-stale (got exit $NARC)"
grep -qF -- 'approval-stale' "$T/err" || fail "expected approval-stale token for the non-ancestor case"
pass "pre-merge anchor: a genuine non-ancestor commit (a real object, unreachable from HEAD) refuses approval-stale"

# =============================================================================
# 12. class-M mechanics-repair re-freeze pair (DP-13): not exempted.
# =============================================================================
AR="$(printf '\342\206\222')"
CM_TAIL="- intent-ratified (2026-08-27): v1${AR}v2 $EM class=mechanics; standing grant: operator configuration $EM repairing a broken check line
  - refreeze-class (v1${AR}v2): mechanics $EM trigger=broken-as-command $EM old-hash=$HC $EM lines=1 $EM old[1]: superseded $EM new[1]: replacement $EM evidence: live run"

bd board-cm-ok.md "- intent-hash (v1): $HC" "$(rec specify-seam reviewer-01 author-02 v2)" "$CM_TAIL"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-cm-ok.md")
chk "class-M: a current approves=v2 at a class-M re-freeze passes exactly as at a class-B re-freeze" 0 "$rc"

bd board-cm-stale.md "- intent-hash (v1): $HC" "$(rec specify-seam reviewer-01 author-02 v1)" "$CM_TAIL"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-cm-stale.md")
chk "class-M: a stale approves=v1 at a class-M re-freeze STILL refuses (no class-M exemption)" 1 "$rc"
grep -qF -- 'approval-stale' "$T/err" || fail "expected approval-stale token at the class-M stale case"

# =============================================================================
# 13. Round-2 rework, Blocker 1: the specify-seam anchor equality is bounded
#     BEFORE any arithmetic runs on the untrusted approves= field — the
#     overflow value itself, a 20-digit value, and a leading-zero form.
# =============================================================================
bd board-overflow.md "$(rec specify-seam reviewer-01 author-02 v18446744073709551617)"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-overflow.md")
chk "anchor bound: approves=v18446744073709551617 (wraps 2^64 to 1 under unbounded 10# arithmetic) refuses approval-anchor-malformed" 1 "$rc"
grep -qF -- 'approval-anchor-malformed' "$T/err" || fail "expected approval-anchor-malformed token for the overflow value"

bd board-20digit.md "$(rec specify-seam reviewer-01 author-02 v99999999999999999999)"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-20digit.md")
chk "anchor bound: a 20-digit approves= value refuses approval-anchor-malformed" 1 "$rc"
grep -qF -- 'approval-anchor-malformed' "$T/err" || fail "expected approval-anchor-malformed token for the 20-digit value"

bd board-leadzero.md "$(rec specify-seam reviewer-01 author-02 v01)"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-leadzero.md")
chk "anchor bound: a leading-zero approves=v01 refuses approval-anchor-malformed rather than being read as v1" 1 "$rc"
grep -qF -- 'approval-anchor-malformed' "$T/err" || fail "expected approval-anchor-malformed token for the leading-zero value"

# =============================================================================
# 13b. Round-3 rework (Codex impl-review round 2, fresh Blocker): the
#      specify-seam equality's OTHER operand — MAXV, derived from the
#      board's own `- intent-hash (v<M>):` sub-bullets — is bounded the
#      same way, before ITS `$((10#$v))` conversion runs.
# =============================================================================

# The reviewer's exact live repro: a single oversized intent-hash line with
# no genuine higher entry beside it. Under the pre-fix unbounded capture
# this passed silently (exit 0) because `$((10#18446744073709551617))`
# wraps to 1, making MAXV=1 and EXPECTED=2 — indistinguishable from a
# genuine v1 entry. Must now refuse.
bd board-maxv-overflow.md "- intent-hash (v18446744073709551617): $HC" "$(rec specify-seam reviewer-01 author-02 v2)"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-maxv-overflow.md")
chk "MAXV bound: an oversized intent-hash version (20 digits, wraps 2^64 to 1) refuses intent-hash-malformed rather than exit 0" 1 "$rc"
grep -qF -- 'intent-hash-malformed' "$T/err" || fail "expected intent-hash-malformed token for the oversized intent-hash version"
grep -qF -- '18446744073709551617' "$T/err" && fail "the intent-hash-malformed refusal must not echo the oversized digit string"

# One digit past the ported {1,4} bound (5 digits) — the boundary case.
bd board-maxv-5digit.md "- intent-hash (v99999): $HC" "$(rec specify-seam reviewer-01 author-02 v1)"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-maxv-5digit.md")
chk "MAXV bound: a 5-digit intent-hash version (one past the ported {1,4} bound) refuses intent-hash-malformed" 1 "$rc"
grep -qF -- 'intent-hash-malformed' "$T/err" || fail "expected intent-hash-malformed token for the 5-digit intent-hash version"

# Positive control: a conformant multi-version board (two well-formed
# intent-hash sub-bullets, v1 and v2) still derives MAXV=2 correctly, so a
# ratified approves=v3 passes and a stale approves=v2 still refuses.
bd board-maxv-multi-ok.md "- intent-hash (v1): $HC" "- intent-hash (v2): $HC" "$(rec specify-seam reviewer-01 author-02 v3)"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-maxv-multi-ok.md")
chk "MAXV bound: a conformant two-entry intent-hash board (v1, v2) still derives MAXV=2, and a current approves=v3 passes" 0 "$rc"

bd board-maxv-multi-stale.md "- intent-hash (v1): $HC" "- intent-hash (v2): $HC" "$(rec specify-seam reviewer-01 author-02 v2)"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-maxv-multi-stale.md")
chk "MAXV bound: the same conformant two-entry board still refuses a stale approves=v2 (expected v3)" 1 "$rc"
grep -qF -- 'approval-stale' "$T/err" || fail "expected approval-stale token for the stale case against the multi-entry MAXV"

# =============================================================================
# 14. Round-2 rework, Blocker 2: an em-dash-delimited decoy tail inside
#     record='s own free-form value cannot shift an earlier field's
#     extraction — a conformant record with a decoy-bearing locator still
#     passes, and a genuinely malformed record is not rescued by a decoy.
# =============================================================================
# A single decoy segment (just a trailing "— approves=v999") is NOT
# genuinely ambiguous under a greedy-`.*` extraction: since there is only
# one "date=" and one "record=" substring in the whole line, the regex
# engine has exactly one way to satisfy the fields still required after the
# capture, so it resolves correctly by construction rather than by this
# fix. The decoy below duplicates BOTH "date=" and "record=" (not just
# "approves=") after the real fields, which is what makes the earlier
# fields' extraction genuinely ambiguous under a greedy-backtracking design
# — verified directly against this exact string with three independent
# regex engines (BSD sed, Python `re`, Perl) before this fixture was
# written, each resolving `approves=` to the decoy's `v999` under the
# pre-fix five-independent-greedy-`sed`-pass shape.
DECOY_OK="  - oversight-approval (specify-seam): approver=reviewer-01 $EM producer=author-02 $EM approves=v1 $EM date=2026-08-27 $EM record=docs/specs/fixture.md $EM approves=v999 $EM date=2099-01-01 $EM record=evil.md"
bd board-decoy-ok.md "$DECOY_OK"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-decoy-ok.md")
chk "record forgery: an em-dash decoy tail inside record= (duplicating approves=/date=/record=, the genuinely ambiguous shape under a greedy-.* extraction) does not shift the real approves= — the conformant record still passes" 0 "$rc"

DECOY_BAD="  - oversight-approval (specify-seam): approver=reviewer-01 $EM producer=author-02 $EM date=2026-08-27 $EM record=docs/specs/fixture.md $EM approves=v1"
bd board-decoy-bad.md "$DECOY_BAD"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-decoy-bad.md")
chk "record forgery: a genuinely malformed record (approves= missing from its own slot) is not rescued by a decoy approves= inside record=" 1 "$rc"
grep -qF -- 'approval-malformed' "$T/err" || fail "expected approval-malformed token for the decoy-rescued-malformed case"

# =============================================================================
# 15. Round-2 rework, Major 1: the absent arm genuinely resolves and
#     validates the shipped templates/oversight-default.conf from the
#     SCRIPT'S OWN installed directory, member for member with
#     bin/resolve-executor.sh's absent arm — proven with a scratch bin/ +
#     templates/ pair the real repo's own templates/oversight-default.conf
#     cannot satisfy by accident.
# =============================================================================
mkdir -p "$T/shipped-present/bin" "$T/shipped-present/templates" "$T/shipped-present/absentbase"
cp "$SCRIPT" "$T/shipped-present/bin/check-oversight.sh"
printf 'schema 1\n\nprofile autonomous\n' > "$T/shipped-present/templates/oversight-default.conf"
rc=$(bash "$T/shipped-present/bin/check-oversight.sh" --base "$T/shipped-present/absentbase" --print-profile >"$T/out" 2>"$T/err"; echo $?)
chk "absent arm: a present shipped default (script's own installed dir) resolves and prints its declared profile" 0 "$rc"
[ "$(cat "$T/out")" = "profile autonomous" ] || fail "absent arm: stdout must be exactly 'profile autonomous' from the shipped default"

mkdir -p "$T/shipped-missing/bin" "$T/shipped-missing/absentbase"
cp "$SCRIPT" "$T/shipped-missing/bin/check-oversight.sh"
rc=$(bash "$T/shipped-missing/bin/check-oversight.sh" --base "$T/shipped-missing/absentbase" --print-profile >"$T/out" 2>"$T/err"; echo $?)
chk "absent arm: a missing shipped templates/oversight-default.conf refuses declaration-unreadable (exit 2), never a hardcoded literal" 2 "$rc"
grep -qF -- 'declaration-unreadable' "$T/err" || fail "expected declaration-unreadable token for a missing shipped default"

# =============================================================================
# 16. Round-2 rework, Major 2: approval-malformed never echoes a real-looking
#     handle's bytes — extending the AC12-style no-echo assertion to the
#     grammar-mismatch class it did not previously cover.
# =============================================================================
GRAMMAR_BAD="  - oversight-approval (specify-seam): approver=reviewer-01 producer=author-02 approves=v1 date=2026-08-27 record=docs/specs/fixture.md"
bd board-grammar-handles.md "$GRAMMAR_BAD"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-grammar-handles.md")
chk "no-echo: a grammar-mismatching record (missing EM separators) refuses approval-malformed" 1 "$rc"
grep -qF -- 'approval-malformed' "$T/err" || fail "expected approval-malformed token"
grep -qF -- 'reviewer-01' "$T/err" && fail "approval-malformed must never echo the approver handle's bytes"
grep -qF -- 'author-02' "$T/err" && fail "approval-malformed must never echo the producer handle's bytes"

# =============================================================================
# 17. Round-2 rework, Minor 1: a genuine `git log` failure (an anomalous
#     spec: path) refuses rather than being silently treated as "no commit
#     has touched this path yet" (the legitimate, reachable skip case).
# =============================================================================
mkdir -p "$T/gitfail"
printf 'schema 1\nprofile governance-controlled\nseam pre-merge\n' > "$T/gitfail/oversight.conf"
BOGUS_SPEC=':(bogus)notreal.md'
printf '# Tasks\n\n## Active\n\n- [ ] **T-000** Fixture %s %sREADY_FOR_ARCH%s %s spec: %s\n  %s\n\n## Done\n' \
  "$EM" "$BT" "$BT" "$EM" "$BOGUS_SPEC" "$(rec pre-merge reviewer-01 author-02 "$HC")" > "$T/board-gitfail.md"
rc=$(invoke --base "$T/gitfail" --seam pre-merge --task T-000 --board "$T/board-gitfail.md")
chk "git-log failure: an anomalous spec: path that makes git log itself fail refuses rather than silently skipping the precedence check" 2 "$rc"
grep -qF -- 'git log' "$T/err" || fail "expected the refusal to name the git log failure"

# =============================================================================
# 18. Round-2 rework, Minor 2: date= is validated against its documented
#     YYYY-MM-DD grammar rather than accepted as free text.
# =============================================================================
bd board-baddate.md "- oversight-approval (specify-seam): approver=reviewer-01 $EM producer=author-02 $EM approves=v1 $EM date=not-a-date $EM record=docs/specs/fixture.md"
rc=$(invoke --base "$T/approvalbase" --seam specify-seam --task T-000 --board "$T/board-baddate.md")
chk "date grammar: date=not-a-date refuses approval-malformed" 1 "$rc"
grep -qF -- 'approval-malformed' "$T/err" || fail "expected approval-malformed token for the date grammar violation"

echo "check-oversight suite: all assertions passed"
