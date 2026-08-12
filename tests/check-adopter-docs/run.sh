#!/usr/bin/env bash
# run.sh — drive bin/check-adopter-docs.sh (T-1061's freeze-time adopter-docs
# gate; .shell-team/specs/T-1061-adopter-docs-gate.md) against synthetic spec
# fixtures and assert its exit contract: 0 = pass (silently), 1 = a content
# refusal, 2 = the input could not be evaluated at all — every refusal is one
# token, alone, on stderr, asserted via `grep -x`, never a substring match
# that could pass on a wrong-but-nonzero result (this repository's
# fixture-synthesis discipline — the same one tests/check-interventions/run.sh
# and tests/check-refreeze-class/run.sh already follow).
#
# Case classes (each asserted via the shared assert_case helper below):
#   cad-usage-*        — no args, extra arg, unknown flag, --help
#   cad-unreadable-*    — a missing path, a directory
#   cad-block-*         — no marker pair, duplicate BEGIN, reversed markers,
#                         the ONLY marker pair sitting inside a fenced block
#   cad-missing-*       — no declaration, an indented-only declaration, a
#                         fenced-only declaration
#   cad-duplicate       — two declaration lines
#   cad-malformed-*     — a non-canonical value, a missing separator, a
#                         whitespace-only rationale, a CRLF-terminated line
#                         (tolerated, not a malformed case)
#   cad-misplaced-*      — before the BEGIN marker, at/after `## Non-goals`
#   cad-boundary-*       — a declaration on the first line of the block and
#                         one on the last line before `## Non-goals` (both
#                         valid placements — AC16(b) boundary probe)
#   cad-undischarged-*   — a bare `yes`, a `yes` with a whitespace-only
#                         `- adopter-surface:` value
#   cad-waiver-empty     — a `yes` whose only marker is an empty waiver
#                         (distinct token from undischarged)
#   cad-conflict-*       — `yes` with both markers, `no` with a surface,
#                         `no` with a waiver
#   cad-pass-*           — `no` alone (zero-byte pass), `yes` discharged by a
#                         surface, `yes` discharged by a waiver
#   cad-fence-*          — DP5/AC16(b) blind-spot probes: an info-stringed
#                         opening fence, an unterminated fence swallowing a
#                         trailing declaration, a grammar line inside an HTML
#                         comment (never counted — the anchor requires the
#                         line to START with the token, which an HTML
#                         comment's own leading `<!--` defeats)
#   cad-dogfood          — this task's own spec passes with zero output

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CHECKER="$REPO_ROOT/bin/check-adopter-docs.sh"

if [ -n "${TMPDIR:-}" ]; then
  TMP="$(mktemp -d "${TMPDIR%/}/check-adopter-docs-fixtures.XXXXXX")"
else
  TMP="$(mktemp -d "$HERE/tmp-roots.XXXXXX")"
fi
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# assert_case <case-id> <want-exit-code> <want-token-or-empty> -- <args...>
# want-token is matched with `grep -x` against stderr ALONE — a token
# embedded in a longer message must not look like a pass (the same
# wrong-but-nonzero discipline check-refreeze-class's suite uses). An empty
# want-token additionally asserts stdout AND stderr are BOTH zero bytes (the
# pass-case contract).
CASES=0
assert_case() {
  local id="$1" want_rc="$2" want_token="$3" out err rc
  shift 3
  CASES=$((CASES + 1))
  set +e
  out="$(bash "$CHECKER" "$@" 2>"$TMP/stderr.$$")"
  rc=$?
  set -e
  err="$(cat "$TMP/stderr.$$")"
  rm -f "$TMP/stderr.$$"
  if [ "$rc" -ne "$want_rc" ]; then
    fail "$id: expected exit $want_rc, got $rc (stdout: $out; stderr: $err)"
  fi
  if [ -n "$want_token" ]; then
    if ! printf '%s\n' "$err" | grep -qx -- "$want_token"; then
      fail "$id: expected stderr to be exactly the token '$want_token', got: $err"
    fi
  else
    [ -z "$out" ] || fail "$id: expected zero bytes on stdout on a pass, got: $out"
    [ -z "$err" ] || fail "$id: expected zero bytes on stderr on a pass, got: $err"
  fi
  pass "$id"
}

TIC="$(printf '\140\140\140')"
CR="$(printf '\015')"

# --- fixture builders ---------------------------------------------------------
# body: the rest of a well-formed intent block after the Goal-region content
# (Non-goals / Acceptance criteria / Input space / END marker), with an
# optional indented `- adopter-surface:` line under AC1.
body() {  # $1 = optional indented surface line (with leading spaces already applied by caller)
  local surf="${1:-}"
  printf 'Goal prose.\n\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** placeholder\n'
  if [ -n "$surf" ]; then printf '%s\n' "$surf"; fi
  printf '\n## Input space\n\nnot applicable.\n\n<!-- END intent-block: T-999 -->\n'
}
head_() {
  printf '# Fixture\n\n**Task ID**: T-999\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n\n'
}
# mk: a full fixture — declaration line ($2), optional indented surface line
# ($3, ALREADY prefixed with its own indent), optional top-level waiver line
# ($4) — matching the AC5 check line's own generator shape.
mk() {
  local p="$1" d="$2" s="$3" w="$4"
  {
    head_
    if [ -n "$d" ]; then printf '%s\n\n' "$d"; fi
    if [ -n "$w" ]; then printf '%s\n\n' "$w"; fi
    body "$s"
  } > "$p"
}

# --- usage ---------------------------------------------------------------------
assert_case "cad-usage-no-args" 2 usage
assert_case "cad-usage-extra-arg" 2 usage "$TMP/a" "$TMP/b"
assert_case "cad-usage-unknown-flag" 2 usage --nope "$TMP/a"
HELP_OUT="$(bash "$CHECKER" --help 2>&1)"
[ -n "$HELP_OUT" ] || fail "cad-usage-help: expected non-empty --help output"
CASES=$((CASES + 1)); pass "cad-usage-help"

# --- unreadable path -------------------------------------------------------------
assert_case "cad-unreadable-missing" 2 spec-unreadable "$TMP/does-not-exist-xyz.md"
A_DIR="$TMP/a-directory"; mkdir -p "$A_DIR"
assert_case "cad-unreadable-directory" 2 spec-unreadable "$A_DIR"

# --- intent-block resolution -----------------------------------------------------
NONE="$TMP/none.md"; mk "$NONE" '' '' ''
NO_MARKERS="$TMP/no-markers.md"
awk '$0 != "<!-- BEGIN intent-block: T-999 -->" && $0 != "<!-- END intent-block: T-999 -->"' "$NONE" > "$NO_MARKERS"
assert_case "cad-block-no-markers" 2 intent-block-missing "$NO_MARKERS"

DUP_MARKERS="$TMP/dup-markers.md"
awk '{ print; if ($0 == "<!-- BEGIN intent-block: T-999 -->") print }' "$NONE" > "$DUP_MARKERS"
assert_case "cad-block-duplicate-markers" 2 intent-block-missing "$DUP_MARKERS"

REVERSED="$TMP/reversed.md"
awk '{
  if ($0 == "<!-- BEGIN intent-block: T-999 -->") print "<!-- END intent-block: T-999 -->";
  else if ($0 == "<!-- END intent-block: T-999 -->") print "<!-- BEGIN intent-block: T-999 -->";
  else print
}' "$NONE" > "$REVERSED"
assert_case "cad-block-reversed-markers" 2 intent-block-missing "$REVERSED"

FENCEDMARK="$TMP/fencedmark.md"
{
  printf '# Fixture\n\n## Goal\n\n%s\n' "$TIC"
  printf -- '<!-- BEGIN intent-block: T-999 -->\n- user-visible: no — fenced marker\n<!-- END intent-block: T-999 -->\n'
  printf '%s\n\nprose only.\n' "$TIC"
} > "$FENCEDMARK"
grep -qF -- 'BEGIN intent-block' "$FENCEDMARK" || fail "cad-block-fenced-marker: fixture sanity — no BEGIN marker text at all"
assert_case "cad-block-fenced-marker" 2 intent-block-missing "$FENCEDMARK"

# --- declaration-missing --------------------------------------------------------
assert_case "cad-missing-none" 1 declaration-missing "$NONE"

INDENT_ONLY="$TMP/indent-only.md"
{
  head_
  printf '  - user-visible: no — indented\n\n'
  body ""
} > "$INDENT_ONLY"
assert_case "cad-missing-indented-only" 1 declaration-missing "$INDENT_ONLY"

FENCED_ONLY="$TMP/fenced-only.md"
{
  head_
  printf '%s\n' "$TIC"
  printf -- '- user-visible: no — fenced\n- adopter-surface: x\n- adopter-docs-waiver: y\n'
  printf '%s\n\n' "$TIC"
  body ""
} > "$FENCED_ONLY"
assert_case "cad-missing-fenced-only" 1 declaration-missing "$FENCED_ONLY"

HTML_COMMENT="$TMP/html-comment.md"
{
  head_
  printf '<!-- - user-visible: no — inside an html comment -->\n\n'
  body ""
} > "$HTML_COMMENT"
grep -qF -- 'user-visible' "$HTML_COMMENT" || fail "cad-missing-html-comment: fixture sanity — token text absent entirely"
assert_case "cad-missing-html-comment" 1 declaration-missing "$HTML_COMMENT"

# --- declaration-duplicate ------------------------------------------------------
DUP="$TMP/dup.md"
{ head_; printf -- '- user-visible: no — a\n- user-visible: yes — b\n\n'; body ""; } > "$DUP"
assert_case "cad-duplicate" 1 declaration-duplicate "$DUP"

# --- declaration-malformed -------------------------------------------------------
BADVAL="$TMP/badval.md"
{ head_; printf -- '- user-visible: Yes — x\n\n'; body ""; } > "$BADVAL"
assert_case "cad-malformed-value" 1 declaration-malformed "$BADVAL"

NORAT="$TMP/norat.md"
{ head_; printf -- '- user-visible: no\n\n'; body ""; } > "$NORAT"
assert_case "cad-malformed-no-separator" 1 declaration-malformed "$NORAT"

BLANKRAT="$TMP/blankrat.md"
{ head_; printf -- '- user-visible: no —    \n\n'; body ""; } > "$BLANKRAT"
assert_case "cad-malformed-blank-rationale" 1 declaration-malformed "$BLANKRAT"

CRLF="$TMP/crlf.md"
{ head_; printf -- '- user-visible: no — crlf%s\n\n' "$CR"; body ""; } > "$CRLF"
grep -qF -- "$CR" "$CRLF" || fail "cad-malformed-crlf-tolerated: fixture sanity — no CR byte present"
assert_case "cad-malformed-crlf-tolerated" 0 "" "$CRLF"

# --- declaration-misplaced -------------------------------------------------------
OUTSIDE="$TMP/outside.md"
{ printf '# Fixture\n\n- user-visible: no — outside\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n\n'; body ""; } > "$OUTSIDE"
assert_case "cad-misplaced-before-begin" 1 declaration-misplaced "$OUTSIDE"
# specifically not declaration-missing:
set +e
OUT_ERR="$(bash "$CHECKER" "$OUTSIDE" 2>&1 1>/dev/null)"
set -e
printf '%s' "$OUT_ERR" | grep -qx -- declaration-missing && fail "cad-misplaced-before-begin: must not ALSO be reported as declaration-missing"

AFTER_NG="$TMP/after-ng.md"
{
  head_
  printf 'Goal prose.\n\n## Non-goals\n\n- none\n\n- user-visible: no — after non-goals\n\n## Acceptance criteria\n\n- [ ] **AC1** placeholder\n\n## Input space\n\nnot applicable.\n\n<!-- END intent-block: T-999 -->\n'
} > "$AFTER_NG"
assert_case "cad-misplaced-after-non-goals" 1 declaration-misplaced "$AFTER_NG"

# --- boundary placements (AC16(b) probe: first line of block / last line
# before ## Non-goals) — both are VALID placements -----------------------------
FIRST_LINE="$TMP/first-line.md"
printf '# Fixture\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n- user-visible: no — first line of the block\n\n' > "$FIRST_LINE"
body "" >> "$FIRST_LINE"
assert_case "cad-boundary-first-line" 0 "" "$FIRST_LINE"

LAST_LINE="$TMP/last-line.md"
{
  head_
  printf 'Goal prose.\n\n- user-visible: no — last line before non-goals\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** placeholder\n\n## Input space\n\nnot applicable.\n\n<!-- END intent-block: T-999 -->\n'
} > "$LAST_LINE"
assert_case "cad-boundary-last-line" 0 "" "$LAST_LINE"

# --- obligation-undischarged ----------------------------------------------------
BARE="$TMP/bare.md"
mk "$BARE" '- user-visible: yes — ships a new command' '' ''
assert_case "cad-undischarged-bare" 1 obligation-undischarged "$BARE"

EMPTYSURF="$TMP/emptysurf.md"
mk "$EMPTYSURF" '- user-visible: yes — x' '  - adopter-surface:    ' ''
assert_case "cad-undischarged-blank-surface" 1 obligation-undischarged "$EMPTYSURF"

# --- waiver-reason-empty (distinct from undischarged) ---------------------------
EMPTYWAIV="$TMP/emptywaiv.md"
mk "$EMPTYWAIV" '- user-visible: yes — x' '' '- adopter-docs-waiver:    '
assert_case "cad-waiver-empty" 1 waiver-reason-empty "$EMPTYWAIV"
set +e
EW_ERR="$(bash "$CHECKER" "$EMPTYWAIV" 2>&1 1>/dev/null)"
set -e
printf '%s' "$EW_ERR" | grep -qx -- obligation-undischarged && fail "cad-waiver-empty: must not ALSO be reported as obligation-undischarged"

# --- marker-conflict --------------------------------------------------------------
BOTH="$TMP/both.md"
mk "$BOTH" '- user-visible: yes — x' '  - adopter-surface: docs/adopting.md' '- adopter-docs-waiver: no adopter surface exists here'
grep -qF -- '- adopter-surface:' "$BOTH" || fail "cad-conflict-both: fixture sanity — surface token absent"
grep -qF -- '- adopter-docs-waiver:' "$BOTH" || fail "cad-conflict-both: fixture sanity — waiver token absent"
assert_case "cad-conflict-both" 1 marker-conflict "$BOTH"

NOSURF="$TMP/nosurf.md"
mk "$NOSURF" '- user-visible: no — internal' '  - adopter-surface: docs/adopting.md' ''
assert_case "cad-conflict-no-with-surface" 1 marker-conflict "$NOSURF"

NOWAIV="$TMP/nowaiv.md"
mk "$NOWAIV" '- user-visible: no — internal' '' '- adopter-docs-waiver: nothing to document'
assert_case "cad-conflict-no-with-waiver" 1 marker-conflict "$NOWAIV"

# --- pass cases ------------------------------------------------------------------
NOPASS="$TMP/nopass.md"
mk "$NOPASS" '- user-visible: no — internal loop mechanics only' '' ''
assert_case "cad-pass-no" 0 "" "$NOPASS"

SURFPASS="$TMP/surfpass.md"
mk "$SURFPASS" '- user-visible: yes — ships a new command' '  - adopter-surface: docs/adopting.md' ''
assert_case "cad-pass-surface" 0 "" "$SURFPASS"

WAIVPASS="$TMP/waivpass.md"
mk "$WAIVPASS" '- user-visible: yes — ships a new command' '' '- adopter-docs-waiver: this repository ships no adopter-readable surface'
assert_case "cad-pass-waiver" 0 "" "$WAIVPASS"

# --- fence blind-spot probes (DP5 / AC16(b)) --------------------------------------
# An opening fence line carrying an info string (```bash) must still open a
# fence — the toggle applies regardless of what follows the backtick run.
INFOSTRING="$TMP/infostring.md"
{
  head_
  # shellcheck disable=SC2016  # literal backticks, not command substitution
  printf '```bash\n- user-visible: no — inside an info-stringed fence\n```\n\n'
  body ""
} > "$INFOSTRING"
assert_case "cad-fence-info-string" 1 declaration-missing "$INFOSTRING"

# An unterminated fence (no closer before EOF) swallows everything after it,
# including a would-be declaration and the END marker itself — this must
# refuse intent-block-missing (the END marker is inert too), never silently
# resolve using the still-in-fence tail as if it were unfenced.
UNTERMINATED="$TMP/unterminated.md"
{
  head_
  printf '%s\n' "$TIC"
  printf -- '- user-visible: no — never reached, the fence never closes\n'
  printf 'Goal prose.\n\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** placeholder\n\n## Input space\n\nnot applicable.\n\n<!-- END intent-block: T-999 -->\n'
} > "$UNTERMINATED"
assert_case "cad-fence-unterminated" 2 intent-block-missing "$UNTERMINATED"

# --- dogfood: this task's own spec ------------------------------------------------
SELF_SPEC="$REPO_ROOT/.shell-team/specs/T-1061-adopter-docs-gate.md"
assert_case "cad-dogfood" 0 "" "$SELF_SPEC"

printf '\ncheck-adopter-docs fixture suite: all %d cases passed\n' "$CASES"
