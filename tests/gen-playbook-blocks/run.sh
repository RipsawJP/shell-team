#!/usr/bin/env bash
# run.sh — assert bin/gen-playbook-blocks.sh honors the T-045 behavior
# contract (docs/specs/T-045-ace-playbook.md):
#   AC3  regenerates templates/prompt-blocks/playbook-<role>.md + splices
#        registered consumer marker regions; fail-closed on a schema
#        violation in tasks/lessons.md (nothing written); idempotent
#   AC7  injected lines are the Rule field only (no Why / How to apply); a
#        `Status: superseded` entry is excluded
#   AC8  shellcheck clean (soft-skip when unavailable)
#
# Temp roots live under $TMPDIR when set (restricted sandboxes), falling back
# to $HERE/tmp-roots on plain CI runners. Cleaned via trap.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
GEN="$REPO_ROOT/bin/gen-playbook-blocks.sh"
FIX="$HERE/fixtures/root"
if [ -n "${TMPDIR:-}" ]; then
  TMP="$(mktemp -d "${TMPDIR%/}/gen-playbook-blocks-test-roots.XXXXXX")"
else
  TMP="$(mktemp -d "$HERE/tmp-roots.XXXXXX")"
fi

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

trap 'rm -rf "$TMP"' EXIT

clone_fixture() {  # $1 = destination
  # T-1006 DP-6: the fixture tree carries tasks/lessons.md but NO
  # tasks/loops/shell-team.contract.yaml, so bin/team-paths.sh classifies it as
  # the DEFAULT layout (base=.shell-team) rather than legacy. The legacy
  # marker is created here, at runtime, rather than committed into the
  # fixture -- every other suite in this repo does the same (see
  # .shell-team/test-recipe.md's T-1006 entry) -- so every bare `--root`
  # invocation below keeps resolving to tasks/lessons.md exactly as it did
  # before the consumer was wired to the resolver.
  rm -rf "$1"
  cp -R "$FIX" "$1"
  mkdir -p "$1/tasks/loops"
  : > "$1/tasks/loops/shell-team.contract.yaml"
}

# clone_fixture_default_layout $1 = destination
# T-1006 AC3: the same fixture, but on the DEFAULT layout -- no legacy marker,
# and the corpus moved to .shell-team/lessons.md (the resolver's canonical
# default-layout path). Derived at runtime, same reasoning as clone_fixture().
clone_fixture_default_layout() {  # $1 = destination
  rm -rf "$1"
  cp -R "$FIX" "$1"
  mkdir -p "$1/.shell-team"
  mv "$1/tasks/lessons.md" "$1/.shell-team/lessons.md"
  rmdir "$1/tasks"
}

run_gen() {  # $1 = root; prints exit code
  local rc=0
  bash "$GEN" --root "$1" >/dev/null 2>&1 || rc=$?
  printf '%s' "$rc"
}

# --- AC3/AC7: a clean fixture generates the expected per-role content -------
C="$TMP/clean"
clone_fixture "$C"
[ "$(run_gen "$C")" -eq 0 ] || fail "clean fixture must regenerate successfully (exit 0)"

ENG="$C/templates/prompt-blocks/playbook-engineer.md"
QA="$C/templates/prompt-blocks/playbook-qa-verifier.md"
TL="$C/templates/prompt-blocks/playbook-tech-lead.md"
PM="$C/templates/prompt-blocks/playbook-pm-spec.md"

grep -qF 'Engineer rule one.' "$ENG"      || fail "AC3: engineer-only rule missing from playbook-engineer.md"
grep -qF 'All-roles rule two.' "$ENG"     || fail "AC3: an 'all' entry must reach playbook-engineer.md"
grep -qF 'All-roles rule two.' "$QA"      || fail "AC3: an 'all' entry must reach playbook-qa-verifier.md"
grep -qF 'All-roles rule two.' "$TL"      || fail "AC3: an 'all' entry must reach playbook-tech-lead.md"
grep -qF 'All-roles rule two.' "$PM"      || fail "AC3: an 'all' entry must reach playbook-pm-spec.md"
grep -qF 'QA/tech-lead rule four.' "$QA"  || fail "AC3: qa-verifier,tech-lead entry missing from playbook-qa-verifier.md"
grep -qF 'QA/tech-lead rule four.' "$TL"  || fail "AC3: qa-verifier,tech-lead entry missing from playbook-tech-lead.md"
if grep -qF 'QA/tech-lead rule four.' "$ENG"; then
  fail "AC3: an entry NOT applying to engineer must not reach playbook-engineer.md"
fi
if grep -qF 'Engineer rule one.' "$PM"; then
  fail "AC3: an entry NOT applying to pm-spec must not reach playbook-pm-spec.md"
fi
pass "AC3: role filtering (single role / multi-role / 'all') matches Applies-to"

# --- AC7: superseded excluded; Why/How-to-apply never transcribed ------------
for f in "$ENG" "$QA" "$TL" "$PM"; do
  if grep -qF 'Superseded rule three' "$f"; then
    fail "AC7: a Status: superseded entry leaked into $(basename "$f")"
  fi
  if grep -qF 'full prose explanation' "$f"; then
    fail "AC7: Why/How-to-apply prose leaked into $(basename "$f")"
  fi
done
pass "AC7: superseded entries are excluded and Why/How-to-apply are never transcribed"

# --- pointer format: date + heading text accompanies the Rule text ----------
grep -qF 'tasks/lessons.md, 2026-01-01 — Engineer-only active entry' "$ENG" \
  || fail "AC3: injected line must carry a tasks/lessons.md date+heading pointer"
pass "AC3: injected lines carry a tasks/lessons.md date+heading pointer"

# --- T-1006 AC3/AC21: the default layout resolves the lessons path via -----
# bin/team-paths.sh -- no legacy marker, corpus at .shell-team/lessons.md.
C="$TMP/t1006-default-layout"
clone_fixture_default_layout "$C"
[ "$(run_gen "$C")" -eq 0 ] || fail "T-1006: the default-layout fixture must regenerate successfully"
grep -qF '.shell-team/lessons.md, 2026-01-01' "$C/templates/prompt-blocks/playbook-engineer.md" \
  || fail "T-1006: the default-layout pointer must name .shell-team/lessons.md"
if grep -qF 'tasks/lessons.md, 2026-01-01' "$C/templates/prompt-blocks/playbook-engineer.md"; then
  fail "T-1006: the default-layout pointer must not fall back to the legacy tasks/lessons.md literal"
fi
pass "T-1006: the default layout resolves the lessons path via bin/team-paths.sh"

# --- T-1006 AC4/AC21: the legacy layout still resolves tasks/lessons.md ----
# via bin/team-paths.sh -- the no-adopter-file-moves guarantee.
C="$TMP/t1006-legacy-layout"
clone_fixture "$C"
[ "$(run_gen "$C")" -eq 0 ] || fail "T-1006: the legacy-layout fixture must regenerate successfully"
grep -qF 'tasks/lessons.md, 2026-01-01' "$C/templates/prompt-blocks/playbook-engineer.md" \
  || fail "T-1006: the legacy-layout pointer must name tasks/lessons.md"
if grep -qF '.shell-team/lessons.md, 2026-01-01' "$C/templates/prompt-blocks/playbook-engineer.md"; then
  fail "T-1006: the legacy-layout pointer must not resolve to .shell-team/lessons.md"
fi
pass "T-1006: the legacy layout resolves tasks/lessons.md via bin/team-paths.sh"

# --- T-1006 AC6/AC21: a resolver failure is fail-closed (nothing written) --
# Two probes: (a) an invalid $TEAM_RUN_BASE with no --lessons; (b) a sibling
# team-paths.sh stubbed to exit 0 printing nothing (the empty-path hole).
C="$TMP/t1006-fail-closed"
clone_fixture_default_layout "$C"
[ "$(run_gen "$C")" -eq 0 ] || fail "T-1006: fail-closed setup: initial generation must succeed"
[ -f "$C/templates/prompt-blocks/playbook-engineer.md" ] \
  || fail "T-1006: fail-closed setup: anti-vacuity control — the block must exist before it is removed"
rm -f "$C/templates/prompt-blocks/playbook-engineer.md"
rca=0
erra="$(TEAM_RUN_BASE=.. bash "$GEN" --root "$C" 2>&1)" || rca=$?
[ "$rca" -eq 2 ] || fail "T-1006: an invalid \$TEAM_RUN_BASE with no --lessons must exit 2, got $rca"
case "$erra" in
  *"could not resolve the lessons path"*) : ;;
  *) fail "T-1006: invalid \$TEAM_RUN_BASE: expected 'could not resolve the lessons path', got: $erra" ;;
esac
[ ! -e "$C/templates/prompt-blocks/playbook-engineer.md" ] \
  || fail "T-1006: an invalid \$TEAM_RUN_BASE must not generate anything"

STUB_BIN="$TMP/t1006-stub-bin"
rm -rf "$STUB_BIN"
cp -R "$REPO_ROOT/bin" "$STUB_BIN"
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB_BIN/team-paths.sh"
chmod 755 "$STUB_BIN/team-paths.sh"
rcb=0
errb="$(env -u TEAM_RUN_BASE bash "$STUB_BIN/gen-playbook-blocks.sh" --root "$C" 2>&1)" || rcb=$?
[ "$rcb" -eq 2 ] || fail "T-1006: an empty-printing resolver stub must exit 2, got $rcb"
case "$errb" in
  *"could not resolve the lessons path"*) : ;;
  *) fail "T-1006: empty resolver stub: expected 'could not resolve the lessons path', got: $errb" ;;
esac
[ ! -e "$C/templates/prompt-blocks/playbook-engineer.md" ] \
  || fail "T-1006: an empty-printing resolver stub must not generate anything"
pass "T-1006: a resolver failure is fail-closed (nothing written)"

# --- Fix 1 (T-045 rework, Major): a trailing-space Status entry is still ----
# included, not silently dropped. bin/check-playbook.sh trims Status before
# comparing it against its known-enum set, so `- **Status**: active ` (a
# trailing space) validates green; this generator must compare against the
# SAME trimmed form or the entry would vanish from every role's block with
# no warning and no non-zero exit.
C="$TMP/status-trailing-space"
clone_fixture "$C"
sed 's/- \*\*Status\*\*: active$/- **Status**: active /' \
  "$C/tasks/lessons.md" > "$C/tasks/lessons.md.new"
mv "$C/tasks/lessons.md.new" "$C/tasks/lessons.md"
[ "$(run_gen "$C")" -eq 0 ] || fail "a trailing-space (but otherwise schema-valid) Status entry must still generate successfully"
grep -qF 'Engineer rule one.' "$C/templates/prompt-blocks/playbook-engineer.md" \
  || fail "Fix 1: an entry whose Status trims to 'active' must still reach its role's generated block"
pass "Fix 1: an entry with a trailing-space Status value is still included in the generated block (not silently dropped)"

# --- Fix 3 (T-045 rework, Minor): --lessons PATH is reflected in the pointer -
# text, not hardcoded to the literal "tasks/lessons.md".
C="$TMP/custom-lessons-path"
clone_fixture "$C"
cp "$C/tasks/lessons.md" "$C/custom-lessons-name.md"
rm "$C/tasks/lessons.md"
rc=0
bash "$GEN" --root "$C" --lessons "$C/custom-lessons-name.md" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] || fail "gen with a custom --lessons path must succeed"
grep -qF "$C/custom-lessons-name.md, 2026-01-01" "$C/templates/prompt-blocks/playbook-engineer.md" \
  || fail "Fix 3: pointer text must reflect the actual --lessons path, not a hardcoded 'tasks/lessons.md' literal"
if grep -qF 'tasks/lessons.md, 2026-01-01' "$C/templates/prompt-blocks/playbook-engineer.md"; then
  fail "Fix 3: pointer text must NOT fall back to the hardcoded 'tasks/lessons.md' literal when --lessons is given"
fi
pass "Fix 3: a custom --lessons path is reflected in the generated pointer text"

# --- marker splice: outside-marker content is byte-untouched ----------------
grep -qF 'Fixture engineer agent, before the marker.' "$C/agents/engineer.md" \
  || fail "marker splice must not touch content before the BEGIN marker"
grep -qF 'Fixture engineer agent, after the marker.' "$C/agents/engineer.md" \
  || fail "marker splice must not touch content after the END marker"
grep -qF 'Engineer rule one.' "$C/agents/engineer.md" \
  || fail "marker splice must place the generated content inside the marker region"
pass "marker splice keeps content outside the markers byte-untouched"

# --- idempotency: a second run is byte-identical -------------------------------
C2="$TMP/idempotent"
clone_fixture "$C2"
[ "$(run_gen "$C2")" -eq 0 ] || fail "idempotency: first run must succeed"
cp -R "$C2" "$TMP/idempotent-after-1"
[ "$(run_gen "$C2")" -eq 0 ] || fail "idempotency: second run must succeed"
if ! diff -r "$TMP/idempotent-after-1" "$C2" >/dev/null 2>&1; then
  fail "idempotency: a second run on unchanged input must be byte-identical"
fi
pass "AC3: a second run on unchanged tasks/lessons.md is byte-identical (idempotent)"

# --- Round2 Major 1: a non-canonical heading must NEVER let its fields ------
# merge into (and misattribute themselves to) whatever entry was still open —
# reproduces the exact failure mode the review demonstrated: appending a
# malformed heading + a distinctly-named Rule right after a real entry, then
# confirming that Rule text never reaches ANY generated block (the whole run
# is refused via the check-playbook.sh preflight, so nothing is written at
# all — the misattribution can't happen because nothing is generated).
C="$TMP/heading-merge-attempt"
clone_fixture "$C"
printf '\n## 2027-03-01— No space before the em-dash (malformed)\n- **Rule**: RULE_X_SHOULD_NOT_MERGE.\n- **Applies-to**: engineer\n- **Status**: active\n' \
  >> "$C/tasks/lessons.md"
rc="$(run_gen "$C")"
[ "$rc" -eq 1 ] || fail "a malformed heading following a valid entry must exit 1, got $rc"
if [ -e "$C/templates/prompt-blocks/playbook-engineer.md" ]; then
  fail "Round2 Major1: a malformed-heading fixture must not have generated anything"
fi
if grep -rqF 'RULE_X_SHOULD_NOT_MERGE' "$C/templates" "$C/agents" 2>/dev/null; then
  fail "Round2 Major1: the malformed heading's Rule text must never appear anywhere — misattribution reproduced"
fi
pass "Round2 Major1: a malformed heading after a valid entry is refused; its Rule never merges into any generated block"

# --- Round2 Major 2: a NUL byte (0x00) anywhere in tasks/lessons.md aborts --
# the whole run fail-closed (own defense-in-depth check, ahead of the
# check-playbook.sh preflight — see bin/gen-playbook-blocks.sh's own
# has_nul_byte()). Spliced with head/tail (byte-transparent), not sed/awk,
# which would themselves truncate the line at the NUL and defeat the fixture.
C="$TMP/nul-byte-lessons"
clone_fixture "$C"
rule_line_no="$(grep -n -- '- \*\*Rule\*\*: Engineer rule one\.' "$C/tasks/lessons.md" | head -1 | cut -d: -f1)"
{
  head -n "$((rule_line_no - 1))" "$C/tasks/lessons.md"
  printf -- '- **Rule**: before\x00after the NUL byte.\n'
  tail -n "+$((rule_line_no + 1))" "$C/tasks/lessons.md"
} > "$C/tasks/lessons.md.new"
mv "$C/tasks/lessons.md.new" "$C/tasks/lessons.md"
err=""
rc=0
err="$(bash "$GEN" --root "$C" 2>&1)" || rc=$?
[ "$rc" -eq 1 ] || fail "a NUL byte in tasks/lessons.md must exit 1, got $rc"
case "$err" in
  *"contains a NUL byte"*) : ;;
  *) fail "NUL byte: expected reason in stderr, got: $err" ;;
esac
if [ -e "$C/templates/prompt-blocks/playbook-engineer.md" ]; then
  fail "Round2 Major2: a NUL-byte fixture must not have generated anything"
fi
pass "Round2 Major2: a NUL byte anywhere in tasks/lessons.md aborts the whole run fail-closed"

# --- Round3 Major (a)/(b): an unclosed fence (backtick or tilde) must abort --
# the whole run fail-closed — not silently swallow every line after the
# opening marker (including an otherwise-valid entry) with exit 0.
C="$TMP/fence-unclosed-backtick"
clone_fixture "$C"
{
  printf '\n```markdown\nnever closed\n'
  printf '\n## 2027-04-01 — Entry after an unclosed fence\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: RULE_SHOULD_NEVER_GENERATE.\n- **Why**: w\n- **How to apply**: h\n'
} >> "$C/tasks/lessons.md"
rc="$(run_gen "$C")"
[ "$rc" -eq 1 ] || fail "(a) an unclosed backtick fence must exit 1, got $rc"
if [ -e "$C/templates/prompt-blocks/playbook-engineer.md" ]; then
  fail "(a) an unclosed-fence fixture must not have generated anything"
fi
pass "Round3 (a): an unclosed backtick fence (with a valid entry buried after it) aborts the whole run fail-closed"

C="$TMP/fence-unclosed-tilde"
clone_fixture "$C"
{
  printf '\n~~~markdown\nnever closed\n'
  printf '\n## 2027-04-02 — Entry after an unclosed tilde fence\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: RULE_SHOULD_NEVER_GENERATE.\n- **Why**: w\n- **How to apply**: h\n'
} >> "$C/tasks/lessons.md"
rc="$(run_gen "$C")"
[ "$rc" -eq 1 ] || fail "(b) an unclosed tilde fence must exit 1, got $rc"
if [ -e "$C/templates/prompt-blocks/playbook-engineer.md" ]; then
  fail "(b) an unclosed-tilde-fence fixture must not have generated anything"
fi
pass "Round3 (b): an unclosed tilde fence (with a valid entry buried after it) aborts the whole run fail-closed"

# --- Round3 Major (c): a tilde fence wrapping a fake heading + all 7 fields -
# is correctly treated as fence content — the exact bypass the review
# reproduced (content reaching a generated block without ever going through
# bin/playbook-promote.sh's human-approval gate) must not recur: the fake
# Rule must never appear in ANY generated block.
C="$TMP/fence-tilde-fake-entry"
clone_fixture "$C"
{
  printf '\n~~~markdown\n'
  printf '## 2099-01-01 — Fake heading inside tilde fence\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: FAKE_RULE_SHOULD_NOT_BE_INJECTED.\n- **Why**: w\n- **How to apply**: h\n'
  printf '~~~\n'
} >> "$C/tasks/lessons.md"
rc="$(run_gen "$C")"
[ "$rc" -eq 0 ] || fail "(c) a tilde-fenced fake entry must not itself break generation, got exit $rc"
if grep -rqF 'FAKE_RULE_SHOULD_NOT_BE_INJECTED' "$C/templates" "$C/agents" 2>/dev/null; then
  fail "(c) the tilde-fenced fake Rule must never appear in any generated block — human-approval-gate bypass reproduced"
fi
pass "Round3 (c): a tilde-fenced fake heading + full field set never reaches any generated block"

# --- Round4 (f): a trailing-content pseudo-close (round4 Blocker 1) must ----
# NOT close the fence — a fake entry hidden behind it must never reach any
# generated block, even though the fake entry's own fields are individually
# well-formed (only fence-state correctness, not schema validity, protects it
# here).
C="$TMP/fence-trailing-content"
clone_fixture "$C"
{
  # shellcheck disable=SC2016  # literal backticks (fence markers), not command substitution
  printf '\n```markdown\n```payload-not-a-real-close\n'
  printf '## 2099-01-01 — Fake entry via trailing-content pseudo-close\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: FAKE_RULE_SHOULD_NOT_BE_INJECTED.\n- **Why**: w\n- **How to apply**: h\n'
  printf '```\n'
} >> "$C/tasks/lessons.md"
rc="$(run_gen "$C")"
[ "$rc" -eq 0 ] || fail "(f) a properly-closed fence (with a trailing-content pseudo-close inside) must not itself break generation, got exit $rc"
if grep -rqF 'FAKE_RULE_SHOULD_NOT_BE_INJECTED' "$C/templates" "$C/agents" 2>/dev/null; then
  fail "(f) the trailing-content-pseudo-close fake Rule must never appear in any generated block"
fi
pass "Round4 (f): a trailing-content pseudo-close never lets its hidden fake entry reach any generated block"

# --- Round4 (g): a 1-3-space-indented opening fence (round4 Blocker 2) -----
# must be recognized as a fence — a column-0 fake entry inside it must never
# reach any generated block.
C="$TMP/fence-indented-open"
clone_fixture "$C"
{
  printf '\n   ```markdown\n'
  printf '## 2099-01-01 — Injected from indented fence\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: INDENTED_FENCE_INJECTION_SHOULD_NOT_APPEAR.\n- **Why**: w\n- **How to apply**: h\n'
  printf '   ```\n'
} >> "$C/tasks/lessons.md"
rc="$(run_gen "$C")"
[ "$rc" -eq 0 ] || fail "(g) a 1-3-space-indented fence must not itself break generation, got exit $rc"
if grep -rqF 'INDENTED_FENCE_INJECTION_SHOULD_NOT_APPEAR' "$C/templates" "$C/agents" 2>/dev/null; then
  fail "(g) the indented-fence fake Rule must never appear in any generated block"
fi
pass "Round4 (g): a 1-3-space-indented fence is recognized as a fence; its hidden fake entry never reaches any generated block"

# --- T-047 fast-follow AC5: a TAB-indented fence open/close pair must be ----
# recognized as a fence in the generator too (byte-identical fence functions
# with bin/check-playbook.sh, confirmed via cmp) — a fake entry hidden
# inside must never reach any generated block.
C="$TMP/fence-tab-indented"
clone_fixture "$C"
{
  printf '\n\t```markdown\n'
  printf '## 2099-01-01 — Injected from tab-indented fence\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: TAB_FENCE_INJECTION_SHOULD_NOT_APPEAR.\n- **Why**: w\n- **How to apply**: h\n'
  printf '\t```\n'
} >> "$C/tasks/lessons.md"
rc="$(run_gen "$C")"
[ "$rc" -eq 0 ] || fail "T-047 AC5: a tab-indented fence must not itself break generation, got exit $rc"
if grep -rqF 'TAB_FENCE_INJECTION_SHOULD_NOT_APPEAR' "$C/templates" "$C/agents" 2>/dev/null; then
  fail "T-047 AC5: the tab-indented-fence fake Rule must never appear in any generated block"
fi
pass "T-047 AC5: a tab-indented fence is recognized as a fence; its hidden fake entry never reaches any generated block"

# --- T-047 fast-follow AC2: write_marker() leaves every byte OUTSIDE the ----
# marker pair untouched for a CRLF-terminated consumer AND for a consumer
# missing a final trailing newline (round4 Minor: a prior implementation
# piped the whole file through awk's `print`, which always re-serializes
# with a bare "\n" ORS regardless of the source's own line-ending shape or
# whether the last line had a trailing newline at all). Asserted via `cmp`
# on the marker-EXTERNAL prefix/suffix region, byte-for-byte, before vs.
# after a regenerate run — not merely "the run succeeded".
# NOTE: the marker-INTERNAL region's line count changes across the run (empty
# -> several generated lines), which shifts the END marker's OWN line number
# — so begin_ln/end_ln must be recomputed fresh from each snapshot (before
# vs. after), never reused from a single "before" measurement.
C="$TMP/write-marker-crlf"
clone_fixture "$C"
awk '{ printf "%s\r\n", $0 }' "$C/agents/engineer.md" > "$C/agents/engineer.md.new"
mv "$C/agents/engineer.md.new" "$C/agents/engineer.md"
begin_ln_before="$(grep -n 'BEGIN prompt-block: playbook-engineer' "$C/agents/engineer.md" | head -1 | cut -d: -f1)"
end_ln_before="$(grep -n 'END prompt-block: playbook-engineer' "$C/agents/engineer.md" | head -1 | cut -d: -f1)"
head -n "$begin_ln_before" "$C/agents/engineer.md" > "$TMP/crlf-prefix-before"
tail -n "+$end_ln_before" "$C/agents/engineer.md" > "$TMP/crlf-suffix-before"
[ "$(run_gen "$C")" -eq 0 ] || fail "AC2: a CRLF-terminated consumer must still regenerate successfully"
begin_ln_after="$(grep -n 'BEGIN prompt-block: playbook-engineer' "$C/agents/engineer.md" | head -1 | cut -d: -f1)"
end_ln_after="$(grep -n 'END prompt-block: playbook-engineer' "$C/agents/engineer.md" | head -1 | cut -d: -f1)"
head -n "$begin_ln_after" "$C/agents/engineer.md" > "$TMP/crlf-prefix-after"
tail -n "+$end_ln_after" "$C/agents/engineer.md" > "$TMP/crlf-suffix-after"
cmp -s "$TMP/crlf-prefix-before" "$TMP/crlf-prefix-after" \
  || fail "AC2: a CRLF-terminated consumer's marker-external PREFIX must be byte-untouched"
cmp -s "$TMP/crlf-suffix-before" "$TMP/crlf-suffix-after" \
  || fail "AC2: a CRLF-terminated consumer's marker-external SUFFIX must be byte-untouched"
pass "T-047 AC2: write_marker() leaves a CRLF-terminated consumer's marker-external bytes byte-untouched"

C="$TMP/write-marker-no-trailing-nl"
clone_fixture "$C"
printf '%s' "$(cat "$C/agents/engineer.md")" > "$C/agents/engineer.md.new"
mv "$C/agents/engineer.md.new" "$C/agents/engineer.md"
begin_ln_before="$(grep -n 'BEGIN prompt-block: playbook-engineer' "$C/agents/engineer.md" | head -1 | cut -d: -f1)"
end_ln_before="$(grep -n 'END prompt-block: playbook-engineer' "$C/agents/engineer.md" | head -1 | cut -d: -f1)"
head -n "$begin_ln_before" "$C/agents/engineer.md" > "$TMP/notrail-prefix-before"
tail -n "+$end_ln_before" "$C/agents/engineer.md" > "$TMP/notrail-suffix-before"
[ "$(run_gen "$C")" -eq 0 ] || fail "AC2: a consumer missing a final trailing newline must still regenerate successfully"
begin_ln_after="$(grep -n 'BEGIN prompt-block: playbook-engineer' "$C/agents/engineer.md" | head -1 | cut -d: -f1)"
end_ln_after="$(grep -n 'END prompt-block: playbook-engineer' "$C/agents/engineer.md" | head -1 | cut -d: -f1)"
head -n "$begin_ln_after" "$C/agents/engineer.md" > "$TMP/notrail-prefix-after"
tail -n "+$end_ln_after" "$C/agents/engineer.md" > "$TMP/notrail-suffix-after"
cmp -s "$TMP/notrail-prefix-before" "$TMP/notrail-prefix-after" \
  || fail "AC2: a trailing-newline-less consumer's marker-external PREFIX must be byte-untouched"
cmp -s "$TMP/notrail-suffix-before" "$TMP/notrail-suffix-after" \
  || fail "AC2: a trailing-newline-less consumer's marker-external SUFFIX must be byte-untouched"
last_byte="$(tail -c 1 "$C/agents/engineer.md" | od -An -tx1 | tr -d ' \n')"
[ "$last_byte" != "0a" ] \
  || fail "AC2: a consumer missing a final trailing newline must not gain one after regeneration"
pass "T-047 AC2: write_marker() does not append a trailing newline to a consumer that lacked one"

# --- T-047 fast-follow AC3: --lessons PATH structural check (embedded ------
# newline / reserved marker-literal string) rejected BEFORE any output file
# is written, matching the existing preflight-then-write ordering.
C="$TMP/pointer-path-newline"
clone_fixture "$C"
rc=0
err=""
err="$(bash "$GEN" --root "$C" --lessons "$(printf '%s\nevil' "$C/tasks/lessons.md")" 2>&1)" || rc=$?
[ "$rc" -eq 2 ] || fail "AC3: an embedded newline in --lessons PATH must exit 2, got $rc"
case "$err" in
  *"must not contain an embedded newline"*) : ;;
  *) fail "AC3: embedded-newline --lessons: expected reason in stderr, got: $err" ;;
esac
if [ -e "$C/templates/prompt-blocks/playbook-engineer.md" ]; then
  fail "AC3: an embedded-newline --lessons PATH must not have generated anything"
fi
pass "T-047 AC3: an embedded newline in --lessons PATH is rejected before any output file is written"

C="$TMP/pointer-path-marker"
clone_fixture "$C"
evil_name="$C/evil<!-- BEGIN prompt-block: x -->name.md"
cp "$C/tasks/lessons.md" "$evil_name"
rc=0
err=""
err="$(bash "$GEN" --root "$C" --lessons "$evil_name" 2>&1)" || rc=$?
[ "$rc" -eq 2 ] || fail "AC3: a reserved marker string in --lessons PATH must exit 2, got $rc"
case "$err" in
  *"reserved marker string '<!-- BEGIN prompt-block:'"*) : ;;
  *) fail "AC3: marker-string --lessons: expected reason in stderr, got: $err" ;;
esac
if [ -e "$C/templates/prompt-blocks/playbook-engineer.md" ]; then
  fail "AC3: a marker-collision --lessons PATH must not have generated anything"
fi
pass "T-047 AC3: a reserved marker-literal string in --lessons PATH is rejected before any output file is written"

# --- AC3: schema violation in tasks/lessons.md aborts BEFORE any write -------
# Sub-case A: a totally fresh clone (nothing generated yet) with a broken
# lessons file must leave the canonical block files absent and the consumer
# marker regions empty.
C="$TMP/broken-fresh"
clone_fixture "$C"
sed 's/- \*\*Category\*\*: process/- **Category**: not-a-real-category/' \
  "$C/tasks/lessons.md" > "$C/tasks/lessons.md.new"
mv "$C/tasks/lessons.md.new" "$C/tasks/lessons.md"
rc="$(run_gen "$C")"
[ "$rc" -eq 1 ] || fail "a schema violation in tasks/lessons.md must exit 1, got $rc"
if [ -e "$C/templates/prompt-blocks/playbook-engineer.md" ]; then
  fail "a rejected (never-generated) fixture must not have created playbook-engineer.md"
fi
if ! grep -qF 'Fixture engineer agent, before the marker.' "$C/agents/engineer.md"; then
  fail "a rejected fixture must leave the consumer file untouched"
fi
pass "AC3: a schema violation on a fresh fixture aborts before writing anything (exit 1)"

# Sub-case B: an already-generated fixture, then a schema violation is
# introduced — the previously generated files must remain byte-identical
# (never partially clobbered).
C="$TMP/broken-after-generate"
clone_fixture "$C"
[ "$(run_gen "$C")" -eq 0 ] || fail "broken-after-generate: initial successful generation must succeed"
cp -R "$C" "$TMP/broken-after-generate-snapshot"
sed 's/- \*\*Status\*\*: active/- **Status**: not-a-real-status/' \
  "$C/tasks/lessons.md" > "$C/tasks/lessons.md.new"
mv "$C/tasks/lessons.md.new" "$C/tasks/lessons.md"
rc="$(run_gen "$C")"
[ "$rc" -eq 1 ] || fail "a schema violation after a prior successful generation must exit 1, got $rc"
if ! diff -r "$TMP/broken-after-generate-snapshot/templates" "$C/templates" >/dev/null 2>&1; then
  fail "a rejected re-run must leave the previously generated blocks byte-identical"
fi
if ! diff -r "$TMP/broken-after-generate-snapshot/agents" "$C/agents" >/dev/null 2>&1; then
  fail "a rejected re-run must leave the previously spliced consumers byte-identical"
fi
pass "AC3: a schema violation after a prior successful generation leaves everything byte-identical (no partial clobber)"

# --- marker-shape config errors => exit 2, nothing written -------------------
C="$TMP/marker-missing-end"
clone_fixture "$C"
grep -v 'END prompt-block: playbook-engineer' "$C/agents/engineer.md" > "$C/agents/engineer.md.new"
mv "$C/agents/engineer.md.new" "$C/agents/engineer.md"
[ "$(run_gen "$C")" -eq 2 ] || fail "a missing END marker must exit 2"
if [ -e "$C/templates/prompt-blocks/playbook-engineer.md" ]; then
  fail "a marker-shape config error must abort before any block file is written"
fi
if [ -e "$C/templates/prompt-blocks/playbook-pm-spec.md" ]; then
  fail "a marker-shape error in one role's consumer must block ALL roles from being written (validate-then-write)"
fi
pass "marker-shape error (missing END marker) exits 2 and blocks every role's write, not just the offending one"

C="$TMP/marker-duplicate"
clone_fixture "$C"
printf '<!-- BEGIN prompt-block: playbook-engineer -->\n' >> "$C/agents/engineer.md"
[ "$(run_gen "$C")" -eq 2 ] || fail "a duplicated BEGIN marker must exit 2"
pass "marker-shape error (duplicated BEGIN marker) exits 2"

# --- usage / resolver errors => exit 2 ----------------------------------------
C="$TMP/no-lessons"
clone_fixture "$C"
rm "$C/tasks/lessons.md"
[ "$(run_gen "$C")" -eq 2 ] || fail "a missing lessons file must exit 2"

C="$TMP/no-registry"
clone_fixture "$C"
rm "$C/templates/prompt-blocks/registry.txt"
[ "$(run_gen "$C")" -eq 2 ] || fail "a missing registry must exit 2"

rc=0
bash "$GEN" --root "$TMP/clean" --bogus-flag >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "an unknown flag must exit 2, got $rc"
pass "usage/resolver errors (missing lessons/registry, bad flag) all exit 2"

# --- line-count threshold warning is non-fatal --------------------------------
C="$TMP/threshold"
clone_fixture "$C"
{
  n=1
  while [ "$n" -le 45 ]; do
    printf '\n## 2027-01-%02d — Synthetic bulk entry %d\n' "$((n % 28 + 1))" "$n"
    printf -- '- **Category**: process\n'
    printf -- '- **Applies-to**: engineer\n'
    printf -- '- **Scope**: loop\n'
    printf -- '- **Status**: active\n'
    printf -- '- **Source**: n/a\n'
    printf -- '- **Rule**: Synthetic bulk rule number %d.\n' "$n"
    printf -- '- **Why**: filler\n'
    printf -- '- **How to apply**: filler\n'
    n=$((n + 1))
  done
} >> "$C/tasks/lessons.md"
out=""
rc=0
out="$(bash "$GEN" --root "$C" 2>&1)" || rc=$?
[ "$rc" -eq 0 ] || fail "exceeding the line-count threshold must still exit 0 (warning is non-fatal)"
case "$out" in
  *'warning: playbook-engineer.md is'*) : ;;
  *) fail "expected a non-fatal line-count threshold warning in stderr, got: $out" ;;
esac
pass "a role's block exceeding the line-count threshold prints a non-fatal warning (exit 0)"

# =============================================================================
# T-1007: Scope-typed ledger — the shipping boundary is by Scope, not
# Applies-to (docs/specs/T-1007-scope-typed-ledger.md). The shipped fixture
# ($FIX/tasks/lessons.md) now carries a Scope: maintainer, Applies-to: all
# entry ("Maintainer-scoped all-roles entry") alongside four Scope: loop
# entries — Applies-to: all is load-bearing: it proves the exclusion below is
# by Scope, not by role.
# =============================================================================

# --- T-1007 AC6: maintainer-scoped entries never reach a generated block ----
C="$TMP/t1007-maintainer-excluded"
clone_fixture "$C"
grep -qF 'T1007-LOOP-SENTINEL' "$C/tasks/lessons.md" \
  || fail "T-1007: fixture setup: the loop sentinel must be present in the corpus"
grep -qF 'T1007-MAINTAINER-SENTINEL' "$C/tasks/lessons.md" \
  || fail "T-1007: fixture setup: the maintainer sentinel must be present in the corpus"
[ "$(run_gen "$C")" -eq 0 ] || fail "T-1007: the mixed-scope fixture must generate successfully"
for f in "$C/templates/prompt-blocks/playbook-engineer.md" \
         "$C/templates/prompt-blocks/playbook-qa-verifier.md" \
         "$C/templates/prompt-blocks/playbook-tech-lead.md" \
         "$C/templates/prompt-blocks/playbook-pm-spec.md"; do
  grep -qF 'T1007-LOOP-SENTINEL' "$f" \
    || fail "T-1007: the loop-scoped entry must reach $(basename "$f")"
  if grep -qF 'T1007-MAINTAINER-SENTINEL' "$f"; then
    fail "T-1007: a maintainer-scoped entry (Applies-to: all) must never reach $(basename "$f")"
  fi
done
pass "T-1007: maintainer-scoped entries never reach a generated block"

# --- T-1007 AC8: an all-maintainer corpus yields the no-entries fallback -----
C="$TMP/t1007-all-maintainer"
clone_fixture "$C"
{
  printf '# Lessons\n\n'
  printf '## 2027-02-01 — Only a maintainer entry\n'
  printf -- '- **Category**: process\n- **Applies-to**: all\n- **Scope**: maintainer\n'
  printf -- '- **Bound-in**: CONTRIBUTING.md\n- **Status**: active\n- **Source**: n/a\n'
  printf -- '- **Rule**: T1007_ALL_MAINTAINER_SENTINEL.\n- **Why**: w\n- **How to apply**: h\n'
} > "$C/tasks/lessons.md"
[ "$(run_gen "$C")" -eq 0 ] || fail "T-1007: an all-maintainer corpus must still generate successfully"
for f in "$C/templates/prompt-blocks/playbook-engineer.md" \
         "$C/templates/prompt-blocks/playbook-qa-verifier.md" \
         "$C/templates/prompt-blocks/playbook-tech-lead.md" \
         "$C/templates/prompt-blocks/playbook-pm-spec.md"; do
  grep -qF '(no active entries currently apply to this role)' "$f" \
    || fail "T-1007: an all-maintainer corpus must yield the no-entries fallback in $(basename "$f")"
  if grep -qF 'T1007_ALL_MAINTAINER_SENTINEL' "$f"; then
    fail "T-1007: the sole maintainer entry must never reach $(basename "$f")"
  fi
done
pass "T-1007: an all-maintainer corpus yields the no-entries fallback"

# --- AC8: shellcheck (soft-skip when unavailable) -----------------------------
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$GEN" "$HERE/run.sh" || fail "AC8: scripts must be shellcheck clean"
  pass "AC8: shellcheck clean (generator + test runner)"
else
  printf 'SKIP: AC8 shellcheck not installed locally (CI enforces it)\n'
fi


printf '\nAll gen-playbook-blocks assertions passed.\n'
