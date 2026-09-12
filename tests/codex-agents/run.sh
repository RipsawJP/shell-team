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

# --- adversarial coverage: the four other refusal classes (not one of AC7's
#     five fixed strings, but the same Input space classes 6-8 the generator
#     itself must refuse — nul is the same class 7 as ctrl, exercised as its
#     own fixture because it is the class round-1 review found unrefused) --
printf '\n--- extra: the remaining four refusal classes (Input space 6-8, nul included) ---\n'
i=0
for bad in noeol ctrl nul nofm; do
  i=$((i + 1))
  R="$T/rx$i"
  mkdir -p "$R/agents"
  cp "$REPO_ROOT"/agents/*.md "$R/agents/"
  case "$bad" in
    noeol) printf "%s" "a line ending in a quote '" >> "$R/agents/pm-spec.md" ;;
    ctrl)  printf 'a\014b\n' >> "$R/agents/pm-spec.md" ;;
    nul)   printf 'a\000b\n' >> "$R/agents/pm-spec.md" ;;
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
# Derived from the generator's OWN default ROLES (not this suite's fixed
# 4-role $ROLES above), since this fixture runs the generator with no
# --roles override — read live so a future default-role-count change (as
# T-1135's own fifth role already was) cannot silently desync this count.
EXPECT_ROLE_COUNT="$(sed -n 's/^ROLES="\(.*\)"$/\1/p' "$GEN" | head -1 | tr ' ' '\n' | grep -c .)"
if bash "$GEN" --root "$ROK" --out-dir "$OOK" >/dev/null 2>"$T/genok.err" \
  && [ -s "$OOK/shell-team-pm-spec.toml" ] \
  && [ "$(find "$OOK" -name 'shell-team-*.toml' | wc -l | tr -d ' ')" -eq "$EXPECT_ROLE_COUNT" ]; then
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
# fixture 6 (T-1135 AC7 fixed string 1): the generated developer_instructions
# body for the fifth role, codex-reviewer, is byte-identical to
# agents/codex-reviewer.md's own content, and neither model nor
# model_reasoning_effort is emitted under the shipped default binding.
# =============================================================================
printf '\n--- fixture 6 (T-1135): codex-reviewer developer_instructions body ---\n'
OUT6="$T/out6"
if bash "$GEN" --root "$REPO_ROOT" --out-dir "$OUT6" >"$T/gen6.out" 2>"$T/gen6.err"; then
  F6="$OUT6/shell-team-codex-reviewer.toml"
  ok=1
  if [ -s "$F6" ]; then
    awk -v k="developer_instructions = '''" 'f{print} $0==k{f=1}' "$F6" > "$T/raw6"
    sed '$d' "$T/raw6" > "$T/body6"
    awk 'BEGIN{n=0} /^---$/ && n<2 {n++; next} n==2{print}' "$REPO_ROOT/agents/codex-reviewer.md" > "$T/src6"
    cmp -s "$T/body6" "$T/src6" || ok=0
    tail -n 1 "$F6" | grep -Fxq -- "'''" || ok=0
    grep -Fxq -- 'name = "shell-team-codex-reviewer"' "$F6" || ok=0
    { grep -q '^model = ' "$F6" || grep -q '^model_reasoning_effort = ' "$F6"; } && ok=0
  else
    ok=0
  fi
  if [ "$ok" -eq 1 ]; then
    pass "T-1135: the generated developer_instructions body is byte-identical to agents/codex-reviewer.md"
  else
    fail "T-1135: the generated developer_instructions body is byte-identical to agents/codex-reviewer.md"
  fi
else
  fail "T-1135: the generated developer_instructions body is byte-identical to agents/codex-reviewer.md (generator refused: $(cat "$T/gen6.err"))"
fi

# =============================================================================
# fixture 7 (T-1135 AC7 fixed string 2/3): the Claude-side review recipe's
# capture shape (D3 — stream-json, one JSON object per line, each carrying a
# "type" key) is accepted by the unmodified bin/codex-capture.sh --publish
# unchanged, and a jsonl carrying no typed event at all is refused.
# =============================================================================
printf '\n--- fixture 7 (T-1135): Claude stream-json capture shape at codex-capture.sh ---\n'
CC="$REPO_ROOT/bin/codex-capture.sh"
RVDIR="$T/rv7"
mkdir -p "$RVDIR"
P1="$(bash "$CC" --alloc --stem t1135claudecapok --reviews-dir "$RVDIR" 2>"$T/alloc7.err")"
if [ -n "$P1" ]; then
  O1="$(printf '%s\n' "$P1" | sed -n 1p)"
  J1="$(printf '%s\n' "$P1" | sed -n 2p)"
  printf '%s\n' \
    '{"type":"system","subtype":"init"}' \
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"reviewing"}]}}' \
    '{"type":"result","subtype":"success","is_error":false,"duration_ms":4567,"total_cost_usd":0.1234,"usage":{"total_tokens":890},"result":"APPROVE"}' \
    > "$J1"
  tail -n 1 "$J1" > "$O1"
  if bash "$CC" --publish --stem t1135claudecapok --publish-out "$O1" --publish-jsonl "$J1" --reviews-dir "$RVDIR" >/dev/null 2>"$T/pub7.err" \
    && [ -s "$RVDIR/t1135claudecapok.txt" ] && [ -s "$RVDIR/t1135claudecapok.jsonl" ]; then
    pass "T-1135: a Claude stream-json-shaped capture passes codex-capture.sh --publish unchanged"
  else
    fail "T-1135: a Claude stream-json-shaped capture passes codex-capture.sh --publish unchanged ($(cat "$T/pub7.err"))"
  fi
else
  fail "T-1135: a Claude stream-json-shaped capture passes codex-capture.sh --publish unchanged (alloc refused: $(cat "$T/alloc7.err"))"
fi

P2="$(bash "$CC" --alloc --stem t1135claudecapbad --reviews-dir "$RVDIR" 2>"$T/alloc7b.err")"
if [ -n "$P2" ]; then
  O2="$(printf '%s\n' "$P2" | sed -n 1p)"
  J2="$(printf '%s\n' "$P2" | sed -n 2p)"
  printf '%s\n' 'Not logged in · Please run /login' > "$J2"
  printf 'x\n' > "$O2"
  if bash "$CC" --publish --stem t1135claudecapbad --publish-out "$O2" --publish-jsonl "$J2" --reviews-dir "$RVDIR" >/dev/null 2>&1; then
    fail "T-1135: a capture whose jsonl carries no typed event is refused by codex-capture.sh --publish (publish did not refuse)"
  else
    if [ ! -e "$RVDIR/t1135claudecapbad.txt" ] && [ ! -e "$RVDIR/t1135claudecapbad.jsonl" ]; then
      pass "T-1135: a capture whose jsonl carries no typed event is refused by codex-capture.sh --publish"
    else
      fail "T-1135: a capture whose jsonl carries no typed event is refused by codex-capture.sh --publish (a canonical file was published anyway)"
    fi
  fi
else
  fail "T-1135: a capture whose jsonl carries no typed event is refused by codex-capture.sh --publish (alloc refused: $(cat "$T/alloc7b.err"))"
fi

# =============================================================================
# fixture 8 (T-1135 AC7 fixed string 4 / AC12 live half): a reviewer span row
# built from a Claude JSON result's own REAL usage schema — input_tokens,
# output_tokens, cache_creation_input_tokens, cache_read_input_tokens (no
# single total_tokens field exists) — is accepted by bin/log-run.sh, with
# --tokens the SUM of those four fields (round-2 review minor m3: fixture 8
# previously checked only a field-name's presence, on a flattened
# total_tokens shape the real CLI never emits).
# =============================================================================
printf '\n--- fixture 8 (T-1135): a reviewer span row from a Claude JSON result ---\n'
LOGRUN="$REPO_ROOT/bin/log-run.sh"
RUNSDIR8="$T/runs8"
mkdir -p "$RUNSDIR8"
CLAUDE_RESULT='{"type":"result","subtype":"success","is_error":false,"duration_ms":4567,"total_cost_usd":0.1234,"usage":{"input_tokens":120,"output_tokens":340,"cache_creation_input_tokens":89000,"cache_read_input_tokens":1547},"result":"APPROVE"}'
IN8="$(printf '%s' "$CLAUDE_RESULT" | sed -n 's/.*"input_tokens":\([0-9]*\).*/\1/p')"
OUT8="$(printf '%s' "$CLAUDE_RESULT" | sed -n 's/.*"output_tokens":\([0-9]*\).*/\1/p')"
CC8="$(printf '%s' "$CLAUDE_RESULT" | sed -n 's/.*"cache_creation_input_tokens":\([0-9]*\).*/\1/p')"
CR8="$(printf '%s' "$CLAUDE_RESULT" | sed -n 's/.*"cache_read_input_tokens":\([0-9]*\).*/\1/p')"
TOK8=$((IN8 + OUT8 + CC8 + CR8))
DUR8="$(printf '%s' "$CLAUDE_RESULT" | sed -n 's/.*"duration_ms":\([0-9]*\).*/\1/p')"
USD8="$(printf '%s' "$CLAUDE_RESULT" | sed -n 's/.*"total_cost_usd":\([0-9.]*\).*/\1/p')"
if TEAM_RUNS_DIR="$RUNSDIR8" bash "$LOGRUN" t1135loop --run-id r1 --seq 0 --span codex-reviewer --phase review \
    --iteration 0 --attempt 0 --status success --tokens "$TOK8" --duration-ms "$DUR8" --usd "$USD8" \
    --provider claude --adapter claude-cli >/dev/null 2>"$T/lr8.err"; then
  ROWFILE8="$RUNSDIR8/t1135loop.jsonl"
  if [ -s "$ROWFILE8" ] && [ "$(wc -l < "$ROWFILE8" | tr -d ' ')" -eq 1 ] \
    && grep -Fq "\"tokens\":$TOK8" "$ROWFILE8" \
    && grep -Fq '"duration_ms":4567' "$ROWFILE8" \
    && grep -Fq '"usd":0.1234' "$ROWFILE8" \
    && grep -Fq '"provider":"claude"' "$ROWFILE8" \
    && grep -Fq '"adapter":"claude-cli"' "$ROWFILE8"; then
    pass "T-1135: a reviewer span row from a Claude JSON result is accepted by log-run.sh"
  else
    fail "T-1135: a reviewer span row from a Claude JSON result is accepted by log-run.sh (row shape mismatch: $(cat "$ROWFILE8" 2>/dev/null)"
  fi
else
  fail "T-1135: a reviewer span row from a Claude JSON result is accepted by log-run.sh (log-run.sh refused: $(cat "$T/lr8.err"))"
fi

# =============================================================================
# extra (T-1135): --roles token validation (issue #487 hardening ii) — a
# path-shaped token is refused with nothing written, a legal two-role subset
# generates exactly that subset.
# =============================================================================
printf '\n--- extra (T-1135): --roles token validation ---\n'
OUT9="$T/out9"
if bash "$GEN" --root "$REPO_ROOT" --out-dir "$OUT9" --roles 'pm-spec ../evil' >/dev/null 2>&1; then
  fail "T-1135 extra: a path-shaped --roles token is refused (generator did not refuse)"
else
  n="$(count_toml "$OUT9" '*.toml')"
  if [ "$n" -eq 0 ]; then
    pass "T-1135 extra: a path-shaped --roles token is refused with no file written"
  else
    fail "T-1135 extra: a path-shaped --roles token is refused with no file written (found $n stray file(s))"
  fi
fi
OUT9B="$T/out9b"
if bash "$GEN" --root "$REPO_ROOT" --out-dir "$OUT9B" --roles 'pm-spec engineer' >/dev/null 2>"$T/gen9b.err" \
  && [ "$(find "$OUT9B" -name 'shell-team-*.toml' | wc -l | tr -d ' ')" -eq 2 ]; then
  pass "T-1135 extra: a legal two-role --roles subset generates exactly that subset"
else
  fail "T-1135 extra: a legal two-role --roles subset generates exactly that subset ($(cat "$T/gen9b.err"))"
fi

# =============================================================================
# extra (T-1135): --root / no longer collapses to the current directory
# (issue #487 hardening i) — refused, while --root . in the same run
# succeeds, proving the refusal is narrower than "any root is rejected".
# =============================================================================
printf '\n--- extra (T-1135): --root / is refused rather than collapsed to cwd ---\n'
OUT10="$T/out10"
if bash "$GEN" --root / --out-dir "$OUT10" >/dev/null 2>&1; then
  fail "T-1135 extra: --root / is refused (generator did not refuse)"
else
  n="$(count_toml "$OUT10" '*.toml')"
  if [ "$n" -eq 0 ]; then
    pass "T-1135 extra: --root / is refused with no file written"
  else
    fail "T-1135 extra: --root / is refused with no file written (found $n stray file(s))"
  fi
fi
OUT10B="$T/out10b"
if bash "$GEN" --root . --out-dir "$OUT10B" >/dev/null 2>"$T/gen10b.err"; then
  pass "T-1135 extra: --root . still succeeds in the same run --root / was refused"
else
  fail "T-1135 extra: --root . still succeeds in the same run --root / was refused ($(cat "$T/gen10b.err"))"
fi

# =============================================================================
# extra (T-1135): the out-dir carries only *.toml entries after a default
# run (issue #487 hardening iii/D6 — per-file staged write, never a stray
# staging artifact left behind), and the write pass uses mv onto OUT_DIR
# rather than a direct redirect (source-text lock).
# =============================================================================
printf '\n--- extra (T-1135): per-file staged write leaves no non-toml residue ---\n'
OUT11="$T/out11"
bash "$GEN" --root "$REPO_ROOT" --out-dir "$OUT11" >/dev/null 2>&1
if [ "$(find "$OUT11" -mindepth 1 ! -name '*.toml' | wc -l | tr -d ' ')" -eq 0 ]; then
  pass "T-1135 extra: a default run leaves only *.toml entries in the out-dir"
else
  fail "T-1135 extra: a default run leaves only *.toml entries in the out-dir"
fi
# shellcheck disable=SC2016  # single-quoted grep patterns matching source text, not shell expansions
if [ "$(grep -c 'mv .*OUT_DIR' "$GEN" || true)" -ge 1 ] && [ "$(grep -c '> *"\$OUT_DIR/shell-team-' "$GEN" || true)" -eq 0 ]; then
  pass "T-1135 extra: the write pass renames onto OUT_DIR rather than redirecting directly onto the final name"
else
  fail "T-1135 extra: the write pass renames onto OUT_DIR rather than redirecting directly onto the final name"
fi

# =============================================================================
# extra (T-1135): the first listed role failing validation emits no
# "unbound variable" diagnostic under bash 3.2's set -u (issue #487
# hardening iv), while still refusing non-zero with nothing written.
# =============================================================================
printf '\n--- extra (T-1135): first-role failure under set -u emits no unbound-variable noise ---\n'
FR12="$(sed -n 's/^ROLES="\([^ ]*\).*$/\1/p' "$GEN" | head -1)"
R12="$T/r12"
mkdir -p "$R12/agents"
cp "$REPO_ROOT"/agents/*.md "$R12/agents/"
printf 'no frontmatter at all\n' > "$R12/agents/$FR12.md"
OUT12="$T/out12"
if bash "$GEN" --root "$R12" --out-dir "$OUT12" >/dev/null 2>"$T/gen12.err"; then
  fail "T-1135 extra: a first-listed-role failure still refuses (generator did not refuse)"
else
  n="$(count_toml "$OUT12" '*.toml')"
  if grep -Fq -- 'unbound variable' "$T/gen12.err"; then
    fail "T-1135 extra: a first-listed-role failure emits no unbound-variable noise (found: $(cat "$T/gen12.err"))"
  elif [ "$n" -ne 0 ]; then
    fail "T-1135 extra: a first-listed-role failure writes nothing (found $n stray file(s))"
  else
    pass "T-1135 extra: a first-listed-role failure emits no unbound-variable noise and writes nothing"
  fi
fi

# =============================================================================
# extra (T-1135 round-2 review minor m1): a requested role's own final path
# already existing as a directory is refused BEFORE any rename, with the
# TOML never written — `mv` onto an existing directory silently moves the
# staged file inside it and still exits 0 otherwise.
# =============================================================================
printf '\n--- extra (T-1135): a directory at the target path is refused, not silently moved into ---\n'
OUT13="$T/out13"
mkdir -p "$OUT13/shell-team-pm-spec.toml"
if bash "$GEN" --root "$REPO_ROOT" --out-dir "$OUT13" >/dev/null 2>"$T/gen13.err"; then
  fail "T-1135 extra: a directory at the target path is refused (generator did not refuse)"
else
  if [ -f "$OUT13/shell-team-pm-spec.toml" ]; then
    fail "T-1135 extra: a directory at the target path is refused (a regular file was written there anyway)"
  elif [ -f "$OUT13/shell-team-pm-spec.toml/shell-team-pm-spec.toml" ]; then
    fail "T-1135 extra: a directory at the target path is refused (mv silently moved the staged file INSIDE the directory)"
  else
    pass "T-1135 extra: a directory at the target path is refused, not silently moved into"
  fi
fi

# =============================================================================
# extra (T-1135 round-2 review minor m2): a --roles value containing a shell
# glob character is refused by TOKEN SHAPE, never by accidentally matching
# an expanded filename — run from the repository root (where an unquoted
# `($ROLES)` array assignment would otherwise glob-expand `*` against real
# tracked files) and assert the refusal message names the literal token.
# =============================================================================
printf '\n--- extra (T-1135): --roles glob character is refused by token shape, not glob-expanded ---\n'
OUT14="$T/out14"
if ( cd "$REPO_ROOT" && bash "$GEN" --out-dir "$OUT14" --roles '*' >/dev/null 2>"$T/gen14.err" ); then
  fail "T-1135 extra: --roles '*' is refused (generator did not refuse)"
else
  n="$(count_toml "$OUT14" '*.toml')"
  if [ "$n" -ne 0 ]; then
    fail "T-1135 extra: --roles '*' is refused with no file written (found $n stray file(s))"
  elif ! grep -Fq -- "token is not a valid role identifier (must match ^[a-z][a-z0-9-]*\$): *" "$T/gen14.err"; then
    fail "T-1135 extra: --roles '*' refusal names the literal token, not an expanded filename (got: $(cat "$T/gen14.err"))"
  else
    pass "T-1135 extra: --roles '*' is refused by token shape, not glob-expanded against a real filename"
  fi
fi

# =============================================================================
# extra (T-1135 round-2 review Blocker B1 class closure, deterministic half):
# the SAME "$(cat "<PROMPT_FILE>")" command-substitution shape the Claude
# recipe uses carries a prompt containing all four hazard characters the
# review named — a backtick, a $(...) command substitution, a $VAR
# reference and an embedded double quote — through byte-for-byte, unexpanded,
# when substituted into a double-quoted invocation argument. This is the
# repo-local, no-API-call half of B1's class closure; the live half (an
# actual `claude -p` run receiving this same file) is recorded in
# .shell-team/provenance/T-1135.md and the hand-off, not here (CI carries no
# authenticated Claude Code CLI).
# =============================================================================
printf '\n--- extra (T-1135): the recipe command-substitution quoting carries hazard characters unexpanded ---\n'
PROMPT_FILE15="$T/hazard-prompt.txt"
# shellcheck disable=SC2016  # deliberate fixture text (backtick/$(...)/$HOME) that must land in the FILE literally, never expand
printf 'a `backtick`, a $(echo INJECTED) substitution, a $HOME reference, and an embedded " double quote.\n' > "$PROMPT_FILE15"
RESULT15="$(bash -c 'printf %s "$1"' -- "$(cat "$PROMPT_FILE15")")"
EXPECTED15="$(cat "$PROMPT_FILE15")"
# Byte-for-byte equality against the source file's own content is the whole
# assertion: if any of the four hazard sequences had been expanded (the
# backtick or $(...) executed, $HOME substituted with an actual path, or the
# embedded quote terminating the argument early), RESULT15 would differ from
# EXPECTED15. The four grep checks below are a POSITIVE CONTROL confirming
# the fixture's own source text actually contains all four literal hazard
# sequences (so a vacuous pass — e.g. an empty or truncated PROMPT_FILE15 —
# cannot slip through the equality check unnoticed).
# shellcheck disable=SC2016  # each single-quoted grep pattern below is the literal hazard text being searched for, never meant to expand
if [ "$RESULT15" = "$EXPECTED15" ] \
  && printf '%s' "$EXPECTED15" | grep -Fq -- '`backtick`' \
  && printf '%s' "$EXPECTED15" | grep -Fq -- '$(echo INJECTED)' \
  && printf '%s' "$EXPECTED15" | grep -Fq -- '$HOME' \
  && printf '%s' "$EXPECTED15" | grep -Fq -- '"'; then
  pass 'T-1135 extra: the "$(cat <PROMPT_FILE>)" quoting shape carries a backtick, a $(...), a $VAR and an embedded quote unexpanded'
else
  fail "T-1135 extra: the quoting shape carries hazard characters unexpanded (got: $RESULT15)"
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

# =============================================================================
# extra (T-1136, #494 item 2): a mid-write `mv` failure leaves no staging
# residue in the out-dir (the cleanup trap's own coverage of pass 2, not
# just pass 1's CONTENT_FILES scratch) — reproducing AC7's shim probe here
# so a regression is caught by this suite without needing check-acs.sh.
# =============================================================================
printf '\n--- extra (T-1136): a mid-write mv failure leaves no staging residue ---\n'
SHIMDIR="$T/mvshim"
mkdir -p "$SHIMDIR"
printf '#!/bin/sh\nexit 1\n' > "$SHIMDIR/mv"
chmod +x "$SHIMDIR/mv"
OUT16="$T/out16"
mkdir -p "$OUT16"
if PATH="$SHIMDIR:$PATH" bash "$GEN" --root "$REPO_ROOT" --out-dir "$OUT16" >/dev/null 2>&1; then
  fail "T-1136 extra: a mid-write mv failure is refused (generator did not refuse under the mv shim)"
elif [ "$(find "$OUT16" -name '.gen-codex-agents.*' | wc -l | tr -d ' ')" -eq 0 ] \
  && [ "$(find "$OUT16" -name 'shell-team-*.toml' | wc -l | tr -d ' ')" -eq 0 ]; then
  pass "T-1136 extra: a mid-write mv failure leaves no staging residue and no partial TOML"
else
  fail "T-1136 extra: a mid-write mv failure leaves no staging residue and no partial TOML (residue found)"
fi
# Positive control in the same run: the identical invocation with no shim
# still succeeds and leaves only the expected *.toml entries — proving the
# refusal above is narrower than "this script now always fails".
OUT17="$T/out17"
if bash "$GEN" --root "$REPO_ROOT" --out-dir "$OUT17" >/dev/null 2>&1 \
  && [ "$(find "$OUT17" -name 'shell-team-*.toml' | wc -l | tr -d ' ')" -ge 1 ] \
  && [ "$(find "$OUT17" -name '.gen-codex-agents.*' | wc -l | tr -d ' ')" -eq 0 ]; then
  pass "T-1136 extra: the same invocation without the mv shim still succeeds cleanly"
else
  fail "T-1136 extra: the same invocation without the mv shim still succeeds cleanly"
fi

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'codex-agents suite: all assertions passed\n'
  exit 0
else
  printf 'codex-agents suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
