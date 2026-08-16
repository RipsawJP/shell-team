# `bin/check-handoff.sh` runtime scaling — T-1070 measurement record

This note is the measurement record T-1070 leaves behind: the profile that
separated the checker's two cost paths before any implementation line moved,
the measurement protocol every number here depends on, the before/after
scaling curves on both growth axes, the real-board verification, the
consumer inventory, and the portability floor evidence. Every number is
either pasted verbatim from a command's own output or re-derivable from one
pasted here; no figure is transcribed from an issue or a prior board entry
without being re-measured at its own source (T-1070's `## Non-goals`: "No
performance claim without its conditions").

## Profile

The profile precedes the repair. It was run against the pre-change
implementation (the branch-point committed blob of `bin/check-handoff.sh`,
identical to the working tree at authoring time before this task's first
edit) instrumented to time its two whole-input passes separately: the `awk`
extraction at (then) lines 53-57, and the `while read` loop over the
extracted `## Active` lines at (then) lines 127-177. Instrumentation wrapped
each stage in bash's own `time` reserved word (`TIMEFORMAT='%R'`, wall-clock
seconds, converted to milliseconds here) around an unmodified copy of the
stage's code — no stage's logic was altered to measure it.

The profiling input is a single constructed board, `profiling-board.md`,
built to exercise both candidate cost paths at once (T-1068's own history
records both a huge `## Done` and, separately, one huge `## Active` line at
different points in this repository's real board, so a profile that starves
either path would under-measure the historical incident): the branch-point
committed blob of this repository's own board (2,884,750 bytes, 2,793
lines), with one ~4.2KB multibyte continuation line (Japanese characters,
an em dash, backticks, `*`, `[`, `(`, `$`, `+`, an apostrophe — the exact
character classes T-1070's `## Input space` names) spliced into its `##
Active` section, built with:

```
awk -v longfile=longline.txt '
  BEGIN { while ((getline ln < longfile) > 0) { longline = ln } }
  /^## Active[[:space:]]*$/ && !ins { print; print longline; ins=1; next }
  { print }
' board-base.md > profiling-board.md
```

Three trials were run per stage per condition; the value recorded is the
**median** of three (`## Measurement protocol` names this explicitly).

- profile: before awk_extract elapsed_ms 107 — median of 3 trials, `LC_ALL=C`, profiling-board.md (2,888,961 bytes / 2,794 lines, `## Active` 5,420 bytes) — the whole-file `awk` extraction alone, timed via `{ time active_block="$(awk '...' "$FILE")"; }` wrapped around the unmodified pre-change awk program.
- profile: before bash_loop elapsed_ms 1027 — median of 3 trials, same conditions — the `while IFS= read -r raw; do ... done <<< "$active_block"` loop alone, timed the same way, fed the awk stage's own output so no extraction cost leaks into this number.
- profile: before total elapsed_ms 1137 — median of 3 trials, same conditions — the whole unmodified script (`bash bin/check-handoff.sh profiling-board.md`, uninstrumented), timed externally with the same `time`/`TIMEFORMAT` mechanism.
- profile: after total elapsed_ms 9 — median of 3 trials, same conditions, the post-change working-tree script — a 126x reduction on the one input built to stress both cost paths at once.

- dominant: bash_loop — 1027ms of the 1137ms before-arm total (90.3%, ≥50%) is spent in the bash loop over `## Active`'s own lines, not in the whole-file `awk` pass; the `awk` extraction costs only 107ms even though it reads all 2,794 lines of a 2.89MB file. The single ~4.2KB continuation line this profiling board carries accounts for essentially the entire bash_loop cost (confirmed below by an isolated micro-benchmark of the one bash statement responsible).

- diagnosis: issue_256_quadratic_blank_check confirmed — isolated the blank-line test at (then) line 136, `[[ -z "${content//[[:space:]]/}" ]]`, from the rest of the loop body and timed it alone against synthetic strings of increasing length, three trials each, `LC_ALL=C`:

  ```
  len=1350   0.222s
  len=2700   1.036s   (doubling the length ~4.7x'd the time)
  len=5400   5.536s   (doubling again ~5.3x'd the time)
  len=10800  32.372s  (doubling again ~5.8x'd the time)
  ```

  Each doubling of input length multiplied the runtime by roughly 5x, not 2x
  — clearly super-linear, consistent with a naive O(n^2)-or-worse global
  pattern-substitution implementation that rebuilds the whole string once
  per matched character rather than once per call. As a discriminating
  control, the very next test in the loop body — the anchored regex
  `CONTINUATION_RE` match (`[[ "$content" =~ ^[[:space:]]+[^[:space:]] ]]`)
  — was isolated the same way and stayed at 0.000-0.001s across the same
  length range, confirming the cost is concentrated in the blank test
  specifically, not in `[[ =~ ]]` matching in general. This is exactly
  issue #256's attribution (relayed, `## Assumptions`), now measured rather
  than assumed, and it is the reason this profile names `bash_loop` — not
  `awk_extract` — as dominant, and the `active` axis (not `done`) as this
  checker's dominant growth axis in `## Scaling` below.

  A locale cross-check on the same profiling board: `LC_ALL=en_US.UTF-8`
  moved the before-arm bash_loop time from 1,027ms to 3,973ms (total
  1,137ms → 4,094ms) while `awk_extract` stayed flat (107ms → 118ms) — the
  defect is present under `C` and gets markedly worse under a UTF-8 locale,
  matching `.shell-team/todo.md`'s own T-1068 entry (14.95s UTF-8 / 2.08s
  `C` on the historical board). A cross-bash-version control: the identical
  before-arm run against a locally built bash 4.4.0 (see `## Measurement
  protocol`) took only 130ms on this same board — bash 3.2's own pattern-
  substitution engine is markedly more affected than bash 4.4's, which is
  why the macOS-stock-3.2 floor this repository targets is exactly the
  environment where this defect bites hardest.

  The fix (verified not to change the blank/non-blank verdict for any
  tested input, including the locale-dependent ones): replace the global
  substitution with an anchored whole-string match, `[[ "$content" =~
  ^[[:space:]]*$ ]]`. Equivalence check, both directions, both locales,
  `old` = `${content//[[:space:]]/}` empty test, `new` = the anchored match:

  | input | old (`C`) | new (`C`) | old (UTF-8) | new (UTF-8) |
  |---|---|---|---|---|
  | empty string | blank | blank | blank | blank |
  | spaces-only / tabs-only | blank | blank | blank | blank |
  | `abc`, `  abc`, `abc  ` | non-blank | non-blank | non-blank | non-blank |
  | U+3000 (ideographic space) x1/x2 | non-blank | non-blank | blank | blank |
  | U+00A0 (no-break space) | non-blank | non-blank | blank | blank |
  | U+00A0 + `abc` | non-blank | non-blank | non-blank | non-blank |
  | mixed ASCII + U+3000 spaces | non-blank | non-blank | blank | blank |

  All eleven cases agree in both locales — the locale-dependent verdict a
  byte like U+3000 or U+00A0 receives (blank under UTF-8, non-blank under
  `C`, in both the old and the new form) is unchanged, which is exactly
  what `bin/check-handoff.sh`'s own new comment at the fix site states, and
  exactly the property AC4's two-locale differential input protects.
  Performance of the anchored replacement, isolated the same way as above:

  ```
  len=1352 (C)     0.000s      len=652  (UTF-8)  0.001s
  len=2702 (C)     0.001s      len=1302 (UTF-8)  0.001s
  len=5402 (C)     0.001s      len=2602 (UTF-8)  0.001s
  len=10802 (C)    0.001s      len=5202 (UTF-8)  0.001s
  len=21602 (C)    0.001s      len=10402 (UTF-8) 0.002s
  len=43202 (C)    0.002s      len=20802 (UTF-8) 0.004s
  ```

  Flat to within measurement noise across a 32x length range in both
  locales — the anchored match fails (or succeeds) as soon as the leading
  run of `[[:space:]]` characters ends, rather than rebuilding the whole
  string, which is why the overwhelmingly common case (a non-blank line
  whose first non-whitespace character sits a few columns in) is now
  effectively free.

## Measurement protocol

- condition: bash_version 3.2.57(1)-release (arm64-apple-darwin25, macOS stock `/bin/bash`, `bash --version`) and 4.4.0(1)-release (arm-apple-darwin25.5.0, built from source for this task — see below) — the two distinct `<major.minor>` floors measured.
- condition: locale LC_ALL=C and LC_ALL=en_US.UTF-8, both exercised for every profile/scaling/realboard cell reported above and below unless stated otherwise; the primary recorded numbers in `## Scaling` and `## Consumers` are `LC_ALL=C`, with UTF-8 comparison points recorded inline in `## Profile` where the locale sensitivity itself is the point.
- condition: board_identity read as the branch point's committed blob, never the working tree — `B=$(git merge-base chore/lesson-promotion-2026-08-15 HEAD); git show "$B:$(bash bin/team-paths.sh --get todo)" > scratch/realboard-base.md` — both the before arm (run against a plain copy of that same blob's bytes with the branch-point script) and the after arm (run against the identical bytes with the working-tree script) read this one snapshot.
- condition: board_bytes 2884750 — `wc -c scratch/realboard-base.md` → `2884750 scratch/realboard-base.md`
- condition: board_lines 2793 — `wc -l scratch/realboard-base.md` → `2793 scratch/realboard-base.md`
- condition: active_span 8 lines / 1209 bytes, measured at the branch-point blob — immediately before this task's own board entry was appended, `## Active` held only two leftover `### Local test result` blocks and no task entry at all (the same event `.shell-team/todo.md`'s own T-1070 entry and this spec's `## Assumptions` record); re-measured here rather than transcribed: `awk '/^## Active[[:space:]]*$/ && !seen{seen=1;f=1;next} f&&/^## /{exit} f' scratch/realboard-base.md | wc -lc` → `8` lines / `1209` bytes.
- condition: trials 3 — every `elapsed_ms` figure in this note is the median of 3 trials at the stated condition; `## Profile`'s two before/after totals and `## Scaling`'s twelve cells all follow this same 3-trial-median protocol.
- condition: host_os Darwin 25.5.0 arm64 (`uname -a`: `Darwin ME24022.local 25.5.0 Darwin Kernel Version 25.5.0: Tue Jun 9 22:19:21 PDT 2026; root:xnu-12377.121.10~1/RELEASE_ARM64_T8122 arm64`).

**How the second bash floor was obtained.** This host ships only `/bin/bash`
3.2.57 (no `timeout` either, matching this spec's own `## Input space`); no
bash 5 package could be installed without either reaching a disallowed
network host or writing outside this task's isolated scratch area. A bash
4.4.0 was built from source instead, from `gitGNU/gnu_bash`'s
`bash-4.4`-tagged mirror (a GitHub-hosted mirror, an allowed network host;
`git ls-remote --tags` on that mirror shows no tag past `bash-4.4`, so 4.4 —
not 5.x — is the second floor actually available to this measurement, named
here rather than papered over as "a bash 5 build" per T-1070's own
`## Assumptions`), configured and built with `./configure
--prefix=<scratch>/bash44-install CFLAGS="-Wno-error=implicit-function-declaration
-Wno-error=implicit-int" && make`, entirely under a scratch directory
outside this checkout and never installed onto `PATH` or into the host's
package manager. `/tmp/.../bash --version` confirms `GNU bash, version
4.4.0(1)-release (arm-apple-darwin25.5.0)`.

## Scaling

Twelve points: two arms (`before` = the branch-point committed blob's
implementation; `after` = the working tree), two axes (`done` = whole board
file bytes with `## Active` held constant; `active` = the `## Active`
section's own bytes with `## Done` held constant), three multipliers (1x,
2x, 4x) per axis. All twelve inputs share one small, constant header (745
bytes: `# Tasks` / `## Status flags` / `## Active` with the fixture's
original five-entry, small-content Active section, through the `## Done`
heading) so the `done`-axis boards vary only in `## Done`'s own filler size
and the `active`-axis boards vary only in the one long continuation line's
own length.

- synthetic: `done` axis — `{ cat header.md; awk -v n=<reps> 'BEGIN{for(i=0;i<n;i++) printf "- [x] **T-90%02d** filler done entry number %d ... — \`READY_FOR_MERGE\` — spec: filler/x-%d.md\n  - sub: filler continuation padding text ...\n", (i%99), i, i}'; } > done-<mult>x.md` with reps = 500 / 1000 / 2000 for 1x/2x/4x. `active` axis — a Python one-liner tiling a fixed multibyte+punctuation string (the same character classes as `## Profile`'s long line) to length L = 1200 / 2400 / 4800 for 1x/2x/4x, embedded as one continuation line under one well-formed `## Active` task entry, with `## Done` held to the fixture's original single archived-comment line.

- scaling: before done 1x elapsed_ms 23 axis_bytes 97526 — 3-trial median, `LC_ALL=C`, whole-file bytes (the axis being scaled)
- scaling: before done 2x elapsed_ms 31 axis_bytes 194526 — 3-trial median, `LC_ALL=C`
- scaling: before done 4x elapsed_ms 40 axis_bytes 390526 — 3-trial median, `LC_ALL=C` — 4.00x the bytes of the 1x point, 1.74x the runtime
- scaling: after done 1x elapsed_ms 9 axis_bytes 97526 — 3-trial median, `LC_ALL=C`
- scaling: after done 2x elapsed_ms 9 axis_bytes 194526 — 3-trial median, `LC_ALL=C`
- scaling: after done 4x elapsed_ms 9 axis_bytes 390526 — 3-trial median, `LC_ALL=C` — flat despite a 4.00x byte increase: the early-exit awk never reads `## Done` at all once `## Active` closes
- scaling: before active 1x elapsed_ms 175 axis_bytes 1637 — 3-trial median, `LC_ALL=C`, `## Active` section's own bytes (the axis being scaled)
- scaling: before active 2x elapsed_ms 739 axis_bytes 3189 — 3-trial median, `LC_ALL=C` — 1.95x the bytes of the 1x point, 4.22x the runtime
- scaling: before active 4x elapsed_ms 4145 axis_bytes 6293 — 3-trial median, `LC_ALL=C` — 3.84x the bytes of the 1x point, 23.69x the runtime: clearly super-linear
- scaling: after active 1x elapsed_ms 9 axis_bytes 1637 — 3-trial median, `LC_ALL=C`
- scaling: after active 2x elapsed_ms 8 axis_bytes 3189 — 3-trial median, `LC_ALL=C`
- scaling: after active 4x elapsed_ms 10 axis_bytes 6293 — 3-trial median, `LC_ALL=C` — flat (within measurement noise) despite a 3.84x byte increase: the anchored blank-test match no longer rebuilds the string

- gradient: before done sub_linear — runtime grew 1.74x (23→40ms) while the axis (whole-file bytes) grew 4.00x; the whole-file awk pass is cheap per line and a fixed per-invocation overhead dominates at these sizes, so cost grows slower than the input even before the fix.
- gradient: before active super_linear — runtime grew 23.69x (175→4145ms) while the axis (`## Active` bytes) grew only 3.84x — sharply faster than linear, the signature `## Profile`'s isolated micro-benchmark attributes to the quadratic-or-worse blank test.
- gradient: after done invariant — runtime held at 9ms across a 4.00x byte increase in the axis; the early-exit awk's cost is structurally independent of `## Done`'s size.
- gradient: after active invariant — runtime held at 8-10ms (measurement noise) across a 3.84x byte increase in the axis; the anchored blank-test match's cost no longer depends materially on the line's own length.

- dominant-axis: active — agrees with `## Profile`'s `- dominant: bash_loop` (the active axis is the one `bash_loop`'s per-line work scales with); the before-arm active-axis 4x/1x ratio (23.69x) is also the one of the two axes that clears the "before-arm 4x/1x ratio above 2.0" floor by a wide margin, and after the fix both axes are flat, with the dominant axis meeting the stronger "after 4x under half of before 4x" bar (10ms vs 4145ms/2=2072.5ms) and the non-dominant (`done`) axis meeting the no-regression floor (9ms ≤ 40ms×1.5=60ms).

## Consumers

Ref-pinned extraction, not a hand-assembled list:

```
B=$(git merge-base chore/lesson-promotion-2026-08-15 HEAD)
git grep -c -e check-handoff "$B" -- bin tests
```

- scope: bin and tests — every checker or helper script under `bin/` and every fixture-driven suite under `tests/` that mentions `check-handoff` at all, whether by invoking `bin/check-handoff.sh` directly, by name in a comment, or in a suite's own fixture text.
- population: files 25 occurrences 144 — re-derived directly from the command above (`grep -c . <output> = 25`; `awk -F: '{s+=$NF} END{print s}' <output> = 144`); this corrects the Routing Map's relayed 16-files/112-occurrences figure, which this spec's own `## Assumptions` already identifies as the `tests/`-only half of the union (`tests/` alone is 16 files / 112 occurrences; `bin/` adds 9 files / 32 occurrences).
- consumer: bin/close-out.sh invokes the checker twice per close-out (the synthesized single-entry board, the rewritten whole board) and discriminates its three exit codes (0/1/2) — unaffected, since exit codes, stdout and stderr are pinned byte-identical by AC4/AC5.
- consumer: bin/check-board-headings.sh carries (and, per T-1070 AC10, now correctly resolves) a comment referencing the section-tracking construct this task changed; its own scanning logic is untouched (T-1070 `## Non-goals`).
- consumer: tests/errexit-safe/run.sh pins two of the checker's `printf` lines by exact content with a declared count of one each — both survive byte-identical (AC5), so this suite's registry needs no update.
- consumer: tests/check-handoff/run.sh is this checker's own fixture suite, extended (not replaced) with the six new section-structure fixtures and their assertions (AC9).
- consumer: tests/close-out/run.sh exercises the checker indirectly through `bin/close-out.sh`'s two invocations; unaffected for the same reason as the `bin/close-out.sh` row above.
- consumer: .github/workflows/check-handoff.yml invokes the checker against `templates/todo-template.md` and, as a dogfood step, against this repository's own real (and growing) board — the runtime this task repairs, byte-identical to its branch-point blob (AC9), so no CI wiring changes.

## Real-board verification

- realboard: before exit 0 stderr_bytes 0 elapsed_ms 141 — `LC_ALL=C`, branch-point committed blob of `bash bin/team-paths.sh --get todo`'s resolved path, run with the branch-point implementation, 3-trial median.
- realboard: after exit 0 stderr_bytes 0 elapsed_ms 8 — `LC_ALL=C`, identical bytes, run with the working-tree implementation, 3-trial median — 8ms is under half of 141ms (17.5x faster on the real board this checker exists to make cheap). Under `LC_ALL=en_US.UTF-8` the same pair measured 254ms before / 9ms after (28.2x).

Both arms agree on exit status (0) and stderr byte count (0) — the verdict
on this repository's own board did not move. The after-arm figures are
re-verified live, against whatever `bash bin/team-paths.sh --get todo`
resolves to at verification time (not the pinned snapshot above), by AC6's
own `- check:` line.

## Portability

- portability: bash_3_2 pass — the fix uses only constructs already present in the file's bash-3.2 floor (indexed-array-free, no `mapfile`/`readarray`, no `${var^^}`/`${var,,}`); the differential oracle (AC4) and this note's `before`/`after` scaling measurements were run directly under this host's stock `/bin/bash` 3.2.57.
- portability: posix_awk pass — the early-exit change adds one POSIX `exit` statement to the existing awk program; no `gensub`/`asort`/`systime`/`strftime`/`IGNORECASE`/`FIELDWIDTHS`/`patsplit`/`nextfile` and no `gawk`/`nawk` is introduced.
- portability: shellcheck_0_11_0 pass — `shellcheck --version` on this host reports `0.11.0`; `shellcheck bin/check-handoff.sh tests/check-handoff/run.sh` exits 0.

## AC14 — runtime, reported item by item

AC14 is `SKIP` by design (no command can prove a command was run), so this
section — not the engineer's ephemeral hand-off message — is this
criterion's evidence. Per this task's own repo-wide discipline ("Git-tracked
files are the only shared state"), everything AC14 asks for lives here,
committed, rather than in any message. QA round 1 (2026-08-15) found this
section absent; this is the durable transcription of the same content the
engineer's hand-off message already reported, not new analysis.

### (a) Mutation self-check — every probe, one line each

All seventeen mutations below were made on a `git worktree add --detach`
scratch copy at `HEAD` (`/tmp/.../t1070-mut`, outside this working tree),
each observed red, restored to the pre-mutation byte-identical content
(diffed to confirm), and observed green again before the next probe.

1. **AC1** — renamed a `- profile: before awk_extract` stage id to `awk_extractX` in the note → `AC1: FAIL (exit 1)`; restored → `AC1: PASS (exit 0)`.
2. **AC1** — overwrote the dominant stage's before-arm milliseconds (`- profile: before bash_loop elapsed_ms 1027`) to `100`, under half of the before-arm total (1137) → `AC1: FAIL (exit 1)` (the arithmetic clause — proving "dominant" is computed, not read); restored → `AC1: PASS (exit 0)`.
3. **AC2** — replaced `git show`/`git ls-tree`/`git cat-file` inside the `- condition: board_identity` line with a non-matching token → `AC2: FAIL (exit 1)`; restored → `AC2: PASS (exit 0)`.
4. **AC2** — set `- condition: trials 3` to `2` → `AC2: FAIL (exit 1)`; restored → `AC2: PASS (exit 0)`.
5. **AC3** — flipped `- dominant-axis: active` to `done`, disagreeing with `- dominant: bash_loop` → `AC3: FAIL (exit 1)` (the cross-section agreement clause); restored → `AC3: PASS (exit 0)`.
6. **AC3** — inflated `- scaling: after done 4x elapsed_ms 9` to `30`, past twice the 1x value (9) → `AC3: FAIL (exit 1)`; restored → `AC3: PASS (exit 0)`.
7. **AC4** — reverted the blank-test fix in `bin/check-handoff.sh` to a non-equivalent form (`[[ -z "$content" ]]`, which is not the anchored regex) → `AC4: FAIL (exit 1)`, caught by **`tests/check-handoff/fixtures/strand-tolerant.md`** (its whitespace-only line 12 was mis-classified as a boundary line rather than blank, which falsely reset `in_entry` and stranded line 13's real continuation); restored → `AC4: PASS (exit 0)`.
8. **AC5** — changed the reason string `"format mismatch"` to `"format mismatchX"` in `bin/check-handoff.sh` → `AC5: FAIL (exit 1)` (the byte-exact expected stream); restored → `AC5: PASS (exit 0)`.
9. **AC5** — duplicated the `emit()` `printf '%s:%s: %s: %s\n' "$FILE" "$1" "$2" "$3" >&2` line → `AC5: FAIL (exit 1)` (the exactly-once clause, the shape `tests/errexit-safe/run.sh` counts); restored → `AC5: PASS (exit 0)`.
10. **AC6** — altered the recorded after-arm `- realboard: after exit 0 stderr_bytes 0` to `stderr_bytes 5` → `AC6: FAIL (exit 1)`; restored → `AC6: PASS (exit 0)`.
11. **AC7** — altered the declared `- population: files 25 occurrences 144` to `files 99 occurrences 144` → `AC7: FAIL (exit 1)`; restored → `AC7: PASS (exit 0)`.
12. **AC8** — introduced `mapfile -t foo < /dev/null` as a non-comment line appended to `bin/check-handoff.sh` → `AC8: FAIL (exit 1)`; restored → `AC8: PASS (exit 0)`.
13. **AC8** — separately introduced `# mapfile is not used anywhere in this file` as a full-line comment → `AC8: PASS (exit 0)` **(still green — the deliberate scan boundary, reported as such rather than as a defect)**; restored (removed) → `AC8: PASS (exit 0)`.
14. **AC9** — deleted one new fixture's name (`no-active.md` → `no-active-XXX.md`) from `tests/check-handoff/run.sh` → `AC9: FAIL (exit 1)`; restored → `AC9: PASS (exit 0)`.
15. **AC10** — pointed the `bin/check-handoff.sh:<start>-<end>` reference in `bin/check-board-headings.sh` at `1-2` (a range with no `in_active`) → `AC10: FAIL (exit 1)`; restored → `AC10: PASS (exit 0)`.
16. **AC10** — separately appended an unrelated comment line to `bin/check-board-headings.sh` → `AC10: FAIL (exit 1)` (the at-most-two-differing-lines clause); restored → `AC10: PASS (exit 0)`.
17. **AC11** — added an untracked stray file (`stray-file.txt`) at the scratch worktree root → `AC11: FAIL (exit 1)`; removed → `AC11: PASS (exit 0)`.

(The spec's own AC14(a) prose enumerates these same seventeen mutations
across eleven distinct AC labels — AC1 through AC11 excluding AC12/AC13,
which this item's own text does not name — in this same order; none were
skipped.)

### (b) The profile's own method

Two whole-input passes, timed separately by wrapping each stage's
**unmodified** code in bash's own `time` reserved word (`TIMEFORMAT='%R'`,
plain wall-clock seconds) — never by altering logic to measure it. Held
constant across the before/after comparison for a given input: the input
file's own bytes (read once per arm from the same on-disk file) and the
locale (`LC_ALL=C` primary, `LC_ALL=en_US.UTF-8` as a stated cross-check).
Three trials per cell; the **median** of three is what is recorded (stated
explicitly in `## Measurement protocol`'s `- condition: trials` line). Both
arms of every before/after pair read the identical bytes by construction:
each synthetic board is generated once and reused unmodified for both the
branch-point script and the working-tree script; the real board is pinned
via `git show <branch-point>:<path> > scratch/realboard-base.md` once and
that one file is fed to both scripts. The `bash_loop` stage is timed fed
from the `awk_extract` stage's own captured output (`active_block`), so no
extraction cost leaks into the loop's own number.

### (c) Full CI-wired step list, run locally in workflow order

`.github/workflows/check-handoff.yml` carries 71 named steps. Two are not
applicable to a local run, named individually with their reason: **`Checkout`**
(this is already a checkout of the repository; there is nothing to check
out) and **`Install shellcheck (pinned — must match local dev version)`**
(shellcheck 0.11.0 is already present on this host and version-verified —
`shellcheck --version` reports `0.11.0`, matching the workflow's own
`SHELLCHECK_VERSION` pin — so the install step's own effect already holds).
The remaining 69 were run directly, strictly sequentially (no suite started
before the previous one exited), in the workflow's own order:

1. shellcheck (full list, the workflow's own single physical shellcheck line) — PASS
2. Lint the shipped board template (hand-off linter) — PASS
3. Dogfood check-handoff — this repository's own board — PASS
4. Run check-handoff fixture suite — PASS
5. Lint the shipped shell-team loop contract — PASS
6. Lint the shipped generic loop-contract template — PASS
7. Lint the shipped goal loop contract — PASS
8. Run check-contract fixture suite — PASS
9. Run loop-guard fixture suite — PASS
10. Run check-run fixture suite — PASS
11. Run log-run resolution suite — PASS
12. Run team-init fixture suite — PASS
13. Run discover-work fixture suite — PASS
14. Run check-acs fixture suite — PASS
15. Run check-design-note fixture suite — PASS
16. Run goal-state fixture suite — PASS
17. Run rework-digest fixture suite — PASS
18. Run check-retro fixture suite — PASS
19. Run retro-inputs fixture suite — PASS
20. Run retro-inputs bounded invariants lock — PASS
21. Dogfood retro-inputs — the cycle window resolves against this repository — PASS
22. Dogfood check-retro — this repository's own retros pass the ledger contract — PASS
23. Dogfood check-retro — the shipped retro template passes its own contract — PASS
24. Run machine-tokens fixture suite — PASS
25. Run gen-loop-replay fixture suite — PASS
26. Run check-readme-version fixture suite — PASS
27. Dogfood check-readme-version on the repo's READMEs — PASS
28. Run rollup-runs fixture suite — PASS
29. Run rollup-track fixture suite — PASS
30. Run consolidate-proposals fixture suite — PASS
31. Run cluster-failures fixture suite — PASS
32. Run is-span-row-parity fixture suite — PASS
33. Run review-gate fixture suite — PASS
34. Run close-out fixture suite — PASS
35. Run check-prompt-sync fixture suite — PASS
36. Dogfood check-prompt-sync — this repo's prompt blocks must be in sync — PASS
37. Run check-playbook fixture suite — PASS
38. Run gen-playbook-blocks fixture suite — PASS
39. Run playbook-promote fixture suite — PASS
40. Dogfood check-playbook — the real repository corpus at the resolved lessons path is schema-valid — PASS
41. Dogfood gen-playbook-blocks — regenerating into a scratch copy reproduces every shipped block and consumer — PASS
42. Run team-paths fixture suite — PASS
43. Dogfood team-paths — a repo with no legacy markers resolves to the default layout — PASS
44. Run install fixture suite — PASS
45. Run check-intent fixture suite — PASS
46. Run check-provenance fixture suite — PASS
47. Run check-interventions fixture suite — PASS
48. Run interventions-reminder fixture suite — PASS
49. Dogfood check-interventions — every committed interventions file in this repository is conformant — PASS
50. Run check-board-headings fixture suite — PASS
51. Run errexit-safe regression suite — PASS
52. Run codex-skeleton-hygiene suite — PASS
53. Run check-pii-shapes fixture suite — PASS
54. check-pii-shapes on the PR diff (adapted: compared against this task's own branch point, `chore/lesson-promotion-2026-08-15`'s tip, rather than `origin/develop` — this branch is stacked and not yet merged into `develop`, so a `develop`-based diff would also pick up the earlier stacked cars' own changes; the real CI run, once this PR's base is reached, compares against `origin/develop` as written) — PASS
55. Run check-commit-identity fixture suite — PASS
56. Run gitignore-raw-dumps lock suite — PASS
57. check-commit-identity on the PR commits (same branch-point adaptation as row 54) — PASS
58. Run check-refreeze-class fixture suite — PASS
59. Run bin-exec-bit lock suite — PASS
60. Run check-durability fixture suite — PASS
61. Dogfood check-durability — this repository's own T-1048 implement-phase records — PASS
62. Run check-binding fixture suite — PASS
63. Dogfood check-binding — the shipped binding-config specimen validates — PASS
64. Run check-adapter fixture suite — PASS
65. Dogfood check-adapter — the shipped contract and definitions validate — PASS
66. Run check-liveness fixture suite — PASS
67. Dogfood check-liveness — the real classifier's --help — PASS
68. Run resolve-executor fixture suite — PASS
69. Dogfood resolve-executor — probe-free mode against this repository (the runner carries neither executor CLI) — PASS

`grep -c '^RESULT: PASS'` on this run's own log = 69; `grep -c '^RESULT: FAIL'` = 0.

### (d) `## Blast radius` production, narrated

Already committed in the spec itself (`.shell-team/specs/T-1070-check-handoff-scaling.md`'s `## Blast radius` section, outside the frozen intent block) — not duplicated here to avoid two sources of truth for the same figures. In summary: population enumerated with `git ls-tree -r --name-only "$(git merge-base chore/lesson-promotion-2026-08-15 HEAD)" -- .shell-team/specs | grep '\.md$'` = 74; every criterion of 45 of those 74 specs was run once against a `git worktree add --detach` at the branch point (reading that ref's committed blobs) and once at `HEAD`, sequentially; two genuine flips found (`T-1019-is-span-row-parity.md` AC10, `T-1020-lessons-supersede-sweep.md` AC14, both `base: PASS → head: FAIL`, both whole-`bin/`-tree preservation locks this task's own in-scope `bin/` edit necessarily breaks); the remaining 29 population specs are named individually as unmeasured in that same section, per this item's own license ("any spec not run at both refs named individually as unmeasured").

### (e) Measured 40-hex values

- `git merge-base chore/lesson-promotion-2026-08-15 HEAD` = `aa28e9a36f8e0ced94f0533b6e4443471283c820`
- `git rev-parse chore/lesson-promotion-2026-08-15` = `aa28e9a36f8e0ced94f0533b6e4443471283c820` (identical to the merge-base — this branch's point of divergence is that branch's own tip)
- `git rev-parse develop` = `627a90259a1c878f3c57b8591c2733db7eb7c622`
- Branch-point-vs-`develop` inequality this stacked premise rests on: `aa28e9a36f8e0ced94f0533b6e4443471283c820` ≠ `627a90259a1c878f3c57b8591c2733db7eb7c622` — confirmed unequal, satisfying AC11's own premise check.
- `git branch --show-current` = `feature/1070-check-handoff-performance`

### (f) Every `## Assumptions` bullet, re-measured and reported individually

The spec carries seven `## Assumptions` bullets. Each is addressed below by
its own number, in the spec's own order.

1. **RELAYED — issue #269's contents.** Re-fetched directly by this role via `https://api.github.com/repos/RipsawJP/shell-team/issues/269` (a public, unauthenticated GET — `api.github.com` is on this environment's network allow-list) rather than left relayed. Title: "check-handoff.sh runs ~122s against a 2.6MB board — approaching harness timeouts." Body (verbatim): "Fast-follow from T-1065 QA round 5 (2026-08-14); filed only, not acted on this sprint. ## Measured `bash bin/check-handoff.sh .shell-team/todo.md` took ~122 seconds against this repository's own board at 2637 lines / 2.6MB (QA round-5 record on the T-1065 board entry). The coordinating session independently hit a 120s default Bash timeout on a command chain that included the same check. Not a correctness defect — the checker returns the right verdict — but it now sits at the edge of common harness timeouts, and every loop phase (freeze, seam gates, QA, close-out) runs it at least once, so the cost multiplies per task. ## Likely shape The board grows monotonically under append-only records discipline, and this sprint's stacked train adds several long per-round record sub-bullets per task. Options for the implementing task to weigh: - Profile the checker (likely per-line subshell/grep patterns that go quadratic with board size) and make it single-pass. - And/or an archival convention: move `## Done` entries older than N sprints to a `todo-archive.md` the checker skips (needs care — several merged criteria and retro procedures read board history). Interacts with #268 (both concern record-layer scale as the board corpus grows). Evidence: `.shell-team/todo.md` T-1065 entry, QA round-5 record (\"took ~122s against the board's current 2637 lines\")." One comment on the issue (root-cause note, quoted in full under bullet 2 below since it is the source of the "confirmed" verdict this task's own `- diagnosis:` line reaches). This confirms the relayed ≈122s/2637-line/2.6MB figures exactly; no criterion in this task depends on any of them.
2. **RELAYED — issue #256's contents and its status as a root-cause candidate.** Re-fetched via `https://api.github.com/repos/RipsawJP/shell-team/issues/256`. Title: "check-handoff.sh: per-line blank-line normalization goes quadratic on long multibyte board lines (measured 2.5 min under macOS bash 3.2)." Body (verbatim): "Found operationally during T-1062's close-out (2026-08-13); filed as a fast-follow, not touched in sprint v2.0.1. **The symptom.** `bash bin/check-handoff.sh .shell-team/todo.md` took **147 s wall / 138 s user CPU** (previously: seconds) once the board's T-1062 entry carried its full freeze ledger. Verified by `bash -x` trace: the time is spent in the per-line loop, dominated by the blank-line test `[[ -z \"${content//[[:space:]]/}\"]]` — bash's pattern substitution over a long line is superlinear, and severely so for multibyte content under macOS's `/bin/bash` 3.2.57 (arm64). The board lines that trigger it are the ones this repository's own record formats guarantee: `- refreeze-class` sub-bullets carry the superseded and replacement check lines verbatim (`old[i]:`/`new[i]:` pairs), producing single lines of 5–6 KB dense with em-dashes and arrows; T-1062's entry carries two of them plus several 2 KB sweep narratives. **Why it matters.** check-handoff runs at every hand-off gate, in CI, and inside QA/review rounds — a per-run 2.5-minute floor on the very boards that used the freeze machinery most is a tax on exactly the audit trail the loop is proudest of. (`bin/close-out.sh` is unaffected: it lints synthesized single-entry boards, measured 0.77 s for the same entry.) **Unmeasured:** the same board under CI's Ubuntu bash 5.x — likely much less severe (bash 5 improved substitution performance), but unverified; CI durations for PR #255 are the ready data point. **Fix candidates (any one is a small, behavior-preserving patch):** 1. Replace the blank test with a linear regex scan: `[[ ! \"$content\" =~ [^[:space:]] ]]` — same truth table, no substitution. 2. Reorder the loop: classify continuation lines first (`CONTINUATION_RE`, a cheap anchored regex) and only apply the blank test to what remains — the giant lines are all continuations and would skip the hot path entirely. 3. Both. Whichever lands must keep the checker fail-closed and shellcheck-clean, and `tests/` already covers the blank/continuation semantics the patch must preserve. Origin: T-1062 close-out, `time` measurement `138.67s user 0.45s system 94% cpu 2:27.42 total` against board state `1e40af9`; trace evidence in the session record." This is the specific attribution AC1's `- diagnosis: issue_256_quadratic_blank_check confirmed` line settles — confirmed exactly as this issue describes (the blank test, not the CR strip or the anchored regex matches, is the quadratic term), via this task's own isolated micro-benchmark (see `## Profile` above), independent of reading the issue's own suggested fix, which happens to match option 1 this task implemented.
3. **RELAYED — the board's live size today.** Re-measured: `bash bin/team-paths.sh --get todo` resolves `.shell-team/todo.md`; `wc -l`/`wc -c` on it now (post this task's own board edits) report 2,809 lines / 2,897,611 bytes. The branch-point committed blob (the snapshot every criterion in this task actually reads) is 2,793 lines / 2,884,750 bytes — both distinct from issue #269's relayed 2,637 lines / 2.6MB, confirming the board has kept growing since that issue was filed, exactly as the two-axis model predicts.
4. **MEASURED at authoring time — `## Active`'s pre-entry span.** Re-confirmed against the branch-point committed blob: `## Active` spanned lines 13–20 (8 lines) and held no task entry, only two leftover `### Local test result` blocks — matches the spec's own authored figure exactly.
5. **MEASURED at authoring time — the consumer inventory.** Re-derived in `## Consumers` above: 25 files / 144 occurrences (`git grep -c -e check-handoff <branch-point> -- bin tests`), matching the spec's own corrected figure exactly (not the Routing Map's relayed 16-files/112-occurrences, which was the `tests/`-only half).
6. **RELAYED — the branch point's 40-hex value and this task's stacked-train position.** Measured in item (e) above: `aa28e9a36f8e0ced94f0533b6e4443471283c820`, identical to `chore/lesson-promotion-2026-08-15`'s own tip, distinct from `develop`'s `627a90259a1c878f3c57b8591c2733db7eb7c622`.
7. **RELAYED — the existence of the orchestrator-owned `.shell-team/interventions/T-1070.md`.** Confirmed present and conformant: `bash bin/check-interventions.sh --task T-1070 -- .shell-team/interventions/T-1070.md` → `check-interventions: conformant: .shell-team/interventions/T-1070.md (2 entries, 0 sentinel)`; file untouched by this role throughout (confirmed via `git status --short .shell-team/interventions/T-1070.md`, empty).

The eighth bullet ("ASSUMED, stated as unverified — bash 5 / UTF-8 locale
availability") is not itself relayed, so it is not re-derived here; its
outcome is what `## Measurement protocol`'s `- condition: bash_version` and
`- condition: locale` lines already state — a bash 5 build was not
reachable (bash 4.4.0 was built instead, disclosed rather than
papered over), and a UTF-8 locale (`en_US.UTF-8`) was available and used.

### (g) Per-source report — every `## Summarized sources` entry

The spec carries eleven `## Summarized sources` bullets (ten named
artifacts plus one combined relayed-issues bullet). Each is addressed below.

1. **`bin/check-handoff.sh`** — opened and read end to end (both before and after editing it). Confirmed: the two whole-input passes (awk extraction, bash loop) at the then-current 53–57/127–177 line ranges; the exit-2/exit-1/exit-0 contract; the three grammar constants and `ALLOWED_FLAGS`; the `!seen` single-open-only guard; the blank test / CR strip / two splits as per-line operations. Nothing contradicted.
2. **`bin/close-out.sh` lines 337–417`** — opened and read first-hand (lines 330–419 read in this task's own session). Confirmed: the three-outcome discrimination (exit 0/1/2), the verbatim-stderr-then-reason-line order, the fail-closed `die` at line 378 (unchanged — verified present at the same line number after this task's diff, since this task never touches `bin/close-out.sh`), and the two invocations at (then) lines 357/414. Nothing contradicted.
3. **`bin/check-board-headings.sh` lines 159–173`** — opened and read first-hand, and edited (the one permitted comment line). Confirmed: the stale `47-51` reference (verified stale — those lines were the tail of `flag_allowed()` and two comments, not the section-tracking awk) and the single occurrence of the `check-handoff\.sh:[0-9]+-[0-9]+` pattern under `bin/` (re-confirmed after the fix: `grep -rn 'check-handoff\.sh:[0-9]\+-[0-9]\+' bin/` → exactly one hit, now `65-69`). Nothing contradicted; this task's repair is exactly what the source distinction called for.
4. **`tests/errexit-safe/run.sh` lines 329–365`** — opened and read first-hand. Confirmed: the `NOT_APPLY` registry pins the two named `printf` lines by exact content with a declared count of 1 each (re-confirmed post-fix: both lines survive byte-identical, both counts still 1, via the suite's own green run and AC5's live check). Nothing contradicted.
5. **`tests/check-handoff/run.sh` and `tests/check-handoff/fixtures/`** — opened and read first-hand, and extended. Confirmed: 11 committed fixtures pre-task (now 17, the 6 new section-structure ones added); the corpus covered grammar shapes exhaustively and section-structure shapes not at all before this task (confirmed by inspection — no pre-existing fixture omitted `## Active`, ended inside it, repeated it, or placed it last); `valid.md`'s own line numbers (`## Active` at line 7, `## Done` at line 19) unchanged, still used as the base for AC4's generated corpora. Nothing contradicted.
6. **`.github/workflows/check-handoff.yml`** — opened and read first-hand, and executed in full (item (c) above). Confirmed: one physical shellcheck line already naming `bin/check-handoff.sh` and `tests/check-handoff/run.sh` first; the double invocation (once on `templates/todo-template.md`, once as a dogfood step on the resolved real board); byte-identical to its branch-point blob throughout this task (`cmp -s` in AC9's own check, PASS). Nothing contradicted.
7. **`templates/todo-template.md`** — opened and read first-hand. Confirmed: `## Active` holds only `_(none)_`; `## Format` sits after `## Done`; its fenced `- [ ] **T-XXX** …` example is outside `## Active` and untouched by any traversal change (confirmed: `bash bin/check-handoff.sh templates/todo-template.md` still exits 0 post-fix). Nothing contradicted.
8. **`.shell-team/todo.md`** — opened and read first-hand, both at the branch-point blob and live today. Confirmed: the pre-entry `## Active` span (item (f)4 above); `###` sub-headings do not close a `## ` section (unchanged behavior, still relied on by this task's own board entries sitting inside `## Active`); the T-1068 entry's prior measurements (14.95s/2.08s, the 5,008-byte line, ≈12.3s isolation) read directly from the board rather than relayed. Nothing contradicted.
9. **`.shell-team/lessons.md`** — opened and read first-hand. Confirmed both cited 2026-08-15 entries exist verbatim: "A checker's runtime cost is recorded only from a measurement whose locale and input size are stated" (its re-evaluation trigger names issue #269 explicitly: "Issue #269 tracks the locale/content-length root cause; re-price or retire this entry when that lands") and "A completeness claim is written only as the extraction command plus its pasted output." Finding for retro's awareness (not a criterion, not fixed here): this task's own landing is the named re-evaluation trigger for the first entry — a candidate for the next lessons-promotion round to retire or re-price, not something this engineer edits unilaterally.
10. **`bin/check-acs.sh`** — opened and read first-hand (and relied on throughout — every AC verdict and every mutation probe in this task ran through it). Confirmed: `timeout ${CHECK_ACS_TIMEOUT:-120}` applied only when `command -v timeout` resolves (confirmed absent on this host: `command -v timeout` exits 1); `AC_RE` matches only the first `- check:` line per criterion; `--root <dir>` reruns each `check:` command from that directory (used for all seventeen mutation probes in item (a)). Nothing contradicted.
11. **Issue #269 (primary) and issue #256 (root-cause candidate) — RELAYED** — both re-fetched directly by this role during this rework round (item (f)1–2 above quotes both in full); no longer relayed as of this record, though neither issue's figures are used by any criterion, exactly as the spec states.

### (h) Execution-context matrix

The one shipped, adopter-facing command this task's records point a reader
at is `bin/check-handoff.sh <board-path>`. Verified in both contexts:

| context | invocation | result |
|---|---|---|
| checkout root, plugin not on `PATH` | `bash bin/check-handoff.sh tests/check-handoff/fixtures/valid.md` | exit 0, empty stdout/stderr |
| adopter-shaped repo, plugin loaded (`bin/` on `PATH`, bare name) | `check-handoff.sh tests/check-handoff/fixtures/valid.md` | exit 0, empty stdout/stderr — byte-identical to the row above |

Every other command this note quotes (`git show <ref>:<path>`, `git
ls-tree`, `wc -c`/`wc -l`, the `awk` board-splicing/generation commands, the
Python measurement one-liners) is an ad hoc measurement or fixture-
construction command produced for this task's own analysis, not a command
any reader — adopter or otherwise — is told to run as a standard procedure.
**Not applicable — these are one-off measurement scaffolding, not a shipped
or documented procedure**, so the execution-context matrix does not apply
to them individually; this is stated explicitly rather than the rows being
silently omitted.

### One additional disclosed deviation

The profile note and the two implementation edits (the awk early-exit, the
blank-test regex) landed in a single commit (`1697099`) rather than two
separate commits, even though the spec's Notes for engineer phrase the
order as "profile first, and commit the profile before writing any
implementation change." The **work order** was followed exactly as written
— the before-arm profile numbers in `## Profile` above were all measured
against the unmodified branch-point script, before either implementation
edit was made, using a separate instrumented scratch copy outside
`bin/check-handoff.sh` itself — but the **commit** boundary was not split
to mirror it. Disclosed here rather than left implicit; the note's own
before-arm figures are unaffected by this transcription choice either way.
