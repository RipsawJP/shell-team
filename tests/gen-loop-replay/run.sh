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
//
// T-1014 (D6): classList is now a RECORDING stub, not a no-op triple — a
// per-element class SET, created fresh inside this function call so five
// dots built by buildRailB() never share state (H7). `toggle(name, force)`
// honours the DOM's own two-argument semantics exactly: a truthy `force`
// always adds, a falsy `force` always removes, and an absent `force` flips —
// `updateRailB` clears a dot with `toggle("reached", false)`, so a stub that
// ignored `force` would flip instead of clear and the rewind assertion below
// could never observe a real rewind.
function makeFakeElement() {
  var classes = Object.create(null);
  return {
    className: '', textContent: '', innerHTML: '', hidden: false, title: '',
    style: {}, id: '',
    classList: {
      add: function (name) { classes[name] = true; },
      remove: function (name) { delete classes[name]; },
      toggle: function (name, force) {
        if (force === undefined) {
          if (classes[name]) { delete classes[name]; return false; }
          classes[name] = true; return true;
        }
        if (force) { classes[name] = true; return true; }
        delete classes[name]; return false;
      },
      contains: function (name) { return !!classes[name]; },
    },
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
  // T-1014 (D6): the rail machinery joins the harness's exported surface —
  // flagFromLabel (the match rule), FLAG_STOPS (the single-source stop
  // list), flagEvents (the derived flag-bearing subset), updateRailB (the
  // per-call re-derivation) and railStopsB (the built dot/name pairs the
  // recording classList stub observes).
  const body = slice + '\nreturn { computeSceneB: computeSceneB, getCurrentStepB: getCurrentStepB, ' +
    'TOTAL_MS: TOTAL_MS, events: events, RING_AGENTS: RING_AGENTS, PAYLOAD: PAYLOAD, RING_POS: RING_POS, ' +
    'agentChip: agentChip, agentLabelHtml: agentLabelHtml, agentLabel: agentLabel, escapeHtml: escapeHtml, ' +
    'flagFromLabel: flagFromLabel, FLAG_STOPS: FLAG_STOPS, flagEvents: flagEvents, updateRailB: updateRailB, ' +
    'railStopsB: railStopsB };';
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

// ---- 3. board-flag rail (T-1014, issue #83) — the eight frozen assertion
//         ids, scoped by fixture label. rail-precondition guards every other
//         rail assertion on the flag-rail fixture and FAILS (never skips)
//         when the expected flag-event/rail-stop shape is wrong; the mixed
//         fixture instead proves the empty-state half (rail-empty-state). ----
(function boardFlagRail() {
  if (label === 'flag-rail') {
    // rail-precondition FAILS (never returns/skips) on a wrong flag-event or
    // rail-stop count, but does NOT short-circuit the assertions below it:
    // every one of them either has no positional dependency on the exact
    // count (rail-forward-reached, rail-rewind, rail-near-miss,
    // rail-uniform-kind) or guards its own positional access explicitly
    // (rail-step-back, rail-determinism) — so a mutation that changes the
    // flag count (e.g. trimming turns the trailing-space near-miss into a
    // genuine flag) still lets the MORE SPECIFIC assertion it actually
    // targets (rail-near-miss) report its own, more informative violation,
    // rather than being masked behind the precondition's generic message.
    var expectedFlagCount = 7, expectedStopCount = 5;
    if (scene.flagEvents.length !== expectedFlagCount || scene.railStopsB.length !== expectedStopCount) {
      fail('rail-precondition: expected ' + expectedFlagCount + ' flag events and ' + expectedStopCount +
        ' rail stops on the flag-rail fixture, got ' + scene.flagEvents.length + ' flag event(s) and ' +
        scene.railStopsB.length + ' rail stop(s)');
    } else {
      ok('rail-precondition: ' + scene.flagEvents.length + ' flag events, ' + scene.railStopsB.length + ' rail stops, as expected');
    }

    function snapshot() {
      return scene.railStopsB.map(function (s) {
        return s.flag + ':' + (s.dot.classList.contains('reached') ? 1 : 0) + ':' + (s.dot.classList.contains('current') ? 1 : 0);
      }).join('|');
    }
    function reachedFlags() {
      return scene.railStopsB.filter(function (s) { return s.dot.classList.contains('reached'); }).map(function (s) { return s.flag; });
    }
    function currentFlags() {
      return scene.railStopsB.filter(function (s) { return s.dot.classList.contains('current'); }).map(function (s) { return s.flag; });
    }

    // rail-determinism: the class-set snapshot at one mid simMs is identical
    // whether reached by forward-only playback or by seeking backward from
    // TOTAL_MS first. Runs BEFORE every other rail-* assertion below —
    // deliberately: a still-broken monotonic accumulator (the shape this
    // task's D3 replaces) never clears once anything has called
    // updateRailB(TOTAL_MS), so if rail-forward-reached/rail-step-back/
    // rail-rewind ran first and each called updateRailB(TOTAL_MS) at least
    // once, a broken accumulator would already be saturated to "everything
    // reached" by the time this comparison ran and BOTH its forward and
    // rewind-first snapshots would read that same saturated state — passing
    // for the wrong reason (mutation self-check #5 caught this ordering
    // blind spot: with the assertions in file order, restoring the old
    // accumulator left this check green instead of red).
    var midEvt = scene.flagEvents[2]; // the fixture's first READY_FOR_QA
    if (!midEvt) {
      fail('rail-determinism: fixture shape assumption broken — flagEvents[2] does not exist (only ' + scene.flagEvents.length + ' flag event(s))');
    } else {
      var midMs = midEvt._tStart;
      scene.updateRailB(0);
      scene.updateRailB(midMs);
      var forwardSnapshot = snapshot();
      scene.updateRailB(scene.TOTAL_MS);
      scene.updateRailB(midMs);
      var rewindSnapshot = snapshot();
      if (forwardSnapshot === rewindSnapshot) {
        ok('rail-determinism: the rail at simMs=' + midMs + ' is identical whether reached forward-only or by rewinding first');
      } else {
        fail('rail-determinism: forward snapshot (' + forwardSnapshot + ') != rewind-first snapshot (' + rewindSnapshot + ') at simMs=' + midMs);
      }
    }

    // rail-forward-reached: after seeking to TOTAL_MS, all five dots are
    // reached and exactly one is current — the positive control that proves
    // the recording classList stub actually records at all (without it,
    // rail-rewind below would pass for the wrong reason: vacuously).
    scene.updateRailB(scene.TOTAL_MS);
    var reachedAtEnd = reachedFlags(), currentAtEnd = currentFlags();
    if (reachedAtEnd.length === scene.railStopsB.length && currentAtEnd.length === 1) {
      ok('rail-forward-reached: all ' + reachedAtEnd.length + ' dots reached, exactly one current after seeking to TOTAL_MS');
    } else {
      fail('rail-forward-reached: expected all ' + scene.railStopsB.length + ' dots reached and exactly one current, got reached=[' +
        reachedAtEnd.join(',') + '] current=[' + currentAtEnd.join(',') + ']');
    }

    // rail-step-back: flagEvents[4] is the fixture's re-emitted READY_FOR_QA
    // (the step-back, seq 14) — at its _tStart, READY_FOR_REVIEW (a LATER
    // stop, reached earlier at seq 9) stays reached while current moves back
    // to READY_FOR_QA. Times are derived from the fixture's own flagEvents,
    // never hardcoded (a hardcoded ms would silently detach the first time a
    // span duration changes).
    var stepBack = scene.flagEvents[4];
    if (!stepBack || stepBack.flag !== 'READY_FOR_QA') {
      fail('rail-step-back: fixture shape assumption broken — flagEvents[4] is not the step-back READY_FOR_QA row (got ' +
        (stepBack ? stepBack.flag : 'undefined') + ')');
    } else {
      scene.updateRailB(stepBack._tStart);
      var reachedAtStepBack = reachedFlags(), currentAtStepBack = currentFlags();
      var expectedReached = ['READY_FOR_ARCH', 'READY_FOR_ENG', 'READY_FOR_QA', 'READY_FOR_REVIEW'];
      var reachedSetOk = reachedAtStepBack.length === expectedReached.length &&
        expectedReached.every(function (f) { return reachedAtStepBack.indexOf(f) !== -1; });
      if (reachedSetOk && currentAtStepBack.length === 1 && currentAtStepBack[0] === 'READY_FOR_QA') {
        ok('rail-step-back: the first four stops stay reached (including the later READY_FOR_REVIEW), current moves back to READY_FOR_QA');
      } else {
        fail('rail-step-back: expected reached=[' + expectedReached.join(',') + '] current=[READY_FOR_QA], got reached=[' +
          reachedAtStepBack.join(',') + '] current=[' + currentAtStepBack.join(',') + ']');
      }
    }

    // rail-rewind: after seeking to TOTAL_MS then back to 0, zero dots are
    // reached and zero are current — the reached trace is derived fresh per
    // call (D3), never accumulated, so a rewind un-reaches every stop the
    // playhead has not yet passed.
    scene.updateRailB(scene.TOTAL_MS);
    scene.updateRailB(0);
    var reachedAtZero = reachedFlags(), currentAtZero = currentFlags();
    if (reachedAtZero.length === 0 && currentAtZero.length === 0) {
      ok('rail-rewind: seeking back to 0 after reaching the end leaves zero dots reached and zero current');
    } else {
      fail('rail-rewind: expected zero reached and zero current after rewinding to 0, got reached=[' +
        reachedAtZero.join(',') + '] current=[' + currentAtZero.join(',') + ']');
    }

    // rail-near-miss: none of the three committed near-miss labels derive a
    // flag — asserted through flagFromLabel directly AND through the adapted
    // event set, and each near-miss label is asserted PRESENT in events
    // first, so this cannot pass against a fixture that never carried it.
    var nearMisses = ['now READY_FOR_QA', 'ready_for_qa', 'READY_FOR_QA '];
    var nearMissOk = true;
    nearMisses.forEach(function (nm) {
      var present = scene.events.some(function (e) { return e.label === nm; });
      if (!present) {
        fail('rail-near-miss: the flag-rail fixture never carried the near-miss label ' + JSON.stringify(nm));
        nearMissOk = false;
        return;
      }
      if (scene.flagFromLabel(nm) != null) {
        fail('rail-near-miss: flagFromLabel() derived a flag for the near-miss label ' + JSON.stringify(nm));
        nearMissOk = false;
      }
      var derivedOnEvent = scene.events.some(function (e) { return e.label === nm && e.flag; });
      if (derivedOnEvent) {
        fail('rail-near-miss: an adapted event carrying the near-miss label ' + JSON.stringify(nm) + ' derived a flag');
        nearMissOk = false;
      }
    });
    if (nearMissOk) {
      ok('rail-near-miss: none of the three near-miss labels (prose-embedded, lowercase, trailing-space) derive a flag, directly or via the adapted event set');
    }

    // rail-uniform-kind: D1's uniformity probe — the fixture's `human` row
    // (seq 22) carries a bare READY_FOR_MERGE label and IS the last entry of
    // flagEvents, proving the derivation is not restricted to `handoff` rows.
    var lastFlagEvent = scene.flagEvents[scene.flagEvents.length - 1];
    if (lastFlagEvent && lastFlagEvent.type === 'human' && lastFlagEvent.flag === 'READY_FOR_MERGE') {
      ok('rail-uniform-kind: the human-kind row\'s bare token (READY_FOR_MERGE) derives a flag and is the last flagEvents entry');
    } else {
      fail('rail-uniform-kind: expected the last flagEvents entry to be a human-kind row carrying READY_FOR_MERGE, got ' +
        (lastFlagEvent ? (lastFlagEvent.type + '/' + lastFlagEvent.flag) : 'none'));
    }
  } else if (label === 'mixed') {
    // rail-empty-state: on the mixed fixture, flagEvents is empty — the
    // ratified empty-state caption path — while a positive control proves
    // events itself is non-empty, so the emptiness is a property of the
    // labels (no READY_FOR_* string in this fixture) and not of an absent
    // event set.
    if (scene.events.length > 0 && scene.flagEvents.length === 0) {
      ok('rail-empty-state: the mixed fixture carries ' + scene.events.length + ' events and zero flag events');
    } else {
      fail('rail-empty-state: expected events.length > 0 and flagEvents.length === 0 on the mixed fixture, got events=' +
        scene.events.length + ' flagEvents=' + scene.flagEvents.length);
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
  run_harness flag-rail  20260801T000000Z-flagrail flag-rail
  pass "node-harness.js: every fixture executes the real scene/adaptation code without a crash or an injection escape"
fi

printf 'gen-loop-replay: all checks passed\n'
exit 0
