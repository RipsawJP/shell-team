#!/usr/bin/env bash
# run.sh — drive bin/check-adopter-docs.sh (T-1061's freeze-time adopter-docs
# gate, rebuilt on an explicit three-variable state machine by T-1151;
# .shell-team/specs/T-1151-adopter-docs-checker.md) against synthetic spec
# fixtures and assert its exit contract: 0 = pass (silently), 1 = a content
# refusal, 2 = the input could not be evaluated at all — every refusal is one
# token, alone, on stderr, asserted via `grep -x`, never a substring match
# that could pass on a wrong-but-nonzero result (this repository's
# fixture-synthesis discipline — the same one tests/check-interventions/run.sh
# and tests/check-refreeze-class/run.sh already follow). This suite's case
# inventory is derived one-way from the checker's own transition table
# (documented in the header comment of bin/check-adopter-docs.sh): every row
# of that table has a case exercising it, and no case exists the table does
# not license.
#
# Case classes (each asserted via the shared assert_case helper below), the
# 42 classes the carved-out generation coined, unchanged in intent:
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
#                         valid placements)
#   cad-undischarged-*   — a bare `yes`, a `yes` with a whitespace-only
#                         `- adopter-surface:` value
#   cad-waiver-empty     — a `yes` whose only marker is an empty waiver
#                         (distinct token from undischarged)
#   cad-conflict-*       — `yes` with both markers, `no` with a surface,
#                         `no` with a waiver
#   cad-pass-*           — `no` alone (zero-byte pass), `yes` discharged by a
#                         surface, `yes` discharged by a waiver (the surface/
#                         waiver pass cases now carry a conformant
#                         `- shipped-docs:` line — T-1151, issue #577)
#   cad-fence-*          — DP5 blind-spot probes: an info-stringed opening
#                         fence, an unterminated fence swallowing a trailing
#                         declaration, a grammar line inside an HTML comment
#   cad-scope-*          — round-1 rework (Codex Major #1, class-closure):
#                         discharge markers outside the intent block (a
#                         '## Notes for engineer' / '## Assumptions' example,
#                         surface and waiver each), and a surface line inside
#                         the block but not nested under any AC-bullet-shaped
#                         line — none of these discharge
#   cad-order-*          — round-1 rework (Codex Major #2, class-closure):
#                         two in-scope occurrences of the same marker, one
#                         blank and one valid, in both orders — surface and
#                         waiver each — the verdict must not depend on order
#                         (each now carries a conformant `- shipped-docs:`
#                         line — T-1151, issue #577)
#
# New classes T-1151's redesign requires:
#   cad-control-pair-*   — the fence/no-fence control pair (AC3): an
#                         intervening `^## ` heading, unfenced (closes AC
#                         scope: obligation-undischarged) versus fenced
#                         (inert: the identity transition, pass) — the two
#                         fixtures are otherwise byte-identical.
#   cad-fence-scope-*    — a fenced-heading scope-survival probe distinct
#                         from the control pair (a different heading, deeper
#                         in the block), closing the R2 finding: a fenced
#                         line's scope effect is an explicit identity
#                         transition, never a skip.
#   cad-region-*         — R closes at the FIRST `^## ` heading after BEGIN,
#                         not specifically `## Non-goals` (AC4): a block with
#                         no `## Non-goals` heading at all still closes R at
#                         whatever heading comes first.
#   cad-shipped-*        — issue #577's four new tokens (missing, malformed
#                         x3, misplaced, unmeasured x2) plus two conformant
#                         passes (`this-task` and `issue #<N>`) and the
#                         `no`-beside-`shipped-docs` conflict (reuses
#                         marker-conflict, mints no fifteenth token).
#   cad-nofs-*           — the no-filesystem-access probe (AC11): an
#                         on-disk-existing path that is unmeasured (still
#                         refused) and an on-disk-absent path that is
#                         measured (still passes) — inverting filesystem
#                         truth against the checker's verdict.
#   cad-dogfood          — this task's own spec (T-1151) passes with zero
#                         output.

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
# optional indented line under AC1 — a surface line, a check line, or
# anything else the caller wants inserted verbatim there.
body() {  # $1 = optional indented line under AC1 (with leading spaces already applied by caller)
  local extra="${1:-}"
  printf 'Goal prose.\n\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** placeholder\n'
  if [ -n "$extra" ]; then printf '%s\n' "$extra"; fi
  printf '\n## Input space\n\nnot applicable.\n\n<!-- END intent-block: T-999 -->\n'
}
head_() {
  printf '# Fixture\n\n**Task ID**: T-999\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n\n'
}
# mk: a full fixture — declaration line ($2), optional extra AC1 line ($3,
# ALREADY prefixed with its own indent), optional top-level waiver line
# ($4), optional top-level `- shipped-docs:` line ($5, T-1151/issue #577).
mk() {
  local p="$1" d="$2" s="$3" w="$4" sh="${5:-}"
  {
    head_
    if [ -n "$d" ]; then printf '%s\n\n' "$d"; fi
    if [ -n "$sh" ]; then printf '%s\n\n' "$sh"; fi
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
NONE="$TMP/none.md"; mk "$NONE" '' '' '' ''
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

# --- R closes at the FIRST `^## ` heading, not specifically `## Non-goals`
# (AC4): a block with no `## Non-goals` heading at all, a declaration placed
# AFTER the first (only) heading is misplaced; the same declaration placed
# BEFORE it passes -----------------------------------------------------------
REGION_AFTER="$TMP/region-after.md"
{
  printf '# Fixture\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n\n## Acceptance criteria\n\n- [ ] **AC1** x\n\n'
  printf -- '- user-visible: no — after the first heading\n'
  printf '\n## Input space\n\nnot applicable.\n\n<!-- END intent-block: T-999 -->\n'
} > "$REGION_AFTER"
grep -qF -- '## Non-goals' "$REGION_AFTER" && fail "cad-region-after-first-heading: fixture sanity — must carry no Non-goals heading"
assert_case "cad-region-after-first-heading" 1 declaration-misplaced "$REGION_AFTER"

REGION_BEFORE="$TMP/region-before.md"
{
  printf '# Fixture\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n'
  printf -- '- user-visible: no — before the first heading\n'
  printf '\n## Acceptance criteria\n\n- [ ] **AC1** x\n\n## Input space\n\nnot applicable.\n\n<!-- END intent-block: T-999 -->\n'
} > "$REGION_BEFORE"
assert_case "cad-region-before-first-heading" 0 "" "$REGION_BEFORE"

# --- QA round-1 gap (a): R's non-content identity transition across a
# FENCED `^## ` heading sitting INSIDE R (round-1's cad-fence-* cases only
# exercised a fenced heading AFTER R had already closed, via the control
# pair and cad-fence-scope-survives — never one BEFORE R closes). Two
# placements, each as a fenced/unfenced pair: the heading between BEGIN and
# the declaration, and the heading between the declaration and the real
# `## Non-goals`. Fenced must not close R (declaration stays well-placed,
# pass); the same heading unfenced closes R (declaration-misplaced) — the
# same fence/no-fence control-pair discipline AC3 already applies to S. ----
REGION_FENCE_BEFORE_DECL_OK="$TMP/region-fence-before-decl-ok.md"
{
  printf '# Fixture\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n'
  printf '%s\n## Assumptions\n%s\n' "$TIC" "$TIC"
  printf -- '- user-visible: no — after a fenced heading, still inside R\n'
  printf '\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** x\n\n## Input space\n\nn/a\n\n<!-- END intent-block: T-999 -->\n'
} > "$REGION_FENCE_BEFORE_DECL_OK"
grep -qF -- '## Assumptions' "$REGION_FENCE_BEFORE_DECL_OK" || fail "cad-region-fence-before-decl: fixture sanity — heading text absent"
assert_case "cad-region-fence-before-decl-pass" 0 "" "$REGION_FENCE_BEFORE_DECL_OK"

REGION_PLAIN_BEFORE_DECL_BAD="$TMP/region-plain-before-decl-bad.md"
{
  printf '# Fixture\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n'
  printf '## Assumptions\n'
  printf -- '- user-visible: no — after an UNFENCED heading, R already closed\n'
  printf '\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** x\n\n## Input space\n\nn/a\n\n<!-- END intent-block: T-999 -->\n'
} > "$REGION_PLAIN_BEFORE_DECL_BAD"
assert_case "cad-region-fence-before-decl-control" 1 declaration-misplaced "$REGION_PLAIN_BEFORE_DECL_BAD"

# The "between the declaration and ## Non-goals" placement does NOT form a
# discriminating fenced/unfenced pair — verified live before writing this
# comment: a declaration is classified by its OWN line's R value at the
# moment it is matched, so a heading appearing AFTER it, fenced or not,
# never retroactively changes the declaration's already-recorded placement.
# Both members below pass; this is reported honestly as a non-discriminating
# confirmation (the placement was considered, not a coverage gap) rather
# than mislabelled as a red/green control pair.
REGION_FENCE_AFTER_DECL="$TMP/region-fence-after-decl.md"
{
  printf '# Fixture\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n'
  printf -- '- user-visible: no — before a fenced heading, still inside R\n'
  printf '%s\n## Assumptions\n%s\n' "$TIC" "$TIC"
  printf '\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** x\n\n## Input space\n\nn/a\n\n<!-- END intent-block: T-999 -->\n'
} > "$REGION_FENCE_AFTER_DECL"
grep -qF -- '## Assumptions' "$REGION_FENCE_AFTER_DECL" || fail "cad-region-fence-after-decl: fixture sanity — heading text absent"
assert_case "cad-region-fence-after-decl-pass" 0 "" "$REGION_FENCE_AFTER_DECL"

REGION_PLAIN_AFTER_DECL="$TMP/region-plain-after-decl.md"
{
  printf '# Fixture\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n'
  printf -- '- user-visible: no — before an unfenced extra heading\n'
  printf '## Assumptions\n'
  printf '\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** x\n\n## Input space\n\nn/a\n\n<!-- END intent-block: T-999 -->\n'
} > "$REGION_PLAIN_AFTER_DECL"
grep -qF -- 'user-visible' "$REGION_PLAIN_AFTER_DECL" || fail "cad-region-plain-after-decl: fixture sanity — declaration text absent"
assert_case "cad-region-plain-after-decl-still-pass" 0 "" "$REGION_PLAIN_AFTER_DECL"

# --- boundary placements (first line of block / last line before ## Non-goals)
# — both are VALID placements ------------------------------------------------
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
mk "$BARE" '- user-visible: yes — ships a new command' '' '' ''
assert_case "cad-undischarged-bare" 1 obligation-undischarged "$BARE"

EMPTYSURF="$TMP/emptysurf.md"
mk "$EMPTYSURF" '- user-visible: yes — x' '  - adopter-surface:    ' '' ''
assert_case "cad-undischarged-blank-surface" 1 obligation-undischarged "$EMPTYSURF"

# --- waiver-reason-empty (distinct from undischarged) ---------------------------
EMPTYWAIV="$TMP/emptywaiv.md"
mk "$EMPTYWAIV" '- user-visible: yes — x' '' '- adopter-docs-waiver:    ' ''
assert_case "cad-waiver-empty" 1 waiver-reason-empty "$EMPTYWAIV"
set +e
EW_ERR="$(bash "$CHECKER" "$EMPTYWAIV" 2>&1 1>/dev/null)"
set -e
printf '%s' "$EW_ERR" | grep -qx -- obligation-undischarged && fail "cad-waiver-empty: must not ALSO be reported as obligation-undischarged"

# --- marker-conflict --------------------------------------------------------------
BOTH="$TMP/both.md"
mk "$BOTH" '- user-visible: yes — x' '  - adopter-surface: docs/adopting.md' '- adopter-docs-waiver: no adopter surface exists here' ''
grep -qF -- '- adopter-surface:' "$BOTH" || fail "cad-conflict-both: fixture sanity — surface token absent"
grep -qF -- '- adopter-docs-waiver:' "$BOTH" || fail "cad-conflict-both: fixture sanity — waiver token absent"
assert_case "cad-conflict-both" 1 marker-conflict "$BOTH"

NOSURF="$TMP/nosurf.md"
mk "$NOSURF" '- user-visible: no — internal' '  - adopter-surface: docs/adopting.md' '' ''
assert_case "cad-conflict-no-with-surface" 1 marker-conflict "$NOSURF"

NOWAIV="$TMP/nowaiv.md"
mk "$NOWAIV" '- user-visible: no — internal' '' '- adopter-docs-waiver: nothing to document' ''
assert_case "cad-conflict-no-with-waiver" 1 marker-conflict "$NOWAIV"

# --- pass cases ------------------------------------------------------------------
NOPASS="$TMP/nopass.md"
mk "$NOPASS" '- user-visible: no — internal loop mechanics only' '' '' ''
assert_case "cad-pass-no" 0 "" "$NOPASS"

# The two yes-discharging pass cases now carry a conformant `- shipped-docs:`
# line (T-1151, issue #577) — a bare `yes` pass without one would now be
# shipped-docs-missing.
SURFPASS="$TMP/surfpass.md"
mk "$SURFPASS" '- user-visible: yes — ships a new command' '  - adopter-surface: docs/adopting.md' '' '- shipped-docs: docs/adopting.md — this-task'
assert_case "cad-pass-surface" 0 "" "$SURFPASS"

WAIVPASS="$TMP/waivpass.md"
mk "$WAIVPASS" '- user-visible: yes — ships a new command' '  - check: test -e docs/adopting.md' '- adopter-docs-waiver: this repository ships no adopter-readable surface' '- shipped-docs: docs/adopting.md — this-task'
assert_case "cad-pass-waiver" 0 "" "$WAIVPASS"

# --- fence blind-spot probes (DP5) --------------------------------------
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

# Tilde fences (T-1151 adds tilde tracking; the carved-out generation
# tracked backtick only) close the same way — a declaration wrapped in
# `~~~` is inert, exactly as a backtick-fenced one is.
TILDE="$TMP/tilde.md"
{
  head_
  printf '~~~\n'
  printf -- '- user-visible: no — inside a tilde fence\n'
  printf '~~~\n\n'
  body ""
} > "$TILDE"
grep -qF -- 'user-visible' "$TILDE" || fail "cad-fence-tilde: fixture sanity — token text absent entirely"
assert_case "cad-fence-tilde" 1 declaration-missing "$TILDE"

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

# --- round-1 rework regressions (Codex Major #1 + #2, class-closure) --------------
# Major #1 (Codex-reproduced): a bare AC with no discharge, plus an UNFENCED
# example line sitting in '## Notes for engineer' (outside the intent block,
# after the END marker) must NOT discharge — the whole-file scan the round-1
# checker used could see it; the scoped scan must not.
NOTES_SURFACE="$TMP/notes-surface.md"
{
  head_
  printf -- '- user-visible: yes — ships a new command\n\n'
  printf 'Goal prose.\n\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** placeholder\n\n## Input space\n\nnot applicable.\n\n<!-- END intent-block: T-999 -->\n\n## Notes for engineer\n\nIllustrative metadata:\n  - adopter-surface: docs/adopting.md\n'
} > "$NOTES_SURFACE"
assert_case "cad-scope-notes-unfenced-surface" 1 obligation-undischarged "$NOTES_SURFACE"

# Same class, waiver side (Codex adversarial pass confirmed this independently):
# a top-level waiver line after END must likewise not discharge.
NOTES_WAIVER="$TMP/notes-waiver.md"
{
  head_
  printf -- '- user-visible: yes — ships a new command\n\n'
  printf 'Goal prose.\n\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** placeholder\n\n## Input space\n\nnot applicable.\n\n<!-- END intent-block: T-999 -->\n\n## Assumptions\n\n- adopter-docs-waiver: this line is prose, not a discharge\n'
} > "$NOTES_WAIVER"
assert_case "cad-scope-notes-unfenced-waiver" 1 obligation-undischarged "$NOTES_WAIVER"

# Class-closure: a surface line that IS inside the intent block, and IS
# indented, but is NOT nested under any AC-bullet-shaped line (it sits right
# after the '## Acceptance criteria' heading, before AC1) must not discharge —
# "an acceptance criterion carries" the line, per the Goal's own wording.
NOT_UNDER_AC="$TMP/not-under-ac.md"
{
  head_
  printf -- '- user-visible: yes — ships a new command\n\n'
  printf 'Goal prose.\n\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n  - adopter-surface: docs/adopting.md\n\n- [ ] **AC1** placeholder\n\n## Input space\n\nnot applicable.\n\n<!-- END intent-block: T-999 -->\n'
} > "$NOT_UNDER_AC"
assert_case "cad-scope-surface-not-under-ac" 1 obligation-undischarged "$NOT_UNDER_AC"

# Major #2 (Codex-reproduced): two AC-nested surface lines, one blank and one
# valid — the verdict must be the SAME (a clean PASS) regardless of which one
# comes first. Both orders are asserted, matching the reviewer's own two-order
# fixture pair. Each now carries a conformant `- shipped-docs:` line
# (T-1151, issue #577), measured against the valid surface's own path.
ORDER_A="$TMP/order-a.md"
{
  head_
  printf -- '- user-visible: yes — ships a new command\n\n'
  printf -- '- shipped-docs: docs/adopting.md — this-task\n\n'
  printf 'Goal prose.\n\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** first\n  - adopter-surface:\n\n- [ ] **AC2** second\n  - adopter-surface: docs/adopting.md\n\n## Input space\n\nnot applicable.\n\n<!-- END intent-block: T-999 -->\n'
} > "$ORDER_A"
assert_case "cad-order-surface-blank-then-valid" 0 "" "$ORDER_A"

ORDER_B="$TMP/order-b.md"
{
  head_
  printf -- '- user-visible: yes — ships a new command\n\n'
  printf -- '- shipped-docs: docs/adopting.md — this-task\n\n'
  printf 'Goal prose.\n\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** first\n  - adopter-surface: docs/adopting.md\n\n- [ ] **AC2** second\n  - adopter-surface:\n\n## Input space\n\nnot applicable.\n\n<!-- END intent-block: T-999 -->\n'
} > "$ORDER_B"
assert_case "cad-order-surface-valid-then-blank" 0 "" "$ORDER_B"

# Same class-closure audit, applied to waiver (two top-level waiver lines in
# scope, one blank and one valid, both orders) — the spec ships no
# duplicate-waiver refusal token either, so the same any-valid semantics
# apply. A `- check:` line under AC1 gives the shipped-docs path something to
# be measured against, since these fixtures discharge by waiver, not surface.
WAIVER_ORDER_A="$TMP/waiver-order-a.md"
{
  head_
  printf -- '- user-visible: yes — ships a new command\n\n'
  printf -- '- shipped-docs: docs/adopting.md — this-task\n\n'
  printf -- '- adopter-docs-waiver:\n\n'
  printf -- '- adopter-docs-waiver: this repository ships no adopter-readable surface\n\n'
  body '  - check: test -e docs/adopting.md'
} > "$WAIVER_ORDER_A"
assert_case "cad-order-waiver-blank-then-valid" 0 "" "$WAIVER_ORDER_A"

WAIVER_ORDER_B="$TMP/waiver-order-b.md"
{
  head_
  printf -- '- user-visible: yes — ships a new command\n\n'
  printf -- '- shipped-docs: docs/adopting.md — this-task\n\n'
  printf -- '- adopter-docs-waiver: this repository ships no adopter-readable surface\n\n'
  printf -- '- adopter-docs-waiver:\n\n'
  body '  - check: test -e docs/adopting.md'
} > "$WAIVER_ORDER_B"
assert_case "cad-order-waiver-valid-then-blank" 0 "" "$WAIVER_ORDER_B"

# ==============================================================================
# T-1151 additions: the fence/no-fence control pair (AC3), a distinct
# fence-scope-survival probe, the shipped-docs family (issue #577), and the
# no-filesystem-access probe (AC11).
# ==============================================================================

# --- cad-control-pair-*: two fixtures identical except that one wraps an
# intervening `^## ` heading in a backtick fence — unfenced closes AC scope
# (obligation-undischarged); fenced is inert (an explicit identity
# transition), scope survives, and the fixture passes. This is the same
# behavioural probe AC3 freezes, ported into the suite verbatim. ------------
control_pair_head() {
  printf '# Fixture\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n'
  printf -- '- user-visible: yes — ships a new command\n'
  printf -- '- shipped-docs: docs/x.md — this-task\n'
  printf '\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** x\n'
}
control_pair_tail() {
  printf '  - adopter-surface: docs/x.md\n\n## Input space\n\nn/a\n\n<!-- END intent-block: T-999 -->\n'
}
CP_PLAIN="$TMP/control-pair-plain.md"
{ control_pair_head; printf '## Notes\n'; control_pair_tail; } > "$CP_PLAIN"
CP_FENCED="$TMP/control-pair-fenced.md"
{ control_pair_head; printf '%s\n## Notes\n%s\n' "$TIC" "$TIC"; control_pair_tail; } > "$CP_FENCED"
for f in "$CP_PLAIN" "$CP_FENCED"; do
  grep -qF -- '## Notes' "$f" || fail "cad-control-pair: fixture sanity — heading text absent"
  grep -qF -- '- adopter-surface: docs/x.md' "$f" || fail "cad-control-pair: fixture sanity — surface token absent"
done
assert_case "cad-control-pair-plain" 1 obligation-undischarged "$CP_PLAIN"
assert_case "cad-control-pair-fenced" 0 "" "$CP_FENCED"

# --- cad-fence-scope-survives: a DIFFERENT fenced heading (`## Assumptions`,
# deeper in the block, between AC1's bullet and its surface line) — a
# distinct fixture from the control pair, still probing the same identity-
# transition property so the R2 finding's closure is not carried by a single
# fixture alone. ---------------------------------------------------------------
FENCE_SCOPE="$TMP/fence-scope-survives.md"
{
  printf '# Fixture\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n'
  printf -- '- user-visible: yes — ships a new command\n'
  printf -- '- shipped-docs: docs/x.md — this-task\n'
  printf '\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** x\n'
  printf '%s\n## Assumptions\n%s\n' "$TIC" "$TIC"
  printf '  - adopter-surface: docs/x.md\n'
  printf '\n## Input space\n\nn/a\n\n<!-- END intent-block: T-999 -->\n'
} > "$FENCE_SCOPE"
grep -qF -- '## Assumptions' "$FENCE_SCOPE" || fail "cad-fence-scope-survives: fixture sanity — heading text absent"
assert_case "cad-fence-scope-survives" 0 "" "$FENCE_SCOPE"

# --- cad-shipped-*: the four new tokens, two conformant passes, and the
# `no`-beside-`shipped-docs` conflict (issue #577) ----------------------------
mkship() {  # p ship-line-or-empty extra-AC1-line-or-empty waiver-line-or-empty out-of-region-shipped-line-or-empty
  local p="$1" ship="$2" s="$3" w="$4" outship="$5"
  {
    head_
    printf -- '- user-visible: yes — ships a new command\n\n'
    if [ -n "$ship" ]; then printf '%s\n\n' "$ship"; fi
    if [ -n "$w" ]; then printf '%s\n\n' "$w"; fi
    body "$s"
    if [ -n "$outship" ]; then printf '\n## Notes for engineer\n\n%s\n' "$outship"; fi
  } > "$p"
}

SHIP_MISSING="$TMP/ship-missing.md"
mkship "$SHIP_MISSING" '' '  - adopter-surface: docs/x.md' '' ''
assert_case "cad-shipped-missing" 1 shipped-docs-missing "$SHIP_MISSING"

SHIP_M1="$TMP/ship-malformed-no-sep.md"
mkship "$SHIP_M1" '- shipped-docs: docs/x.md this-task' '  - adopter-surface: docs/x.md' '' ''
assert_case "cad-shipped-malformed-no-separator" 1 shipped-docs-malformed "$SHIP_M1"

SHIP_M2="$TMP/ship-malformed-empty-path.md"
mkship "$SHIP_M2" '- shipped-docs:  — this-task' '  - adopter-surface: docs/x.md' '' ''
assert_case "cad-shipped-malformed-empty-path" 1 shipped-docs-malformed "$SHIP_M2"

SHIP_M3="$TMP/ship-malformed-bad-disposition.md"
mkship "$SHIP_M3" '- shipped-docs: docs/x.md — someday' '  - adopter-surface: docs/x.md' '' ''
assert_case "cad-shipped-malformed-bad-disposition" 1 shipped-docs-malformed "$SHIP_M3"

SHIP_MISPLACED="$TMP/ship-misplaced.md"
mkship "$SHIP_MISPLACED" '' '  - adopter-surface: docs/x.md' '' '- shipped-docs: docs/x.md — this-task'
assert_case "cad-shipped-misplaced" 1 shipped-docs-misplaced "$SHIP_MISPLACED"

SHIP_UNMEASURED="$TMP/ship-unmeasured.md"
mkship "$SHIP_UNMEASURED" '- shipped-docs: docs/nowhere-named.md — this-task' '  - adopter-surface: docs/x.md' '' ''
assert_case "cad-shipped-unmeasured" 1 shipped-docs-unmeasured "$SHIP_UNMEASURED"

SHIP_UNMEASURED_FENCED="$TMP/ship-unmeasured-fenced.md"
{
  head_
  printf -- '- user-visible: yes — ships a new command\n\n'
  printf -- '- shipped-docs: docs/x.md — this-task\n\n'
  printf 'Goal prose.\n\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** x\n  - adopter-surface: docs/other.md\n'
  printf '%s\n  - check: grep -q docs/x.md .\n%s\n' "$TIC" "$TIC"
  printf '\n## Input space\n\nn/a\n\n<!-- END intent-block: T-999 -->\n'
} > "$SHIP_UNMEASURED_FENCED"
assert_case "cad-shipped-unmeasured-fenced" 1 shipped-docs-unmeasured "$SHIP_UNMEASURED_FENCED"

SHIP_PASS_TASK="$TMP/ship-pass-this-task.md"
mkship "$SHIP_PASS_TASK" '- shipped-docs: docs/x.md — this-task' '  - adopter-surface: docs/x.md' '' ''
assert_case "cad-shipped-pass-this-task" 0 "" "$SHIP_PASS_TASK"

SHIP_PASS_ISSUE="$TMP/ship-pass-issue.md"
mkship "$SHIP_PASS_ISSUE" '- shipped-docs: docs/y.md — issue #577' '  - adopter-surface: docs/x.md' '' ''
assert_case "cad-shipped-pass-issue" 0 "" "$SHIP_PASS_ISSUE"

# --- QA round-1 gap (b): the `issue #<N>` disposition grammar's own edge
# cases — a non-digit tail, no digits at all, a digit run with a trailing
# non-digit, and the boundary value `0` (legal: the grammar requires digits,
# not a positive integer) -----------------------------------------------------
SHIP_ISSUE_NONDIGIT="$TMP/ship-issue-nondigit.md"
mkship "$SHIP_ISSUE_NONDIGIT" '- shipped-docs: docs/x.md — issue #abc' '  - adopter-surface: docs/x.md' '' ''
assert_case "cad-shipped-issue-nondigit" 1 shipped-docs-malformed "$SHIP_ISSUE_NONDIGIT"

SHIP_ISSUE_NODIGITS="$TMP/ship-issue-nodigits.md"
mkship "$SHIP_ISSUE_NODIGITS" '- shipped-docs: docs/x.md — issue #' '  - adopter-surface: docs/x.md' '' ''
assert_case "cad-shipped-issue-nodigits" 1 shipped-docs-malformed "$SHIP_ISSUE_NODIGITS"

SHIP_ISSUE_TRAILING="$TMP/ship-issue-trailing.md"
mkship "$SHIP_ISSUE_TRAILING" '- shipped-docs: docs/x.md — issue #12a' '  - adopter-surface: docs/x.md' '' ''
assert_case "cad-shipped-issue-trailing-nondigit" 1 shipped-docs-malformed "$SHIP_ISSUE_TRAILING"

SHIP_ISSUE_ZERO="$TMP/ship-issue-zero.md"
mkship "$SHIP_ISSUE_ZERO" '- shipped-docs: docs/x.md — issue #0' '  - adopter-surface: docs/x.md' '' ''
assert_case "cad-shipped-issue-zero" 0 "" "$SHIP_ISSUE_ZERO"

SHIP_CONFLICT_NO="$TMP/ship-conflict-no.md"
mk "$SHIP_CONFLICT_NO" '- user-visible: no — internal' '' '' '- shipped-docs: docs/x.md — this-task'
assert_case "cad-shipped-conflict-no" 1 marker-conflict "$SHIP_CONFLICT_NO"
CLEAN_NO="$TMP/ship-clean-no.md"
mk "$CLEAN_NO" '- user-visible: no — internal' '' '' ''
assert_case "cad-shipped-clean-no" 0 "" "$CLEAN_NO"

# --- yes/no x waiver/surface/shipped-docs conflict matrix: the remaining
# untested cell — a `no` declaration carrying BOTH a waiver AND a surface
# at once still reuses `marker-conflict` (no new precedence interaction) ----
SHIP_CONFLICT_NO_BOTH="$TMP/ship-conflict-no-both.md"
mk "$SHIP_CONFLICT_NO_BOTH" '- user-visible: no — internal' '  - adopter-surface: docs/x.md' '- adopter-docs-waiver: nothing to document' ''
assert_case "cad-conflict-no-with-both" 1 marker-conflict "$SHIP_CONFLICT_NO_BOTH"

# --- cad-nofs-*: the no-filesystem-access probe (AC11) — filesystem truth
# and checker verdict must invert cleanly in both directions ------------------
test -f "$REPO_ROOT/README.md" || fail "cad-nofs-exists-unmeasured: fixture sanity — README.md must exist on disk"
NOFS_EXISTS="$TMP/nofs-exists-unmeasured.md"
mkship "$NOFS_EXISTS" '- shipped-docs: README.md — this-task' '  - adopter-surface: docs/other.md' '' ''
assert_case "cad-nofs-exists-unmeasured" 1 shipped-docs-unmeasured "$NOFS_EXISTS"

test ! -e "$REPO_ROOT/no/such/path-xyz.md" || fail "cad-nofs-absent-measured: fixture sanity — the absent path must not exist"
NOFS_ABSENT="$TMP/nofs-absent-measured.md"
mkship "$NOFS_ABSENT" '- shipped-docs: no/such/path-xyz.md — this-task' '  - check: test -f no/such/path-xyz.md' '- adopter-docs-waiver: no adopter-readable surface for this internal path' ''
assert_case "cad-nofs-absent-measured" 0 "" "$NOFS_ABSENT"

# --- dogfood: this task's own spec ------------------------------------------------
SELF_SPEC="$REPO_ROOT/.shell-team/specs/T-1151-adopter-docs-checker.md"
assert_case "cad-dogfood" 0 "" "$SELF_SPEC"

printf '\ncheck-adopter-docs fixture suite: all %d cases passed\n' "$CASES"
