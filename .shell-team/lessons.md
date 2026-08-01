# Lessons learned

Append-only log of corrections and validated approaches. Read at session start. Add an entry whenever:

- The user corrects an approach taken ("don't do X")
- The user confirms a non-obvious choice was right ("yes, exactly that")
- A team-workflow misstep was caught downstream (e.g. engineer skipped re-reading the spec and it cost a QA cycle)

## Format

```markdown
## YYYY-MM-DD — <short title>
- **Category**: <small closed taxonomy — process | tooling-ci | security-pii | prompt-injection | path-resolution | sandbox-constraints | verification-discipline>
- **Applies-to**: <comma list from {engineer, qa-verifier, tech-lead, pm-spec, all}>
  (`all` = the four IN roles above, all at once — not a token for a role outside that set)
- **Scope**: <loop | maintainer>
- **Bound-in**: <repository-relative path>
- **Status**: <active | superseded>
- **Source**: <repository-relative path, or "n/a">
- **Rule**: <the takeaway, in one sentence>
- **Why**: <the incident or reasoning that led to it>
- **How to apply**: <where in the workflow this kicks in>
```

The fields above make each entry machine-readable: `bin/check-playbook.sh` validates them, `bin/gen-playbook-blocks.sh` derives the per-role digest blocks (the `Rule` line only, plus a pointer back here) injected into `agents/engineer.md` / `agents/qa-verifier.md` / `agents/tech-lead.md` / `agents/pm-spec.md`, and `bin/playbook-promote.sh` is how a human-approved candidate gets appended. `Why` / `How to apply` stay full prose for a human reading this file directly — they are never injected.

**`Scope` decides whether an entry ships at all, and it has exactly two values.** `loop` means the rule is useful to any repository running this loop, and is what `bin/gen-playbook-blocks.sh` reads into the shipped digest blocks. `maintainer` means the rule is specific to developing this plugin itself and stays in this file, bound to a repository-local file named in `Bound-in` — it is never emitted into a shipped block. Only two of the four possible dispositions a candidate lesson can receive ever become a `Scope` value here: the other two, `operator-global` (knowledge about a tool's own behavior that is useful across any project, not specific to this repository) and `drop` (knowledge tied to a convention this repository no longer uses), never enter this repository at all. Every disposition — including the ones that never enter — is recorded in `docs/loop-engineering/lessons-import-disposition.md`, which is the ledger for both the entries below and for candidates raised in a retro.

Two more field bullets exist outside the fenced example above (kept out of it deliberately, so a naive line-count of a real entry's fields is never thrown off by the illustrative template itself). `**Superseded-by**` is the retirement pointer, written as `- **Superseded-by**: <entry key>`: a `superseded` entry must carry one, naming (by exact `date — title` key) the `active` entry that now covers its ground; an `active` entry must never carry one. `bin/check-playbook.sh` resolves it (equality, not containment) against every OTHER entry's key in this file and rejects a missing pointer, a dangling one, a self-reference, or a chain into another superseded entry. An optional `**Extended by**` bullet, written as `- **Extended by**: <free text>`, may also appear on an `active` entry when its scope was broadened after the fact (`bin/check-playbook.sh` recognizes the field name only — its value is never schema-checked).

---

## 2026-04-29 — Bootstrap
- **Category**: process
- **Applies-to**: tech-lead
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: The reviewer role MUST go through `codex-reviewer` (the Codex CLI), not a Claude sub-agent.
- **Why**: Models from the same family share blind spots; the entire reason this role exists is cross-provider coverage.
- **How to apply**: If the Codex setup step fails, return `BLOCKED` rather than substituting a Claude-only review.

## 2026-06-12 — Review gate caught a regression in practice (cross-provider review vindicated)
- **Category**: verification-discipline
- **Applies-to**: engineer, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: An engineer-caused regression, such as a broken status-flag chain on the board, is exactly the kind of thing the cross-provider review gate is meant to catch. Do not skip or rush past that gate.
- **Why**: During a dogfood run, an engineer corrupted the board's status-flag chain (a missing `READY_FOR_QA`, a duplicated `READY_FOR_REVIEW`). The cross-provider reviewer caught it on the first pass with `REQUEST_CHANGES`, the chain was restored, and the re-review approved. This is a concrete case of the "both QA and the cross-provider review must reach done" rule doing its job.
- **How to apply**: Never skip the cross-provider review round, in a dogfood or a real run. Don't take an engineer's self-reported result (especially a hand-edited board) at face value ahead of that review.

## 2026-06-13 — Codex review runs synchronously (background inside a sub-agent never materializes)
- **Category**: tooling-ci
- **Applies-to**: engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: A Codex-backed review defaults to **synchronous execution**, with the result returned in the final message. If it must run asynchronously, that has to be a top-level backgrounded task the harness itself tracks — never a background process started from inside a sub-agent. Immediately after launching it, confirm a tracked task actually exists; if none does, treat it as never having materialized and re-run it synchronously.
- **Why**: A Codex review was invoked without top-level backgrounding, and the sub-agent reported "started in the background, a notification will follow" after roughly half a minute — but no such process, no event stream, and no notification ever existed. The same invocation run synchronously returned a full review a few minutes later. The harness only tracks and notifies about asynchronous jobs backgrounded at the top level; once a sub-agent returns, any background child process it started (and any notification target) disappears with it.
- **How to apply**: Run the Codex review round synchronously in the review flow. Don't take "a notification will follow" at face value — confirm the job actually exists (a tracked task, a running process, a saved transcript) rather than assuming.

## 2026-06-13 — Release: keep the version of record (`plugin.json`) and the README badge in sync (machine-enforced)
- **Category**: tooling-ci
- **Applies-to**: engineer
- **Scope**: maintainer
- **Bound-in**: CONTRIBUTING.md
- **Status**: active
- **Source**: n/a
- **Rule**: On a version release, update the plugin manifest's `version` field to the new version, and bring every README's static version badge to the same value. A release-time check enforces that the two agree. Always include the manifest bump as an explicit step in the release procedure.
- **Why**: A prior release left the manifest's version unbumped across two point releases, drifting from the README badges, which had themselves briefly been switched to a dynamic badge before being reverted (a private repository's badge host can't render a dynamic badge without authenticated access, so the static badge stays the source of truth here). A git tag isn't a reliable stand-in for either of them, since a shallow checkout in CI may not have the tag fetched.
- **How to apply**: A release pull request must bump the manifest version and update every README's badge together; a mismatch fails the release-time check.

## 2026-06-13 — Don't transcribe real PII values in documents that describe scrubbing PII
- **Category**: security-pii
- **Applies-to**: pm-spec, engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: A document that plans or describes scrubbing personal information (an issue, a pull request, a commit message, a spec) must never contain the **real value** of the thing being scrubbed. Generalize to the *category* of the value (a work email address, a home-directory path) and let the affected file itself be the reference for the real value. This applies with extra force to anything hosted externally, since even a private tracker can become public or get indexed later.
- **Why**: A PII-scrub planning document once transcribed a fragment of the exact email address it was supposed to be scrubbing directly into its own body, re-leaking the very thing it was written to remove. A later review caught it.
- **How to apply**: Write PII-related documents with placeholders (a generic personal-email token, a generic username token), never the real value. After filing, sweep the issue, pull request, and commit messages for a leaked real value before moving on. A mask must be complete, not partial — a value with even part of a username still visible is still a leak.

## 2026-06-14 — Don't mark a runtime user-verify AC done until evidence for its own pass criterion exists (two ACs mis-recorded back to back)
- **Category**: verification-discipline
- **Applies-to**: qa-verifier, engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: Do not mark a runtime, user-verified acceptance criterion done on "it ran" or "the output appeared" alone. Only evidence for that specific criterion's own pass condition — which path was taken, and what the final state actually was — earns the checkmark. Two recurring traps: (1) install/marketplace criteria are not interchangeable just because a generic status line looks similar; a local-path dogfood install and a marketplace install are different mechanisms, and the on-disk configuration (registered marketplaces, installed-plugin records, which source a usage record attributes an invocation to) is the primary evidence, not a UI listing that doesn't distinguish the path. (2) "the command was invoked" is not the same claim as "the criterion's own completion condition (every phase ran, and the board's status flag reached the terminal state) was met" — completion needs its own evidence, not just a launch. (3) An isolation feature (e.g. a worktree) can be confirmed to be honored in both dogfood and installed modes only by repeated, timed polling that actually catches the resource existing and then disappearing — a single after-the-fact check that finds nothing gone is not proof it never existed; it may simply have already been cleaned up.
- **Why**: The same category of mistake happened twice in one review pass. First, a status line showing a plugin as active was recorded as evidence of a marketplace install, when the actual mechanism was a local-path dogfood install with zero trace on disk of a marketplace install ever happening — caught by a follow-up question. Immediately after correcting that, a second criterion was marked complete based on an assumption that installation had already happened (it had not) and without ever having received evidence that all phases completed and the board's flag reached its terminal state — a worktree's output was mistaken for a full, regression-free pass. A pointed follow-up question ("how did you check that criterion if installation never happened?") caught it. Neither runtime action is something that can be executed directly in this environment (no interactive UI, no sandboxed command runner for it) — every runtime criterion depends entirely on evidence supplied from outside, and that should have been assumed from the start. A related trap surfaced the same day: an early conclusion that a private repository categorically cannot be installed via a marketplace was itself an overgeneralization from a single failure, later shown to be wrong once both install paths were demonstrated to succeed once proper repository access was in place — the original failure was an access-state problem for that particular account, not a structural block. A negative conclusion ("X is impossible") deserves exactly the same scrutiny as a premature positive one; both are "asserted without enough evidence," just pointing in opposite directions, and neither should be generalized from one failed attempt. A later, timing-sensitive claim about a resource "not having appeared" the first time it was checked was likewise corrected — continuous polling on a later attempt caught the resource appearing, persisting briefly, and then being cleaned up automatically, meaning the earlier "it never appeared" conclusion had simply been a timing artifact of checking after the window had already closed. That corrected conclusion did turn out to match the underlying mechanism once independently reproduced — but it was asserted with zero supporting evidence at the time, which is the actual defect being recorded, regardless of whether the guess later turned out to be right. Getting the right answer by luck is not the same thing as having verified it.
- **How to apply**: Before checking off a runtime acceptance criterion, ask three questions in order: what exactly is this criterion's own pass condition; has evidence meeting that specific condition actually been received; and does the path that evidence came from match what the criterion requires (e.g. dogfood vs. installed). Don't mistake a displayed status string, or a report that something "was run," for the underlying state. If no evidence has been received, record it explicitly as unverified rather than checking it off. Don't assume an isolation guarantee (like worktree isolation) as a substitute for an actual regression check. Neither a positive assertion nor a negative one should be generalized from a single unverified observation — distinguish "this failed under this specific condition" from "this is categorically impossible," and hold a root-cause explanation as unconfirmed until independent evidence settles it, even if the guess later turns out to have been correct.

## 2026-06-13 — Don't take a Codex inline-paste review's false positive at face value
- **Category**: verification-discipline
- **Applies-to**: engineer, qa-verifier
- **Scope**: loop
- **Status**: superseded
- **Source**: n/a
- **Rule**: When a Codex-backed review's sandbox blocks direct file reads and the diff or source is pasted inline into the prompt for review instead, a HIGH-severity finding about something like "unquoted execution" or an ASCII-vs-full-width character mismatch is often a false positive caused by the paste losing quoting, backslashes, or full-width characters in transit. Don't accept it at face value — verify against the real file with a lint pass, the full test suite, and if needed a byte-level comparison, and don't make a bogus "fix" for a finding that doesn't actually exist in the file. At the same time, treat a real underlying defect (a missing timeout, an unanchored grep, a wrong field order, second-order injection through quoted text) as real and fix it.
- **Why**: Across several review rounds, real files that were shellcheck-clean and passed every test still drew HIGH findings like "unquoted" or "invalid extended regex" on the first pass. In one case a finding claimed a grep used an ASCII parenthesis where the real file used a full-width one — but both the grep and the code it matched used the identical full-width byte, and the full pipeline ran clean end to end, directly disproving the finding. The cause was the paste transport losing information, not a defect in the real file.
- **How to apply**: When a cross-provider review's finding conflicts with the real file's own evidence, treat the real file's lint/test/byte-level result as primary evidence. Push back with that evidence in the next round rather than making a needless change; the goal is still an eventual approval. Fix a genuinely real finding one at a time. This inline-paste workaround was later replaced by a direct-read path, where the reviewer reads the real files itself rather than being handed a pasted excerpt — that change eliminated false positives caused by paste transport loss in later reviews. New reviews should not paste a diff into the prompt; this entry stays as a historical record of why the inline-paste workaround existed and what its failure mode was.
- **Superseded-by**: 2026-06-12 — Review gate caught a regression in practice (cross-provider review vindicated)

## 2026-06-15 — Introducing a configurable base dir needs a full consumer inventory and untrusted-input validation together
- **Category**: path-resolution
- **Applies-to**: engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When generalizing a hardcoded path into a configurable base directory, (1) inventory **every** consumer of that value and bring it into agreement — especially anything that treats the path string as a grammar to check or generate against, such as a linter, a regular expression, or a candidate-path generator. (2) Never trust a base value supplied from the outside (an environment variable, say) without validating it: reject `.`, `..`, an absolute path, an embedded `..` component, `~`, an empty value, and whitespace. Walking the path one component at a time is the reliable way to do this — a single `case` pattern aimed only at a trailing `../` misses a value like `./.`. Put this validation in the resolver (the single source of truth), and have every caller catch the resolver's non-zero exit and fail cleanly rather than swallowing it — a shell construct like `eval "$(...)"` will swallow a die call, so capture the output first and check it explicitly.
- **Why**: Introducing a configurable base directory surfaced two real bug classes in review. First, a value like `.` or `./.` slipped past validation and let a scaffolding step write into the host's root directory, breaking the "never touch the host root" guarantee — a single `*/../*`-style check caught the first form but missed the second. Second, a board linter's regular expression had a legacy path hardcoded into it, so on a repository using the new layout, a spec path written in the new form was rejected by the linter and the phase gate could never advance — a separate path-discovery helper had the identical hardcoded assumption.
- **How to apply**: In a pull request that introduces a configurable path, grep for and checklist every place that reads, writes, or validates the new path — the resolver, other scripts, any skill or agent prompt that names it, CI, a linter's regular expression, template examples, and documentation. Validate an untrusted base by walking its components, with tests for `.`-style, `..`-style, absolute, `~`, and whitespace inputs. Loosen an overly strict path-prefix lock in a linter (accept any well-formed path) or, if keeping it fixed, apply the same choice to every consumer rather than leaving an inconsistent mix. Keep the resolver and the linter's grammar in agreement (if the resolver allows whitespace in a base, the linter must too, or the resolver should reject it instead).

## 2026-06-17 — The board's `- [ ]` lines follow check-handoff's strict format; don't wedge a note between the flag and `— spec:`
- **Category**: process
- **Applies-to**: pm-spec, engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: A board's `- [ ]` task lines in its active-work section are checked by a strict line format: `- [ ] **T-NNN** <title> — `<FLAG>` — spec: <path>.md`. Immediately after the backtick-quoted flag, ` — spec:` must come next — a parenthetical date or round-status note (e.g. "round 2 approved") wedged between the flag and `— spec:` is a format mismatch the hand-off linter (`check-handoff.sh`) rejects. Dated or round-number annotations belong on an indented sub-bullet (outside the linter's reach) or on a line in the completed-work section.
- **Why**: During a pipeline, an active-section entry was written with a status parenthetical squeezed in right after the flag, and the hand-off linter rejected the board on the very next push and pull-request trigger for the same commit — both triggers fired the same rule. That linter ran over the live board automatically in the repository where the incident happened; whether any given repository automates it that way is its own workflow's decision. A codex-reviewer sub-agent had added the parenthetical, and it wasn't removed before the final board edit.
- **How to apply**: After editing an active-section `- [ ]` line, run the hand-off linter locally before committing — `check-handoff.sh <board path>` — whether or not your own automation runs it too. Never put a parenthetical right after the flag. Put completion history, dates, and review-round notes on a sub-bullet or in the completed-work section instead.

## 2026-06-17 — Adding score-driven eval to the self-improvement loop has limited marginal value at this scale
- **Category**: process
- **Applies-to**: tech-lead
- **Scope**: maintainer
- **Bound-in**: CONTRIBUTING.md
- **Status**: active
- **Source**: n/a
- **Rule**: The idea of adding a binary, score-gated evaluation harness to this project's self-improvement loop has limited marginal value here and is not being adopted right now. The deterministic layer (bin/ scripts, scaffolding) is already covered by fixtures, a lint pass, and the acceptance-criteria checker, which is effectively a binary eval already. The non-deterministic layer (the agents) is already served by QA's machine-checked acceptance criteria plus cross-provider review acting as a per-run quasi-eval that catches real regressions (cross-provider review resists a shared bias better than self-evaluation would). The one real gap — detecting quality regression in an agent's prompt over time — doesn't justify a maintained eval-set's fixed cost at this single-task-at-a-time, largely manual throughput, and turning open-ended agent output into a binary score reintroduces subjectivity through a rubric or judge, with its own risk of gaming the metric.
- **Why**: This idea was considered as external input worth weighing against the existing setup. The core mechanism it proposes (a learnings log, a consolidation step, a personal/project split, a retro) is already implemented here, so its novelty is limited to "outside confirmation of a direction already taken."
- **How to apply**: Don't build a full eval harness right now. Instead, use a threshold trigger: once a phase of actively reworking agent prompts begins, consider a lightweight smoke-eval at that point (a known task or two, checked for regression). Keep leaning on the existing quality safety net (the cross-provider review gate) until that threshold is hit. Weigh outside input by its marginal value against the current setup, not by how novel the technique sounds.

## 2026-06-17 — While a spec is still uncommitted on a feature branch, run the engineer step inline instead of in a worktree
- **Category**: process
- **Applies-to**: engineer, tech-lead
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: Starting an isolated engineer sub-agent (one that works in its own worktree) while the spec it needs is still uncommitted on the same feature branch causes the worktree to be cut from the branch's base instead, and it never sees the uncommitted spec or board update. For a single task run end to end on one feature branch (spec, then implementation, then QA, then review), run the engineer step inline in the same checkout instead. A read-only review or QA sub-agent doesn't need a worktree and can still be launched normally.
- **Why**: An engineer worktree was once cut from an old base commit while the spec had just been placed, uncommitted, on the same branch by a preceding step — the engineer sub-agent couldn't see it and the work had to be manually reconciled back onto the main checkout afterward. Running the engineer step inline for every task since has avoided the problem entirely. Worktree isolation exists to prevent multiple agents from writing the same files concurrently; for a single sequential pipeline, the isolation cost outweighs the benefit.
- **How to apply**: A workflow where a higher-level skill itself launches a worktree-isolated engineer sub-agent is fine as-is (in that case the spec is already committed before the engineer step starts). But in a lightweight, hand-driven pipeline connecting a spec-writing step directly to an engineer step, run the engineer step inline. Before starting any isolated sub-agent, confirm what it will actually be able to see.

## 2026-06-17 — A distributed `bin/` script should run relative to the caller's cwd / the adopted repo, not its own install location
- **Category**: path-resolution
- **Applies-to**: engineer
- **Scope**: maintainer
- **Bound-in**: CONTRIBUTING.md
- **Status**: active
- **Source**: n/a
- **Rule**: When a `bin/*.sh` script distributed on `PATH` touches files in the repository it's operating **on**, it must not `cd` into a root directory derived from its own script location (which points at this plugin's own checkout) — it should operate relative to the caller's current working directory (the adopted, target repository), or accept an explicit `--root` flag. Self-hosting this repository's own tooling against its own tree happens to work either way, since cwd and script location coincide there — but once the same binary is invoked against a *different* target repository, deriving the root from the script's own location silently operates on the wrong tree.
- **Why**: A tool in this codebase resolved its own root by walking up from the script's own path (pointing at this plugin's own checkout) and then ran its checks from there — so when invoked against a separate adopted repository, file-existence checks meant for the target repository were silently evaluated against this plugin's own tree instead. It went undetected for a while precisely because self-hosted use from the plugin's own root always happened to line up.
- **How to apply**: When writing or reviewing a distributed `bin/` script that touches an adopted repository's files, ask whether it derives its root from `cwd` or from its own script location. Portability requires keeping "where the binary lives" and "what it operates on" as two separate, deliberately chosen things — never conflated. Testing a script by pointing it at a real, separate adopted repository is what actually catches this class of bug.

## 2026-06-18 — A self-hosted negative `check:` can false-positive on the spec's own mention of the token it forbids
- **Category**: verification-discipline
- **Applies-to**: engineer, pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When an acceptance criterion self-hosts (a spec's own `check:` runs against the repository the spec itself lives in), a negative check for "this string must not appear anywhere in the repository" fails the instant the spec's own body mentions that token as a non-goal or an explanation. Restrict a negative footprint's grep to the operational files it actually concerns (skills, agents, `bin/`, templates), or write a more precise form — "no file of this name exists" plus "no operational code implements the mechanism," which matters more than the tempting shortcut of a blanket repo-wide grep — rather than a whole-repository text search. Let a spec, its docs, or a review freely discuss the design in prose.
- **Why**: A spec's own negative acceptance criterion ("this token must not appear anywhere") failed because the spec's own text discussed the exact token it was declaring out of scope — even after every operational file was reworded to a generic phrasing, the token surviving in the spec's own prose kept the check red, until the criterion was rewritten to check for the absence of a specifically-named file plus the absence of the mechanism in operational code.
- **How to apply**: A `check:` meant to verify "we do not use X" should not be a bare whole-repository grep. Scope it to the directories that would actually implement the mechanism if it existed. A positive existence grep is safe to self-host; a negative-absence grep is the one to watch for self-reference.

## 2026-06-18 — CI's shellcheck is older than the local one and flags info-level issues as failures; avoid the "A-and-B-or-C" idiom in test scripts
- **Category**: tooling-ci
- **Applies-to**: engineer
- **Scope**: maintainer
- **Bound-in**: CONTRIBUTING.md
- **Status**: active
- **Source**: n/a
- **Rule**: In a `tests/*/run.sh`-style shell script, don't write the `cmd && fail "..." || true` (or `[ ... ] && [ ... ] || fail`) idiom — "A && B || C" is not an if-then-else. Write it as an `if` statement instead (`if cmd; then fail "..."; fi` / `if [ ! ... ] || [ ! ... ]; then fail; fi`). The shellcheck rule flagging this idiom is only an info-level finding, but this repository's CI installs an older shellcheck than what a contributor may have locally, and that older version turns even an info-level finding into a failing exit code for the whole shellcheck step.
- **Why**: A test script used the `grep -qF '...' "$OUT" && fail "..." || true` shape in three places. The locally-installed, newer shellcheck version did not flag it at all, but the exact same shellcheck rule fired under CI's older, package-manager-installed version and failed the shellcheck CI step — even though every other step was green locally. The cause was purely a shellcheck version difference between the local environment and CI's.
- **How to apply**: Write a negative test assertion ("if grep matches, fail") as an `if` statement from the start. Treat any `&& ... || true`-style construct used to dodge `errexit` the same way. Before committing, grep the test suites for the "&&" ... "||" idiom to catch any that remain. Assume "green locally" does not imply "green in CI" for this class of shellcheck finding, and avoid the idiom rather than relying on a local shellcheck version to catch it.

## 2026-07-12 — Cross-cutting-discipline ACs must specify the mechanism, not just the outcome
- **Category**: process
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: For a cross-cutting-discipline task (one discipline applied across many sites), the spec's acceptance criteria must specify not just the outcome but the mechanism: a full inventory of applicable sites, a requirement that every site is covered, and (for tasks with parallel implementations) a per-fix mirrored-application checklist between the parallel surfaces.
- **Why**: An external trial of this same team-run process on an unrelated visual clean-up task went through five rework rounds where almost every finding was a variation of the same single root-cause discipline gap, missed at a different site each round, yet the coordinator kept asking for "fix the N reported instances" instead of a class-level sweep. A retrospective estimated most of those cycles were compressible had the spec required an up-front inventory, full coverage, and a mirrored-application checklist.
- **How to apply**: When drafting an AC for a task where one discipline must be applied across many sites (or replicated identically across several parallel output surfaces), phrase it to require a full inventory of applicable sites, explicit coverage of all of them, and a mirrored-application checklist across parallel surfaces — not just a statement that the discipline is applied.

## 2026-07-12 — Regression fixtures must cross the boundary and assertions must check final state, not that the mechanism fired
- **Category**: verification-discipline
- **Applies-to**: engineer, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: Regression fixtures must include values that cross the boundary (a fixture that "just barely" passes is not sufficient), and assertions must check the final state (the thing that actually ended up correct or contained), not merely that the triggering mechanism fired, in a narrower or reduced form.
- **Why**: In the same external retrospective, rework rounds repeatedly re-broke the same discipline because regression coverage sat right at the edge of the boundary rather than past it, and assertions verified that a fix's trigger ran rather than verifying the resulting state was actually correct — so the underlying gap kept resurfacing under slightly different conditions each round.
- **How to apply**: When adding a regression test for a boundary-condition fix, include at least one fixture value that is past the boundary (not merely at it), and write the assertion against the final observable state the fix is supposed to guarantee, not against an intermediate signal that only shows the mechanism ran.

## 2026-07-12 — Two consecutive rounds of new Blocker/Major findings against a verification subsystem should trigger a redesign, not another patch
- **Category**: process
- **Applies-to**: engineer, tech-lead
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a verification subsystem (part of a parser, state tracker, or validator) draws newly-discovered Blocker or Major findings in two consecutive review rounds, caused by the previous round's own fix, explicitly consider and propose a formal grammar or state-machine redesign of that subsystem before proposing a third round of individual patches.
- **Why**: A fence-tracking mechanism drew new Blocker/Major findings across three consecutive review rounds (a silent-merge bug, then an unterminated-fence/leading-whitespace bypass, then trailing-content misacceptance and an invalid-opener acceptance), and only converged once an ad-hoc line classifier was replaced wholesale with a pair of CommonMark-compliant state-machine functions.
- **How to apply**: When a review record shows a pattern of "new Major findings against the same file or function group in two consecutive rounds," include a general redesign option in the next rework proposal, alongside any point fixes. This sits next to, but is distinct from, the existing rule about two consecutive rounds of the same root cause recurring at *different sites*; this one is about repeated new penetration of the *same* subsystem.

## 2026-07-12 — A "whole artifact exits 0" assertion can false-pass against a stale remote-tracking ref — narrow the assertion instead
- **Category**: verification-discipline
- **Applies-to**: engineer, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a regression test or a `check:` line is expressed as "the whole target spec or artifact exits 0," first check whether any individual acceptance criterion inside that artifact depends on a remote-tracking ref comparison, a network call, or the current time. If it does, rewrite the regression condition to a narrower assertion aimed at the actual property being protected — this is exactly the shape of gap that passed locally but still failed in CI.
- **Why**: A rework round passed entirely locally but failed in CI, because a regression assertion in a checker's own test suite required "the whole spec exits 0," and one of that spec's own acceptance criteria (a release-time gate comparing against a remote branch) happened to pass by coincidence against a stale local remote-tracking ref in a sandbox with no fetch access, while correctly failing against a fresh CI checkout. The fix narrowed the assertion to the two properties actually being protected.
- **How to apply**: Before writing a new regression assertion, grep the target artifact for a remote-ref reference, a three-dot git-diff form, a network command, or a non-deterministic date call. If any is present, verify the fix's correctness by reproducing the CI condition locally (temporarily and safely repointing a local remote-tracking ref, verifying, then restoring it) rather than adopting the "whole artifact exits 0" shape.

## 2026-07-12 — Track whether a newly-written behavioral rule actually got applied, in the retro one or two cycles later
- **Category**: process
- **Applies-to**: tech-lead, engineer, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a behavioral rule (a same-class-N style rule) is written into a skill or agent prompt, check the retro one or two cycles later for actual evidence of it being applied (a review record, a board note), and track whether it stuck.
- **Why**: A same-class rule and detection-lens split were written into two skill files, and the very next cycle's rework recorded that the same-class inventory step had actually been carried out. That is a case of a newly-written rule making it into practice within one cycle, and is a useful sample for measuring whether "writing a lesson down" changes behavior.
- **How to apply**: In a retro's "keep" section, deliberately look for evidence that a recently-introduced behavioral rule was actually applied in the last cycle or two, and record it as a keep if found. If not found, record it in the "problem" section as not yet sticking.

## 2026-07-12 — A parser/consumer task's spec must cite the producer's own contract and require negative ACs plus fixtures
- **Category**: process
- **Applies-to**: pm-spec, engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When writing a spec for a new or extended parser/consumer (code that interprets a text or wire format another component produces), the acceptance criteria must cite the producer side's existing contract (a related spec's non-goals, or the implementation's actual set of possible output values) and require fixtures covering the boundary values and malformed inputs that contract permits.
- **Why**: A cluster-line parsing task took four rounds and three reworks, and every round traced back to a gap that citing an existing, related spec's non-goals (which explicitly declared certain fields free-text) up front would have prevented — including one round where the engineer built a regular expression purely from observed output shapes and, without checking the existing spec, silently re-constrained a value the producer's contract allowed to be free.
- **How to apply**: When writing a spec for a parser/consumer task, name in the acceptance criteria or assumptions that the implementation must read the contract of whatever existing component produces its input (a related spec's non-goals, the producer's actual output logic), and must include fixtures covering the range of values that contract permits. In review, check whether the consumer's validation logic silently narrows the producer's stated freedom, against that existing spec's non-goals.

## 2026-07-12 — Rework instructions should require a batch verification grounded in the input's canonical contract, not a point-fix transcription
- **Category**: process
- **Applies-to**: tech-lead
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a reviewer flags a verification gap (not fail-closed, an unverified shape), the rework instruction relayed to the engineer should not ask only for that one point to be fixed — it should explicitly require the *entire* verification for that same input source to be redesigned as a batch, grounded in the input's canonical contract (an existing related spec's non-goals, the producer's implementation contract), rather than in the shapes actually observed in output so far.
- **Why**: A rework instruction that only addressed the first round's specific finding (adding a missing marker-existence check) led to the same class of gap recurring in the next round (an unverified signature grammar), and the quick patch attempted after that introduced a new regression (a constraint narrower than the producer's actual contract). Only once the instruction explicitly said "ground this in the producer's actual documented contract" did it converge.
- **How to apply**: When relaying review feedback into a rework request, name not just the individual defect but where the verification mechanism's canon should come from (an existing spec's non-goals, or a specific part of the producer's implementation), and ask the engineer to cite that canon explicitly in the rework record.

## 2026-07-12 — Tasks that write or extend a verification mechanism itself run long; thicken the spec review up front
- **Category**: process
- **Applies-to**: tech-lead, pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: A "pure addition, following an existing pattern" task in this loop tends to get approved on the first cross-provider review round, while a task that writes or extends a verification mechanism itself (a parser, validator, or state tracker) tends to need several rounds. Classify a task this way at planning time, and apply spec-review rigor at the higher standard for the latter category as a default.
- **Why**: Several verification-mechanism tasks (a fence-tracking rewrite, an environment-dependent assertion, a cluster-line parser) all needed multiple rounds, while pure-addition, small-scope tasks were consistently approved on the first round — a correlation confirmed again by a third example. A counterexample later showed the axis isn't perfectly predictive on its own: a task that looked like pure wiring on the surface still needed several rounds because it wired into stateful control logic (a completion gate, a no-progress detector, a signature calculation).
- **How to apply**: At planning and spec-writing time, classify a task as "pure addition of an existing pattern" or "a verification mechanism itself, new or extended," and apply the heavier spec-review standard (deeper deliberation, citing the input's canonical contract, requiring negative acceptance criteria) as the default for the latter. When classifying, also separately check whether the task wires into stateful control logic (a completion gate, a no-progress detector, a signature calculation) — if so, treat it as the heavier category even if it otherwise looks like pure addition.

## 2026-07-13 — Environment-dependent bugs in an existing test suite stay unconfirmed until it's actually wired into CI — treat the real CI run as the primary evidence
- **Category**: verification-discipline
- **Applies-to**: pm-spec, engineer, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: A spec for a task that wires an existing test/lint/validation suite into CI for the first time should state in its assumptions that local verification has so far been limited to the developer's own OS and coreutils, and that whether environment-dependent bugs exist remains unconfirmed until CI wiring actually happens — and should treat the real CI result (green or failing) as the primary evidence for the merge decision.
- **Why**: On a task wiring an install test suite into CI for the first time, the engineer, QA, and the first review round all verified only on a single OS family, and nobody independently disproved the spec's own assumption that dual-branch OS handling was already in place. Wiring the suite into CI for the first time caused it to run on a different OS family for the first time ever, and the first CI round immediately caught a non-portable implementation that had gone unnoticed until then.
- **How to apply**: When writing the spec for a task that wires an existing suite into CI for the first time, state this limitation in the assumptions. When implementing or verifying such a suite, if it contains OS-specific branches, state explicitly which OS was used for verification and disclose the resulting scope of coverage. Where practical, prefer verifying across more than one OS locally before relying on CI to be the first place it's exercised.

## 2026-07-13 — Simultaneous edits to a shared board by multiple tasks are prone to heading-replacement accidents — guard with a structural diff against the base
- **Category**: process
- **Applies-to**: pm-spec, tech-lead
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When adding entries for more than one task to a shared board in the same commit, assume the existing format checker does not verify heading-line identity, and before committing, diff the board against its base to check for an unintended heading replacement or deletion — don't treat a cross-provider review's structural confirmation (comparing against the base ref) as a nice-to-have.
- **Why**: Adding one task's board entry once fully replaced an adjacent task's heading line, silently folding that task's own sub-bullets underneath the wrong entry — a real board-corruption bug that the board's own format linter stayed green through. Only the cross-provider review's independent passes caught it, a case where evaluator independence actually mattered.
- **How to apply**: When editing a shared board with more than one task in flight, take the extra step of visually diffing against the base before committing to check for heading-count changes. A permanent, machine-checked heading-identity check has been proposed as a follow-up.

## 2026-07-13 — A release's version bump should update every README variant and run check-readme-version.sh against the full file list before pushing
- **Category**: process
- **Applies-to**: tech-lead
- **Scope**: maintainer
- **Bound-in**: CONTRIBUTING.md
- **Status**: active
- **Source**: n/a
- **Rule**: In a repository where version-carrying files (README badges, release notes) span more than one locale or variant, run the version-badge checker against every variant file explicitly at the moment of the version bump commit, and confirm it exits clean before pushing. Don't rely on CI's after-the-fact dogfood check to catch it.
- **Why**: A release once bumped the primary README but left its localized counterpart on the old version, and CI's dogfood assertion for the version checker caught the mismatch only after the fact, requiring an additional fix-up commit. The verification had only been run against the single primary file.
- **How to apply**: In the release-close-out step's version-bump stage, enumerate every README variant path this repository has and run the version-badge checker against all of them, confirming a clean exit, before pushing.
- **Extended by**: mirrors 2026-06-13 — Release: keep the version of record (`plugin.json`) and the README badge in sync (machine-enforced), which sets the engineer-facing version-of-record and CI-guard principle; this entry sets the tech-lead-facing pre-push execution checklist for a release.

## 2026-07-13 — "Settled, won't revisit" configuration decisions are conditional on a fixed environment — pair them with an explicit re-evaluation trigger
- **Category**: process
- **Applies-to**: tech-lead, pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When settling a "decided, won't revisit" kind of decision (a model-allocation or architecture choice), write down alongside the decision itself which conditions would trigger a re-evaluation (a change in the model or cost environment, an observed quality regression, an observed cost increase). A settlement with no stated trigger stays frozen unconditionally even after the environment changes, and its own staleness becomes undetectable.
- **Why**: A model-tiering design document named four explicit re-evaluation triggers (model-environment change, cost-structure change, observed quality regression, observed cost increase) rather than declaring the allocation an unconditional absolute, and a related decision to defer a promotion was reinterpreted as conditional on those same triggers.
- **How to apply**: When recording a settled configuration decision in a design note or spec, add a "re-evaluation triggers" section right after the decision itself. A settlement with no stated trigger should be treated as provisional, and flagged as such in review.

## 2026-07-13 — Don't punt a gate's judgment to a human — an AI evaluator with grounded context should hold the judgment and escalate only the out-of-distribution cases
- **Category**: process
- **Applies-to**: tech-lead, pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a review gate or self-check is designed so that "a human must read and judge it," and an AI evaluator can directly read and verify the actual diff, contract, or spec within its own reach, that evaluator should hold the judgment itself rather than punt it. Escalation to a human should be reserved for the genuinely out-of-distribution exceptions the AI cannot judge.
- **Why**: A design note observed that the completion gate's safety net against certain failure modes rested on "a specific human continuing to read generated code and re-articulate the judgment criteria every cycle," and proposed moving that weight onto machine-enforced, grounded knowledge plus an independent AI evaluator instead. A later retro's trap review confirmed the orchestration layer already acting on this principle.
- **How to apply**: When designing a new gate or checklist, ask first whether this is something only a human can judge, or something an AI can judge using already-grounded knowledge. If the latter, keep the judgment with the AI evaluator and design an exception path for out-of-distribution cases only.

## 2026-07-13 — Under `pipefail`, piping into `grep -q` can false-fail on SIGPIPE — verify through a temp file instead
- **Category**: tooling-ci
- **Applies-to**: engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: In a shell script running under `pipefail`, don't check "does this pipeline's output contain a pattern" by writing `upstream-command | grep -q PATTERN`. `grep -q` exits on the first match and can send the upstream command a SIGPIPE, which can make the whole pipeline report non-zero even though the match was genuinely true. Redirect the output to a temp file first, then `grep -q` against the file.
- **Why**: A precondition-guard implementation in a git-tracked-artifact generator was explicitly reworked to check through a temp file specifically to avoid this SIGPIPE false-negative under `pipefail`, as part of a review-blocker fix.
- **How to apply**: When writing or reviewing a new or existing `bin/` script's existence-check pipeline under `pipefail`, check whether it has the `| grep -q` shape, and replace it with `cmd > "$tmp"; grep -q PATTERN "$tmp"` where needed.

## 2026-07-13 — A script that produces a git-tracked artifact should carry a PII/secret content guard before it writes
- **Category**: security-pii
- **Applies-to**: engineer, pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: A script that generates an artifact meant to be committed to git should check its own content, immediately before writing, for PII-shaped signatures (email-like tokens, home-directory-style paths) and secret-shaped tokens, and refuse loudly (a non-zero exit, no file written) if any is found.
- **Why**: A script that rolls up tracking data into a committed artifact had a write-time PII content guard added as part of a review-blocker fix, closing off a path where the risk of the artifact's classification could silently be elevated. A follow-up extended the same guard to cover platform-specific path shapes and secret-shaped tokens too. This is distinct from an earlier, related lesson about not transcribing PII into planning documents — this one is about a guard checked at the moment of writing an artifact, not about how a human writes prose.
- **How to apply**: When writing or specifying a new script that produces a git-tracked artifact, default to including a write-time PII/secret content guard as part of the design. An existing content guard implementation in this repository can be used as a reference.

## 2026-07-14 — A protective existence check should treat a dangling symlink as occupied
- **Category**: path-resolution
- **Applies-to**: engineer, pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: An existence check meant to guard against overwriting or write-through should test for a dangling symlink as occupied too, not just a normal existing path.
- **Why**: A plain existence test returns false for a dangling symlink, so a copy-guard mistook the destination as free and was about to write through the symlink to whatever it pointed at, outside the intended base. A cross-provider review reproduced this live and treated it as a host-root invariant violation.
- **How to apply**: When writing a copy or scaffold guard, or when writing an acceptance criterion for "must not overwrite," include a dangling-symlink negative test case.

## 2026-07-14 — A new bin/ script's sibling-resolution code should reuse the repo's existing resolver, not reinvent it
- **Category**: path-resolution
- **Applies-to**: engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a `bin/*.sh` script needs to find a sibling script's path, don't write a fresh `dirname $0`-style resolver — port the repository's existing symlink-safe resolver pattern (already used in several places).
- **Why**: A naive `dirname` of the script's own source path resolves to the symlink's own directory when the script is launched by its bare name through a `PATH` symlink — which fails to find its sibling and breaks the feature outright, and this is the exact way scripts in this repository are normally launched in production. The correct pattern had already been implemented in several other places by the time this bug was hit again for the ninth time, costing an extra review round.
- **How to apply**: The moment a new script needs to reference a sibling, copy the existing resolver block from another script line for line rather than writing a new one.

## 2026-07-14 — A launch-shape-dependent script's fixtures must cover all three invocation forms
- **Category**: verification-discipline
- **Applies-to**: engineer, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: A script whose behavior depends on its executable bit or symlink resolution should have fixtures covering at least three launch shapes: `bash script`, `./script` directly, and a bare name reached through a `PATH` symlink.
- **Why**: A fixture that only tested one launch shape (`bash "$path"`) hid two separate real defects: a missing executable bit and a broken symlink-resolution bug, each caught in a different review round. The test didn't match the way the script is actually launched in production.
- **How to apply**: When writing a fixture for a launch-shape-dependent script, or when reviewing one, cover all three invocation forms.

## 2026-07-14 — Don't use the Grep tool's matching semantics as a stand-in for the runtime grep the implementation actually uses
- **Category**: verification-discipline
- **Applies-to**: pm-spec, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: A grep-based acceptance criterion should be verified by running the real shell grep the implementation actually uses (with its real flags, e.g. a case-insensitive or extended-regex form) against a real fixture, not by relying on an editor-integrated search tool's own (typically case-sensitive) matching semantics as a proxy.
- **Why**: An existing piece of prose happened to match a runtime, case-insensitive grep and produced a false-pass baseline, which an editor-integrated search tool's case-sensitive matching never surfaced — a gap between the search tool's semantics and the runtime's.
- **How to apply**: When drafting or verifying a grep-dependent acceptance criterion, run it as the real shell command against a real fixture rather than trusting an editor search tool's result, and lean toward deterministic, exact-match verification wherever practical.

## 2026-07-14 — A docs/board-only PR still needs a minimal review trace left on the board
- **Category**: process
- **Applies-to**: engineer, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When merging a pull request with no code diff (a documentation or board-only change, such as a release close-out or a closing out a carried-over acceptance criterion) without a dedicated cross-provider review round, record on the board's entry what was independently checked, in two or three concrete lines — don't settle for a label alone (e.g. "closed out the carried-over criterion").
- **Why**: A small, two-file docs/board-only pull request had no dedicated review record, but its board entry recorded three concrete, specific things that were checked (an on-disk cache measurement, which branch an implementation commit landed on, whether a worktree was newly created) — noticeably more traceable than an earlier release pull request in the same cycle that recorded no verification content at all. This good pattern is worth standardizing as the minimum practice for a docs/board-only merge.
- **How to apply**: Immediately before merging a release close-out, a carried-over acceptance criterion's closure, or any other board-hygiene change that skips the cross-provider review pipeline, add two or three concrete lines to the board entry describing what was independently checked (the commands run and the results).

## 2026-07-14 — When acting on a fast-follow, state on the board whether an issue was filed and why (or why not)
- **Category**: process
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a prior task's spec declared, in its non-goals, that some item should be handled as a fast-follow in a separate issue, and a later task picks it up, the board's source line for that later task must explicitly state whether an issue was filed (and if so, referenced) or the item went straight to a spec without one — plus the reasoning, if not filed. A boilerplate phrase like "no separate issue" is not sufficient on its own.
- **Why**: An earlier task's non-goals declared a particular gap as "a fast-follow candidate to be handled in a separate issue," but a following task went straight to a spec and a pull request without going through an issue first. The outcome ended up resolving more than the original gap in one pass, but because the board's source line only had a boilerplate phrase, a later retrospective couldn't tell from the record alone whether the earlier retro's recommended action (filing an issue) had actually happened.
- **How to apply**: When writing a board's source line for a task that originates from a prior spec's declared fast-follow, record in one line: a reference to the originating spec's non-goals, whether an issue was filed (with its reference if so), and if not, the reasoning for skipping it.

## 2026-07-14 — QA on a same-class bulk fix should disclose verification depth per site, not one blanket claim
- **Category**: verification-discipline
- **Applies-to**: qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When QA verifies a task that fixes the same class of issue at multiple sites in one pass, it should record, per site, whether that site was confirmed by a live reproduction against its real destination or by a green test suite plus reading the diff — not use one uniform phrase like "confirmed across all N sites" that papers over a difference in depth. Further, a negative conclusion drawn at one site (real risk is zero, no gap remains, another lock will catch it) must never be generalized to another site without independently trying the same test at that other site too.
- **Why**: A same-class bulk fix across five sites had four confirmed by live reproduction against their real destination, with the fifth explicitly and separately noted as "same implementation, confirmed green in-suite and by reading the diff, individual reproduction skipped" — that explicit disclosure is exactly what let a later retro's audit of unverified self-reports flag that one site mechanically. Without the disclosure, all five sites would have looked equally verified. In a later, unrelated case, a QA judgment that a change was harmless because "another lock will catch it anyway" was overturned twice: once when a reviewer demonstrated a site where inserting the same change outside quoted text in a free-form prompt slipped past every sub-check, and again in a following round where QA itself acknowledged missing the same class of gap.
- **How to apply**: When writing a same-class bulk-fix QA hand-off, map each site to one verification method (live reproduction, or suite-plus-diff) and give a reason for skipping individual reproduction where applicable (identical implementation, shared code path). When concluding that "this variant carries no real risk because some other lock catches it," test that specific claim at every site before extending it — don't extend a conclusion reached at one primary site to a secondary site without testing there too.

## 2026-07-14 — A same-class completeness AC should be a machine-checkable anchor (e.g. a grep count), not a prose claim
- **Category**: verification-discipline
- **Applies-to**: pm-spec, engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: An acceptance criterion asserting "every site of this class was fixed with no omissions" should carry a machine-checkable anchor runnable by the acceptance-criteria checker — a grep count, for instance — rather than a prose claim that only a reviewer's manual recount can confirm.
- **Why**: A criterion phrased as "a guard now exists at all four scripts" was expressed as a grep count as a machine check, and a cross-provider review's adversarial pass was able to independently re-run the same grep and confirm the count matched exactly — a successful example of turning an inventory-scope requirement into an executable check rather than prose, worth reusing on future same-class bulk fixes.
- **How to apply**: When writing a same-class completeness acceptance criterion, use a grep count that can be cross-checked against the canonical inventory's site count (e.g. "the count of matches for this pattern across these files is at least N"), plus a negative grep confirming zero remaining instances where applicable. The engineer should self-verify with the same anchor at implementation time.

## 2026-07-15 — Audit a shared norm across parallel gate surfaces with a symmetry table, not just a diff
- **Category**: process
- **Applies-to**: pm-spec, tech-lead
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a task adds or changes the same norm or discipline across parallel gate surfaces (for example, both QA and the cross-provider review), don't rely on a diff comparison or a site enumeration alone — build a norm-boundary-by-parallel-surface symmetry audit table from the spec stage on, with each cell marked present, mirrored-now, or not-applicable-with-a-reason, and confirm semantic equivalence cell by cell before shipping.
- **Why**: A rework round applied a same-class inventory sweep across sites, but still missed a security/trust-boundary carve-out that existed on one gate surface but not its parallel counterpart, plus a mode-scoped omission — drawing two Blocker findings in the next review round. A follow-up rework introduced a norm-boundary-by-surface symmetry table, which made the asymmetry visible mechanically and converged on the round after that. Confirming a mirrored application by "does the same wording exist" is not enough — it has to be "does the same norm boundary exist, in a form appropriate to each surface's role."
- **How to apply**: When specifying a norm addition or change across parallel surfaces, include a symmetry audit table in the spec itself: rows are norm boundaries, columns are the parallel surfaces, cells are present / mirrored-now / not-applicable (with a required reason for any not-applicable cell, e.g. "this surface has no concept of modes"). Update the table during rework and use it to decide what applies where.

## 2026-07-15 — Verifying a grep/regex invariant needs fixtures that deliberately collide with its own vocabulary
- **Category**: verification-discipline
- **Applies-to**: qa-verifier, engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When verifying a grep/regex-based invariant (a signature check, an anchor, a word boundary, an enum match), synthesize and run negative fixtures made of "legal input that collides with the invariant's own vocabulary" (for example, a legal slug that contains a verdict word as a substring), in addition to the normal-case fixtures.
- **Why**: A legal slug used as a test's own pass-case name defeated a `grep -w` word-boundary check (a hyphen is treated as a word separator) and leaked a false pass, which the cross-provider review caught as a Blocker. This exact input was constructible by QA at the time but hadn't been made into a fixture. A separate retrospective audit that classified every review-driven finding across many rounds found regex/character-class anchoring gaps as the second-largest detectable class, showing this same shape of miss recurring across the project's history.
- **How to apply**: When verifying a grep/regex invariant, mechanically enumerate collision candidates from the target vocabulary (verdict words, enum values, delimiter characters) and turn at least three shapes into fixtures and run them: substring containment, word-boundary evasion (hyphen/underscore), and case variation. The engineer should include the same three shapes in their own self-test at implementation time.

## 2026-07-15 — Classify a post-QA Codex stop by artifact type before treating it as a QA quality problem
- **Category**: process
- **Applies-to**: tech-lead, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When "QA passed but Codex then returned REQUEST_CHANGES" happens, don't immediately read it as a drop in QA quality — first classify the driving findings by artifact type. A finding against a prose-only artifact (an agent prompt, a skill, spec wording, doc consistency) falls squarely outside QA's execution-based detection surface by design and should be treated according to the existing lens split. A finding against an executable artifact (a `bin/` script, for instance) should be judged by whether a concrete reproducible input existed at the time it should have been caught — and only counted as a QA fixture-synthesis gap if one did.
- **Why**: A retrospective audit classified every finding driving a review round's REQUEST_CHANGES across a large sample and found the split between "QA-detectable" and "static-only" was entirely explained by artifact type, not by when in the project's history it happened (prose-only tasks were almost entirely static-only; script tasks were almost entirely QA-detectable). Misapplying the lens-split doctrine to a script task risks excusing a real fixture-coverage gap as "just how it is," while blaming QA for a prose-task finding is structurally unfair. Requiring a concrete, nameable reproduction input as the bar for "QA-detectable" guards against hindsight bias when making that classification.
- **How to apply**: When analyzing a gap between QA and cross-provider review verdicts in a retro or a quality review, first classify each finding by artifact type (prose-only vs. executable), then by whether a concrete reproduction input was constructible at the time (only counted as QA-detectable if one was nameable), and use the QA-detectable class's own findings to decide where fixture-synthesis coverage should be expanded.

## 2026-07-16 — An AC that widens a scope from narrow to broad needs a paired revert-detection regression lock
- **Category**: verification-discipline
- **Applies-to**: pm-spec, engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When writing an acceptance criterion that widens an applicability scope (a gate, an exemption, a class definition) from what it was before, always pair it with a regression-lock acceptance criterion proving that a commit reverting the widening fails the machine check — so a future edit that quietly reverts the widening back to its narrower form is caught, not silently accepted.
- **Why**: A rework round widened an applicability condition from "executable artifact" to a "runnable claim" basis, but the acceptance criteria that resulted only checked the post-widening state, with nothing checking that reverting to the pre-widening wording would fail — a gap the review caught as a Major finding one round later, costing an extra rework round. Confirming both directions with a real commit (the pre-widening state failing, the post-widening state passing) resolved it.
- **How to apply**: When drafting an acceptance criterion that widens an applicability scope in a spec or a rework, pair it from the start with a regression-lock acceptance criterion that fails when reverted to the pre-widening wording or the deleted line. At implementation time, actually measure both sides of the boundary (the reverted commit failing, the current commit passing) and record both results in the hand-off.

## 2026-07-16 — Decide "is this an executable artifact" by whether a canonical command exists, not by file extension
- **Category**: verification-discipline
- **Applies-to**: pm-spec, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When deciding whether a QA or review discipline applies based on "is this an executable artifact," judge by whether a runnable input exists (including a canonical command documented inside a piece of prose) rather than by file extension, executable bit, or whether it's literally a script file.
- **Why**: A cross-provider review found an internal contradiction in an applicability condition restricted to "executable artifact only" — it structurally excluded exactly the class of gap where a canonical command documented in prose was never actually run before being written down. A separate retrospective audit had already classified that exact gap as QA-detectable, on the grounds that the deciding factor for whether verification is needed is the presence of a runnable claim, not the file's category.
- **How to apply**: When specifying the applicability condition for a verification discipline or checklist, and when judging whether an adversarial fixture checklist applies, phrase the test as "does this artifact contain a runnable input (including a canonical command or runbook step documented in prose)?" If excluding by file category, require an explicit reason for the exclusion.

## 2026-07-17 — A term with more than one plausible referent needs a definition table before implementation
- **Category**: verification-discipline
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a spec's normative wording (a rule or a loop-step description) introduces a term with more than one plausible referent (for example, "tier" or "baseline"), place a "term × candidate referent × in/out-of-scope" definition table at the start of the spec before implementation begins.
- **Why**: A spec's ambiguity over what "model tier" referred to (an agent's assigned tier, versus the main session's own runtime tier) and an ambiguous definition of "baseline" drove the same root-cause Major finding across three consecutive review rounds, costing five total rounds, two loop-guard stops, and two user-approved extensions on an otherwise prose-only task. An up-front definition table would likely have prevented it in one round.
- **How to apply**: When a spec's normative wording introduces a term with multiple plausible referents, place a definition table near the top of the spec (before the input-space section), enumerating candidate referents and marking each in or out of scope. Write the normative wording so it reads unambiguously against that table.

## 2026-07-17 — A guard that pattern-matches free-form board text needs a self-referential dogfooding fixture
- **Category**: verification-discipline
- **Applies-to**: pm-spec, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When introducing a guard that pattern-matches free-form board prose (a hand-off narrative), add a "the guard-introducing task's own board entry quotes the guard's anchor string inside its own prose" self-referential dogfooding fixture to the standard set of synthetic fixtures — or run a dry-run pass against the real board as part of QA.
- **Why**: An unanchored grep in a close-out guard produced a real false-positive rejection against the introducing task's own board hand-off prose, which had quoted the guard's anchor string and a related keyword on the same line inside backticks — a bug synthetic fixtures never surfaced, and one that only became visible once run against the real board data belonging to the very task that introduced the guard. A guard-introducing task's own board prose will structurally tend to quote the guard's own vocabulary, so this collision class recurs by construction.
- **How to apply**: When specifying a new board-prose guard, include a self-referential case in the fixture acceptance criteria. When verifying such a guard, in addition to synthetic fixtures, dry-run it against the current branch's real board and confirm it doesn't misfire on the introducing task's own entry.

## 2026-07-19 — When a new subsystem grafted onto stable judgment logic hits two consecutive rounds of independent defects, re-propose splitting it out or deferring it
- **Category**: process
- **Applies-to**: pm-spec, tech-lead
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a rework grafts a newly-added subsystem onto an otherwise stable set of judgments, and that subsystem draws independent new defects in two consecutive rounds, explicitly re-present the option of splitting it out or deferring it to the user before the next round starts — don't wait for a third round.
- **Why**: A ledger tamper-evidence subsystem drew independent defects in every round it existed (a design gap, then a Blocker and a Major, then two Blockers and two Majors), while the other, older judgments stayed clean for five rounds straight. A pre-commitment to split it out was set at one round but its actual execution was delayed until a later round's pile-up of findings, even though the "two consecutive rounds" condition had already been met earlier. This generalizes an existing two-strike protocol from task level to spec level.
- **How to apply**: When setting rework direction, classify each round's findings as coming from an existing, previously-stable judgment or from a newly-added subsystem. If the latter hits two consecutive rounds, include the option to split it out or defer it alongside the rework proposal itself in the escalation (always paired with any request to extend the user's approval for more rounds).

## 2026-07-19 — A same-class bulk-fix inventory claim needs the actual grep command and hit count attached, not just a prose assertion
- **Category**: verification-discipline
- **Applies-to**: pm-spec, engineer, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a same-class bulk-fix inventory (an apply/not-apply table) is produced, attach the actual repository-wide grep command string and its hit count to the hand-off, not just a prose claim of "checked everywhere." QA should independently re-run the same grep to audit completeness.
- **Why**: Even after an engineer reported "the whole scope was inventoried," a reviewer's own repository-wide grep and a cross-provider review's independent pass both caught the same two missed sites — one of which was inside a file already claimed as inventoried. A prose claim of completeness alone does not guarantee it.
- **How to apply**: When building an inventory table (whether as the engineer or as pm-spec), write "grep run: <command> → N hits, all listed in the table" directly under the table. QA should re-run the identical grep during verification and confirm the count matches the table's row count before trusting the apply/not-apply judgment.

## 2026-07-19 — A change to a completion gate's condition count needs an AC covering downstream consumers of the gate's result
- **Category**: verification-discipline
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: superseded
- **Source**: n/a
- **Rule**: When a spec changes the number or composition of a completion gate's conditions, it must mechanically enumerate the downstream logic that consumes the gate's result (a no-progress detector, a signature calculation, a failure-class record, a stop digest) and require an explicit acceptance criterion checking each consuming site.
- **Why**: When a completion gate was expanded from three to four conditions, a no-progress detector's signature-calculation template didn't follow along, collapsing a structural and a drift-detected verdict into the same signature and firing a false no-progress stop — a gap only found in a review's adversarial pass, though the primary spec's own acceptance criteria could have caught it if a downstream-impact check had been included.
- **How to apply**: When deciding a gate definition (adding a layer, changing verdict vocabulary), grep for "who reads this gate's result" (a loop-guard call site, a signature calculation, a digest, a contract comment), confirm apply/not-apply for each site, and turn it into an acceptance criterion.
- **Superseded-by**: 2026-07-26 — A change to a completion gate's condition count needs a contamination check and a sentinel-distinctness AC (supersedes two earlier entries)

## 2026-07-19 — Default a pre-commitment's trigger threshold to the existing "two consecutive rounds"; state the reason if loosening it
- **Category**: process
- **Applies-to**: pm-spec, tech-lead
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When setting a pre-commitment escalation contract's trigger ("after N consecutive rounds of the same-class defect, change the design or split it out"), default the threshold to the existing "two consecutive rounds" convention. If setting a looser threshold (allowing a third round), state the reason explicitly in the spec, board, or review record.
- **Why**: A gate-boundary defect class had already reached two consecutive rounds (a first-round unbounded retry issue, then a second-round issue where the boundary was only prose with no real mechanism), but because the pre-commitment's trigger was set to fire only "if it recurs a third time," it didn't fire until a third round's findings, costing an extra round of rework. This follows the same threshold philosophy as two related existing lessons, applied to the pre-commitment's own configured trigger value.
- **How to apply**: When writing a pre-commitment escalation into a rework digest or an escalation, use "two consecutive rounds of the same class" as the default trigger wording. If a task-specific reason calls for allowing a third round, state that reasoning directly after the pre-commitment wording so it's traceable in review.

## 2026-07-19 — A stateful gate boundary can't be machine-enforced by conversational memory alone
- **Category**: process
- **Applies-to**: pm-spec, tech-lead
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: Enforcing a gate boundary that depends on state carried across multiple invocations (an iteration count, a normalized verdict-hash comparison) purely through prompt wording and an LLM's conversational memory, with no persistent state file, has a structural ceiling that repeated wording fixes will not converge past. When the same class of defect recurs across two consecutive rounds, present the decision point explicitly before a third round of wording fixes: either (a) introduce an explicit persistent-state primitive, or (b) abandon stateful boundary enforcement and replace it with a simple fail-closed-plus-human-escalation form.
- **Why**: A provenance gate's loop-guard boundary produced defects across three consecutive rounds (an unbounded retry, then a boundary statement lacking an actual execution procedure that left an iteration counter stuck at zero under unlimited continuation, then a false no-progress signal from collapsing two values into one and a shared-counter contradiction across mixed sequences) — the cross-provider review's primary and adversarial passes both independently converged on the same root cause: stateful boundary enforcement relying purely on conversational memory, with no machine enforcement. Replacing it with the simple form (fail immediately, escalate to a human) converged on approval the very next round; the full stateful design was carved out as a separate follow-up.
- **How to apply**: When specifying a gate boundary and a requirement appears for "compare against the previous invocation's result" or "count attempts," ask immediately which persistent substrate (a state file, the board, a state-tracking script) that state would live in as the first design decision point. If no such substrate is being introduced, don't attempt the stateful form — choose the simple form instead. This is adjacent to, but distinct from, an existing lesson about redesigning a single-execution text parser as a state machine — that one concerns parsing within one execution; this one concerns the absence of persistent state across multiple invocations.

## 2026-07-19 — A downstream-impact inventory needs a check for other-gate raw output bleeding into a combined value
- **Category**: verification-discipline
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: superseded
- **Source**: n/a
- **Rule**: When writing a downstream-impact inventory for a completion gate's result, enumerate not just which sites consume the result, but also whether a value fed into a combined signature or text field might include another gate's own raw stdout or diagnostic output — a content-level poisoning check, not just a list of consuming sites.
- **Why**: A completion-checker's own diagnostic "running:" line included the literal text of an acceptance criterion's check command, which then bled unconditionally into every tick's signature regardless of the actual result — de-duplicating what should have been distinct signatures. A downstream-impact inventory (site enumeration) had already existed for this spec, but it lacked a content-level audit, so a mere presence lock wasn't enough to prevent it.
- **How to apply**: Add a column to the inventory table for "where the value fed to each consuming site originates, and any path by which another gate's output could leak into it." When reserving a sentinel string, add an acceptance criterion measuring its distinctness against every existing gate's stdout and diagnostic output.
- **Superseded-by**: 2026-07-26 — A change to a completion gate's condition count needs a contamination check and a sentinel-distinctness AC (supersedes two earlier entries)

## 2026-07-20 — An advisory-only evaluation path report should distinguish "the underlying mechanism ran" from "the production-shaped output actually shipped"
- **Category**: verification-discipline
- **Applies-to**: qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When verifying an advisory-only evaluation path (for instance, a drift evaluator), distinguish what was actually exercised ad hoc at the lower layer (the call completing, a read-only guarantee, zero mutation) from whether the agent's own output contract's production-shaped artifact (for instance, a named review-report file) has actually ever been produced. If the latter has never happened, state that explicitly in the hand-off and on the board.
- **Why**: QA completed a real invocation of a drift evaluator on a disposable copy, confirming zero mutation and getting a verdict — but the advisory report file the agent's own output contract required had never once been generated, something a retro later confirmed directly by checking for the file's absence. Conflating "the path ran" with "the production-shaped deliverable shipped" is the same family of risk as overstating a confidence level, and can mislead a later promotion decision.
- **How to apply**: When verifying a task involving an advisory or optional evaluation/reporting path, separate the confirmed layer from the never-yet-exercised layer explicitly in the risk notes. On the first cycle a production-shaped output actually appears, check it once against its output contract (required verdict header, required keys).

## 2026-07-20 — A verification-mechanism pre-commitment should separate its factual trigger condition from its contextual one
- **Category**: process
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When writing a pre-commitment for a verification-mechanism task (a parser, validator, or state tracker), separate its trigger into a factual condition ("the same subsystem drew N consecutive rounds of independent new defects") and a contextual condition ("before starting a third round of rework"), and set a default priority in the spec for the reviewer to use when the two conditions disagree.
- **Why**: A pre-commitment named two subsystems, and both technically met "two consecutive rounds of independent defects" in wording, but the reviewer judged the contextual condition unmet (a third round of rework wasn't actually needed, since the round's new findings were all minor) and decided the carve-out/defer proposal did not need to be re-presented. The decision was recorded with reasoning and caused no real problem, but the pre-commitment's wording had implicitly mixed the factual and contextual conditions, leaving room for the trigger decision to vary by the reviewer's interpretation.
- **How to apply**: When writing a pre-commitment for a verification-mechanism-class spec, state the factual and contextual trigger conditions in separate sentences, and pre-decide in the spec which one takes priority when the factual condition holds but the contextual one doesn't.

## 2026-07-20 — A path-classification AC needs an explicit test case for a same-directory relative link
- **Category**: verification-discipline
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When writing a path-classification acceptance criterion (a carry-out/retain decision, a self-containment grep) whose regular expression requires a literal directory prefix, explicitly include a same-directory relative link (with no prefix at all) as an independent test case and capture target.
- **Why**: An acceptance criterion's regular expression required a literal directory prefix, which structurally placed an entire class of same-directory relative links out of its reach — the check reported green (zero matches) while a real dangling link of exactly that form passed straight through undetected. A green machine check is not protection when the regex's own assumption doesn't match a real shape of the data.
- **How to apply**: When designing an acceptance criterion that classifies or restricts path references, enumerate the ways a link can be written (absolute, repository-root-relative, same-directory-relative, with an anchor) and decide explicitly whether each is captured or excluded. Prefer a regular expression that doesn't depend on a literal prefix (extract the directory segment and check it against an allow-list), and build a representative synthetic probe for each form as a fixture.

## 2026-07-20 — When a dependency graph runs deep by design, default to a categorical summary rather than an enumeration
- **Category**: process
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a disclosure's target dependency graph is known to run deep (for instance, by an intentional dogfood setup), default to a categorical summary statement (the dependency's existence, its impact, and the scope of resolving it) rather than an item-by-item enumeration. If even one round of a fresh audit turns up a newly-found omission from a list, treat that itself as a signal that the list shape is wrong, and switch to a categorical summary the very next round.
- **Why**: A disclosure acceptance criterion about carried CI/test dependencies used an enumeration strategy that failed to converge across three consecutive rounds — a general statement, then a widened list of two workflow steps and three test suites, then four more suites and four more steps independently discovered in the round after that. The enumeration kept losing to each fresh audit, and the shape problem wasn't recognized as a design issue until the third round, costing two extra rework rounds. Removing the enumeration in favor of a categorical rewrite converged.
- **How to apply**: When drafting a disclosure acceptance criterion at spec time, set its verifiable condition as "a categorical summary exists, with a stable anchor phrase" rather than "the enumeration is exhaustive." The summary should state the dependency's existence, that it can't be resolved by a byte copy, and the scope of what would resolve it, without a partial list that falsely implies completeness. If an already-enumerated disclosure turns up a fresh gap during an audit, rewrite it to a categorical summary rather than appending to the list.

## 2026-07-20 — A paraphrase that removes an internal reference must be cross-checked for meaning drift in the surrounding claim
- **Category**: verification-discipline
- **Applies-to**: engineer, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a self-containment scrub or similar rework removes an existing internal link or reference and paraphrases the surrounding text, don't stop at removing the link syntax — check whether the paraphrased surrounding claim (an install possibility, an exclusivity statement, a behavior description) is still semantically equivalent to the original, and cross-check every file where the same kind of paraphrase was made for meaning drift.
- **Why**: A paraphrase that removed an internal cross-reference in one round changed the surrounding claim's meaning across four files, into an incorrect statement that two variants could be installed side by side — directly contradicting a "mutually exclusive install" statement in another document in the very same diff. This misstatement did not exist in the original text; the scrub work itself introduced it. Removing a reference is a rewrite, not a deletion, and a rewrite can inject a factual error.
- **How to apply**: After paraphrasing away a removed reference, grep across every file carrying the same topic for its key phrases (an install-possibility phrase, an exclusivity phrase) and read the replacement claim against a canonical document (like a distribution guide) for consistency. When the same kind of paraphrase touches multiple surfaces (for instance, more than one language, more than one document), sample-compare original versus new meaning on at least a representative set, and add a "semantic equivalence confirmed" column to the mirrored-application checklist.

## 2026-07-21 — A completeness-audit spec must say up front that a static scan can't trace indirect or constructed call paths
- **Category**: verification-discipline
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When specifying a task that claims completeness through an audit or verification, state up front, in the input space's out-of-scope section, that a dependency written through indirection or a constructed call path (something assembled at runtime, like a suite path built from a loop variable) is not something a static grep/regex scan can trace in principle — and delegate the completeness guarantee for that class to empirical/runtime verification instead of static scanning.
- **Why**: A static-scan-based completeness audit of retained-dogfood dependencies closed one round with a widened scan, only to have a second round turn up three more independent findings of the identical class — a non-convergent pattern. The chosen design's completeness guarantee turned out to be a tautology (the acceptance criteria only verified the scan's own output table against itself, never that the scan's output actually equaled the real dependency set), and one real consumer invoked a target through a for-loop variable that a static regex structurally cannot follow. The design premise was abandoned, the scope was narrowed, and the untraceable half was carved into a best-effort audit plus later runtime empirical verification.
- **How to apply**: When specifying an audit/completeness-class task, before setting a grep/regex scan as an acceptance criterion's check, list the classes of dependency a scan cannot trace (indirect calls, variable-expanded paths, runtime-constructed calls) in the input space's out-of-scope section, and design completeness around empirical/runtime verification instead. Two consecutive rounds of non-convergent same-class findings is itself the signal that a static method has hit a principled limit — the third round should change method or narrow scope, not widen the scan again.

## 2026-07-21 — When the same class of norm appears across several canonical files, inventory every occurrence before fixing any of them
- **Category**: process
- **Applies-to**: engineer, pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When the same class of norm or token appears across more than one canonical file (an operative doc and a governing spec, plus a board), don't fix just one — before starting, do a repository-wide grep inventory of every file and every occurrence, and fix them all in one round. A canonical pair is not counted by file boundary alone — prose within a single file that states a discipline, and the concrete code or fenced block that discipline governs, also count as a canonical pair that belongs in the same inventory.
- **Why**: A rework round fixed a `.gitignore` contradiction in an operational checklist alone, while the identical misstatement was left behind in six other spots across the governing spec (its input space, several acceptance criteria, a design-decision section, and its notes), and resurfaced as a same-class Major finding in the very next round. An up-front, cross-file inventory of the checklist plus the spec together would have prevented that extra round.
- **How to apply**: At the start of a rework, once a norm or token is known to appear in more than one canonical file (a checklist, a spec, the board), grep across every canonical file for it, list every occurrence, and fix them in one pass. pm-spec should state explicitly in a rework instruction that the target is every file in the diff's scope, and the engineer should self-inventory before implementing. This extends the existing same-class-2/mirrored-application discipline across file boundaries. When prose changes a discipline, the same hand-off must also update any code block or fence governed by that discipline — detecting a half-updated change needs a structural lock on the code side, not just a presence lock on the prose.
- **Extended by**: a later, related incident in the same file drew two more Major/Blocker findings from an async-execution rewrite: a round's added prose ("run this in one continuous shell") itself became a Major finding two rounds later, and the rework that reversed that prose failed to update the fenced code block to match — leaving an allocation block that only assigned a variable and printed nothing, so a single invocation could no longer observe the path at all.

## 2026-07-21 — Design a complex irreversible procedure as a checklist of safety invariants, not numbered sequential steps
- **Category**: process
- **Applies-to**: pm-spec, engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: Specifying a complex, irreversible procedure as numbered sequential steps with cross-references between them has a structural weakness: inserting a gate or a step partway through makes every later step's numbering go stale, and this defeats convergence. Designing it from the start as an order-independent checklist of safety invariants (each checked for presence, with sequencing decided by prose judgment about before/after relationships) converges more reliably.
- **Why**: An empirical runbook written as six numbered steps drew the same class of finding (stale numbered cross-references — one round's inserted gate caused another round's line-number-based reference to go stale) across three consecutive review rounds and triggered a loop-guard stop. Rewriting it as a checklist of numbered-step-free safety invariants converged the very next round, confirmed mechanically by a grep for step-numbering finding zero occurrences.
- **How to apply**: When specifying a complex, irreversible procedure, avoid numbered sequential steps with cross-references between them — design a checklist of safety invariants each of which can be checked for presence, with ordering decided by prose judgment about before/after relationships rather than a line-number-ordering acceptance criterion. Leave the detailed sequential execution to the session actually carrying it out.

## 2026-07-22 — A text-lock regression AC should be designed around equality, not containment
- **Category**: verification-discipline
- **Applies-to**: pm-spec, engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: A text-lock regression acceptance criterion enforcing "a specific canonical phrase must exist," via grep, should be designed from the start around equality — the extracted segment, once a known fixed wrapper is stripped, must exactly match the canonical phrase — rather than containment (a substring match). A containment approach conflates "the text is present" with "the meaning is actually being asserted," and a negated or historically-contextualized sentence that embeds the phrase can defeat it through a whack-a-mole of patches that never fully closes.
- **Why**: A conditional-check-intent lock drew three consecutive rounds of the same-class review finding (a qualifier-detection false negative) — first a plain substring match, then a negating phrase embedding the canonical text, then a historically-contextualized sentence embedding it again — and a synthesis audit explicitly concluded that a denylist approach cannot close in a finite number of patches. Converting to exact-phrase matching still left containment residue, and the issue was finally resolved by narrowing the threat model rather than patching further.
- **How to apply**: When drafting an acceptance criterion that locks the presence of a canonical phrase, design it around equality (extracted segment minus a known fixed wrapper equals the canonical phrase) as the first choice, not containment. This is adjacent to, but distinct from, an existing lesson about synthesizing vocabulary-collision fixtures for grep/regex invariants — that one is about fixture coverage, this one is about the acceptance criterion's own judgment logic. When a same-class defect recurs two or three rounds running on a verification-mechanism task, present the option of narrowing the threat model to a human before the next patch.

## 2026-07-22 — Ground provenance citations in a durable anchor, not a line number
- **Category**: process
- **Applies-to**: pm-spec, engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: A provenance record's grounding citation should cite a durable anchor inside the target file — a heading, an acceptance-criterion label, a `check:` snippet — rather than a spec's line-number range, which is exactly the kind of citation a later rework or rescope invalidates silently.
- **Why**: A rescope commit inserted roughly forty lines near the front of a spec, silently shifting what four line-number citations in that task's provenance record actually pointed at — the provenance file itself stayed byte-unchanged and its own conformance checker doesn't verify the content at a cited line range, so it stayed reported as conformant while quietly wrong. A cross-provider review caught it as an orthogonal finding. Specs in this project are frequently reworked or rescoped across multiple rounds, with prose commonly inserted early in the document, so a line-number citation can be invalidated wholesale by a single rescope.
- **How to apply**: When writing or updating a provenance grounding entry, avoid line numbers and cite a durable, grep-able anchor instead (a section name, an acceptance-criterion label, an exact quoted snippet). This is the same family of discipline as inserting an edit that preserves its anchor and not inflating confidence wording in a summary — durability and accuracy of a reference.

## 2026-07-22 — A scope-lock allow-list should include a task's required deliverables from the start
- **Category**: process
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When writing a scope-lock allow-list acceptance criterion (a negative-grep check confining a diff to a permitted path list), pre-include, at spec-drafting time, the task's required deliverables — a provenance record and a review record — since these are unconditionally required for the task and will unconditionally appear in the diff, and the files mechanically coupled to what the task edits (test fixtures, CI workflow argument lists, registry-pinned companions), which enter the diff the moment the primary edit lands.
- **Why**: One task needed a rework specifically to add a review record to its allow-list, because a provenance/review record is a deliverable that necessarily enters the diff but got overlooked when the allow-list was first drafted. Two following tasks pre-included these deliverables at drafting time and avoided the churn (with one small gap in one of them closed by an immediate follow-up commit).
- **How to apply**: When writing a scope-lock acceptance criterion, include in the allow-list not only "the files being changed" but "the artifacts this task will unconditionally produce" (a provenance record, a review record, the board). If the engineer notices an allow-list gap during their own first self-verification pass, escalate to pm-spec immediately. Enumerate mechanically-coupled companions at drafting time by mechanical means (grep the primary files' names across tests/, the CI workflow, and any registry files) rather than from memory: in one sprint, two tasks that each missed one companion paid a re-freeze or a failed round for it, while the task that pre-included them absorbed a Major finding without ever touching the frozen scope.

## 2026-07-23 — Before pinning existing logic in CI, estimate whether it's actually buildable
- **Category**: verification-discipline
- **Applies-to**: pm-spec, tech-lead
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When planning to architecturally change a verification mechanism (for example, "pin an existing single-line grep/sed lock through CI"), before implementation begins, explicitly ask two design questions: (1) can this actually be verified in CI without duplicating the production logic, and (2) if the real script has to be run directly, what is the blast radius (the side effects on other, future pull requests)? If the answer to either is "not possible" or "too large," decide the carve-out before implementation, not after.
- **Why**: A plan to pin a GNU-specific behavior lock through an additive CI step was straightforwardly implemented in the first round, but re-implementing the production selector inline for the CI pin turned out to be self-referential (three consecutive rounds of pin-completeness findings), while running the real script directly either broke CI for every future pull request or had to fail open — the design was structurally unbuildable either way. Four rounds were spent before landing on zero CI change (reverting to an existing lock model) and carving the item out to a follow-up task. This difficulty only surfaced after round-one implementation had already begun, not before a pre-commitment tripwire fired.
- **How to apply**: When specifying a task that pins or enforces an existing grep/sed-style lock in CI, evaluate these two design questions explicitly before implementation and record the answers in the spec. When generating the routing map, evaluate up front whether a small script can really close the loop, and propose a carve-out before implementation if it can't.

## 2026-07-24 — Check an error-exit contract against the runtime's own default failure code before designing its regression assertion
- **Category**: verification-discipline
- **Applies-to**: pm-spec, engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: Before designing a regression assertion for an error-exit contract (a die function, an errexit-safe path), first check whether the contracted exit code N matches that language or shell runtime's own default failure fallback value. If it does (for example, bash's `errexit` write-failure fallback is exit 1, and the contract is also exit 1), a behavioral assertion cannot, in principle, tell "the fix is working" apart from "the guard was quietly stripped out" — no matter how precisely targeted, it's structurally vacuous. That class of site should be protected only by static/source-text verification (a grep, a content hash, a protected-substring lock) from the start.
- **Why**: A behavioral test row for several exit-1-contract sites (verified by suppressing stderr) drew the same-class review finding (a vacuous, strawman behavioral assertion) in two consecutive rounds, triggering a spec-level pre-commitment. The root cause was that exit 1 is indistinguishable from errexit's own write-failure fallback — no line reachable by the test could ever tell a real fix apart from no fix at all. The user's chosen direction (drop the behavioral row for exit-1 sites entirely, consolidating on a static layer of a grep plus a content-aware self-audit plus a protected-content lock) converged in one round.
- **How to apply**: When designing a DP for a die/exit-path regression check, first sort target sites by their contracted exit code (a code matching the runtime's own default failure value needs static verification only; a code that doesn't match can be usefully protected by a behavioral row). Apply the same sort when implementing the harness.

## 2026-07-24 — Check a review round's findings for self-consistency before relaying rework instructions
- **Category**: process
- **Applies-to**: tech-lead
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a review round raises more than one finding, and one finding (A) already states a generalizable principle (for example, "a behavioral check on an exit-1 site is vacuous"), check, before relaying the rework instruction for a different finding (B) in that same round, whether B's proposed fix direction contradicts A's principle. If it does, adjust B's instruction to align with A's principle before relaying it.
- **Why**: A review round's Major section stated a general principle ("a behavioral check on an exit-1 site is vacuous, since errexit's own fallback is also exit 1"), while that same round's recommendation for a different finding instructed adding eight more exit-1 behavioral rows — directly contradicting the stated principle, and producing two more strawman findings the following round. The two-consecutive-round pre-commitment did eventually fire correctly, but reflecting the first round's own stated principle back onto the other finding's instruction could have prevented it a round earlier. Since the reviewer itself runs on a separate provider and can't be tuned directly, the practical gate belongs on the side relaying its rework instructions.
- **How to apply**: When translating a cross-provider review's findings into rework instructions, cross-check within the same round whether a general principle stated by one finding conflicts with the fix direction proposed for another. If it does, adjust the instruction to favor the principle, and record that adjustment on the board or in the review record. This is a same-round gate, applied earlier than the existing cross-round same-class detection.

## 2026-07-24 — A validation spec should evaluate at write-time how far its own DP actually reaches an abstract guarantee
- **Category**: verification-discipline
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a hygiene or validation-class spec's problem statement raises an abstract guarantee goal (for instance, "verify beyond a mere exit code"), explicitly evaluate, at spec-writing time, in the input space's reachable/synthetic tables, whether the design's concrete implementation (a shallow proxy, like a first-character check) actually reaches that abstract goal or only approximates it as a shallow proxy.
- **Why**: A design decision for validating captured JSON structure was a shallow "does the first line start with a brace" check, which only shallowly satisfied the problem statement's stated goal of "verification beyond a mere exit code" from the start — but this shortfall wasn't evaluated at spec-writing time, and only surfaced as a Major finding in a later review round, after which it was retroactively added to the non-goals as "identified, deferred."
- **How to apply**: When deciding a spec's DP, classify each DP that raises an abstract guarantee goal as either "full validity" or "shallow proxy" in the input space's reachable/synthetic table. This generalizes an adjacent, earlier lesson about checking an error-exit contract against a runtime's default failure value (foreseeing a vacuous check at design time, before escalation) to validation depth in general.

## 2026-07-24 — A carve-out spec inheriting prior art should freshness-check the paths it cites against the current branch
- **Category**: path-resolution
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When drafting a new spec that inherits prior art (a reverted or superseded spec from an earlier task, or a carve-out's originating issue), freshness-check any file path the inherited material cites against the current branch's real file tree with a grep, rather than trusting the inherited text's own description, before finalizing the spec.
- **Why**: Two acceptance criteria referenced a skill file by a path that had already been renamed in an earlier rebranding commit, predating the spec's own drafting — a stale reference the negative-lock acceptance criteria's own check (a file-not-found result negated) risked passing vacuously, which the engineer caught during implementation and recorded for a human to decide.
- **How to apply**: When drafting a spec that inherits a file-path reference from prior art, grep the current `develop` branch to confirm the path still exists before locking the spec's wording. This sits one step before an existing lesson about preventing vacuous passes in an acceptance criterion's `check:` line — this one is about the freshness of the spec-writing input (the inherited text), that one is about the acceptance criterion's own design.

## 2026-07-25 — A new lock or guard should get a producer-run mutation self-check before its first review round
- **Category**: verification-discipline
- **Applies-to**: engineer, pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When writing a new lock, guard, or check (an acceptance criterion's `check:` line, a test assertion, a golden file, a grep lock), ask before submitting it for cross-provider review, "what mutation would this implementation be blind to," and personally run a mutation self-check (deliberately break it, confirm it fails, restore it, confirm it passes again) before the hand-off.
- **Why**: Across one multi-task cycle, five of seven tasks submitted a lock that looked like it worked but was blind to a specific mutation (a nested-hierarchy blind spot, duplicated logic inside the test rather than the implementation, an unwired golden file, an incomplete partial-match grep, a grep-exit-code confusion causing a fail-open) on the first round, each caught by the cross-provider review and costing a rework round. The mutation self-check itself was always performed correctly once requested during rework — the missing discipline was doing it before submission, not the ability to do it.
- **How to apply**: Include, as a required hand-off item, a recorded mutation FAIL-then-PASS transition for every new lock (don't submit a lock that fails to go red when broken). When drafting a `check:` line, mentally confirm whether the grep/expression actually covers the full target string and returns non-zero on a broken variant. This extends an existing, adjacent lesson about designing shallow-proxy checks and about assertions checking final state — the extension here is moving the timing of the self-check earlier, to before submission.

## 2026-07-25 — Grep a tool-generated file's tail for wrapper residue before committing it
- **Category**: process
- **Applies-to**: pm-spec, engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: After an agent creates or edits a file through a tool call, explicitly grep the artifact's tail for tool-wrapper residue lines (stray closing tags from the tool call) before committing, for example counting the occurrences to confirm zero and reading the tail directly.
- **Why**: A spec file's own tail once had two wrapper-residue lines left in it, and the file — whose whole purpose was to sharpen its own wording — passed straight through QA in that corrupted state and became a Major finding at cross-provider review. No checker, test, or grep lock catches this class, since a file's own structural integrity is outside every lock's concern — only a producer's own self-check stands between it and a shipped defect. A following task avoided it by self-checking on instruction.
- **How to apply**: Any agent that writes or edits a file should check its tail and grep for residue before hand-off, and report the result. Whoever receives a newly-created spec or retro file should run the same grep once before passing it to the next step.

## 2026-07-25 — Editing a file-line-pinned `bin/` script needs an explicit check that cross-suite registries still match
- **Category**: verification-discipline
- **Applies-to**: engineer, qa-verifier
- **Scope**: maintainer
- **Bound-in**: CONTRIBUTING.md
- **Status**: active
- **Source**: n/a
- **Rule**: When a task edits a `bin/` script pinned elsewhere by a `file:line:content` registry (for example, an errexit-safe test suite's not-applicable registry), treat two things as a required check, distinct from that script's own suite passing: (1) confirm with a repository-wide grep whether the edit shifted any pinned line number, and (2) explicitly run the pinning suite (at minimum the errexit-safe suite).
- **Why**: A usage-string rewrite shifted a script's line numbers by several lines, and both the engineer and QA only ran that script's own suite and judged it green — CI then failed because the pinning registry had gone stale, requiring a fix-up commit after an otherwise-approved round. Later tasks made this a standard practice without it ever being written down as an instruction to agents.
- **How to apply**: Before completing an implementation that touches a `bin/` script, include "run every CI-wired suite that could be affected (at minimum errexit-safe)" as a completion checklist item. When a task changes a `bin/` diff, QA should independently confirm the pin registry's line numbers still match (currently, wherever a script is pinned by file and line).

## 2026-07-26 — A task that creates a verification mechanism needs two self-checks: is the method sound, and where is the detector itself blind
- **Category**: verification-discipline
- **Applies-to**: pm-spec, engineer, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: A task creating a verification mechanism itself (a lock, guard, or checker) requires two stages. (1) At the spec stage, before settling on a design decision: ask whether this invariant can only be judged correctly by tracking grammar-level state (quote open/close state, nesting, multi-line structure). If yes, treat a hand-rolled regex/awk scan as having a structural ceiling, and consider using an existing grammar-aware tool (a shell linter, a shell syntax check) as a design decision, recording whether it was adopted and why. (2) At the implementation stage: beyond mutating the target file, adversarially enumerate the detection logic's own blind spots (does it only look at the first line, does it distinguish inside from outside a quoted string, does it collapse multiple lines before checking, does it silently skip when a marker is absent), and attempt at least one mutation that targets one of those blind spots.
- **Why**: Despite a producer already following the practice of running a mutation self-check every round, a fence-structure checker — the verification mechanism itself — still had six independent blind spots discovered across three consecutive rounds. The existing self-check discipline had settled "when to self-check" but had not yet required a recursive second layer checking the detector's own blind spots. More fundamentally, even after the check was formalized into an awk state machine in one round, it kept drawing new blind spots for two more consecutive rounds (a marker-position issue, a trailing-connector issue, a nested-quote issue), and the reviewer stated outright that a regex-based scan has a structural ceiling, and every scope widening surfaces a new uncovered surface. The single spec-stage question above would likely have prevented the later rounds entirely.
- **How to apply**: pm-spec should add one line to a lock's design decision asking whether grammar-state tracking is required, and if so, record the evaluation of a grammar-aware tool (adopted or not, and why) as its own design decision. Engineer should include, in the hand-off, a list of the detection logic's own blind spots plus the measured result of a self-authored mutation targeting one of them. QA should independently attempt at least one mutation aimed at the detector itself, for any task that creates or changes a verification mechanism.

## 2026-07-26 — A change to a completion gate's condition count needs a contamination check and a sentinel-distinctness AC (supersedes two earlier entries)
- **Category**: verification-discipline
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a spec changes a completion gate's condition count or composition, it must mechanically enumerate the downstream logic that consumes the gate's result (a no-progress detector, a signature calculation, a failure-class record, a stop digest) and require an acceptance criterion for each consuming site, **and** that inventory table must include a column checking whether a value flowing to each consuming site could be contaminated by another gate's raw stdout or diagnostic output — and where a sentinel string is reserved, an acceptance criterion must measure its distinctness against every existing gate's stdout and diagnostic output.
- **Why**: When a completion gate was expanded from three to four conditions, a no-progress detector's signature template didn't follow along, collapsing two distinct verdicts into one signature and firing a false no-progress stop — a gap only caught in a review's adversarial pass, even though the primary review's own acceptance criteria could have caught it had a downstream-impact check existed. Separately, a different gate's diagnostic "running:" line embedded a literal acceptance-criterion check-command string, which then bled unconditionally into every tick's combined signature regardless of the real result, de-duplicating what should have been distinct signatures — a downstream-impact inventory (a site enumeration) already existed for that spec, but lacked a content-level audit, so a presence lock alone didn't prevent it. Both cases show that enumerating consuming sites is not enough on its own — whether that inventory itself examines content-level poisoning has to be asked too, every time.
- **How to apply**: When deciding a gate definition (adding a layer, changing verdict vocabulary), grep for "who reads this gate's result" (a loop-guard call site, a signature calculation, a digest, a contract comment), confirm apply/not-apply per site, and turn it into an acceptance criterion. Add a column to that inventory table checking the origin of each value flowing into a consuming site and any path by which another gate's output could leak into it. When reserving a sentinel string, add an acceptance criterion measuring its distinctness against every existing gate's stdout and diagnostic output.

## 2026-07-26 — Run a spec's `check:` lines live and reconcile them before recording an intent hash
- **Category**: verification-discipline
- **Applies-to**: pm-spec, tech-lead
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: Because pm-spec has no shell and cannot execute a `check:` line itself, before freezing an intent block, whichever side has execution capability (the coordinating session, or tech-lead) must run every `check:` line in the spec live, in full, and detect (a) a line that's mechanically broken and always returns the same result, and (b) a line that passes vacuously even when the target artifact doesn't exist — correct them with a meaning-preserving fix, and only then finalize the intent hash. Verify, then correct, then freeze — in that order.
- **Why**: In one case, two `check:` lines inside an already-frozen intent were discovered to be mechanically broken after the freeze, requiring a full re-freeze. A following case applied this same order proactively, and before freezing caught (one) a lock that always returns exit 2 in this sandbox because a diff comparison can't read a process-substitution file descriptor here — meaning it cannot distinguish "the check is broken" from "a real violation" — and (two) a criterion whose usage-error exit code returns 2 even when the fixture it's supposed to check for doesn't exist yet, meaning it cannot distinguish "the feature works" from "the deliverable is simply absent." Pm-spec, once sent back, then audited all of its acceptance criteria across the board and pre-corrected an identically-shaped one on its own. A vacuous `check:` line imports the exact same fail-open defect class this project has repeatedly had to close elsewhere, just introduced from the spec side — and if it survives past the freeze, fixing it later costs a re-freeze's churn.
- **How to apply**: Whoever has execution capability (the coordinating session, or tech-lead) should run the checker (in this repository, the acceptance-criteria checker) once against a spec received from pm-spec, before recording an intent hash. Most acceptance criteria failing is expected and normal pre-implementation — what to look for are exactly two classes: something mechanically broken, and something that passes even though the deliverable doesn't exist. When found, send it back to pm-spec to correct as a meaning-preserving fix, and require a sweep for the same shape across every other acceptance criterion. Only record the intent hash (v1) once that correction is done. The obligation has no scale cap: a spec with a large criteria count still gets every line run live before the freeze — one applied case ran all 28 and caught a host-environment mismatch plus two vacuous-pass shapes in that single pass, each of which would otherwise have cost a re-freeze.

## 2026-07-26 — Don't use `^-[^-]` to confirm a markdown-bullet file only had lines added
- **Category**: verification-discipline
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When mechanically confirming "zero deletions, purely additive" for a file whose every line is a markdown bullet (starting with "- "), account for the fact that a deleted line in a diff always appears as a two-character run of a diff removal marker followed by the bullet's own leading hyphen — so use a check built for that shape (counting lines that start with two literal hyphens, or a diff stat's own deletion column). A check requiring the second character to be a non-hyphen will never detect a deletion in this kind of file and is a vacuous check that always returns zero.
- **Why**: An engineer discovered this defect in an acceptance criterion and corrected it to match the two-literal-hyphen shape, forcing a re-freeze — yet a following task found the identical defect surviving somewhere else: in a procedure a coordinating session was still using for confirming a purely additive board edit, and in an active `check:` line inside an older spec. Further, a machine search of committed review transcripts found this exact "zero matches for the wrong shape" phrase used as "proof of a purely additive change" 204 times across roughly thirty tasks, most of them aimed at the board file — meaning the evidence for "confirmed zero deletions" may have been vacuous in a broad swath of cases (whether an actual deletion was ever missed as a result remains unverified). A single fix in one place left the same shape intact elsewhere.
- **How to apply**: Whoever asserts a purely additive change (a `check:` line written by pm-spec or the engineer, evidence a QA or cross-provider reviewer cites in a hand-off, a coordinating session's own post-edit self-check on the board) should first check the target file's own line-leading character shape. For a markdown-bullet file, use the two-literal-hyphen form or a diff stat's own deletion column — never a check requiring the second character to be a non-hyphen. Apply the same check when copying an existing `check:` line or template from elsewhere. Note that a diff stat's deletion column also counts a legitimate single-line flag transition as a deletion, so don't fix the expected count at zero without matching it against the expected breakdown of deletions.

## 2026-07-26 — A verification command needs array/literal file args, an unswallowed exit code, and a positive control
- **Category**: verification-discipline
- **Applies-to**: engineer, qa-verifier, pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: A verification command that inspects files (a spec's `check:` line, a self-run test's supporting grep, an evidence command included in a hand-off) must satisfy three points. (1) Don't put more than one filename into a single string variable and pass that (use array expansion or a literal enumeration; quoting alone does not fix this, and the behavior varies by shell). (2) Don't swallow the exit code with a fallback like "or echo zero" (a grep's exit code 1, meaning "no match, this is normal," is different from exit code 2, meaning "a file couldn't be read, or the usage was wrong" — collapsing both to the same displayed output turns the verifier's own failure into an apparent pass). (3) Include a paired positive control (show that the command actually hits a term guaranteed to exist in the target file, proving the command really is reading the file).
- **Why**: A verification of an acceptance criterion put four newly-created filenames into a single string variable and ran a grep against it with an "or echo zero" fallback, and all four files reported "zero matches, passing" even though grep had never actually read a single one of them. The root cause identified on the day was attributed to a particular shell's word-splitting, but a careful, literal comparison against the real behavior later showed the opposite — that shell does not word-split an unquoted expansion, so the four names were passed as one single path and failed with exit code 2 either way (quoted or not); a different shell happened to pass by accident through its own word-splitting behavior (a shell-dependent vacuous pass). The real root cause was collapsing exit code 1 and exit code 2 into the same fallback. On the same day, a separate, unrelated fence-structure checker's own fail-open defect (the detector itself returning exit 0 even when broken) had just been closed — this incident was the same class of defect, hit by the side doing the verifying, in their own hands.
- **How to apply**: Before running a verification command, visually confirm the three points (are file arguments an array or a literal list; does a fallback swallow the exit code; is there a positive control). After writing it, show the target file's real existence and size first, show the grep's exit code directly rather than a fallback message, and keep a paired result from a term guaranteed to hit alongside it. This is the same class of vacuous pass as an existing lesson about running a spec's `check:` lines live before recording an intent hash — that one targets a `check:` line written into a spec, this one targets verification commands in general (a self-run test's supporting grep, an evidence command in a hand-off, included).

## 2026-08-01 — A bin/ edit's completion checklist runs the full CI-wired suite list, not a self-selected subset
- **Category**: verification-discipline
- **Applies-to**: engineer,qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When an implementation touches a bin/ script, the completion checklist must include running every suite the CI workflow wires, in the order the workflow lists them, and the hand-off must state that the full list ran — a self-selected 'required suites' subset is not a completion criterion.
- **Why**: A task edited a bin/ script whose line numbers were pinned by another suite's registry, ran only a narrow self-declared list of suites, and declared the work ready; QA failed the round on the stale pin. The corpus already carried an adjacent rule for exactly this class, but it was bound in a maintainer document the roles never see at run time — the written rule did not change behavior at the moment the checklist was drawn up.
- **How to apply**: The engineer includes 'ran every CI-wired suite, in CI order' as an explicit completion-checklist item whenever the diff touches bin/, and lists the result in the hand-off; QA re-runs at minimum the pinning/registry suites rather than trusting the claim.

## 2026-08-01 — Close-out verifies the task's interventions record exists
- **Category**: process
- **Applies-to**: all
- **Scope**: maintainer
- **Bound-in**: CONTRIBUTING.md
- **Status**: active
- **Source**: n/a
- **Rule**: The close-out step of a task includes a check that the task's interventions record (the zero-entry sentinel when nothing happened) exists before the entry moves to Done — a missing record is a gap to fix at close-out, not later.
- **Why**: Across one sprint, every task but one had a zero-entry interventions sentinel; the exception had no file at all, and nothing at close-out noticed. The absence was only caught by the sprint retro's input ledger, which distinguishes consulted-and-empty from missing — by then the task was merged and the record's provenance value had already decayed.
- **How to apply**: Whoever runs close-out checks that the interventions record exists alongside the provenance and review records. Wiring the check into the close-out tooling, and the corresponding line in the contributor-facing procedure, land through that document's next ratified edit rather than ad hoc.

## 2026-08-01 — A task that builds a fail-closed gate writes boundary-shape acceptance criteria against the gate itself
- **Category**: verification-discipline
- **Applies-to**: pm-spec,qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a task creates or extends a fail-closed validation gate, its acceptance criteria must include near-miss and non-canonical input shapes aimed at the gate's own boundary logic (unknown identifiers, near-miss spellings, region-closing conditions) — a gate that validates its inputs strictly but closes its regions loosely is fail-open at exactly one spot.
- **Why**: A checker rewrite validated section markers strictly, but its region-closing condition matched any marker-shaped line rather than the validated set, so an unknown-identifier line silently closed a region and escaped the unrecognised-line check. The cross-provider review caught it as a Major after QA had passed: the gate's own boundary was the one input class nobody had aimed a criterion at.
- **How to apply**: At spec time, when the acceptance criteria cover a new gate, add criteria that mutate the gate's anchor vocabulary (unknown id, near-miss spelling, malformed variant placed at a boundary) and require a reported violation; QA probes the same shapes empirically, including at least one input the gate's two matching paths could disagree on.
