#!/usr/bin/env bash
# run.sh — assert bin/check-playbook.sh honors the T-045 behavior contract
# (docs/specs/T-045-ace-playbook.md):
#   AC1  required-field / known-enum / structural (single-line, no control
#        chars, no marker-collision) validation, fail-closed
#   AC5  the real repo's tasks/lessons.md passes (dogfood)
#   AC6  unknown Applies-to role tokens are rejected
#   AC8  shellcheck clean (soft-skip when unavailable)
#
# Mutated fixtures are derived on the fly from fixtures/valid-base.md (sed
# against a temp copy) rather than checked in as near-duplicate files — same
# style as tests/check-prompt-sync/run.sh's clone_fixture + mutate pattern.
#
# Temp files live under $TMPDIR when set (restricted sandboxes), falling back
# to $HERE/tmp-roots on plain CI runners. Cleaned via trap.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CHECKER="$REPO_ROOT/bin/check-playbook.sh"
BASE="$HERE/fixtures/valid-base.md"
if [ -n "${TMPDIR:-}" ]; then
  TMP="${TMPDIR%/}/check-playbook-test-roots"
else
  TMP="$HERE/tmp-roots"
fi

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

rm -rf "$TMP"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"

run_checker() {  # $1 = file; prints exit code
  local rc=0
  bash "$CHECKER" "$1" >/dev/null 2>&1 || rc=$?
  printf '%s' "$rc"
}

run_checker_stderr() {  # $1 = file; prints stderr only
  { bash "$CHECKER" "$1" >/dev/null; } 2>&1 || true
}

# --- AC1 (positive): the pristine fixture is green ---------------------------
[ "$(run_checker "$BASE")" -eq 0 ] || fail "valid-base.md should be green"
pass "AC1: a well-formed lessons file (active + superseded + 'all' applies-to) is green"

# --- usage / unreadable file => exit 2 ---------------------------------------
[ "$(run_checker "$TMP/does-not-exist.md")" -eq 2 ] || fail "missing file must exit 2"
rc=0
bash "$CHECKER" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "no args must exit 2, got $rc"
pass "usage/missing-file errors exit 2"

# --- AC1: missing required fields --------------------------------------------
for field in Category Applies-to Status Source Rule Why 'How to apply'; do
  C="$TMP/missing-${field// /_}.md"
  grep -v -- "- \*\*${field}\*\*: " "$BASE" > "$C"
  rc="$(run_checker "$C")"
  [ "$rc" -eq 1 ] || fail "missing field '$field' must exit 1, got $rc"
  err="$(run_checker_stderr "$C")"
  case "$err" in
    *"missing required field: $field"*) : ;;
    *) fail "missing field '$field': expected reason in stderr, got: $err" ;;
  esac
done
pass "AC1: each missing required field is rejected with a matching reason"

# --- AC1/AC6: unknown enum values --------------------------------------------
C="$TMP/unknown-category.md"
sed 's/- \*\*Category\*\*: process/- **Category**: not-a-real-category/' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "unknown Category value must exit 1"
case "$(run_checker_stderr "$C")" in
  *"unknown Category value"*) : ;;
  *) fail "unknown Category: expected reason in stderr" ;;
esac
pass "AC1: unknown Category value is rejected"

C="$TMP/unknown-status.md"
sed 's/- \*\*Status\*\*: active/- **Status**: in-progress/' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "unknown Status value must exit 1"
case "$(run_checker_stderr "$C")" in
  *"unknown Status value"*) : ;;
  *) fail "unknown Status: expected reason in stderr" ;;
esac
pass "AC1: unknown Status value is rejected"

C="$TMP/unknown-role-token.md"
sed 's/- \*\*Applies-to\*\*: engineer$/- **Applies-to**: engineer, scrum-master/' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "AC6: unknown Applies-to role token must exit 1"
case "$(run_checker_stderr "$C")" in
  *"unknown Applies-to role token: 'scrum-master'"*) : ;;
  *) fail "AC6: expected reason naming the unknown role token" ;;
esac
pass "AC6: unknown Applies-to role token ('scrum-master') is rejected"

C="$TMP/empty-source.md"
sed 's/- \*\*Source\*\*: n\/a/- **Source**: /' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "empty Source must exit 1"
case "$(run_checker_stderr "$C")" in
  *"Source must be non-empty"*) : ;;
  *) fail "empty Source: expected reason in stderr" ;;
esac
pass "AC1: empty Source value is rejected"

# --- Fix 4 (T-045 rework, Minor): whitespace-only Rule/Why/How-to-apply -------
# rejected the same way an empty Source is — "the field is present" is not
# enough if its value trims to nothing.
C="$TMP/whitespace-only-rule.md"
sed 's/- \*\*Rule\*\*: Rule one\./- **Rule**:    /' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "whitespace-only Rule must exit 1"
case "$(run_checker_stderr "$C")" in
  *"Rule must be non-empty"*) : ;;
  *) fail "whitespace-only Rule: expected reason in stderr" ;;
esac
pass "Fix 4: whitespace-only Rule value is rejected"

C="$TMP/whitespace-only-why.md"
sed 's/- \*\*Why\*\*: Why one\./- **Why**:    /' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "whitespace-only Why must exit 1"
case "$(run_checker_stderr "$C")" in
  *"Why must be non-empty"*) : ;;
  *) fail "whitespace-only Why: expected reason in stderr" ;;
esac
pass "Fix 4: whitespace-only Why value is rejected"

C="$TMP/whitespace-only-howto.md"
sed 's/- \*\*How to apply\*\*: How one\./- **How to apply**:    /' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "whitespace-only How to apply must exit 1"
case "$(run_checker_stderr "$C")" in
  *"How to apply must be non-empty"*) : ;;
  *) fail "whitespace-only How to apply: expected reason in stderr" ;;
esac
pass "Fix 4: whitespace-only How to apply value is rejected"

# --- Fix 1 (T-045 rework, Major): a trailing-space Status is trimmed, not ----
# treated as unknown — the validator must accept it (bin/gen-playbook-blocks.sh
# is separately required to trim before comparing, so it doesn't silently
# vanish; see tests/gen-playbook-blocks/run.sh for that half of the regression).
C="$TMP/status-trailing-space.md"
sed 's/- \*\*Status\*\*: active$/- **Status**: active /' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 0 ] || fail "a trailing-space (but otherwise valid) Status must still validate green"
pass "Fix 1: a trailing-space Status value (trims to a known enum) still validates green"

# --- Fix 2 (T-045 rework, Major): control chars / marker-collision in the ----
# ENTRY HEADING'S TITLE are rejected too, not just in `- **Field**:` bullets —
# bin/gen-playbook-blocks.sh reads the title back out (as `remainder`) to
# build its tasks/lessons.md pointer, using the same 0x1F delimiter its
# fields use, so an unchecked title could desync its field-splitting.
C="$TMP/title-control-char.md"
printf -- '## 2026-02-01 — title with a \x0c control char\n' > "$TMP/title-cc-line.txt"
awk -v newline_file="$TMP/title-cc-line.txt" '
  /^## 2026-01-01 — First entry$/ { while ((getline l < newline_file) > 0) print l; close(newline_file); next }
  { print }
' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "a control character in the entry title must exit 1"
case "$(run_checker_stderr "$C")" in
  *"field 'Title' contains a control character"*) : ;;
  *) fail "title control-char: expected reason in stderr" ;;
esac
pass "Fix 2: a control character in the entry heading's title is rejected"

C="$TMP/title-marker-collision.md"
sed 's/^## 2026-01-01 — First entry$/## 2026-01-01 — title with <!-- BEGIN prompt-block: evil --> injected/' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "a marker-collision string in the entry title must exit 1"
case "$(run_checker_stderr "$C")" in
  *"field 'Title' contains the reserved marker string '<!-- BEGIN prompt-block:'"*) : ;;
  *) fail "title marker-collision: expected reason in stderr" ;;
esac
pass "Fix 2: a reserved marker string in the entry heading's title is rejected"

# --- Round2 Major 1: non-canonical headings are rejected fail-closed, ------
# never silently absorbed as body text of the still-open PRIOR entry. Every
# scenario below appends a malformed `## ` line right after $BASE's last
# entry ("Third entry"), so a silent-merge regression would show up as that
# entry gaining an extra/overwritten field instead of a reported violation
# (the deeper "which entry's Rule got misattributed" demonstration lives in
# tests/gen-playbook-blocks/run.sh, where the generated output is directly
# observable).
C="$TMP/heading-missing-space.md"
{ cat "$BASE"; printf '\n## 2026-02-02— No space before the em-dash\n- **Rule**: should not merge into entry 1.\n'; } > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "a heading missing the space before the em-dash must exit 1"
case "$(run_checker_stderr "$C")" in
  *"not a canonical entry heading"*) : ;;
  *) fail "heading-missing-space: expected reason in stderr" ;;
esac
pass "Round2 Major1: a heading with no space before the em-dash is rejected (not silently absorbed)"

C="$TMP/heading-hyphen-not-emdash.md"
{ cat "$BASE"; printf '\n## 2026-02-03 - Hyphen instead of em-dash\n- **Rule**: should not merge into entry 1.\n'; } > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "a heading using a plain hyphen separator must exit 1"
case "$(run_checker_stderr "$C")" in
  *"not a canonical entry heading"*) : ;;
  *) fail "heading-hyphen: expected reason in stderr" ;;
esac
pass "Round2 Major1: a heading using a plain hyphen (not the em-dash) separator is rejected"

# The allow-listed `## Format` heading itself must NOT be flagged (it is
# already present, unmutated, in $BASE — this just asserts the base fixture
# stays green, i.e. the allow-list actually works for the real shape this
# repo's own tasks/lessons.md uses).
[ "$(run_checker "$BASE")" -eq 0 ] || fail "Round2 Major1: the allow-listed '## Format' heading must not itself be flagged"
pass "Round2 Major1: the allow-listed '## Format' section heading is accepted, not flagged"

# --- Round2 Major 2: a NUL byte (0x00) in a field value is rejected --------
# fail-closed, not silently truncated/ignored by bash's read. Spliced with
# head/tail (byte-transparent redirection) rather than awk/sed — both awk and
# bash `read` truncate a line at an embedded NUL, which would defeat the
# fixture itself, not just the code under test.
C="$TMP/nul-byte-rule.md"
rule_line_no="$(grep -n -- '- \*\*Rule\*\*: Rule one\.' "$BASE" | head -1 | cut -d: -f1)"
{
  head -n "$((rule_line_no - 1))" "$BASE"
  printf -- '- **Rule**: before\x00after the NUL byte.\n'
  tail -n "+$((rule_line_no + 1))" "$BASE"
} > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "a NUL byte in a field value must exit 1"
case "$(run_checker_stderr "$C")" in
  *"contains a NUL byte"*) : ;;
  *) fail "nul-byte: expected reason in stderr" ;;
esac
pass "Round2 Major2: a NUL byte (0x00) anywhere in the file is rejected fail-closed"

# --- Round3 Major (a): an unclosed BACKTICK fence, followed by an otherwise
# valid entry, must be rejected fail-closed — not silently swallow every
# line after the opening marker (including that valid entry) with exit 0.
C="$TMP/fence-unclosed-backtick.md"
{
  cat "$BASE"
  printf '\n```markdown\nnever closed\n'
  printf '\n## 2026-04-01 — Entry after an unclosed fence\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: should never validate.\n- **Why**: w\n- **How to apply**: h\n'
} > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "(a) an unclosed backtick fence must exit 1"
case "$(run_checker_stderr "$C")" in
  *"never closed"*) : ;;
  *) fail "(a) unclosed backtick fence: expected 'never closed' reason in stderr" ;;
esac
pass "Round3 (a): an unclosed backtick fence (with a valid entry buried after it) is rejected fail-closed"

# --- Round3 Major (b): same, but an unclosed TILDE fence. ---------------------
C="$TMP/fence-unclosed-tilde.md"
{
  cat "$BASE"
  printf '\n~~~markdown\nnever closed\n'
  printf '\n## 2026-04-02 — Entry after an unclosed tilde fence\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: should never validate.\n- **Why**: w\n- **How to apply**: h\n'
} > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "(b) an unclosed tilde fence must exit 1"
case "$(run_checker_stderr "$C")" in
  *"never closed"*) : ;;
  *) fail "(b) unclosed tilde fence: expected 'never closed' reason in stderr" ;;
esac
pass "Round3 (b): an unclosed tilde fence (with a valid entry buried after it) is rejected fail-closed"

# --- Round3 Major (c): a tilde fence wrapping a fake heading + all 7 fields -
# must be treated as fence content (validator green), i.e. the exact
# real-injection scenario the review reproduced does NOT validate as a real
# entry. (The stronger assertion — that the fake Rule never reaches a
# generated block — lives in tests/gen-playbook-blocks/run.sh, where
# generated output is directly observable.)
C="$TMP/fence-tilde-fake-entry.md"
{
  cat "$BASE"
  printf '\n~~~markdown\n'
  printf '## 2099-01-01 — Fake heading inside tilde fence\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: FAKE_RULE_SHOULD_NOT_BE_INJECTED.\n- **Why**: w\n- **How to apply**: h\n'
  printf '~~~\n'
} > "$C"
[ "$(run_checker "$C")" -eq 0 ] || fail "(c) a fake entry wrapped in a tilde fence must NOT fail validation (it is fence content, not a real entry)"
pass "Round3 (c): a tilde-fenced fake heading + full field set validates green (correctly treated as fence content, not a real entry)"

# --- Round3 Major (d): a same-character CLOSE attempt shorter than the -----
# opening fence's length must NOT close it; only a marker of the SAME
# character with length >= the opening's does.
C="$TMP/fence-short-close-attempt.md"
{
  cat "$BASE"
  printf '\n````markdown\n'                          # opens with 4 backticks
  printf 'fake content inside the 4-backtick fence\n'
  printf '```\n'                                      # only 3 — must NOT close
  printf 'still inside the fence (the 3-backtick line above did not close it)\n'
  printf '````\n'                                      # closes with 4 — matches
  printf '\n## 2026-04-03 — Entry after a properly-closed 4-backtick fence\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: real entry after the fence.\n- **Why**: w\n- **How to apply**: h\n'
} > "$C"
[ "$(run_checker "$C")" -eq 0 ] || fail "(d) a properly-closed longer fence (with a too-short close attempt inside) must validate green"
pass "Round3 (d): a same-character close attempt shorter than the opening fence does not close it; a same-or-longer one does"

# --- Round3 Major (e): a DIFFERENT-character close attempt (backtick fence, -
# tilde 'close') must NOT close it either — only a matching character closes.
C="$TMP/fence-wrong-char-close-attempt.md"
{
  cat "$BASE"
  printf '\n```markdown\n'                             # opens with backticks
  printf 'fake content inside the backtick fence\n'
  printf '~~~\n'                                       # tilde — wrong character, must NOT close
  printf 'still inside the fence (the tilde line above did not close it)\n'
  printf '```\n'                                       # closes with backticks — matches
  printf '\n## 2026-04-04 — Entry after a properly-closed backtick fence\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: real entry after the fence.\n- **Why**: w\n- **How to apply**: h\n'
} > "$C"
[ "$(run_checker "$C")" -eq 0 ] || fail "(e) a properly-closed fence (with a wrong-character close attempt inside) must validate green"
pass "Round3 (e): a different-character close attempt (tilde inside a backtick fence) does not close it; a matching character does"

# --- Round4 (f): a close attempt with TRAILING NON-WHITESPACE CONTENT after -
# the run (round4 Blocker 1 — "```payload-not-a-real-close") must NOT close
# the fence; only a fully-blank-after-the-run line closes it.
C="$TMP/fence-trailing-content-unclosed.md"
{
  cat "$BASE"
  # shellcheck disable=SC2016  # literal backticks (fence markers), not command substitution
  printf '\n```markdown\n```payload-not-a-real-close\nnever actually closed\n'
} > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "(f) a fence 'closed' only by a trailing-content pseudo-close, then never really closed, must exit 1"
case "$(run_checker_stderr "$C")" in
  *"never closed"*) : ;;
  *) fail "(f) trailing-content pseudo-close: expected 'never closed' reason in stderr" ;;
esac
pass "Round4 (f): a trailing-content pseudo-close does not close the fence (still unclosed at EOF -> exit 1)"

C="$TMP/fence-trailing-content-then-real-close.md"
{
  cat "$BASE"
  # shellcheck disable=SC2016  # literal backticks (fence markers), not command substitution
  printf '\n```markdown\n```payload-not-a-real-close\n'
  printf '## 2099-01-01 — Fake entry via trailing-content pseudo-close\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: FAKE_RULE_SHOULD_NOT_BE_INJECTED.\n- **Why**: w\n- **How to apply**: h\n'
  printf '```\n'
  printf '\n## 2026-05-01 — Real entry after properly-closed fence\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: real entry after the fence.\n- **Why**: w\n- **How to apply**: h\n'
} > "$C"
[ "$(run_checker "$C")" -eq 0 ] || fail "(f) a properly-closed fence (with a trailing-content pseudo-close inside, correctly ignored) must validate green"
pass "Round4 (f): a trailing-content pseudo-close is fence content, not a close; the fence still closes properly later and real entries around it validate"

# --- Round4 (g): a 1-3-space-INDENTED opening fence must be recognized as a -
# fence (round4 Blocker 2 negation) — a column-0 fake entry inside it must
# NOT validate as a real entry.
C="$TMP/fence-indented-open.md"
{
  cat "$BASE"
  printf '\n   ```markdown\n'
  printf '## 2099-01-01 — Injected from indented fence\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: INDENTED_FENCE_INJECTION_SHOULD_NOT_APPEAR.\n- **Why**: w\n- **How to apply**: h\n'
  printf '   ```\n'
  printf '\n## 2026-05-02 — Real entry after an indented fence\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: real entry after the fence.\n- **Why**: w\n- **How to apply**: h\n'
} > "$C"
[ "$(run_checker "$C")" -eq 0 ] || fail "(g) a 1-3-space-indented fence (with a column-0 fake entry inside) must validate green"
pass "Round4 (g): a 1-3-space-indented opening fence is recognized as a fence; its column-0 content is never treated as a real entry"

# --- Round4 (h): a 1-3-space-INDENTED closing fence must correctly close. ---
C="$TMP/fence-indented-close.md"
{
  cat "$BASE"
  # shellcheck disable=SC2016  # literal backticks (fence markers), not command substitution
  printf '\n```markdown\nfiller content\n  ```\n'
  printf '\n## 2026-05-03 — Real entry after an indent-closed fence\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: real entry after the fence.\n- **Why**: w\n- **How to apply**: h\n'
} > "$C"
[ "$(run_checker "$C")" -eq 0 ] || fail "(h) a 2-space-indented closing fence must correctly close (real entry after it must validate)"
pass "Round4 (h): a 1-3-space-indented closing fence correctly closes the fence"

# --- Round4 (i): a backtick OPENER whose info string itself contains a -----
# backtick is invalid per CommonMark — must be rejected fail-closed, not
# silently opened as a fence.
C="$TMP/fence-invalid-opener.md"
{
  cat "$BASE"
  # shellcheck disable=SC2016  # literal backticks (fence markers), not command substitution
  printf '\n```inv`alid\nsome content\n```\n'
} > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "(i) a backtick opener with a backtick in its info string must exit 1"
case "$(run_checker_stderr "$C")" in
  *"invalid fence opener"*) : ;;
  *) fail "(i) invalid opener: expected 'invalid fence opener' reason in stderr" ;;
esac
pass "Round4 (i): a backtick fence opener whose info string contains a backtick is rejected fail-closed"

# --- Round4 (j): a 4-OR-MORE-space-indented line that still looks like a ---
# fence-run, encountered OUTSIDE any fence, is an ambiguous construct this
# validator refuses to guess at — fail-closed violation.
C="$TMP/fence-ambiguous-outside.md"
{
  cat "$BASE"
  # shellcheck disable=SC2016  # literal backticks (fence markers), not command substitution
  printf '\n    ```markdown\nsome content\n```\n'
} > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "(j) a 4+-space-indented fence-like line outside any fence must exit 1"
case "$(run_checker_stderr "$C")" in
  *"ambiguous fence-like line"*) : ;;
  *) fail "(j) ambiguous outside fence: expected 'ambiguous fence-like line' reason in stderr" ;;
esac
pass "Round4 (j): a 4+-space-indented fence-like line outside any fence is rejected fail-closed (ambiguous, not guessed)"

# --- Round4 (k): a 4-OR-MORE-space-indented fence-run line encountered ------
# INSIDE an already-open fence is unremarkable content — it must NOT close
# the fence (0-3 leading spaces is required to close).
C="$TMP/fence-ambiguous-inside.md"
{
  cat "$BASE"
  # shellcheck disable=SC2016  # literal backticks (fence markers), not command substitution
  printf '\n```markdown\n    ```\nstill inside the fence (the indented run above did not close it)\n```\n'
  printf '\n## 2026-05-04 — Real entry after a fence with 4+-space content inside\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: real entry after the fence.\n- **Why**: w\n- **How to apply**: h\n'
} > "$C"
[ "$(run_checker "$C")" -eq 0 ] || fail "(k) a 4+-space-indented fence-run line inside an open fence must be treated as content (must not close it)"
pass "Round4 (k): a 4+-space-indented fence-run line inside an open fence is content, not a close"

# --- T-047 fast-follow AC1: heading date calendar-value-range validation -----
# `## YYYY-MM-DD — <title>` used to accept any digit shape matching the
# regex with no check that it is a REAL Gregorian calendar date.
C="$TMP/date-invalid-month.md"
sed 's/## 2026-01-01 — First entry/## 2026-13-01 — First entry/' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "AC1: an invalid month (2026-13-01) must exit 1"
case "$(run_checker_stderr "$C")" in
  *"heading date '2026-13-01' is not a valid Gregorian calendar date"*) : ;;
  *) fail "AC1: invalid-month: expected reason in stderr" ;;
esac
pass "T-047 AC1: an invalid month (2026-13-01) is rejected fail-closed"

C="$TMP/date-invalid-day.md"
sed 's/## 2026-01-01 — First entry/## 2026-04-31 — First entry/' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "AC1: an invalid day-of-month (2026-04-31, April has 30 days) must exit 1"
case "$(run_checker_stderr "$C")" in
  *"heading date '2026-04-31' is not a valid Gregorian calendar date"*) : ;;
  *) fail "AC1: invalid-day: expected reason in stderr" ;;
esac
pass "T-047 AC1: an invalid day-of-month (2026-04-31) is rejected fail-closed"

C="$TMP/date-non-leap-feb29.md"
sed 's/## 2026-01-01 — First entry/## 2023-02-29 — First entry/' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "AC1: Feb 29 on a non-leap year (2023) must exit 1"
case "$(run_checker_stderr "$C")" in
  *"heading date '2023-02-29' is not a valid Gregorian calendar date"*) : ;;
  *) fail "AC1: non-leap-Feb29: expected reason in stderr" ;;
esac
pass "T-047 AC1: Feb 29 on a non-leap year (2023-02-29) is rejected fail-closed"

C="$TMP/date-valid-leap-day.md"
sed 's/## 2026-01-01 — First entry/## 2024-02-29 — First entry/' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 0 ] || fail "AC1: a genuine leap day (2024-02-29) must still validate green"
pass "T-047 AC1: a genuine leap day (2024-02-29) continues to pass"

# --- T-047 fast-follow AC4: a whitespace-only heading Title is rejected ------
# (the same trim-then-non-empty check Rule/Why/How to apply/Source already
# get — round5 Minor: Title never got the equivalent check).
C="$TMP/title-whitespace-only.md"
sed 's/## 2026-01-01 — First entry/## 2026-01-01 —    /' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "AC4: a whitespace-only Title must exit 1"
case "$(run_checker_stderr "$C")" in
  *"Title must be non-empty"*) : ;;
  *) fail "AC4: whitespace-only Title: expected reason in stderr" ;;
esac
pass "T-047 AC4: a whitespace-only heading Title is rejected fail-closed"

# --- T-047 fast-follow AC5: a TAB-indented fence open/close pair is ----------
# recognized as a fence, not silently treated as ordinary text that falls
# through unclassified (round5 Minor: only ASCII-space leading indentation
# was recognized; a leading tab fell through both the "recognized fence" and
# the "ambiguous violation" branches).
C="$TMP/fence-tab-indented.md"
{
  cat "$BASE"
  printf '\n\t```markdown\n'
  printf '## 2099-01-01 — Injected from tab-indented fence\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: TAB_FENCE_INJECTION_SHOULD_NOT_APPEAR.\n- **Why**: w\n- **How to apply**: h\n'
  printf '\t```\n'
  printf '\n## 2026-05-05 — Real entry after a tab-indented fence\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: real entry after the fence.\n- **Why**: w\n- **How to apply**: h\n'
} > "$C"
[ "$(run_checker "$C")" -eq 0 ] || fail "T-047 AC5: a tab-indented fence open/close pair must validate green (recognized as a fence)"
pass "T-047 AC5: a tab-indented fence open/close pair is recognized as a fence, not silently unclassified"

# --- AC1: structural safety-net checks ---------------------------------------
# (a) single-line: a Rule value spilling onto a second physical line.
C="$TMP/multiline-rule.md"
sed 's/- \*\*Rule\*\*: Rule one\./- **Rule**: Rule one\ncontinues onto a second physical line without a bullet marker./' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "multi-line Rule value must exit 1"
case "$(run_checker_stderr "$C")" in
  *"field 'Rule' value spans multiple lines"*) : ;;
  *) fail "multi-line Rule: expected reason in stderr" ;;
esac
pass "AC1(a): a Rule value spanning two physical lines is rejected"

# (b) control character (tab is EXPLICITLY allowed — only non-tab control
# chars are rejected). Built with printf (a literal byte, not text) rather
# than a static fixture file.
C="$TMP/control-char.md"
cp "$BASE" "$C"
printf -- '- **Rule**: contains a control char [\x0c] here.\n' > "$TMP/cc-line.txt"
awk -v newline_file="$TMP/cc-line.txt" '
  /- \*\*Rule\*\*: Rule one\./ { while ((getline l < newline_file) > 0) print l; close(newline_file); next }
  { print }
' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "control-char Rule value must exit 1"
case "$(run_checker_stderr "$C")" in
  *"contains a control character"*) : ;;
  *) fail "control-char Rule: expected reason in stderr" ;;
esac
pass "AC1(b): a Rule value containing a non-tab control character is rejected"

# (b, negative control) a literal TAB inside a value must NOT be rejected —
# the spec explicitly excepts tab from the control-character check.
C="$TMP/tab-allowed.md"
printf -- '- **Rule**: contains a\ttab and is still fine.\n' > "$TMP/tab-line.txt"
awk -v newline_file="$TMP/tab-line.txt" '
  /- \*\*Rule\*\*: Rule one\./ { while ((getline l < newline_file) > 0) print l; close(newline_file); next }
  { print }
' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 0 ] || fail "a literal tab inside a value must NOT be rejected"
pass "AC1(b): a literal tab inside a value is explicitly allowed (only non-tab control chars are rejected)"

# (c) marker-collision: a value containing the fixed marker strings
# bin/check-prompt-sync.sh uses to locate marker regions.
C="$TMP/marker-collision.md"
sed 's/- \*\*Rule\*\*: Rule one\./- **Rule**: injected <!-- BEGIN prompt-block: evil --> text./' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "marker-collision Rule value must exit 1"
case "$(run_checker_stderr "$C")" in
  *"reserved marker string '<!-- BEGIN prompt-block:'"*) : ;;
  *) fail "marker-collision: expected reason in stderr" ;;
esac
pass "AC1(c): a value containing the reserved '<!-- BEGIN prompt-block:' string is rejected"

# --- multiple files: one clean + one failing => exit 1 -----------------------
C="$TMP/unknown-category-2.md"
sed 's/- \*\*Category\*\*: process/- **Category**: not-a-real-category/' "$BASE" > "$C"
[ "$(bash "$CHECKER" "$BASE" "$C" >/dev/null 2>&1; echo $?)" -eq 1 ] \
  || fail "multi-file: a clean file plus a failing one must exit 1"
pass "multi-file invocation: the failure wins (exit 1)"


# =============================================================================
# T-108: Superseded-by reference-resolution + unknown-field allow-list
# (docs/specs/T-108-lessons-supersede-curation.md). $BASE (fixtures/
# valid-base.md) now bakes in a positive Superseded-by case as part of its own
# pristine-fixture shape: "Second entry" (superseded) points at "Third entry"
# (active), which is DEFINED AFTER it in the file — so the very first
# assertion above (valid-base.md is green) already exercises a forward
# reference end to end; "Third entry" also carries an unrelated
# "Extended by" bullet, recognized (not an unknown-field violation) but never
# value-checked (DP-5).
# =============================================================================

# --- T-108 AC7 (forward reference must PASS, not be order-dependent) --------
# Re-asserted explicitly (not just implicitly via the AC1 pristine-fixture
# check above) so a future edit that removes the forward-pointing shape from
# $BASE cannot silently drop this coverage without this assertion's own label
# going missing too.
[ "$(run_checker "$BASE")" -eq 0 ] \
  || fail "T-108 AC7: a Superseded-by pointing to a LATER-defined entry (forward reference) must still validate green"
pass "T-108 AC7: Superseded-by pointing to a later-defined entry (forward reference) resolves and passes — not order-dependent"

# --- T-108 AC1: a superseded entry with Superseded-by missing ---------------
C="$TMP/t108-missing-superseded-by.md"
sed '/^- \*\*Superseded-by\*\*: 2026-01-03 — Third entry (applies to all)$/d' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "T-108 AC1: a superseded entry with no Superseded-by must exit 1"
case "$(run_checker_stderr "$C")" in
  *"Status is 'superseded' but Superseded-by is missing"*) : ;;
  *) fail "T-108 AC1: expected reason in stderr" ;;
esac
pass "T-108 AC1: a superseded entry with Superseded-by missing is rejected"

# (AC1, empty/whitespace-only value is treated the same as missing)
C="$TMP/t108-empty-superseded-by.md"
sed 's/^- \*\*Superseded-by\*\*: 2026-01-03 — Third entry (applies to all)$/- **Superseded-by**:    /' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "T-108 AC1: a whitespace-only Superseded-by must exit 1"
case "$(run_checker_stderr "$C")" in
  *"Status is 'superseded' but Superseded-by is missing"*) : ;;
  *) fail "T-108 AC1: whitespace-only Superseded-by: expected reason in stderr" ;;
esac
pass "T-108 AC1: a whitespace-only (trims to empty) Superseded-by is treated the same as missing"

# --- T-108 AC2: an active entry must never carry Superseded-by -------------
printf -- '- **Superseded-by**: 2026-01-01 — First entry\n' > "$TMP/t108-ac2-insert.txt"
C="$TMP/t108-active-with-superseded-by.md"
awk -v newline_file="$TMP/t108-ac2-insert.txt" '
  /^- \*\*How to apply\*\*: How three\.$/ { print; while ((getline l < newline_file) > 0) print l; close(newline_file); next }
  { print }
' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "T-108 AC2: an active entry with Superseded-by present must exit 1"
case "$(run_checker_stderr "$C")" in
  *"Status is 'active' but Superseded-by is present"*) : ;;
  *) fail "T-108 AC2: expected reason in stderr" ;;
esac
pass "T-108 AC2: an active entry carrying a Superseded-by bullet is rejected"

# (AC2 regression lock, rework1/Codex round1 Major, orchestrator-reproduced):
# a WHITESPACE-ONLY value must ALSO be caught — the pre-rework1 code tested
# field PRESENCE via the trimmed VALUE's non-emptiness (`[ -n "$e_sup" ]`),
# so `- **Superseded-by**:    ` (bullet present, value blank after trim) was
# indistinguishable from the bullet being absent entirely and silently
# passed (rc=0). AC1's mirror case (whitespace-only on a SUPERSEDED entry,
# tested just above) was unaffected because AC1 wants the OPPOSITE union
# (blank-or-absent both violate) — only AC2's "must not exist at all" half
# needed field-presence tracking independent of the value.
printf -- '- **Superseded-by**:    \n' > "$TMP/t108-ac2-whitespace-insert.txt"
C="$TMP/t108-active-with-whitespace-superseded-by.md"
awk -v newline_file="$TMP/t108-ac2-whitespace-insert.txt" '
  /^- \*\*How to apply\*\*: How three\.$/ { print; while ((getline l < newline_file) > 0) print l; close(newline_file); next }
  { print }
' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "T-108 AC2 (regression lock): an active entry with a WHITESPACE-ONLY Superseded-by value must exit 1 (bullet presence, not value emptiness, is what AC2 tests)"
case "$(run_checker_stderr "$C")" in
  *"Status is 'active' but Superseded-by is present"*) : ;;
  *) fail "T-108 AC2 (regression lock): expected reason in stderr" ;;
esac
pass "T-108 AC2 (regression lock): an active entry carrying a Superseded-by bullet with a WHITESPACE-ONLY value is rejected (field presence, not value emptiness)"

# (AC2 regression lock, tab-only value — same shape, different whitespace).
# Note the space right after the colon: the field regex itself (like every
# other field's) requires `": "` before capturing a value; without it the
# line falls through to the AC8 unknown-field catch-all instead (a
# DIFFERENT, already-covered code path) rather than exercising THIS field's
# own value-trimming logic.
printf -- '- **Superseded-by**: \t\t\n' > "$TMP/t108-ac2-tab-insert.txt"
C="$TMP/t108-active-with-tab-superseded-by.md"
awk -v newline_file="$TMP/t108-ac2-tab-insert.txt" '
  /^- \*\*How to apply\*\*: How three\.$/ { print; while ((getline l < newline_file) > 0) print l; close(newline_file); next }
  { print }
' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "T-108 AC2 (regression lock): an active entry with a TAB-ONLY Superseded-by value must exit 1"
case "$(run_checker_stderr "$C")" in
  *"Status is 'active' but Superseded-by is present"*) : ;;
  *) fail "T-108 AC2 (regression lock): tab-only: expected reason in stderr" ;;
esac
pass "T-108 AC2 (regression lock): an active entry carrying a Superseded-by bullet with a TAB-ONLY value is rejected"

# --- T-108 AC3: Superseded-by resolution is equality, not containment -------
C="$TMP/t108-nonexistent-key.md"
sed 's/^- \*\*Superseded-by\*\*: .*$/- **Superseded-by**: 2026-09-09 — This key does not exist anywhere/' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "T-108 AC3: Superseded-by pointing to a nonexistent key must exit 1"
case "$(run_checker_stderr "$C")" in
  *"does not exist in this file"*) : ;;
  *) fail "T-108 AC3: nonexistent key: expected reason in stderr" ;;
esac
pass "T-108 AC3: Superseded-by pointing to a key that does not exist in the file is rejected"

# (AC3, containment must NOT be treated as a match — a strict substring of a
# real key, missing its trailing "(applies to all)", must still be rejected)
C="$TMP/t108-containment-only.md"
sed 's/^- \*\*Superseded-by\*\*: .*$/- **Superseded-by**: 2026-01-03 — Third entry/' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "T-108 AC3: a containment-only (not exact) key match must exit 1"
case "$(run_checker_stderr "$C")" in
  *"does not exist in this file"*) : ;;
  *) fail "T-108 AC3: containment-only match: expected reason in stderr" ;;
esac
pass "T-108 AC3: a Superseded-by value that is only a SUBSTRING of a real key (not an exact match) does not resolve (equality, never containment)"

# (AC3, positive: leading/trailing whitespace on the value is trimmed before
# the equality comparison — it must still resolve and pass)
C="$TMP/t108-whitespace-trimmed.md"
sed 's/^- \*\*Superseded-by\*\*: .*$/- **Superseded-by**:    2026-01-03 — Third entry (applies to all)   /' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 0 ] || fail "T-108 AC3: a Superseded-by value with surrounding whitespace must still resolve (trim then equality)"
pass "T-108 AC3: a Superseded-by value with leading/trailing whitespace is trimmed before the equality comparison and resolves"

# (AC3, a hyphen instead of the em-dash separator never resolves — the real
# key always uses the em-dash, so this is just another non-existent-key case)
C="$TMP/t108-hyphen-not-emdash.md"
sed 's/^- \*\*Superseded-by\*\*: .*$/- **Superseded-by**: 2026-01-03 - Third entry (applies to all)/' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "T-108 AC3: a hyphen-separated (not em-dash) Superseded-by value must exit 1"
case "$(run_checker_stderr "$C")" in
  *"does not exist in this file"*) : ;;
  *) fail "T-108 AC3: hyphen-not-em-dash: expected reason in stderr" ;;
esac
pass "T-108 AC3: a Superseded-by value using a hyphen instead of the em-dash separator does not resolve"

# (AC3, a pseudo Superseded-by bullet written INSIDE a fenced code block is
# fence content, never a real field — it must not be parsed at all, and must
# not make an otherwise-valid file fail)
C="$TMP/t108-fenced-pseudo-field.md"
{
  cat "$BASE"
  # shellcheck disable=SC2016  # literal backticks (fence markers), not command substitution
  printf '\n```markdown\n- **Superseded-by**: 2026-01-01 — First entry\n```\n'
} > "$C"
[ "$(run_checker "$C")" -eq 0 ] || fail "T-108 AC3: a pseudo Superseded-by bullet inside a fenced code block must not affect validation"
pass "T-108 AC3: a Superseded-by-shaped bullet inside a fenced code block is ignored (fence content, not a real field)"

# --- T-108 AC4: Superseded-by must point to an ACTIVE entry (no chains) -----
C="$TMP/t108-chain.md"
{
  cat "$BASE"
  printf '\n## 2026-06-01 — Fourth entry (chains to a superseded entry)\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: superseded\n'
  printf -- '- **Source**: n/a\n- **Rule**: r\n- **Why**: w\n- **How to apply**: h\n'
  printf -- '- **Superseded-by**: 2026-01-02 — Second entry (superseded)\n'
} > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "T-108 AC4: Superseded-by pointing to a non-active (superseded) entry must exit 1"
case "$(run_checker_stderr "$C")" in
  *"is not 'active'"*) : ;;
  *) fail "T-108 AC4: expected reason in stderr" ;;
esac
pass "T-108 AC4: Superseded-by pointing to an entry whose own Status is not 'active' (chained supersession) is rejected"

# --- T-108 AC5: self-reference ------------------------------------------------
C="$TMP/t108-self-reference.md"
{
  cat "$BASE"
  printf '\n## 2026-06-02 — Fifth entry (points at itself)\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: superseded\n'
  printf -- '- **Source**: n/a\n- **Rule**: r\n- **Why**: w\n- **How to apply**: h\n'
  printf -- '- **Superseded-by**: 2026-06-02 — Fifth entry (points at itself)\n'
} > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "T-108 AC5: a self-referencing Superseded-by must exit 1"
case "$(run_checker_stderr "$C")" in
  *"points to itself (self-reference not allowed)"*) : ;;
  *) fail "T-108 AC5: expected reason in stderr" ;;
esac
pass "T-108 AC5: a Superseded-by value pointing at its own entry's key (self-reference) is rejected"

# --- T-108 AC6: (date, title) key uniqueness --------------------------------
C="$TMP/t108-duplicate-key.md"
{
  cat "$BASE"
  printf '\n## 2026-06-03 — Duplicate title\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: r1\n- **Why**: w1\n- **How to apply**: h1\n'
  printf '\n## 2026-06-03 — Duplicate title\n'
  printf -- '- **Category**: process\n- **Applies-to**: engineer\n- **Status**: active\n'
  printf -- '- **Source**: n/a\n- **Rule**: r2\n- **Why**: w2\n- **How to apply**: h2\n'
} > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "T-108 AC6: two entries sharing the same (date, title) key must exit 1"
case "$(run_checker_stderr "$C")" in
  *"duplicate entry key (date, title)"*) : ;;
  *) fail "T-108 AC6: expected reason in stderr" ;;
esac
pass "T-108 AC6: two entries sharing the same (date, title) key are rejected (ambiguous pointer target)"

# --- T-108 AC8: unknown field bullets (DP-4 allow-list, fail-closed) --------
# (a) a case-different "Superseded-By" (capital B) must not be silently
# dropped — it must be flagged as an unknown field bullet.
C="$TMP/t108-wrong-case-field.md"
sed 's/^- \*\*Superseded-by\*\*: .*$/- **Superseded-By**: 2026-01-03 — Third entry (applies to all)/' "$BASE" > "$C"
[ "$(run_checker "$C")" -eq 1 ] || fail "T-108 AC8: a case-different 'Superseded-By' bullet must exit 1"
case "$(run_checker_stderr "$C")" in
  *"unknown field bullet: '- **Superseded-By**:'"*) : ;;
  *) fail "T-108 AC8: expected reason in stderr" ;;
esac
pass "T-108 AC8: a case-different field bullet ('Superseded-By', capital B) is rejected, not silently dropped"

# (b) "Extended by" IS a recognized field name (not unknown) — already
# exercised implicitly by $BASE's own "Third entry" carrying one and staying
# green (the very first AC1 assertion in this file), asserted explicitly here
# too so this coverage cannot silently vanish.
[ "$(run_checker "$BASE")" -eq 0 ] \
  || fail "T-108 AC8: an 'Extended by' bullet must be recognized (not an unknown-field violation)"
pass "T-108 AC8: an 'Extended by' bullet is recognized as a known field name (present in \$BASE, stays green)"

# --- AC8: shellcheck (soft-skip when unavailable) -----------------------------
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$CHECKER" "$HERE/run.sh" || fail "AC8: scripts must be shellcheck clean"
  pass "AC8: shellcheck clean (checker + test runner)"
else
  printf 'SKIP: AC8 shellcheck not installed locally (CI enforces it)\n'
fi

printf '\nAll check-playbook assertions passed.\n'
