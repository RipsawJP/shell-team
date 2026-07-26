---
description: Opt-in outer-loop triage — discover failing CI / open PRs / loop-triage issues and PROPOSE them as todo.md candidates in a run file. Read-only; never edits the board (todo.md).
---

You are running the **opt-in triage loop** for this repository. Its job is to
*surface* candidate work and propose it — never to act on it. This is the first
step of the "outer loop": find what the shell-team pipeline might pick up next.

**Step 0 — the paths are resolved by `team-paths.sh`** (this repo's shell-team files
may live under `.shell-team/` (default), a legacy `tasks/` layout, or a
`$TEAM_RUN_BASE` override). `discover-work.sh` self-resolves its board/specs, so
you don't pass them. For any path *you* write or read directly, resolve it **in
the same shell call** with `$(team-paths.sh --get KEY)` (on PATH when the plugin
is loaded; else `bin/team-paths.sh`) — do **not** rely on a previously
`eval`-exported `$TEAM_*`, because env vars do not persist across separate Bash
tool calls.

Contract: `$(team-paths.sh --get loops)/triage.contract.yaml` (TRIGGER=manual, BUDGET caps the
number of candidates, STOP when there is nothing new). You may read it to learn
`budget.max_candidates`.

Do this:

1. **Run the discovery engine** (read-only — it writes nothing):

   ```
   discover-work.sh --max <budget.max_candidates from the contract, default 10>
   ```

   (`discover-work.sh` self-resolves the board for de-dup; no `--todo` needed.)

   It is on PATH when the plugin is loaded; otherwise call `bin/discover-work.sh`.
   Pass `--base <branch>` / `--label <label>` only if the user asked for a
   non-default branch or triage label. The script prints `- [ ] **T-000** ...`
   candidate lines plus `# note:` lines (sources skipped, truncation, etc.).

2. **Capture the proposal to a run file.** Write the candidates **and a short
   rationale per candidate** (which source it came from, why it's worth
   triaging — e.g. "failing CI on develop", "open PR awaiting review", "issue
   tagged for triage") to:

   ```
   $(team-paths.sh --get runs)/triage-<YYYY-MM-DD>.md
   ```
   (resolve the runs dir in the same call — do not rely on an exported `$TEAM_RUNS_DIR`)

   Collision rule: if that file already exists, append a numeric suffix
   (`-2`, `-3`, …) and use the first free slot. **Never overwrite.** Include any
   `# note:` lines from discover-work so skipped sources / truncation are visible.

3. **Never touch the board (`$TEAM_TODO`).** Promotion of a candidate into the
   board is a human / inner-loop decision, not yours. Do not edit the board, do
   not open or close issues, do not push.

4. **Report a hand-off summary**: how many candidates per source, which sources
   were skipped and why (from the notes), and the proposal file path. Remind the
   user that to promote a candidate they copy its line into the board (`$TEAM_TODO`)
   under `## Active`, replace the `T-000` placeholder with the next real task number,
   and write the referenced spec — after which `check-handoff.sh` passes (the
   candidate lines already use the board's grammar).

If discover-work reported that `gh` is missing or unauthenticated, still write
the proposal file (with the note explaining the gap) so the run is recorded —
partial is better than nothing.

Do not hand-build the candidate lines yourself — `discover-work.sh` is the single
deterministic source of discovery (dedup / cap / sanitization) and is covered by
`tests/discover-work/` and CI.
