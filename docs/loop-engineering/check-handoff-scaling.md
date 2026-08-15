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
