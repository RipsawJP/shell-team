Task: T-1012

# Design note — degraded-fidelity visual treatment for the loop-replay generator

## Mode line

Full (`frontend-design`) — consulted. Its guidance is written for choosing a
greenfield aesthetic (typography, palette, motion language), and nearly all of
that is inapplicable here: this task's palette, fonts and motion are a
**ratified contract** in `templates/loop-replay.html` and are explicitly out of
scope to change. What the skill's own core principle does apply — commit to one
intentional direction rather than a wishy-washy default — is what shaped the
decisions below: every new state below is built by **extending an existing
token or mechanism the prototype already has** (a token, a CSS-var slot, a
`highlightMode` branch, a chip-strip pattern) rather than inventing new visual
vocabulary. That restraint is itself the design decision for a task this
narrowly scoped.

## Non-goals (restated, this note does not touch them)

This note does **not** redesign anything already ratified: the ground ring,
the single serial ball, the beam channel, the flag-rail mechanism itself, the
camera controls, the LOD mini-card mechanism, the idle UI-designer caption,
the JA/EN toggle architecture, `prefers-reduced-motion` handling, the playback
transport, the color system's existing tokens/hues, or the typography. Every
instruction below is additive: a new dictionary key, a new CSS-variable value
slotted into the theme blocks that already exist, a new modifier class next to
an existing one, or a null-guard on a string that is already built the same
way elsewhere in the file. Nothing here changes the document's rendering mode,
adds `<!DOCTYPE>`, or introduces a second injection site.

**Aesthetic direction**

The prototype's existing metaphor is a **flight recorder** — an instrument
console reporting what a black box captured, in the instrument's own
mono/sans, teal-on-neutral idiom. The degraded states are designed as **the
instrument honestly reporting a sensor gap**, not as an error screen and not
as a silently sparser scene. Two things follow from committing to that frame
rather than treating degradation as a defect to apologize for:

1. **The signal is calm, not alarming.** A run with no event rows is the
   *dominant, expected* case (11 of 12 runs in this repository, per the spec).
   It gets the **warning** token (`--warning` / `--warning-soft`), not danger.
   Danger stays reserved for rework and non-success outcomes — real problems
   in the loop, not gaps in what a run happened to record. This is `--warning`'s
   first real use anywhere in the shipped template; introducing it here rather
   than reusing danger is the one deliberate new-token decision in this note,
   and it is a reuse of an already-defined-but-idle token, not a new color.
2. **The signal lives in the instrument's own furniture, not a modal.** The
   fixed no-scroll, no-page-scroll layout (`.console{ height:100dvh;
   overflow:hidden }`) is itself part of the ratified contract; a banner that
   pushes layout or overlays the stage would fight it. Every degraded-state
   affordance below is placed inside a component the page already has (the
   header chip-strip, the flag rail's own title block, the detail
   panel/tooltip/mini-card) using that component's own existing visual
   grammar (chip shape, dot shape, stat-line shape) — extended, not replaced.

## New dictionary keys (all in both `ja` and `en`, alongside the frozen `degradedNoEvents`)

| key | purpose | `en` | `ja` |
|---|---|---|---|
| `degradedNoEvents` | *(frozen by spec D3 — reused, not renamed)* span-only run: zero event rows | "No event rows — spans only" | "イベント行なし（スパンのみ）" |
| `degradedNoSpans` | event-only run: zero span rows | "No span rows — events only" | "スパン行なし（イベントのみ）" |
| `degradedPartialEvents` | some but not all five event ids present | "Partial event vocabulary — some signals missing" | "イベント語彙が部分的 — 一部のシグナルが欠落" |
| `flagRailEmpty` | no row anywhere carries a `flag` (no gate/human/release reached) | "No board-flag events in this run" | "このランにはボードフラグのイベントがありません" |
| `unknownAgent` | an agent id in the roster outside the six known ids | "Unrecognised agent" | "未登録エージェント" |
| `nonSuccessLabel` | prefix before a verbatim, untranslated `status` token | "status: " | "ステータス: " |

Every new key is chrome, not operator text — consistent with D3's rule that
`label`/`from`/`to` stay verbatim in both languages while the page's own
strings localize. `status` values (`error`, `timeout`, `skipped`, `stopped`)
are data-shaped tokens, like `phase`, and are **displayed verbatim in both
languages**, exactly as `phase` already is — only the `nonSuccessLabel` prefix
around them localizes.

## Component/state notes

### 1. Degradation announcement (banner vs. badge vs. dimmed — my call: badge, in the existing chip-strip)

One new chip, `<li id="degradedChip" class="degraded" hidden>`, appended to
the existing `#readouts` chip-strip in the masthead — the same list that
already carries the rework-count and token-count chips. New CSS, parallel to
the existing `.chip-strip li.rework` / `.chip-strip li.tokens` modifiers:

```css
.chip-strip li.degraded{ color:var(--warning); border-color:var(--warning); background:var(--warning-soft); }
```

Classification is evaluated **once**, at load, over the full payload, with a
fixed precedence so exactly one message ever shows (never a stacked or
conflicting pair):

1. Zero rows with `kind` absent/`"span"` is impossible by definition of this
   task's own payload (rows are either present, and there's always at least
   one, or the run doesn't exist) — not a state to design for.
2. **Zero rows with `kind:"event"`** → chip shows `degradedNoEvents`. Highest
   priority: this is the dominant real case and the frozen key.
3. Else **zero rows with `kind` absent/`"span"`** → chip shows `degradedNoSpans`.
4. Else, if the distinct `event` values present are a **proper subset** of
   `handoff|rework|gate|human|release` → chip shows `degradedPartialEvents`.
5. Else (full vocabulary, both spans and events present) → chip stays `hidden`.

The chip's `title` attribute carries the same string as its text (matching
the existing chips' hover-title pattern), so the message is available to
assistive tech and on hover alike without a second UI element.

### 2. Empty/inactive flag rail

Today, a rail with zero `flag`-bearing rows would render pixel-identical to a
rail mid-playback that simply hasn't reached its first stop yet — both show
five unlit dots on `--border-strong`. That reads as "stuck," not "no data,"
which is exactly the silent-degradation failure mode the spec forbids. Fix:
a rail-level empty state, distinct from the "not reached yet" look.

- When `flagEvents.length === 0` at load, add class `rail-empty` to
  `#bRailTrack` (`.b-rail-track.rail-empty`) and reveal a new caption line,
  `<p class="b-rail-empty-note" id="railEmptyNote">`, inserted directly under
  the existing `#bRailTitle`, text from `flagRailEmpty`.
- CSS:

```css
.b-rail-track.rail-empty .b-rail-dot{ opacity:.4; border-style:dashed; }
.b-rail-empty-note{ font-family:var(--font-mono); font-size:8px; letter-spacing:.06em;
  color:var(--text-faint); text-align:center; margin:0 0 10px; text-wrap:balance; }
```

  Dashed + lower opacity is a **shape** change, not just a color dim, so it
  reads correctly for anyone who can't rely on the opacity difference alone.
  It never overlaps the "reached"/"current" states (those only ever apply
  when `flagEvents.length > 0`, i.e. `rail-empty` is never combined with
  `.reached`/`.current` on the same render).

### 3. Unrecognised-agent styling

The roster is data ∪ the six known ids (spec D3). An id outside the six needs
a style that reads as "this loop supports adopter agent names by design," not
as a missing color mapping.

- New CSS variable, **added to all four existing theme blocks** (the bare
  `:root`, the `prefers-color-scheme: dark` media block, `:root[data-theme="dark"]`,
  `:root[data-theme="light"]`) alongside the eight existing `--agent-*` vars:
  `--agent-unknown: var(--text-faint);` — deliberately a reuse of the existing
  neutral text token, not a new hue, so it sits outside every identity color
  the way the code's own comment already reasons about avoiding the
  accent/danger/success hue bands.
- Canvas node ring: for any id not in `RING_AGENTS` ∪ `{orchestrator, human}`,
  stroke the node circle with a dashed line (`ctx.setLineDash([4,3])` before
  the stroke call in `drawB2`'s node-drawing loop, `ctx.setLineDash([])`
  immediately after) using `--agent-unknown` as both fill-tint and stroke
  color. Dashed + neutral is chosen so it is never confused with the existing
  idle-ui-designer treatment (solid ring, lower fill opacity) — two different
  reasons for a node to look "different" get two different visual cues.
- Tooltip and legend both gain the `unknownAgent` label as a second line/row
  for any such id: the tooltip's bold label falls back to the raw `span`
  string (there is no display-name mapping for it) with `unknownAgent` shown
  as a dimmed second line; the legend (`#agentLegendGrid`) gets one
  dynamically-appended row per distinct unrecognised id actually present in
  the payload, using a dashed-border dot swatch
  (`border:1px dashed var(--border-strong); background:var(--agent-unknown)`)
  echoing the canvas dashing.
- LOD mini-card: same treatment — border/left-accent-bar color is
  `--agent-unknown`, rendered dashed rather than solid.

### 4. Non-success span marking

`status` values other than `success` — `error`, `timeout`, `skipped`,
`stopped` — map onto the two severities the existing palette already
distinguishes:

| status | token | rationale |
|---|---|---|
| `error`, `timeout`, `stopped` | `--danger` / `--danger-soft` | the step did not complete as intended — same weight as rework already uses |
| `skipped` | `--warning` / `--warning-soft` | the step was bypassed on purpose — a lesser severity than a failure, and `--warning`'s second use in this note |

Applied in three places, so it is never silently dropped from any of them:

- **Ring highlight**: `computeSceneB`'s existing `scene.highlightMode`
  mechanism (already branching to `"rework"` for danger-red pulses) gets one
  additional mode, e.g. `"status-warning"`, driving the same pulse-ring code
  path with `--warning` instead of `--danger`. `error`/`timeout`/`stopped`
  reuse the existing `"rework"` mode's danger coloring as-is — no new pulse
  mechanism, just one more value feeding the branch that already exists.
- **Detail panel chip row**: a new chip variant, parallel to the existing
  `.chip.verdict-pass` / `.chip.verdict-reject`:

  ```css
  .chip.status-danger{ color:var(--danger); border-color:var(--danger); background:var(--danger-soft); }
  .chip.status-warning{ color:var(--warning); border-color:var(--warning); background:var(--warning-soft); }
  ```

  Rendered whenever `status !== "success"`, showing the literal status token
  verbatim, uppercased (`ERROR`, `TIMEOUT`, `SKIPPED`, `STOPPED`) — shown
  **independently of whether a `verdict` chip is also present**, since a span
  can carry both, and neither field substitutes for the other.
- **Tooltip / mini-card**: one additional line, prefixed by `nonSuccessLabel`
  ("status: " / "ステータス: "), colored via the same danger/warning mapping,
  the status value itself appended verbatim (not run through `T()`).

### 5. Null-field placeholders

The codebase already has a convention for this — the detail panel's stat grid
does `current.tokens != null ? current.tokens.toLocaleString() : "—"` and
`current.model || "—"`. This note extends that **same glyph** (em dash, `—`,
U+2014 — no dictionary key needed, since it's already unlocalized precedent
in the file) to every other place a nullable field is currently interpolated
**without** a guard:

- The tooltip (`showTip`)'s `model`/`verdict` lines and the mini-card
  (`drawMiniCard`)'s single-span branch both currently concatenate
  `e.model`/`e.verdict` directly with no null check — this is the literal gap
  AC29 is checking for. Every such interpolation becomes
  `field != null ? field : "—"` before it is written into a string.
- This is a general rule, not a per-field patch: **no field that can be
  explicitly `null` (`model`, `verdict`, `usd`, `error`, `parent_span_id`,
  `from`, `to`) is ever interpolated into displayed text without this guard.**

## Confirmations (not redesigned, verified against this note's additions)

- **Machine tokens stay verbatim English in both language modes**, including
  every new caption this note introduces: none of `degradedNoEvents` /
  `degradedNoSpans` / `degradedPartialEvents` / `flagRailEmpty` /
  `unknownAgent` / `nonSuccessLabel` ever wraps or reformats a
  `READY_FOR_*`/`PASS`/`FAIL`/`APPROVE`/`REQUEST_CHANGES` value — those pass
  through exactly as the existing `verdictChip`/`b-now-verdict` code already
  does, untouched by this note.
- **`prefers-reduced-motion` disables decorative motion in every new
  treatment**: the dashed unknown-agent ring and the rail's dashed dots are
  static (a stroke style, not an animation) so they need no reduced-motion
  branch; the new `"status-warning"` highlight mode rides the exact same
  pulse code that already checks `reduceMotion` (see `drawB2`'s `if
  (isHighlighted && !reduceMotion)` branch) and gets that guard for free.
- **Self-contained**: every addition is inline CSS/JS/Canvas drawing already
  inside `templates/loop-replay.html`; no new font, icon font, image, or
  external reference is introduced anywhere in this note.
- **Both themes covered**: `--agent-unknown` is defined once per existing
  theme block (four insertion points: base `:root`, the `prefers-color-scheme:
  dark` block, `[data-theme="dark"]`, `[data-theme="light"]`), and every other
  new color reference in this note (`--warning`, `--warning-soft`, `--danger`,
  `--danger-soft`) already exists in all four blocks today — no new
  light/dark pair needs to be authored.

**Acceptance hooks**

For the validator / QA to check this note was honored:

- **Dictionary keys**, both `ja` and `en` blocks of `I18N`:
  `degradedNoEvents` (frozen, spec-required), plus this note's
  `degradedNoSpans`, `degradedPartialEvents`, `flagRailEmpty`, `unknownAgent`,
  `nonSuccessLabel` — each should appear at least once in each language block.
- **DOM anchors**: `#degradedChip` (with class `degraded`) in `#readouts`;
  `#railEmptyNote` and the `.b-rail-track.rail-empty` modifier on
  `#bRailTrack`; `.chip.status-danger` / `.chip.status-warning` in the detail
  panel's chip rendering.
- **CSS anchor**: `--agent-unknown` declared in all four theme blocks
  (`:root`, the dark media query, `[data-theme="dark"]`, `[data-theme="light"]`).
- **AC29 items this note resolves**:
  - *"a non-success span is visibly marked rather than missing"* → the
    `.chip.status-danger`/`.status-warning` chip renders whenever `status !==
    "success"`, independent of `verdict`, and the ring pulses in the mapped
    color during that step.
  - *"a `null` `model` or `verdict` renders as a placeholder rather than the
    word `null`"* → grep the rendered tooltip/mini-card output for the
    literal substring `null` after generating against a fixture row with an
    explicit `"model":null` or `"verdict":null` — it must not appear; `—`
    must appear in its place. (Flagging for QA/engineer: the `hostile` or a
    dedicated fixture should carry at least one row with an explicit
    `"model":null` so this is actually exercised, not vacuously true.)
  - *"the span-only page shows the degradation caption instead of a silently
    sparser scene"* → `#degradedChip` is visible and reads `degradedNoEvents`
    when opening the generated `span-only` fixture's page; `#railEmptyNote`
    is also visible on that same fixture, since a span-only run by
    construction carries no `flag` rows either.
- **Unknown-agent treatment**: opening the `adopter` fixture (spec/Non-goals
  reference a `span` value outside the six known ids), the ring shows a
  dashed, `--agent-unknown`-colored node for that id, and the legend gains one
  additional row labeled with the raw id plus `unknownAgent`.
