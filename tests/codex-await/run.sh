#!/usr/bin/env bash
# run.sh — suite for bin/codex-await.sh (T-1178; GitHub issue #695).
#
# `codex exec` appends piped stdin to its prompt and waits for EOF. In a
# sub-agent's Bash tool stdin can be an open pipe that never closes, so the
# shipped bare line prints `Reading additional input from stdin...` and never
# emits `thread.started`. The reviewer roles launch it in the background and
# then call codex-await.sh against the capture; this suite locks that wait:
#
#   (a) the closed S / E / T / U table against fixture files, including lines
#       that collide with the event vocabulary (a message item quoting an
#       event, a malformed or oversized id, a reversed key order);
#   (b) a stub `codex` that blocks on a stdin pipe that never reaches EOF —
#       launched in the background in its own process group, its output going
#       to the watched file — asserting `--event start` exits 1 within the
#       timeout plus five seconds while the stub is STILL blocked;
#   (c) a stub that prints the stdin line, `thread.started`, later
#       `turn.completed`, and exits 0: start yields its id, end yields
#       `turn.completed`;
#   (d) launch shapes (`bash script`, `./script`, a PATH symlink) and a closed
#       stderr (the exit contract must survive `2>&-`).
#
# Every stub is started in its own process group and stopped by group before
# the suite exits (EXIT trap). No file is deleted recursively; temp files stay
# under $TMPDIR. Self-contained relative to its own location: the executable
# under test is `$HERE/../../bin/codex-await.sh`.
#
# Exit: 0 = every assertion passed; 1 = at least one FAIL line.

# shellcheck disable=SC2329  # helpers are invoked through assert / the EXIT trap
set -euo pipefail

ulimit -f 20000 2>/dev/null || true

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K="$(cd "$HERE/../../bin" && pwd)/codex-await.sh"
[ -s "$K" ] || { printf 'FAIL: executable under test is missing: %s\n' "$K" >&2; exit 1; }

T="$(mktemp -d "${TMPDIR:-/tmp}/t1178-await.XXXXXX")"
T="$(cd "$T" && pwd -P)"
mkdir -p "$T/w" "$T/bin"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }
# assert <description> <command…>: PASS when the command succeeds, FAIL otherwise.
assert() { local d="$1"; shift; if "$@"; then pass "$d"; else fail "$d"; fi; }
out_is() { [ "$(cat "$T/o")" = "$1" ]; }
rc_is() { [ "$rc" -eq "$1" ]; }
nonempty_out() { [ -s "$T/o" ]; }
stderr_has() { grep -qF -- "$1" "$T/e"; }
no_leftover() { [ -z "$(ls -A "$T/w")" ]; }
fixtures_same() { cmp -s "$T/c0" "$T/c1"; }
not_exists() { [ ! -e "$1" ]; }

# --- process-group bookkeeping: every stub group is stopped on exit ----------
STUB_GROUPS=()
stop_groups() {
  local g
  for g in ${STUB_GROUPS[@]+"${STUB_GROUPS[@]}"}; do
    kill -TERM -- "-$g" 2>/dev/null || true
  done
}
trap stop_groups EXIT

set -m   # background jobs get their own process group (pgid == $!)

# aw <args…>: run the executable from an empty cwd, stdin /dev/null; sets
# rc / el (whole seconds) and leaves stdout in $T/o, stderr in $T/e.
aw() {
  local s0 s1
  s0=$(date +%s)
  rc=0
  (cd "$T/w" && bash "$K" "$@" < /dev/null > "$T/o" 2> "$T/e") || rc=$?
  s1=$(date +%s)
  el=$((s1 - s0))
}

L='Reading additional input from stdin...'
I='019a-Bc_9'
E1="{\"type\":\"thread.started\",\"thread_id\":\"$I\"}"

# =============================================================================
# (a) the table, against fixture files
# =============================================================================
printf '%s\n' "$L" > "$T/hang"
printf '%s\n%s\n{"type":"turn.started"}\n' "$L" "$E1" > "$T/ok"
printf '{"thread_id":"%s","type":"thread.started"}\n' "$I" > "$T/rev"
printf 'note: thread.started is expected\n{"type":"thread.started"}\n{"type":"thread.started","thread_id":"bad id;x"}\n' > "$T/bad"
printf '%s\n{"type":"turn.completed","usage":{}}\n' "$E1" > "$T/fin"
printf '%s\n{"type":"turn.failed","error":{"message":"x"}}\n' "$E1" > "$T/fail"
# a message item that merely QUOTES the events must never count
printf '%s\n{"type":"item.completed","item":{"type":"agent_message","text":"{\\"type\\":\\"thread.started\\",\\"thread_id\\":\\"zzz\\"} {\\"type\\":\\"turn.completed\\"}"}}\n' "$L" > "$T/quote"
# an event embedded after non-JSON text, or followed by trailing text, is not a line-wide JSON event
printf 'warn: {"type":"thread.started","thread_id":"zzz"}\nnote: {"type":"turn.completed"}\nwarn: {"type":"thread.started","thread_id":"zzz"} and {"type":"turn.completed"}\n{"type":"thread.started","thread_id":"zzz"} trailing\n{"type":"turn.completed"} trailing\n' > "$T/embed"
# an id over 128 characters and an id with a space are not ids
long="$(awk 'BEGIN{s=""; for(i=0;i<129;i++) s=s "a"; print s}')"
printf '{"type":"thread.started","thread_id":"%s"}\n' "$long" > "$T/longid"
awk 'BEGIN{for(i=0;i<400;i++) print "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}' > "$T/big"
(cd "$T" && cksum hang ok rev bad fin fail quote embed longid big) > "$T/c0"

expect_ok() {  # $1 = description, $2 = expected stdout
  if [ "$rc" -eq 0 ] && [ "$(cat "$T/o")" = "$2" ] && [ "$(grep -c '' "$T/o")" = 1 ] \
    && [ ! -s "$T/e" ] && [ "$el" -le 2 ]; then
    pass "$1"
  else
    fail "$1 (rc=$rc stdout=$(head -c 80 "$T/o") stderr_bytes=$(wc -c < "$T/e") el=$el)"
  fi
}
expect_timeout() {  # $1 = description, $2 = token, $3 = timeout used
  if [ "$rc" -eq 1 ] && [ ! -s "$T/o" ] && head -n 1 "$T/e" | grep -qF -- "$2" \
    && [ "$el" -ge $(($3 - 1)) ] && [ "$el" -le $(($3 + 5)) ] \
    && [ "$(wc -c < "$T/e")" -le 4400 ]; then
    pass "$1"
  else
    fail "$1 (rc=$rc stdout_bytes=$(wc -c < "$T/o") first_stderr=$(head -n 1 "$T/e" | head -c 80) el=$el stderr_bytes=$(wc -c < "$T/e"))"
  fi
}

aw --event start --watch "$T/ok" --timeout 3
expect_ok "start: stdin line, thread.started and turn.started yields the id only" "$I"
aw --event start --watch "$T/rev" --timeout 3
expect_ok "start: reversed key order yields the id only" "$I"
aw --event start --watch "$T/hang" --timeout 3
expect_timeout "start: only the stdin notice is no-thread-started after the timeout" no-thread-started 3
assert "start timeout: stderr carries the captured stdin notice" stderr_has "$L"
aw --event start --watch "$T/bad" --timeout 2
expect_timeout "start: bare mention, missing id and malformed id are no-thread-started" no-thread-started 2
aw --event start --watch "$T/embed" --timeout 1
expect_timeout "start: an event embedded after text or followed by trailing text never counts" no-thread-started 1
aw --event end --watch "$T/embed" --timeout 1
expect_timeout "end: a terminal event embedded after text or followed by trailing text never counts" no-terminal-event 1
aw --event start --watch "$T/longid" --timeout 1
expect_timeout "start: a 129-character id is not an id" no-thread-started 1
aw --event start --watch "$T/quote" --timeout 1
expect_timeout "start: a message item quoting thread.started never counts" no-thread-started 1
aw --event start --watch "$T/none" --timeout 2
expect_timeout "start: an absent file is no-thread-started" no-thread-started 2
assert "start timeout: absent file is named as absent" stderr_has absent
: > "$T/empty"
aw --event start --watch "$T/empty" --timeout 1
expect_timeout "start: an empty file is no-thread-started" no-thread-started 1
aw --event start --watch "$T/big" --timeout 1
expect_timeout "start: a 20 kB file with no event stays within the 4096-byte tail bound" no-thread-started 1

# the file gains the event while the wait runs
printf '%s\n' "$L" > "$T/grow"
( sleep 2; printf '%s\n' "$E1" >> "$T/grow" ) &
grow_pid=$!
aw --event start --watch "$T/grow" --timeout 8
{ wait "$grow_pid"; } 2>/dev/null || true
if [ "$rc" -eq 0 ] && [ "$(cat "$T/o")" = "$I" ] && [ "$el" -ge 1 ] && [ "$el" -le 6 ]; then
  pass "start: an event appended two seconds into an 8 s wait is seen (el=$el)"
else
  fail "start: appended event not seen (rc=$rc stdout=$(head -c 80 "$T/o") el=$el)"
fi

aw --event end --watch "$T/fin" --timeout 3
expect_ok "end: turn.completed yields that type" turn.completed
aw --event end --watch "$T/fail" --timeout 3
expect_ok "end: turn.failed yields that type" turn.failed
aw --event end --watch "$T/ok" --timeout 2
expect_timeout "end: no terminal event is no-terminal-event" no-terminal-event 2
aw --event end --watch "$T/quote" --timeout 1
expect_timeout "end: a message item quoting turn.completed never counts" no-terminal-event 1

# U row
for a in "" "--event bogus --watch $T/ok --timeout 3" "--event start --watch $T/ok --timeout 0" \
  "--event start --watch $T/ok --timeout 571" "--event start --watch $T/ok --timeout abc" \
  "--event start --watch $T/ok --timeout 03" "--event start --watch $T/ok --timeout -1" \
  "--event start --timeout 3" "--event start --watch $T/ok --timeout 3 extra" \
  "--event start --watch $T/ok --watch $T/ok --timeout 3" "--event start --watch $T/ok --timeout"; do
  # shellcheck disable=SC2086
  aw $a
  if [ "$rc" -eq 2 ] && [ ! -s "$T/o" ] && [ "$(grep -c '' "$T/e")" = 1 ] && grep -qF usage "$T/e"; then
    pass "usage row: [$a] exits 2 with one stderr line containing usage"
  else
    fail "usage row: [$a] (rc=$rc stdout_bytes=$(wc -c < "$T/o") stderr_lines=$(grep -c '' "$T/e"))"
  fi
done
aw --event start --watch "$T/ok" --timeout 570x
assert "usage row: 570x is not an integer" rc_is 2
for a in --help -h; do
  aw "$a"
  if [ "$rc" -eq 0 ] && [ -s "$T/o" ]; then pass "$a exits 0 with non-empty stdout"; else fail "$a (rc=$rc)"; fi
done

(cd "$T" && cksum hang ok rev bad fin fail quote embed longid big) > "$T/c1"
assert "fixtures are byte-identical afterwards" fixtures_same
assert "the working directory stayed empty" no_leftover

# =============================================================================
# (b) a stub codex blocked on a stdin pipe that never reaches EOF
# =============================================================================
STUB_HANG="$T/bin/codex-hang"
cat > "$STUB_HANG" <<'EOF'
#!/usr/bin/env bash
# stands in for `codex exec …` with an open, never-closing stdin pipe
printf 'Reading additional input from stdin...\n'
cat > /dev/null
printf '{"type":"thread.started","thread_id":"never-reached"}\n'
EOF
chmod +x "$STUB_HANG"
HANG_OUT="$T/hang-stub.out"
: > "$HANG_OUT"
# The never-closing stdin is `sleep 600`, a member of the same group as the stub.
( exec bash -c 'sleep 600 | "$1" > "$2" 2>&1' x "$STUB_HANG" "$HANG_OUT" ) &
hang_pid=$!
STUB_GROUPS+=("$hang_pid")
sleep 1
if grep -qF -- "$L" "$HANG_OUT"; then
  pass "hang stub: printed the stdin notice and is waiting on stdin (positive control)"
else
  fail "hang stub: never printed the stdin notice (control)"
fi
aw --event start --watch "$HANG_OUT" --timeout 3
expect_timeout "hang stub: start exits 1 (no-thread-started) within the timeout plus five seconds" no-thread-started 3
assert "hang stub: BLOCKED output carries the captured stdin notice" stderr_has "$L"
if kill -0 -- "-$hang_pid" 2>/dev/null; then
  pass "hang stub: still blocked after the wait (its group is alive)"
else
  fail "hang stub: exited on its own — the fixture did not model a hang"
fi
aw --event end --watch "$HANG_OUT" --timeout 2
expect_timeout "hang stub: end exits 1 (no-terminal-event)" no-terminal-event 2
kill -TERM -- "-$hang_pid" 2>/dev/null || true
{ wait "$hang_pid"; } 2>/dev/null || true
n=0
while kill -0 -- "-$hang_pid" 2>/dev/null && [ "$n" -lt 20 ]; do sleep 0.25; n=$((n + 1)); done
if kill -0 -- "-$hang_pid" 2>/dev/null; then
  fail "hang stub: group still alive after TERM"
else
  pass "hang stub: whole process group stopped"
fi

# =============================================================================
# (c) a stub that starts and completes
# =============================================================================
STUB_OK="$T/bin/codex-ok"
cat > "$STUB_OK" <<EOF
#!/usr/bin/env bash
printf 'Reading additional input from stdin...\n'
printf '%s\n' '$E1'
printf '{"type":"turn.started"}\n'
sleep 2
printf '{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"ok"}}\n'
printf '{"type":"turn.completed","usage":{"input_tokens":1}}\n'
EOF
chmod +x "$STUB_OK"
OK_OUT="$T/ok-stub.out"
: > "$OK_OUT"
( exec bash -c '"$1" < /dev/null > "$2" 2>&1' x "$STUB_OK" "$OK_OUT" ) &
ok_pid=$!
STUB_GROUPS+=("$ok_pid")
aw --event start --watch "$OK_OUT" --timeout 20
expect_ok "ok stub: start yields its thread id" "$I"
aw --event end --watch "$OK_OUT" --timeout 20
if [ "$rc" -eq 0 ] && [ "$(cat "$T/o")" = turn.completed ] && [ ! -s "$T/e" ]; then
  pass "ok stub: end yields turn.completed"
else
  fail "ok stub: end (rc=$rc stdout=$(head -c 80 "$T/o") stderr=$(head -c 120 "$T/e"))"
fi
{ wait "$ok_pid"; } 2>/dev/null || true

# =============================================================================
# (d) launch shapes and a closed stderr
# =============================================================================
(cd "$T/w" && bash "$K" --event start --watch "$T/ok" --timeout 2 < /dev/null > "$T/o" 2> "$T/e") || true
assert "launch shape: bash <script>" out_is "$I"
cp "$K" "$T/bin/direct-await.sh"
chmod +x "$T/bin/direct-await.sh"
(cd "$T/bin" && ./direct-await.sh --event start --watch "$T/ok" --timeout 2 < /dev/null > "$T/o" 2> "$T/e") || true
assert "launch shape: ./script directly" out_is "$I"
mkdir -p "$T/linkdir"
ln -s "$K" "$T/linkdir/codex-await.sh"
(cd "$T/w" && PATH="$T/linkdir:$PATH" codex-await.sh --event start --watch "$T/ok" --timeout 2 < /dev/null > "$T/o" 2> "$T/e") || true
assert "launch shape: bare name through a PATH symlink" out_is "$I"
(cd "$T/w" && PATH="$T/linkdir:$PATH" codex-await.sh --help < /dev/null > "$T/o" 2> "$T/e") || true
assert "launch shape: --help through a PATH symlink reads its own header" nonempty_out

rc=0
(cd "$T/w" && bash "$K" --event start --watch "$T/hang" --timeout 1 < /dev/null > /dev/null 2>&-) || rc=$?
assert "closed stderr: the timeout row still exits 1" rc_is 1
rc=0
(cd "$T/w" && bash "$K" --event bogus < /dev/null > /dev/null 2>&-) || rc=$?
assert "closed stderr: the usage row still exits 2" rc_is 2

# a stub codex first on PATH is never invoked by the executable
printf '#!/usr/bin/env bash\n: > "%s/codex-called"\nexit 0\n' "$T" > "$T/bin/codex"
chmod +x "$T/bin/codex"
(cd "$T/w" && PATH="$T/bin:$PATH" bash "$K" --event start --watch "$T/hang" --timeout 1 < /dev/null > /dev/null 2>&1) || true
(cd "$T/w" && PATH="$T/bin:$PATH" bash "$K" --event end --watch "$T/fin" --timeout 1 < /dev/null > /dev/null 2>&1) || true
assert "a stub codex first on PATH is never invoked" not_exists "$T/codex-called"

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'codex-await suite: all assertions passed\n'
  exit 0
fi
printf 'codex-await suite: %d assertion(s) FAILED\n' "$fails" >&2
exit 1
