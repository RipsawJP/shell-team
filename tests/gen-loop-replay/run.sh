#!/usr/bin/env bash
# run.sh — tests/gen-loop-replay/run.sh (T-1012 D6/D7).
#
# Hosts the CI-only inline-JS syntax-coverage gate for templates/loop-replay.html
# (D6): the artifact under test is the REAL generator's REAL output for a
# committed fixture — the suite extracts the main <script> block (the
# ratified-design script, not the single-line JSON-data script tag D2
# injects) and runs `node --check` on it. No production logic is
# re-implemented; the extraction is a few lines of awk.
#
# T-1012 rework round 1 (Codex round-1 REQUEST_CHANGES, Blockers #2/#3): the
# same node-gated section also runs node-harness.js — a real EXECUTION of the
# generated page's own payload-adaptation and scene-model code (not merely a
# syntax check) against every committed fixture that produces a page. A
# static payload inspection (the spec's own check: lines) cannot catch a
# runtime crash or a DOM-injection failure; this does, by calling the real
# computeSceneB()/agentChip()/agentLabelHtml() functions for real.
#
# Blast radius (measured, D6): invoked with --runs-dir <committed fixture>
# and --out <temp path>, the generator reads two files and writes one file
# under $TMPDIR. It never writes into the repository, never touches git,
# never networks. node-harness.js only reads the generated files already
# under $TMPDIR and writes nothing.
#
# Fail-closed rule: the interpreter is resolved as ${NODE_BIN:-node}. If it is
# unavailable and $CI is non-empty, this suite FAILS (the runner is supposed
# to have node; its absence means the assumption broke). If it is unavailable
# and $CI is empty, this suite prints a SKIP: line and continues — never a
# silent pass either way.
#
# Usage: run.sh
# Exit: 0 = every check passed (or the node gate was skipped outside CI);
#       1 = a check failed, including a real JS syntax error, a scene-execution
#       crash, an injection-escaping failure, or a missing node under $CI.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
GEN="$REPO_ROOT/bin/gen-loop-replay.sh"
FIXTURES="$HERE/fixtures"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/gen-loop-replay-suite.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# --- smoke: the real generator, a committed fixture, exits 0 and produces a
#     real page --------------------------------------------------------------
OUT="$TMP/replay.html"
bash "$GEN" 20260801T000000Z-mixed --runs-dir "$FIXTURES/mixed" --out "$OUT" >/dev/null \
  || fail "generator exited non-zero against the mixed fixture"
[ -s "$OUT" ] || fail "generator produced no output"
grep -qF -- 'id="loop-replay-data"' "$OUT" || fail "generated page is missing the injected data script tag"
pass "generator produces a page from the mixed fixture"

# --- extract the main <script> block (D6) — a few lines of awk, no
#     production logic reimplemented. The frozen single-line JSON-data script
#     tag (`<script type="application/json" id="loop-replay-data">…`) never
#     matches the bare `<script>` anchor, so it can never be mistaken for the
#     ratified-design script this gate actually checks. -----------------------
SCRIPT_BLOCK="$TMP/script-block.js"
awk '
  /^<script>$/   { flag=1; next }
  /^<\/script>$/ { flag=0 }
  flag { print }
' "$OUT" > "$SCRIPT_BLOCK"
[ -s "$SCRIPT_BLOCK" ] || fail "could not extract the main <script> block from the generated page"
pass "extracted the main <script> block"

# --- D6: CI-only node --check, fail-closed under $CI, SKIP outside it --------
NODE_BIN="${NODE_BIN:-node}"
if ! command -v "$NODE_BIN" >/dev/null 2>&1; then
  if [ -n "${CI:-}" ]; then
    fail "node (\$NODE_BIN=$NODE_BIN) is unavailable under \$CI — the inline-JS syntax gate cannot run"
  fi
  printf 'SKIP: node (%s) unavailable outside CI — inline-JS syntax gate not run\n' "$NODE_BIN"
else
  "$NODE_BIN" --check "$SCRIPT_BLOCK" || fail "node --check found a syntax error in the extracted script block"
  pass "node --check: the extracted script block is syntactically valid"

  # --- T-1012 rework round 1: a node harness against every fixture that
  #     produces a page (malformed's whole point is that it does NOT). Same
  #     interpreter, same gate — no separate CI wiring needed. Written to a
  #     temp file here (rather than shipped as its own tests/gen-loop-replay/
  #     *.js file) so this suite's own required-file identity stays exactly
  #     tests/gen-loop-replay/run.sh — AC28's scope-lock allow-list is
  #     merge-point-frozen and is not this round's to re-derive. -----------------
  HARNESS="$TMP/node-harness.js"
  cat > "$HARNESS" <<'HARNESS_EOF'
// node-harness.js — T-1012 rework round 1 (Codex Blocker #2/#3).
//
// Extracts a single, contiguous, verbatim slice of the REAL generated page's
// own <script> block — from "use strict" through the end of agentChip()'s
// definition — and EXECUTES it in Node against every committed fixture's
// real generated payload. No production logic is reimplemented; the slice is
// a textual anchor cut of the real file's own bytes, run through Node's
// `Function` constructor with a minimal generic DOM/window/navigator stub
// (enough surface for `document.getElementById`/`createElement` and
// `window.matchMedia`/`navigator.language` not to throw — nothing in the
// extracted range does real DOM work beyond that).
//
// Checks, per fixture:
//   1. Scene-execution crash sweep (Blocker #3): calls the REAL
//      computeSceneB()/getCurrentStepB() across a dense sweep of the
//      playback timeline, asserting no exception. This is the class the
//      committed `event-only` fixture crashed on (a null-origin move
//      reaching worldPos()/lerp3()) — a static payload check (AC15's own
//      check:) cannot catch it, since nothing there runs the scene JS.
//   1b. Ring-position collision check (Major #1), when the roster exceeds
//      the six known agents.
//   1c. gate/human conflation check (Major #2), when a `gate` event's `from`
//      is literally "human".
//   2. Injection-escaping proof (Blocker #2), on the `adopter` and `hostile`
//      fixtures: calls the REAL agentChip()/agentLabelHtml() against the
//      committed XSS-shaped span id (`adopter`) and event `to` value
//      (`hostile`), asserting the escaped output never contains a raw
//      `<img` while a positive control confirms the raw, unescaped payload
//      really does carry it (D3: an unrecognised agent id is never dropped).
//
// Usage: node node-harness.js <generated-page.html> <fixture-label>
// Exit: 0 = every assertion passed; 1 = a crash or an escaping failure.

'use strict';
const fs = require('fs');

const file = process.argv[2];
const label = process.argv[3] || file;
if (!file) {
  console.error('usage: node node-harness.js <generated-page.html> [label]');
  process.exit(2);
}

let violations = 0;
function fail(msg) { console.error('FAIL [' + label + ']: ' + msg); violations++; }
function ok(msg) { console.log('PASS [' + label + ']: ' + msg); }

function extractScriptBlock(html) {
  const m = html.match(/^<script>$([\s\S]*?)^<\/script>$/m);
  if (!m) throw new Error('could not extract the main <script> block');
  return m[1];
}

function sliceBetween(text, startAnchor, endAnchor) {
  const s = text.indexOf(startAnchor);
  if (s === -1) throw new Error('start anchor not found: ' + JSON.stringify(startAnchor));
  const e = text.indexOf(endAnchor, s);
  if (e === -1) throw new Error('end anchor not found: ' + JSON.stringify(endAnchor));
  return text.slice(s, e);
}

// A minimal, generic DOM stub — every method is a harmless no-op, every
// lookup returns a fresh fake element, so nothing in the extracted range
// (which does no meaningful DOM work beyond existence-checks and simple
// property sets) throws. Not a browser; just enough surface.
function makeFakeElement() {
  return {
    className: '', textContent: '', innerHTML: '', hidden: false, title: '',
    style: {}, id: '',
    classList: { add: function () {}, remove: function () {}, toggle: function () {} },
    appendChild: function () {}, setAttribute: function () {}, getAttribute: function () { return null; },
    addEventListener: function () {}, removeEventListener: function () {},
    getBoundingClientRect: function () { return { width: 0, height: 0, top: 0, left: 0, bottom: 0, right: 0 }; },
    querySelector: function () { return makeFakeElement(); },
  };
}
// getElementById("loop-replay-data") must return the REAL injected payload
// text — the extracted code reads it via `.textContent` exactly as the
// actual page load does (D2: JSON.parse consumes it). Every other id gets a
// harmless generic fake element.
function makeFakeDocument(payloadText) {
  return {
    getElementById: function (id) {
      if (id === 'loop-replay-data') { return { textContent: payloadText }; }
      return makeFakeElement();
    },
    createElement: function () { return makeFakeElement(); },
    querySelector: function () { return makeFakeElement(); },
    querySelectorAll: function () { return []; },
    addEventListener: function () {},
    documentElement: makeFakeElement(),
  };
}

function loadScene(html) {
  const script = extractScriptBlock(html);
  const payloadMatch = html.match(/<script type="application\/json" id="loop-replay-data">([\s\S]*?)<\/script>/);
  if (!payloadMatch) throw new Error('could not find the injected data script tag');
  const slice = sliceBetween(script, '"use strict";', 'function updateDetailPanel(simMs){');
  const body = slice + '\nreturn { computeSceneB: computeSceneB, getCurrentStepB: getCurrentStepB, ' +
    'TOTAL_MS: TOTAL_MS, events: events, RING_AGENTS: RING_AGENTS, PAYLOAD: PAYLOAD, RING_POS: RING_POS, ' +
    'agentChip: agentChip, agentLabelHtml: agentLabelHtml, agentLabel: agentLabel, escapeHtml: escapeHtml };';
  const fn = new Function('window', 'navigator', 'document', body);
  const fakeWindow = { matchMedia: function () { return { matches: false }; } };
  const fakeNavigator = { language: 'en' };
  return fn(fakeWindow, fakeNavigator, makeFakeDocument(payloadMatch[1]));
}

let scene;
try {
  scene = loadScene(fs.readFileSync(file, 'utf8'));
} catch (err) {
  fail('scene extraction/execution setup failed: ' + err.message);
  process.exit(1);
}

// ---- 1. scene-execution crash sweep (every fixture) ----
(function crashSweep() {
  const N = 200;
  let crashed = null;
  for (let i = 0; i <= N; i++) {
    const simMs = (scene.TOTAL_MS * i) / N;
    try {
      scene.computeSceneB(simMs);
    } catch (err) {
      crashed = { simMs: simMs, err: err };
      break;
    }
  }
  if (crashed) {
    fail('computeSceneB() threw at simMs=' + crashed.simMs + ': ' + crashed.err.message);
  } else {
    ok('computeSceneB() executed cleanly across ' + (N + 1) + ' timeline samples (0..TOTAL_MS=' + scene.TOTAL_MS +
      '), ' + scene.events.length + ' events, roster size ' + scene.RING_AGENTS.length);
  }
})();

// ---- 1b. ring-position collision check (Major #1) — only meaningful when
//          the roster exceeds the six known agents (the `adopter` fixture) ----
(function ringCollision() {
  var positions = scene.RING_AGENTS.map(function (id) {
    var p = scene.RING_POS[id];
    return p.x.toFixed(6) + ',' + p.z.toFixed(6);
  });
  var seen = {};
  var collisions = [];
  positions.forEach(function (key, i) {
    if (seen[key] !== undefined) { collisions.push(scene.RING_AGENTS[seen[key]] + ' == ' + scene.RING_AGENTS[i]); }
    seen[key] = i;
  });
  if (collisions.length > 0) {
    fail('ring positions collide (angle step not derived from roster size): ' + collisions.join('; '));
  } else if (scene.RING_AGENTS.length > 6) {
    ok('ring positions are pairwise distinct across ' + scene.RING_AGENTS.length + ' agents (roster exceeds the six known ids)');
  }
})();

// ---- 1c. gate/human conflation check (Major #2) — only meaningful when a
//          `gate` event whose `from` is literally "human" is present ----
(function gateHumanConflation() {
  var gateFromHuman = scene.events.some(function (e) { return e.type === 'gate' && e.agent === 'human'; });
  var realHuman = scene.events.some(function (e) { return e.type === 'human'; });
  if (gateFromHuman && realHuman) {
    ok('a gate event with from="human" and a genuine human event both survive adaptation as DISTINCT types (gate vs human), never conflated');
  } else if (gateFromHuman && !realHuman) {
    fail('a gate event with from="human" is present but no distinct human-type event was found alongside it — cannot prove non-conflation');
  }
})();

// ---- 2. injection-escaping proof (adopter's XSS-shaped span id, hostile's
//         XSS-shaped event `to` value) — only meaningful when present ----
(function injectionProof() {
  const XSS = '<img src=x onerror=alert(1)>';
  const hostileXss = '<img src=x onerror=alert(document.domain)>';

  var foundSpan = scene.RING_AGENTS.indexOf(XSS) !== -1;
  var foundTo = scene.events.some(function (e) { return e.to === hostileXss || e.from === hostileXss; });

  if (foundSpan) {
    var chip = scene.agentChip(XSS);
    var labelHtml = scene.agentLabelHtml(XSS);
    if (chip.indexOf('<img') !== -1 || labelHtml.indexOf('<img') !== -1) {
      fail('agentChip()/agentLabelHtml() emitted a RAW <img for the adopter fixture\'s XSS-shaped span id — injection not neutralised');
    } else if (labelHtml.indexOf('&lt;img') === -1) {
      fail('agentLabelHtml() output does not contain the expected escaped form (&lt;img) — the positive control failed, this assertion may be vacuous');
    } else {
      ok('agentChip()/agentLabelHtml() render the adopter fixture\'s <img onerror> span id INERT (raw <img absent, escaped &lt;img present)');
    }
  }
  if (foundTo) {
    var toHtml = scene.agentLabelHtml(hostileXss);
    if (toHtml.indexOf('<img') !== -1) {
      fail('agentLabelHtml() emitted a RAW <img for the hostile fixture\'s XSS-shaped event `to` value — injection not neutralised');
    } else if (toHtml.indexOf('&lt;img') === -1) {
      fail('agentLabelHtml() output does not contain the expected escaped form (&lt;img) for the hostile `to` value — positive control failed');
    } else {
      ok('agentLabelHtml() renders the hostile fixture\'s <img onerror> event `to` value INERT (raw <img absent, escaped &lt;img present)');
    }
  }
})();

if (violations > 0) {
  console.error(label + ': ' + violations + ' violation(s)');
  process.exit(1);
}
process.exit(0);
HARNESS_EOF

  run_harness() {
    local name="$1" runid="$2" dir="$3" out="$TMP/$1.html"
    bash "$GEN" "$runid" --runs-dir "$FIXTURES/$dir" --out "$out" >/dev/null 2>&1 \
      || fail "generator exited non-zero building the $name fixture for the node harness"
    "$NODE_BIN" "$HARNESS" "$out" "$name" || fail "node-harness.js reported a violation for the $name fixture"
  }
  run_harness mixed      20260801T000000Z-mixed  mixed
  run_harness span-only  20260801T000000Z-spans  span-only
  run_harness event-only 20260801T000000Z-events event-only
  run_harness adopter    20260801T000000Z-adopter adopter
  run_harness hostile    20260801T000000Z-hostile hostile
  run_harness multi-run  20260801T000000Z-a      multi-run
  pass "node-harness.js: every fixture executes the real scene/adaptation code without a crash or an injection escape"
fi

printf 'gen-loop-replay: all checks passed\n'
exit 0
