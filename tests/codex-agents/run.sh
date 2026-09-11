#!/usr/bin/env bash
# run.sh — fixture suite for bin/gen-codex-agents.sh AND bin/check-codex-agents.sh
# together (T-1134; GitHub issue #484;
# .shell-team/specs/T-1134-codex-host-slice1.md).
#
# One suite for both scripts, deliberately (D6): the sync checker is only
# meaningful against the generator's own output, so splitting the scripts
# into two suites would duplicate every fixture rather than duplicate any
# coverage.
#
# The five PASS lines AC7 requires verbatim are emitted exactly once each,
# from the five fixtures below. Additional fixtures beyond those five cover
# the remaining reachable input classes the spec's own `## Input space`
# enumerates (the other three refusal shapes, the positive apostrophe
# control, a missing/extra file at the checker, a malformed description,
# and all three invocation shapes — the test-harness short-circuit class).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
GEN="$REPO_ROOT/bin/gen-codex-agents.sh"
CHK="$REPO_ROOT/bin/check-codex-agents.sh"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

T="$(mktemp -d "${TMPDIR:-/tmp}/codex-agents-suite.XXXXXX")"
trap 'rm -rf "$T"' EXIT

# count_toml <dir> <glob> — 0 if <dir> does not exist (a refused generator run
# never creates its out-dir at all), never lets a nonexistent-directory `find`
# failure propagate through pipefail and abort this suite under set -e.
count_toml() {
  local dir="$1" pat="$2"
  if [ -d "$dir" ]; then
    find "$dir" -name "$pat" 2>/dev/null | wc -l | tr -d ' '
  else
    printf '0\n'
  fi
}

ROLES="tech-lead pm-spec engineer qa-verifier"

# =============================================================================
# fixture 1 (AC7 fixed string 1): the generated developer_instructions body is
# byte-identical to the role file body, for every one of the four shipped
# roles, against the real agents/*.md in this checkout.
# =============================================================================
printf '\n--- fixture 1: byte-identical developer_instructions body ---\n'
OUT1="$T/out1"
if bash "$GEN" --root "$REPO_ROOT" --out-dir "$OUT1" >"$T/gen1.out" 2>"$T/gen1.err"; then
  ok=1
  for r in $ROLES; do
    F="$OUT1/shell-team-$r.toml"
    if [ ! -s "$F" ]; then ok=0; continue; fi
    AWK_OUT="$T/body-$r"
    awk -v k="developer_instructions = '''" 'f{print} $0==k{f=1}' "$F" > "$T/raw-$r"
    sed '$d' "$T/raw-$r" > "$AWK_OUT"
    SRC="$T/src-$r"
    awk 'BEGIN{n=0} /^---$/ && n<2 {n++; next} n==2{print}' "$REPO_ROOT/agents/$r.md" > "$SRC"
    cmp -s "$AWK_OUT" "$SRC" || ok=0
    tail -n 1 "$F" | grep -Fxq -- "'''" || ok=0
  done
  if [ "$ok" -eq 1 ]; then
    pass "T-1134: the generated developer_instructions body is byte-identical to the role file body"
  else
    fail "T-1134: the generated developer_instructions body is byte-identical to the role file body"
  fi
else
  fail "T-1134: the generated developer_instructions body is byte-identical to the role file body (generator refused: $(cat "$T/gen1.err"))"
fi

# =============================================================================
# fixture 2 (AC7 fixed string 2): a role body carrying the TOML literal-string
# terminator ''' is refused, whole-run, with no file written at all.
# =============================================================================
printf '\n--- fixture 2: a role body carrying a TOML literal-string terminator is refused ---\n'
R2="$T/r2"
mkdir -p "$R2/agents"
cp "$REPO_ROOT"/agents/*.md "$R2/agents/"
printf "'''\n" >> "$R2/agents/pm-spec.md"
OUT2="$T/out2"
if bash "$GEN" --root "$R2" --out-dir "$OUT2" >/dev/null 2>"$T/gen2.err"; then
  fail "T-1134: a role body carrying a TOML literal-string terminator is refused with no file written (generator did not refuse)"
else
  n="$(count_toml "$OUT2" '*.toml')"
  if [ "$n" -eq 0 ]; then
    pass "T-1134: a role body carrying a TOML literal-string terminator is refused with no file written"
  else
    fail "T-1134: a role body carrying a TOML literal-string terminator is refused with no file written (found $n stray file(s))"
  fi
fi

# --- adversarial coverage: the three other refusal classes (not one of AC7's
#     five fixed strings, but the same Input space classes 6-8 the generator
#     itself must refuse) --------------------------------------------------
printf '\n--- extra: the remaining three refusal classes (Input space 6-8) ---\n'
i=0
for bad in noeol ctrl nofm; do
  i=$((i + 1))
  R="$T/rx$i"
  mkdir -p "$R/agents"
  cp "$REPO_ROOT"/agents/*.md "$R/agents/"
  case "$bad" in
    noeol) printf "%s" "a line ending in a quote '" >> "$R/agents/pm-spec.md" ;;
    ctrl)  printf 'a\014b\n' >> "$R/agents/pm-spec.md" ;;
    nofm)  printf 'no frontmatter at all\n' > "$R/agents/pm-spec.md" ;;
  esac
  OX="$T/ox$i"
  if bash "$GEN" --root "$R" --out-dir "$OX" >/dev/null 2>&1; then
    fail "T-1134 extra: '$bad' source is refused (generator did not refuse)"
  else
    n="$(count_toml "$OX" '*.toml')"
    if [ "$n" -eq 0 ]; then
      pass "T-1134 extra: '$bad' source is refused with no file written"
    else
      fail "T-1134 extra: '$bad' source is refused with no file written (found $n stray file(s))"
    fi
  fi
done

# --- adversarial coverage: positive control — two consecutive apostrophes and
#     a line ending in a single apostrophe are LEGAL and must still generate,
#     proving the refusal is narrower than "anything quote-shaped" ----------
printf '\n--- extra: positive control — legal apostrophe shapes still generate ---\n'
ROK="$T/rok"
mkdir -p "$ROK/agents"
cp "$REPO_ROOT"/agents/*.md "$ROK/agents/"
printf "%s\n" "two quotes '' and a trailing quote '" >> "$ROK/agents/pm-spec.md"
OOK="$T/ook"
if bash "$GEN" --root "$ROK" --out-dir "$OOK" >/dev/null 2>"$T/genok.err" \
  && [ -s "$OOK/shell-team-pm-spec.toml" ] \
  && [ "$(find "$OOK" -name 'shell-team-*.toml' | wc -l | tr -d ' ')" -eq 4 ]; then
  pass "T-1134 extra: two consecutive apostrophes and a trailing-line apostrophe are legal and still generate"
else
  fail "T-1134 extra: the positive apostrophe control did not generate ($(cat "$T/genok.err"))"
fi

# --- adversarial coverage: a description: carrying a double quote or a
#     backslash is refused (D5 / Input space class 9) -----------------------
printf '\n--- extra: a malformed description: is refused ---\n'
i=0
for kind in quote backslash; do
  i=$((i + 1))
  RD="$T/rd$i"
  mkdir -p "$RD/agents"
  cp "$REPO_ROOT"/agents/*.md "$RD/agents/"
  case "$kind" in
    quote)     BADDESC='description: a bad value with a " quote' ;;
    backslash) BADDESC='description: a bad value with a \ backslash' ;;
  esac
  # head/tail/printf, never `awk -v` for this substitution: awk's -v
  # assignment processes C-style backslash escapes in its VALUE, which would
  # silently mangle the literal backslash this fixture depends on.
  {
    head -n 2 "$RD/agents/pm-spec.md"
    printf '%s\n' "$BADDESC"
    tail -n "+4" "$RD/agents/pm-spec.md"
  } > "$RD/agents/pm-spec.md.new"
  mv "$RD/agents/pm-spec.md.new" "$RD/agents/pm-spec.md"
  OD="$T/od$i"
  if bash "$GEN" --root "$RD" --out-dir "$OD" >/dev/null 2>&1; then
    fail "T-1134 extra: a description: containing a $kind is refused (generator did not refuse)"
  else
    n="$(count_toml "$OD" '*.toml')"
    if [ "$n" -eq 0 ]; then
      pass "T-1134 extra: a description: containing a $kind is refused with no file written"
    else
      fail "T-1134 extra: a description: containing a $kind is refused with no file written (found $n stray file(s))"
    fi
  fi
done

# =============================================================================
# fixture 3 (AC7 fixed string 3): a drifted generated agent file is refused
# by the sync checker, and every untouched file stays byte-identical.
# =============================================================================
printf '\n--- fixture 3: a drifted generated agent file is refused by the sync checker ---\n'
OUT3="$T/out3"
bash "$GEN" --root "$REPO_ROOT" --out-dir "$OUT3" >/dev/null 2>&1
if ! bash "$CHK" --root "$REPO_ROOT" --out-dir "$OUT3" >/dev/null 2>&1; then
  fail "T-1134: a drifted generated agent file is refused by the sync checker (a freshly generated out-dir was not accepted as in-sync)"
fi
cp -R "$OUT3" "$T/snap3"
printf 'x\n' >> "$OUT3/shell-team-pm-spec.toml"
if bash "$CHK" --root "$REPO_ROOT" --out-dir "$OUT3" >/dev/null 2>&1; then
  fail "T-1134: a drifted generated agent file is refused by the sync checker (checker did not refuse the drift)"
else
  if cmp -s "$OUT3/shell-team-engineer.toml" "$T/snap3/shell-team-engineer.toml" \
    && cmp -s "$OUT3/shell-team-tech-lead.toml" "$T/snap3/shell-team-tech-lead.toml" \
    && cmp -s "$OUT3/shell-team-qa-verifier.toml" "$T/snap3/shell-team-qa-verifier.toml" \
    && ! cmp -s "$OUT3/shell-team-pm-spec.toml" "$T/snap3/shell-team-pm-spec.toml"; then
    pass "T-1134: a drifted generated agent file is refused by the sync checker"
  else
    fail "T-1134: a drifted generated agent file is refused by the sync checker (byte-preservation of untouched files was violated)"
  fi
fi

# --- adversarial coverage: a missing expected file, and an extra
#     shell-team-*.toml the checker does not own, are both refused ---------
printf '\n--- extra: missing/extra file refusals at the checker ---\n'
rm -f "$OUT3/shell-team-qa-verifier.toml"
if bash "$CHK" --root "$REPO_ROOT" --out-dir "$OUT3" >/dev/null 2>&1; then
  fail "T-1134 extra: a missing expected role file is refused by the checker (checker did not refuse)"
else
  pass "T-1134 extra: a missing expected role file is refused by the checker"
fi
cp "$T/snap3/shell-team-qa-verifier.toml" "$OUT3/shell-team-qa-verifier.toml"
cp "$T/snap3/shell-team-engineer.toml" "$OUT3/shell-team-bogus-role.toml"
if bash "$CHK" --root "$REPO_ROOT" --out-dir "$OUT3" >/dev/null 2>&1; then
  fail "T-1134 extra: an extra shell-team-*.toml this generator does not own is refused (checker did not refuse)"
else
  pass "T-1134 extra: an extra shell-team-*.toml this generator does not own is refused"
fi
rm -f "$OUT3/shell-team-bogus-role.toml"

# =============================================================================
# fixture 4 (AC7 fixed string 4): a Codex-adapter binding row emits `model`
# and `model_reasoning_effort` — the only place this emitting branch runs at
# all, since the shipped default binding never reaches it (AC4/D3-model).
# Supplies a Codex-adapter row through a $TEAM_RUN_BASE-resolved fixture
# binding.conf, the same override path an adopter uses (Notes for engineer).
# =============================================================================
printf '\n--- fixture 4: a Codex-adapter binding row emits model and model_reasoning_effort ---\n'
WD4="$T/wd4"
BASE4="fixture-base4"
mkdir -p "$WD4/$BASE4"
cat > "$WD4/$BASE4/binding.conf" <<'CONF'
schema 1

bind tech-lead      claude opus   - claude-cli
bind pm-spec        claude opus   - claude-cli
bind engineer       claude sonnet - claude-cli
bind qa-verifier    codex  gpt-5-codex low codex-cli
bind ui-designer    claude sonnet - claude-cli
bind codex-reviewer codex  provider-configured - codex-cli
CONF
OUT4="$T/out4"
if (cd "$WD4" && TEAM_RUN_BASE="$BASE4" bash "$GEN" --root "$REPO_ROOT" --out-dir "$OUT4" >/dev/null 2>"$T/gen4.err"); then
  F="$OUT4/shell-team-qa-verifier.toml"
  ok=1
  grep -Fxq -- 'model = "gpt-5-codex"' "$F" || ok=0
  grep -Fxq -- 'model_reasoning_effort = "low"' "$F" || ok=0
  for r in tech-lead pm-spec engineer; do
    Fr="$OUT4/shell-team-$r.toml"
    { grep -q '^model = ' "$Fr" || grep -q '^model_reasoning_effort = ' "$Fr"; } && ok=0
  done
  if [ "$ok" -eq 1 ]; then
    pass "T-1134: a Codex-adapter binding row emits model and model_reasoning_effort"
  else
    fail "T-1134: a Codex-adapter binding row emits model and model_reasoning_effort"
  fi
else
  fail "T-1134: a Codex-adapter binding row emits model and model_reasoning_effort (generation failed: $(cat "$T/gen4.err"))"
fi

# =============================================================================
# fixture 5 (AC7 fixed string 5): a TOML the generator does not own is left
# untouched in the out-dir, byte-for-byte, across a real generator re-run.
# =============================================================================
printf '\n--- fixture 5: a TOML the generator does not own is left untouched in the out-dir ---\n'
OUT5="$T/out5"
bash "$GEN" --root "$REPO_ROOT" --out-dir "$OUT5" >/dev/null 2>&1
printf 'name = "my-own-agent"\n' > "$OUT5/my-own-agent.toml"
BEFORE="$(cat "$OUT5/my-own-agent.toml")"
bash "$GEN" --root "$REPO_ROOT" --out-dir "$OUT5" >/dev/null 2>&1
AFTER="$(cat "$OUT5/my-own-agent.toml")"
if [ "$BEFORE" = "$AFTER" ] && bash "$CHK" --root "$REPO_ROOT" --out-dir "$OUT5" >/dev/null 2>&1; then
  pass "T-1134: a TOML the generator does not own is left untouched in the out-dir"
else
  fail "T-1134: a TOML the generator does not own is left untouched in the out-dir"
fi

# =============================================================================
# extra: default --root/--out-dir (no flags at all). --root must resolve to
# this script's OWN plugin root (never the caller's cwd — an adopted
# repository has no agents/ of its own), and --out-dir must resolve to
# $PWD/.codex/agents (the caller's own directory, independent of --root).
# Regression lock for the class QA's round-1 AC9 finding named: docs told an
# adopter to run "bash bin/gen-codex-agents.sh" from their own repository,
# where no bin/ or agents/ exists at all.
# =============================================================================
printf '\n--- extra: default --root/--out-dir (no flags) ---\n'
DEFCWD="$T/defaultcwd"
mkdir -p "$DEFCWD"
if ( cd "$DEFCWD" && bash "$GEN" >/dev/null 2>"$T/gendef.err" ); then
  ok=1
  for r in $ROLES; do
    F="$DEFCWD/.codex/agents/shell-team-$r.toml"
    if [ -s "$F" ]; then
      SRC="$T/defsrc-$r"
      awk 'BEGIN{n=0} /^---$/ && n<2 {n++; next} n==2{print}' "$REPO_ROOT/agents/$r.md" > "$SRC"
      awk -v k="developer_instructions = '''" 'f{print} $0==k{f=1}' "$F" > "$T/defraw-$r"
      sed '$d' "$T/defraw-$r" > "$T/defbody-$r"
      cmp -s "$T/defbody-$r" "$SRC" || ok=0
    else
      ok=0
    fi
  done
  if [ "$ok" -eq 1 ]; then
    pass "T-1134 extra: no-flag invocation defaults --root to the generator's own plugin root and --out-dir to \$PWD/.codex/agents"
  else
    fail "T-1134 extra: no-flag invocation defaults --root to the generator's own plugin root and --out-dir to \$PWD/.codex/agents (missing file or byte mismatch)"
  fi
else
  fail "T-1134 extra: no-flag invocation defaults --root to the generator's own plugin root and --out-dir to \$PWD/.codex/agents (generator refused: $(cat "$T/gendef.err"))"
fi
if ( cd "$DEFCWD" && bash "$CHK" >/dev/null 2>"$T/chkdef.err" ); then
  pass "T-1134 extra: check-codex-agents.sh's own no-flag defaults agree with gen-codex-agents.sh's no-flag output"
else
  fail "T-1134 extra: check-codex-agents.sh's own no-flag defaults agree with gen-codex-agents.sh's no-flag output ($(cat "$T/chkdef.err"))"
fi

# =============================================================================
# extra: test-harness short-circuit class (playbook adversarial checklist
# class 4) — the real invocation forms, not only `bash script`.
# =============================================================================
printf '\n--- extra: launch-shape coverage (bash script / ./script / PATH bare name) ---\n'
if bash "$GEN" --help >/dev/null 2>&1; then
  pass "T-1134 extra: gen-codex-agents.sh runs via 'bash script' invocation"
else
  fail "T-1134 extra: gen-codex-agents.sh runs via 'bash script' invocation"
fi
if "$GEN" --help >/dev/null 2>&1; then
  pass "T-1134 extra: gen-codex-agents.sh runs via direct './script' invocation (exec bit honored)"
else
  fail "T-1134 extra: gen-codex-agents.sh runs via direct './script' invocation (exec bit honored)"
fi
PATHBIN="$T/pathbin"
mkdir -p "$PATHBIN"
ln -s "$GEN" "$PATHBIN/gen-codex-agents.sh"
ln -s "$CHK" "$PATHBIN/check-codex-agents.sh"
ln -s "$REPO_ROOT/bin/resolve-executor.sh" "$PATHBIN/resolve-executor.sh"
ln -s "$REPO_ROOT/bin/team-paths.sh" "$PATHBIN/team-paths.sh"
ln -s "$REPO_ROOT/bin/check-binding.sh" "$PATHBIN/check-binding.sh"
ln -s "$REPO_ROOT/bin/check-adapter.sh" "$PATHBIN/check-adapter.sh"
if PATH="$PATHBIN:$PATH" gen-codex-agents.sh --help >/dev/null 2>&1; then
  pass "T-1134 extra: gen-codex-agents.sh runs via a bare PATH-resolved name"
else
  fail "T-1134 extra: gen-codex-agents.sh runs via a bare PATH-resolved name"
fi

# =============================================================================
# extra: --help exits 0 for both scripts (a bare usage read must never refuse)
# =============================================================================
if bash "$GEN" --help >/dev/null 2>&1; then
  pass "T-1134 extra: gen-codex-agents.sh --help exits 0"
else
  fail "T-1134 extra: gen-codex-agents.sh --help exits 0"
fi
if bash "$CHK" --help >/dev/null 2>&1; then
  pass "T-1134 extra: check-codex-agents.sh --help exits 0"
else
  fail "T-1134 extra: check-codex-agents.sh --help exits 0"
fi

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'codex-agents suite: all assertions passed\n'
  exit 0
else
  printf 'codex-agents suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
