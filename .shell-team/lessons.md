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

**`Scope` decides whether an entry ships at all, and it has exactly two values.** `loop` means the rule is useful to any repository running this loop, and is what `bin/gen-playbook-blocks.sh` reads into the shipped digest blocks. `maintainer` means the rule is specific to developing this plugin itself and stays in this file, bound to a repository-local file named in `Bound-in` — it is never emitted into a shipped block. Only two of the four possible dispositions a candidate lesson can receive ever become a `Scope` value here: the other two, `operator-global` (knowledge about a tool's own behavior that is useful across any project, not specific to this repository) and `drop` (knowledge tied to a convention this repository no longer uses), never enter this repository at all. The dispositions of the one-off corpus import that seeded this file — including the ones that never entered — are recorded in `docs/loop-engineering/lessons-import-disposition.md`, together with the candidates of the one retro that ledger names; it is the record of that import round rather than a running register, so a later retro's dispositions are recorded by the promotion task that executes them, in its spec, its board entry and the `Source` field of whatever entry it appends here.

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
- **How to apply**: When a review record shows a pattern of "new Major findings against the same file or function group in two consecutive rounds," include a general redesign option in the next rework proposal, alongside any point fixes. This sits next to, but is distinct from, the existing rule about two consecutive rounds of the same root cause recurring at *different sites*; this one is about repeated new penetration of the *same* subsystem. When the review round's own findings already contain a design-premise-level recommendation (e.g. "reconsider whether this mechanical assertion is necessary at all"), the rework instruction preserves that abstraction level rather than translating it into another mechanism-level patch; two consecutive rounds of the same class with a premise-level recommendation already on the table means the next round opens with the premise question, not a third patch.
- **Extended by**: 2026-08-13 — a reviewer's reconsider-the-design-premise recommendation was already on the table from round 2 of a task's verification-subsystem findings, but was applied only at mechanism level (an awk-strategy patch) through round 3, until an operator intervention forced the premise-level rescope; the abstraction-preservation duty above closes that gap. Source: `.shell-team/retros/2026-08-13.md`.

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
- **Status**: superseded
- **Source**: n/a
- **Rule**: When a same-class bulk-fix inventory (an apply/not-apply table) is produced, attach the actual repository-wide grep command string and its hit count to the hand-off, not just a prose claim of "checked everywhere." QA should independently re-run the same grep to audit completeness.
- **Why**: Even after an engineer reported "the whole scope was inventoried," a reviewer's own repository-wide grep and a cross-provider review's independent pass both caught the same two missed sites — one of which was inside a file already claimed as inventoried. A prose claim of completeness alone does not guarantee it.
- **How to apply**: When building an inventory table (whether as the engineer or as pm-spec), write "grep run: <command> → N hits, all listed in the table" directly under the table. QA should re-run the identical grep during verification and confirm the count matches the table's row count before trusting the apply/not-apply judgment.
- **Superseded-by**: 2026-08-15 — A completeness claim is written only as the extraction command plus its pasted output (supersedes the completeness-accounting and bulk-fix inventory entries)

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
- **How to apply**: When specifying an audit/completeness-class task, before setting a grep/regex scan as an acceptance criterion's check, list the classes of dependency a scan cannot trace (indirect calls, variable-expanded paths, runtime-constructed calls) in the input space's out-of-scope section, and design completeness around empirical/runtime verification instead. Two consecutive rounds of non-convergent same-class findings is itself the signal that a static method has hit a principled limit — the third round should change method or narrow scope, not widen the scan again. Disclosing the blind spot in the out-of-scope section is a first response, not a stable state: once the disclosed class produces confirmed live misses — no later than the second confirmed one — replace the static inventory with a structurally complete method, in this repository a full-population diff of the affected criteria between the base ref and HEAD, rather than continuing to disclose; one applied case reached that replacement only after its disclosed theoretical concern had become two overlooked live criteria.

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
- **Status**: superseded
- **Superseded-by**: 2026-08-01 — A bin/ edit's completion checklist runs the full CI-wired suite list, not a self-selected subset
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
- **Why**: In one case, two `check:` lines inside an already-frozen intent were discovered to be mechanically broken after the freeze, requiring a full re-freeze. A following case applied this same order proactively, and before freezing caught (one) a lock that always returns exit 2 in this sandbox because a diff comparison can't read a process-substitution file descriptor here — meaning it cannot distinguish "the check is broken" from "a real violation" — and (two) a criterion whose usage-error exit code returns 2 even when the fixture it's supposed to check for doesn't exist yet, meaning it cannot distinguish "the feature works" from "the deliverable is simply absent." Pm-spec, once sent back, then audited all of its acceptance criteria across the board and pre-corrected an identically-shaped one on its own. A vacuous `check:` line imports the exact same fail-open defect class this project has repeatedly had to close elsewhere, just introduced from the spec side — and if it survives past the freeze, fixing it later costs a re-freeze's churn. Two consecutive tasks in a later sprint then hit a third shape the pre-freeze run must catch — a frozen line that is structurally unsatisfiable (one criterion contradicting a sibling criterion, or a comparison whose two sides can never agree byte-for-byte) — each discovered only by the engineer mid-implementation and each costing a human-ratified re-freeze, even though this rule was already written and bound into the spec-writing role: a written rule with no owner and no moment mechanically attached to the freeze did not change what happened at the freeze. A following cycle located where the sweep must evaluate: two more frozen lines, in two tasks, were satisfiable against the pre-implementation tree and became impossible only once the task's own deliverables were tracked — one positive-control fragment could never reach the minimum length its own criterion demanded, and one criterion's exclusion clause contradicted a sibling requirement of the same criterion — each green by accident for exactly as long as the relevant file stayed untracked.
- **How to apply**: Whoever has execution capability (the coordinating session, or tech-lead) should run the checker (in this repository, the acceptance-criteria checker) once against a spec received from pm-spec, before recording an intent hash. Most acceptance criteria failing is expected and normal pre-implementation — what to look for are exactly two classes: something mechanically broken, and something that passes even though the deliverable doesn't exist. When found, send it back to pm-spec to correct as a meaning-preserving fix, and require a sweep for the same shape across every other acceptance criterion. Only record the intent hash (v1) once that correction is done. The obligation has no scale cap: a spec with a large criteria count still gets every line run live before the freeze — one applied case ran all 28 and caught a host-environment mismatch plus two vacuous-pass shapes in that single pass, each of which would otherwise have cost a re-freeze. Treat the live-run as a gating step with an owner and a moment, not a standing reminder: the freeze itself is blocked until whoever holds execution capability has recorded that every `check:` line ran, and the sweep covers mutual satisfiability across criteria (can every line hold at once against one artifact) in addition to each line's own mechanics. That satisfiability evaluation is run against the post-implementation tree state — including the state where the task's own spec and deliverables have become tracked files — not only against the tree as it stands at freeze time.

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

## 2026-08-02 — A spec that ships runnable commands verifies them across an execution-context matrix
- **Category**: verification-discipline
- **Applies-to**: pm-spec, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When a task's deliverable documents runnable commands, the spec must name an execution-context matrix — at minimum the repository's own checkout root without the plugin on PATH, and an adopter-shaped repository with the plugin loaded (different cwd, bin/ scripts reached by bare name) — and every documented command must be verified by running it in every cell, not by reading it.
- **Why**: A documentation task fixed a command's launch form for one context and the fix regressed in the other: the rewritten prefix-relative path exited 127 in an adopter repository with the plugin loaded, a defect an independent review round caught only after the first fix had already passed in the checkout-root context. The same defect class firing in two consecutive rounds forced a full inventory audit before the class closed — each round's fix was individually sound, and the missing piece was verifying the whole context matrix at once.
- **How to apply**: At spec time, when a deliverable includes commands a reader is meant to run, add the context matrix as an explicit verification axis with one criterion per cell; QA executes each documented command in each context rather than trusting that a fix verified in one context holds in the other. A fix that changes a command's launch form re-runs the whole matrix.

## 2026-08-02 — An approval gate presents every option's content, never a bare label
- **Category**: process
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When presenting options for a human decision (an escalation, a rework disposition, a ratification), every option's actual content — the concrete text, change, or consequence it stands for — must appear in the same message as its label, because a label-only option forces the approver to decide blind or to stall the gate asking what the label means.
- **Why**: In one sprint the same presentation defect fired twice at human gates: one request enumerated options but gave only a label for one of them, and the human had to push back before the choice was decidable; a sibling incident presented replacement text in a form the approver could not evaluate. Both gates existed formally, and neither was exercisable as presented.
- **How to apply**: Before sending an approval request that enumerates options, check each option against one question: could the approver state what choosing it would change, from this message alone? If an option's content is long, include a faithful summary inline together with the exact text; never defer an option's substance to a follow-up message.

## 2026-08-02 — A ratification request pairs the exact bytes with a summary in the approver's language
- **Category**: process
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: When human ratification covers exact text (frozen spec lines, replacement sentences, prose that will ship), the request must carry both the byte-exact text and a summary in the approver's working language — the two are jointly required, and neither one substitutes for the other.
- **Why**: A ratification gate once presented candidate replacement sentences as byte-strings in a language the approver does not read; the gate existed formally but could not be exercised, and approval became possible only after an approver-language summary was supplied in a second pass. The exact bytes alone were unreviewable; a summary alone would have ratified a paraphrase rather than the text.
- **How to apply**: At every gate that ratifies exact text, present three things together: a summary in the approver's working language, the exact bytes being ratified, and the presenter's own attestation of what was checked; afterwards record only the approval act itself. This holds even when the approver has delegated the judgment — answer the delegation with the attestation, and still leave the decision act to the approver.

## 2026-08-02 — Run the PII-shape checker on a newly written record before its first commit
- **Category**: security-pii
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: Whoever writes a new git-tracked record (a review, provenance, or interventions file) runs the repository's PII-shape checker against that file before its first commit — the CI diff-time check is the last-resort backstop, not the primary defense, because a value that reaches pushed history costs a history rewrite to remove.
- **Why**: A record describing a PII shape transcribed the real value it was describing — a real home-directory path — and the leak was caught only by a cross-provider review Blocker and the CI diff step, after the record had been committed; removing it required rewriting already-pushed history. Prose that explains a PII shape is exactly the prose most likely to reproduce it, so the producer's own pre-commit run is the control that has to hold.
- **How to apply**: Immediately before the first commit of any new record file, run the PII-shape checker against it (in this loop, check-pii-shapes.sh) and describe shapes with placeholders rather than values. This complements the existing lessons on not transcribing PII into planning documents and on write-time guards inside generating scripts: this one is the habit for records written by hand.

## 2026-08-02 — A review-record appendix is committed by the round that writes it
- **Category**: process
- **Applies-to**: all
- **Scope**: maintainer
- **Bound-in**: CONTRIBUTING.md
- **Status**: active
- **Source**: n/a
- **Rule**: Whoever appends to a task's review record (a cross-provider verdict, a rework-round note) commits that edit within the same round that produced it — leaving the appendix untracked for a later round to discover and commit incidentally is a hand-off gap, not a convenience.
- **Why**: Twice in one sprint a cross-provider round-one verdict appendix was left uncommitted: once flagged on the board by an engineer who found it untracked and declined to adopt it silently, and once committed only because an unrelated later rework round happened to sweep it up. In both cases the record's authorship and timing became reconstructable only through board archaeology, and a crash or branch switch in between would have lost the verdict entirely.
- **How to apply**: At the end of any round that wrote or appended to a file under the reviews directory, check git status for that path and commit it as part of the round's own closing commit; the next round treats an unexpectedly dirty reviews file as a hand-off defect to flag, not as material to absorb silently.

## 2026-08-02 — A spec's descriptive grounding claim is re-measured before it is trusted
- **Category**: verification-discipline
- **Applies-to**: pm-spec, qa-verifier
- **Scope**: maintainer
- **Bound-in**: CONTRIBUTING.md
- **Status**: superseded
- **Source**: n/a
- **Rule**: Inside a spec, keep a prescriptive statement (what this project will do from now on) distinct from a descriptive grounding claim (what the project's practice has demonstrably been), and re-measure any descriptive claim against the primary artifacts before relying on it — an inherited descriptive claim is trusted by every later reader and re-checked by none of them.
- **Why**: A spec's rationale line asserted an established tagging practice as grounding for a design decision, and the claim was already stale at the moment it was first written down — the practice it described had not held for the most recent release. The shipped document happened not to mislead, but the claim survived two sprints of review unchallenged until a QA round re-measured the actual tags and found the mismatch; nothing in the pipeline re-checks a descriptive claim once it sits inside a frozen spec.
- **How to apply**: When drafting or reviewing a spec, for each claim of the form 'X is this project's practice', either re-measure it against the primary artifacts (the actual tags, branches, or files — never an earlier spec's assertion) and cite the measurement, or rewrite it prescriptively as 'from this task on, X' so it grounds nothing historical. QA treats an unmeasured descriptive claim used as grounding as a finding.
- **Superseded-by**: 2026-08-04 — A factual claim is re-measured against the primary artifact before it is written down, inherited or relayed (supersedes the descriptive grounding claim entry)

## 2026-08-03 — A completeness claim attaches its accounting: population total, selection method, and exclusion reasons (supersedes the bulk-fix inventory entry)
- **Category**: verification-discipline
- **Applies-to**: pm-spec, engineer, qa-verifier
- **Scope**: loop
- **Status**: superseded
- **Source**: .shell-team/reviews/T-1020.md
- **Rule**: Any claim that a set of items is complete — "all N sites inventoried", "these candidates exhaust the space", "checked everywhere" — attaches its accounting at the claim site: the population total, the selection or search method actually used (the literal command where one exists), and the reason each excluded item is out; the verifying role re-derives the accounting independently from the raw population instead of re-checking the producer's arithmetic.
- **Why**: The narrower form of this rule (bulk-fix inventories attach the grep command and hit count) was already in this corpus when a candidate-set completeness claim shipped with no accounting at all: a companion document asserted 24 candidates exhausted an 80-entry space with no selection method stated, QA passed it, and only two independent cross-provider review passes caught the gap. The defect class is the completeness claim itself, not the bulk-fix special case — any unaccounted "exhaustive" survives every gate that only samples it.
- **How to apply**: pm-spec writes the accounting into the spec or companion document at the point the claim is made; the engineer keeps it current when the set changes; QA re-derives the total and the partition from the raw population (not from the producer's table) and confirms zero overlap and zero gap before treating the claim as verified.
- **Superseded-by**: 2026-08-15 — A completeness claim is written only as the extraction command plus its pasted output (supersedes the completeness-accounting and bulk-fix inventory entries)

## 2026-08-03 — Code feeding a regex-captured digit string into bash arithmetic follows the file's existing base-10 normalization convention
- **Category**: verification-discipline
- **Applies-to**: engineer, qa-verifier
- **Scope**: maintainer
- **Bound-in**: CONTRIBUTING.md
- **Status**: active
- **Source**: .shell-team/reviews/T-1018.md
- **Rule**: When new or edited code in a bin/ script feeds a regex-captured digit string into bash arithmetic ($(( )) or a numeric test), verify it applies the same base-10 normalization (10#) the file's existing code already uses; a missing prefix is a defect even when every current fixture passes, because a leading-zero input crashes the expansion inside an if-condition, a position set -e does not cover, so the failure is silent and the check is skipped.
- **Why**: A new attestation cross-check crashed on a grammar-conformant leading-zero count (bash reads 08 as invalid octal) inside an if-condition exempt from set -e, silently skipping the check and accepting a self-contradictory record — a fail-open inside a fail-closed gate. The same file already normalized another captured value with 10#; the new code did not follow its own file's convention, and the execution-based QA round missed it because no fixture carried a leading zero.
- **How to apply**: At review and QA time for any bin/ diff, grep the touched file for 10# and for arithmetic over captured variables; every captured digit string entering arithmetic gets 10# at first use. When the input grammar admits [0-9]+, add at least one leading-zero fixture to the owning suite.

## 2026-08-04 — A summary of another document preserves the source's own distinctions, checked against the source and not the summary
- **Category**: verification-discipline
- **Applies-to**: pm-spec, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-04.md
- **Rule**: When a spec or any other frozen prose summarizes facts stated in another document — a count and its breakdown, a contract's per-case requiredness, which outcomes a mechanism can reach — the summary preserves the distinctions the source itself draws, and the verifying role confirms that by opening the source document and matching it clause by clause, never by re-reading the summary's own paraphrase.
- **Why**: Two tasks in one cycle shipped frozen prose that flattened a distinction its source document made: a scored population and its excluded remainder collapsed into a single total, and a per-case requiredness contract restated as uniformly optional. Both passed the engineer's self-check and an execution-based verification round that re-derived numbers independently but compared them against the spec's own wording, and both were caught only by the cross-provider round, where the source itself was opened. A distinction that exists only in the source is invisible to every gate that reads the summary.
- **How to apply**: pm-spec names the source document and the specific distinction being carried over at the point the summary is written, and writes an acceptance criterion requiring the verifying role to open that source rather than re-derive the claim from the spec's wording. QA treats a summary it has not compared against the source as unverified, and reports a flattened distinction as a finding rather than as a wording nit.

## 2026-08-04 — A byte-identity blanket rationale does not cover a step that scans a directory
- **Category**: verification-discipline
- **Applies-to**: engineer, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-04.md
- **Rule**: A blanket rationale of the form "every remaining step is inapplicable because its inputs are byte-identical to the base ref" must exclude any step that enumerates a directory, a glob or a resolved path set, and treat each of those individually — byte-identity of the files a step reads says nothing about the set of files it reads, and a newly added record file changes that set.
- **Why**: One task shipped no disclosure at all of which wired verification steps it had run, and the verification round failed on that absence; a second task in the same cycle did disclose, but its blanket byte-identity rationale was under-inclusive — it did not cover two live steps that walk a directory on every run, and that task had added new files to exactly those directories, a gap the verifying role found only by re-running both steps itself and recorded at nit rather than failing the round. The two are different failure shapes rather than one shape at two severities: a missing artifact, and a present artifact whose stated reason does not reach as far as it claims.
- **How to apply**: When writing the completion disclosure, split the step list in two — steps whose inputs are named files, which byte-identity settles, and steps that enumerate a directory or a glob, which are run and whose result is reported. QA re-runs any directory-scanning step that a blanket rationale covers only by inference before accepting the disclosure.

## 2026-08-04 — A factual claim is re-measured against the primary artifact before it is written down, inherited or relayed (supersedes the descriptive grounding claim entry)
- **Category**: verification-discipline
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-04.md
- **Rule**: A claim about what is or has been the case reaches a durable artifact only after it has been re-measured against the primary artifact it describes: a descriptive grounding claim inherited from an earlier document is kept distinct from a prescriptive statement about future practice and is either re-measured or rewritten so it grounds nothing historical, and a summary of facts relayed by a coordinating layer is hearsay until the receiving role opens the artifact itself.
- **Why**: A spec's rationale line asserted an established practice as grounding for a design decision and was already stale when it was first written; it survived two sprints of review because nothing in the pipeline re-checks a descriptive claim once it sits inside a frozen document. The same hazard arrived from the other direction when a cycle summary handed to a reporting role proved, on measurement, to be wrong in both of its factual claims — the role re-derived them from the specs and from the tool's real output and corrected them before writing. Inherited and relayed claims fail the same way: both arrive pre-formed, both are trusted by every later reader, and neither is re-checked by any of them.
- **How to apply**: For each claim of the form "X is this project's practice" or "X happened this cycle", either re-measure it against the primary artifacts — the actual files, commits, tags or tool output, never an earlier document's assertion or a relayed summary — and cite the measurement, or rewrite it so it grounds nothing historical. State which claims were re-measured and which were taken on trust; a role that cannot run the measurement itself says so explicitly instead of transcribing the claim silently. QA treats an unmeasured claim used as grounding as a finding.

## 2026-08-05 — A temp-file registry appended inside a command substitution never reaches the parent shell, and its EXIT-trap cleanup then deletes nothing
- **Category**: tooling-ci
- **Applies-to**: engineer, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-05.md
- **Rule**: A shell function reached through a command substitution runs in a subshell, so anything it appends to a cleanup registry — a temp-path array an `EXIT` trap later reads — is discarded when that subshell exits; keep the registry and the responsibility for removing a temp file in the caller's own shell scope, or do not create the temp file inside a function called that way, because the trap still fires, still finds an empty registry, and still exits zero while deleting nothing.
- **Why**: A newly shipped checker created two temp files on every ordinary invocation, inside a helper that each of its call sites reached through a command substitution. The append ran in the subshell and never reached the parent, so the `EXIT` trap read an empty registry on every run and removed nothing; by the time a cross-provider review measured the temp directory, the accumulation was past thirteen hundred files. Nothing visible failed on the way there — the fixtures passed and the exit codes were right — because a cleanup that deletes nothing behaves exactly like a cleanup that had nothing to delete.
- **How to apply**: When a script creates temp files, keep the tracking variable and the `trap ... EXIT` that reads it in one scope, and check every helper's call sites for the command-substitution shape before trusting a registry-plus-trap design. QA verifies cleanup by counting the files in the temp directory before and after a real run rather than by reading the trap, since a no-op trap reads correctly.

## 2026-08-05 — A document labelling a result `measured at <ref>` prints a command that reads that ref's committed blob, not the working tree
- **Category**: verification-discipline
- **Applies-to**: engineer, pm-spec, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-05.md
- **Rule**: When a document states a result as measured at a named git ref, the command printed beside that label must read that ref's committed blob — through `git show <ref>:<path>`, `git ls-tree <ref>` or an equivalent — and never the working tree, whose bytes at read time are not that ref's; the spec covering such a document carries an acceptance criterion aimed at the printed command's reading target, not only at the printed number.
- **Why**: Two independent sites in one task labelled a measurement with a historical ref while the command printed beside it read the working tree, so the documented procedure could not reproduce the documented number except by coincidence. The cross-provider round raised both as one class, the same-class rule forced a re-derivation across the whole diff, and that sweep found a third site of the same shape — and, at that site, a file count carried over from an unrelated population. The divergence is easy to reintroduce because each half is correct in isolation: the label names a real ref, the command is a real command, and only running the command at the ref shows that they disagree.
- **How to apply**: pm-spec writes a criterion asserting the ref-reading form for every command a deliverable prints beside a measured-at label; the engineer runs each printed command exactly as printed, at each ref it names, and records the output rather than the intent; QA re-runs those commands instead of reading them, and treats a working-tree read under a historical label as a finding rather than a wording nit.

## 2026-08-05 — A background agent is monitored by an active liveness check started at launch, because a completion notification cannot report a stall
- **Category**: process
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-05.md
- **Rule**: Whoever launches an agent to run in the background starts an active liveness check at the same moment — something that samples, on its own schedule, whether the agent is still making progress and raises an alarm when it stops — because waiting for a completion notification cannot detect a stall even in principle: an agent that has stopped mid-run emits nothing, and that silence is indistinguishable from a healthy long run. Which mechanism supplies the signal is the operator's choice; what is required is that one exists, that it starts with the agent, and that a stall verdict is measured from its signals rather than inferred from elapsed time.
- **Why**: A background role stalled mid-task while the launching side treated its own completion notification as the monitoring mechanism; nothing observed the gap until a human noticed the run had overrun by a wide margin and corrected the operating rule. The failure is structural rather than incidental: a notification channel reports only the transition it is built to report, so a run that never reaches that transition is exactly the case the channel is silent about — and the same silence is also the healthy case, which is why waiting longer never resolves it.
- **How to apply**: Pair every background launch with a liveness check that starts at launch, and treat "no notification yet" as no information about the agent's state. On an alarm, verify against the signals the check samples before intervening, and prefer prompting a stalled agent over terminating it while any signal still shows progress; a role that cannot run such a check says so at launch rather than substituting patience for monitoring.

## 2026-08-06 — A relayed premise is re-measured at its primary source before it is written into a downstream prompt
- **Category**: verification-discipline
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-06.md
- **Rule**: A premise that reached you from a coordinating layer rather than from the artifact itself — another task's check result, a predicted verdict, a count, where a frozen constant lives, which marker regions a file carries — is re-read at its primary source before it is written into the instructions of the role that will act on it, and it is written there as the measured value; where the writing side cannot run the measurement, it labels the premise as relayed at the point it appears, so the receiving role opens the source instead of trusting the sentence. Re-measurement by the receiving role is the second line of defence, not the first.
- **Why**: In one cycle at least four hand-offs carried a premise from a coordinating layer into a downstream role's instructions where it disagreed with the primary artifact: two predictions about the shape of another task's check lines, a conflation of two different populations of the same kind of location, and a claim about which criterion a pair of counts had been frozen into. Every one was caught, but only after the receiving role had already acted on it, and one of them originated in the previous cycle's own retro summary, so the class reached a ratified planning input. The relay is what makes it durable: a premise arrives pre-formed, reads as settled, and is cheaper to repeat than to check, so it travels one hand-off further each time nobody opens the source.
- **How to apply**: Before writing a premise into another role's task prompt, a routing map, or a spec, separate what you measured from what you were handed, and re-read the handed part at its primary source — the file, the blob at the named ref, the tool's own output — replacing the relayed wording with the measured value. Where you have no way to measure it, write the premise as relayed, name the side that holds the primary confirmation, and require the receiving role to re-measure and report the value it found. The receiving role treats an unlabelled premise it cannot trace to a source as relayed anyway, and reports a disagreement it finds as a finding about the hand-off rather than silently correcting it.

## 2026-08-06 — An accounting criterion is written as a base-relative delta or a value-independent invariant, never as an absolute literal
- **Category**: verification-discipline
- **Applies-to**: engineer, pm-spec, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-06.md
- **Rule**: A criterion or assertion whose subject is a count — how many elements a set has, how many times a pattern occurs, how many lines a file gained — states that count as a delta measured against a named base ref, or as an invariant that re-derives both sides at run time and compares them, never as an absolute literal typed into the check; the machine-checkable anchor stays required and only its form changes. An absolute literal is correct only for the population that existed when it was typed, it passes on that day and passes review, and once it sits inside frozen text nobody is permitted to repair it.
- **Why**: One task produced three instances of a single coupling defect in a row before the pattern was recognised: a count blind to the population it measured, then a count coupled to the version number of the very document carrying it, then a count coupled to how many repairs the task had already made. Each was repaired individually and each repair created the next, because the underlying shape — an absolute number standing in for a measurement — survived every fix; only after the third consecutive instance did the work switch from point repairs to a full inventory of the class. Nothing distinguishes an absolute-literal accounting check from a sound one until the population moves, which is always after the freeze.
- **How to apply**: When writing a counting criterion, derive both sides at run time: read the named ref's committed blob and compare the current artifact against it, or compute the expected count from something the criterion already pins rather than restating it as a number. Where an absolute literal is genuinely unavoidable, state the reason beside it and attach the observable event that invalidates it. The verifying role re-derives the population independently and treats an absolute-literal accounting check as a finding about the criterion rather than as a red to work around; a role that cannot repair such a literal because it is frozen discloses it and routes a re-freeze instead of bending its own work to match the number.

## 2026-08-06 — Frozen prose carrying no check line goes stale when what it describes moves, and the proportionate repair is one batched editorial pass
- **Category**: process
- **Applies-to**: pm-spec, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-06.md
- **Rule**: An explanatory sentence inside a frozen intent block — a design-decision paragraph, a goal sentence, a note naming where a fact came from — carries no check line, so no machine gate re-reads it when the criterion, version or document it describes moves; such a sentence goes stale silently and only a human reader notices. Treat each occurrence as a disclosed finding rather than an immediate re-freeze, and collect the accumulated ones into a single editorial pass, because a per-instance re-freeze spends a full ratification cycle on a sentence whose meaning nobody disputes.
- **Why**: Three frozen sentences went stale in one cycle for the same structural reason: a design-decision sentence came to contradict the criterion it introduced once that criterion was itself re-frozen, a goal sentence named a version number that a neighbouring task's later re-freeze moved past, and a sentence citing a fact's origin named the wrong record. None was reachable by any machine check, all three were found by a reviewer reading prose, and each was routed individually as a fast-follow — three ratification cycles for three sentences, none of which changed what any task did. The staleness is a property of the freeze itself: the criteria a frozen block pins are re-run every round, and the prose beside them is read once.
- **How to apply**: When freezing prose that refers to a criterion, a version number or another document's contents, prefer wording that stays true as those move, and where it cannot, say beside the sentence that it is expected to need an editorial correction later. The verifying role reports a stale frozen sentence as a finding with a correction proposed, not as a wording nit and not as something to fix in place. Whoever owns the spec collects the accumulated corrections and re-freezes them together in one low-risk editorial pass rather than one at a time, and states in that pass which sentences it covers so the backlog is visibly emptied rather than merely reduced.

## 2026-08-08 — A verification-mechanism task's pre-commitment names the drop order before the first round, so the trigger executes a decision instead of opening one
- **Category**: process
- **Applies-to**: pm-spec, tech-lead
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-08.md
- **Rule**: A pre-commitment written for a task that builds or extends a verification mechanism states, before the first review round, not only the trigger but the disposition the trigger executes — which component is dropped first and why it is the droppable one, where the dropped part goes, and that the rounds' findings travel with it as its requirement list rather than being re-derived there. At the moment a trigger fires, one more patch is always the cheapest move available, so a trigger with no pre-decided disposition reopens the design question at exactly the point where nobody is placed to settle it. The recorded disposition exists only for components named droppable — an item the pre-commitment declares never-dropped has no carve-out to execute, so its defeat stops the task and returns it to planning, because the same mechanism defeated across consecutive design generations is evidence about the design premise rather than about the implementation's craft.
- **Why**: A pre-commitment of this shape fired in practice for the first time: a newly built lock suite drew independent new cross-provider findings in two consecutive rounds, and because the splitting order had been fixed in advance — the droppable component named first — the split was carried out on the spot instead of a fourth round of point repairs, with both rounds' findings carried into the follow-up task as its requirement list. Several existing rules already prescribe the counting and the threshold; none of them prescribes the disposition, and the disposition is what the firing actually consumed. It was decided while the design was still cold, which is the only time it can be decided cheaply. The other branch later fired too: a task whose never-dropped requirement was defeated in consecutive rounds — the third consecutive design generation of the same mechanism to fall — was halted and handed back to planning with its defeat record carried forward as the successor's requirement list, instead of being carved down on the spot as a droppable component would have been.
- **How to apply**: When a task builds or extends a checker, parser, lock or state tracker, write its pre-commitment in three parts: the factual trigger, the component dropped first with the reason it is the droppable one, and the destination that inherits the findings already collected. Whoever plans the task confirms all three exist before the first round rather than at the moment the trigger fires. When it fires, execute the recorded disposition, record the firing where the task's own history is kept, and treat a proposal to patch once more as the move the pre-commitment exists to refuse. State which components are droppable and which are never-dropped, and for a never-dropped item name the return-to-planning disposition explicitly, so that the firing executes a recorded decision in both branches. When the drop the trigger executes touches an item the pre-commitment names never-dropped, re-read that item's exact wording before executing the drop and judge whether the drop weakens or strengthens it: strengthening it is within the recorded disposition and proceeds, but a weakening is the stop-and-return-to-planning branch, not a carve-out to execute on the spot — run this re-read before executing, not after, since two independent tasks in one cycle each invented this same step at the moment a drop reached a never-dropped item.

## 2026-08-08 — A repair closes the class of mutation the finding is an instance of, verified before the round closes
- **Category**: verification-discipline
- **Applies-to**: engineer, qa-verifier, tech-lead
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-08.md
- **Rule**: A fix for a review finding is written against the class of mutation the reported case is an instance of, not against the reported case: before the round closes, name the property of the input that makes the defect fire, enumerate the other inputs, orderings or spellings that share that property, confirm the repair closes those too, and report in the hand-off which variants were tried and what each did. A repair that plugs only the literally reproduced case leaves the class open, and the next round finds the same defect wearing a different input.
- **Why**: Two independent instances appeared in one cycle, in two unrelated tasks. A repair to an exemption rule blocked the exact literal the reviewer had demonstrated while four other spellings of the same exemption still bypassed it, which the following round found. In the other, an orientation sentence was corrected where it had been flagged while the identical defect stayed in neighbouring sentences, and three further rounds each corrected one more site. Both cost a full round to learn what one enumeration before closing would have shown, and neither had yet reached the second-occurrence threshold that switches the instruction to a full inventory — the first occurrence was already enough to see the class.
- **How to apply**: Before calling a review finding closed, restate it as a class and list the variants that share its triggering property, then run the repair against them and report the variants and their results in the hand-off, so the next gate audits the closure rather than the single case. Whoever relays a rework instruction asks for the class rather than the spot from the first occurrence, which is earlier than the same-class-2 rule fires and does not replace it. The verifying role treats a repair demonstrated only against the reported reproduction as an open finding rather than a closed one.

## 2026-08-08 — An obligation added to a shared region reuses the file's existing scoping idiom rather than inventing one
- **Category**: process
- **Applies-to**: engineer, pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-08.md
- **Rule**: Before adding an obligation to a region that several modes, paths or callers share, read the file for the scoping idiom it already uses for exactly that situation — a sentence naming which mode a duty applies in and which one it does not — and reuse that shape, adjusting only the mode names and the direction words the new position requires. A duty written into a shared region with no such clause silently acquires every mode the region serves, including the ones that have no carrier for it, and the repair is almost never a new pattern to invent.
- **Why**: A new obligation was added to a shared preconditions block of an agent prompt, and in the mode where that role produces a different output contract there was nothing for the obligation to attach to. The same file already carried a self-scoping sentence written for precisely that split, a few lines from the edit, and a second one in another section. The cross-provider review raised it on the first round. The failure was not a missing convention but an unread local precedent, which is both the more basic defect and the more repeatable one, because a file's own precedents are invisible to anyone who read only the region being edited.
- **How to apply**: When a change adds a rule to a file with modal or shared regions, search that file for its existing scoping sentences before writing, and copy their shape rather than composing a new one. The spec states in which region and under which mode scope the new wording must sit, so its criterion asserts the placement and the scope rather than the wording's mere presence, and the verifying role reads for the scoping clause rather than for the obligation alone.

## 2026-08-08 — An append to a task's append-only record is written after re-reading the whole record, not after reading the last append
- **Category**: process
- **Applies-to**: engineer, pm-spec, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-08.md
- **Rule**: A task whose deliverable is a record — a board entry, a spec's mutable prose, a review or provenance file that each round appends to — is re-read end to end before each new append, and an append that changes what an earlier line said says so explicitly instead of merely sitting after it. The defect this class produces is not a wrong new sentence but a new sentence contradicting an older one still standing above it: the record accumulates while attention stays on the tail, and no gate re-reads the head.
- **Why**: A task that ended with no product change at all, and five records as its entire output, drew four consecutive cross-provider rounds of findings — every one of them an internal contradiction between a later append and an earlier line of the same entry, and three of them against the immediately preceding repair. Each append was accurate about what had just happened and wrong about what the entry already said. A mechanism has tests that re-read it on every run; a record has only whoever opens it next, and in a records-only task nobody is scheduled to.
- **How to apply**: Before appending to a board entry, a spec's mutable sections or a review record, read the whole entry rather than the last block, and state in the append which earlier line it supersedes when it changes one. A task whose deliverables are mostly records says so in its own hand-off, so the reading is budgeted rather than skipped. The verifying role reads such a record end to end for the same reason and reports a contradiction between two of its own lines as a finding rather than as a wording nit.

## 2026-08-09 — A population-exception control is probed separately for its naming and its wiring
- **Category**: verification-discipline
- **Applies-to**: engineer,pm-spec,qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-09.md
- **Rule**: A control that reports a population exception (an unreadable input, a nothing-detected outcome) can be vacuous in two independent ways — its naming, whether the reported label corresponds to logic actually exercised, and its wiring, whether its execution path passes through the real verdict branch the production path uses — and fixing one facet leaves the other open, so each facet gets its own mutation probe.
- **Why**: One task demonstrated the two facets failing in sequence across consecutive review rounds: the first round found that the label the control reported did not correspond to the logic that had actually run, the repair fixed the naming, and the next round found the rewired control still decided pass or fail from a condition of its own without ever passing through the production verdict branch. Each facet looked closed while only the other had been probed; the sequence is recorded in that task's review file rather than restated here.
- **How to apply**: When a task adds a control that reports an exception case, write two mutation probes before calling the control done: one that mutates the referent of the reported label and confirms the report changes with it, and one that breaks the production verdict branch and confirms the control goes red. A design checklist that confirms only one of the two certifies half the control; the hand-off reports both probes and their results, and the verifying role treats a control probed on one facet as an open finding.

## 2026-08-09 — Norm text bound for several gate surfaces is read against a plural corpus instance before freezing
- **Category**: verification-discipline
- **Applies-to**: pm-spec,tech-lead
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-09.md
- **Rule**: A task that adds the same norm to several gate surfaces tends to freeze wording that carries an implicit cardinality-one assumption about the thing it governs, so before the freeze, enumerate the norm text's singular determiners (the one, the only, a bare the on the governed noun) and read the norm against at least one existing spec in this repository where that governed thing occurs more than once.
- **Why**: A runtime-criterion reporting norm was frozen with singular phrasing while the corpus already held a spec carrying two such criteria in one spec, and that pre-existing plural instance broke the wording immediately — found by the cross-provider review rather than at the freeze. The task the norm belonged to had itself been written to close the class of unenumerated whole-set claims that ship reading as complete, so the norm shipped carrying an instance of the class it was closing; writing a norm against a defect class does not protect the norm from that class.
- **How to apply**: Before freezing norm text destined for more than one surface, list every word in it that implies exactly one of the governed noun, then search the existing specs for a counterexample with more than one occurrence and read each listed word against it; where plurality is possible, reword in plural-tolerant form, and treat a surviving singular determiner as a freeze blocker rather than a wording nit.

## 2026-08-11 — A frozen sentence asserting a file's behavior requires that file in Summarized sources
- **Category**: verification-discipline
- **Applies-to**: pm-spec, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-11.md
- **Rule**: When a frozen intent-block sentence makes a concrete behavioral claim about a specific file — what it does, does not, or leaves unchanged — that file must appear as an entry in the spec's `## Summarized sources` section; a behavioral claim about a file the author never opened and never named as a source is a mechanically detectable tripwire for an unverified assertion.
- **Why**: A frozen intent block asserted a wrapper script's behavior in its design-decision prose while the file it was describing had never been opened and was absent from the spec's own `## Summarized sources` section; the actual behavior contradicted the frozen claim, and only an execution-based verification round that ran the real script against a live fixture caught the mismatch. The absence itself was already detectable at freeze time — a behavioral claim with no corresponding source-file citation names its own gap before anything runs.
- **How to apply**: When drafting or reviewing a frozen intent block, for every sentence making a concrete claim about a named file's behavior, confirm that file is listed in `## Summarized sources`; where it is not, either open the file and add the citation before freezing, or rewrite the sentence to drop the specific behavioral claim. The verifying role treats a behavioral sentence about an uncited file as an open finding rather than a wording nit.

## 2026-08-11 — A freeze sweep cross-checks a base-blob discriminator across sibling criteria in the same spec
- **Category**: verification-discipline
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-11.md
- **Rule**: When more than one criterion in a spec verifies the same property class by reading a base-side blob (a stack-delivered file's prior state, a pre-change value), and one of those criteria has already adopted a discriminator between reading the branch point and reading the merge-base, the freeze sweep explicitly checks whether every sibling criterion in the same spec verifying that same property class applies the same discriminator — a clause evaluated on its own, against its own post-implementation tree, does not surface an inconsistency that only shows up when compared against a sibling clause in the same document.
- **Why**: One criterion in a spec correctly used the branch point (because, under a stacked batch-GO operating mode, the base ref had not yet merged the files a sibling criterion in the same spec depended on), while another criterion in that same spec, verifying the same base-blob-read property, was frozen using the merge-base instead and turned out structurally unsatisfiable in every implementation state — a defect that required a re-freeze to fix. The very next task standardized the discriminator across all of its own base-blob reads from the start, but did so only because it remembered the previous task's failure, not because any procedure names the cross-check.
- **How to apply**: Before freezing a spec, list every criterion that reads a base-side blob for the same property class, and confirm each one uses the same branch-point-vs-merge-base discriminator; where a spec's own earlier criterion already settled which discriminator applies to the stack this task runs on, apply that same discriminator to every sibling criterion rather than deciding each independently.
- **Extended by**: 2026-09-04 — a second base-side class joins the discriminator check: a criterion asserting that text on HEAD is "still present", "remains" or "unchanged" — wording the task itself does not write — is a base-side positive control spelled differently, and it is verified only by running the exact literal against the base ref's blob (never a substring match, never a classification from the prose), because a criterion that is already red before the change starts lets the intended cause mask every other one. Measured case: five of six tasks in one sprint carried a freeze-sweep miss of this family; in three of them the engineer implemented, found the criterion unsatisfiable and stopped with BLOCKED, costing one re-freeze round each, and one criterion asserted a literal a prior task had already deleted. An ad-hoc trace listing every check line whose base-capture read returns non-zero found both remaining defects at re-freeze; mechanizing that trace into the acceptance-criteria checker is filed as its own backlog item. Source: `.shell-team/retros/2026-09-04.md`.

## 2026-08-11 — Porting a test/fixture idiom from a sibling file re-verifies the source's own environmental preconditions
- **Category**: verification-discipline
- **Applies-to**: engineer
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-11.md
- **Rule**: When copying a scratch-root fallback, a positive control, or another test/fixture idiom from a sibling test or spec file, re-verify in the destination file whether the source file's own environmental preconditions (which environment variable it assumed present, which cwd or invocation shape it depended on) actually hold there — an idiom correct at its origin can be silently wrong once moved, because the same literal text carries an assumption the new site does not share.
- **Why**: A test suite copied a `$TMPDIR`-unset fallback from a sibling suite without checking whether that sibling's assumption held at the new site; the fallback in the new location resolved inside the checkout itself rather than a genuine scratch path. Dozens of local runs never exercised the fallback branch because the local sandbox always sets `$TMPDIR`, and the defect surfaced only in CI, after both review gates had already gone green, requiring a post-merge fix.
- **How to apply**: When an engineer's adversarial fixture synthesis reaches for an existing idiom in a sibling test or spec file rather than writing one from scratch, name the precondition that idiom relies on (an env var's presence, a specific cwd, a specific invocation shape) and add a fixture that violates that precondition at the destination — the same class of fixture the fixture-synthesis checklist already requires for beyond-happy-path input, applied here to the idiom's own assumed environment rather than to the artifact's runtime input.

## 2026-08-11 — A hand-off count carries the exact command that produced it, verbatim, in the same bullet
- **Category**: verification-discipline
- **Applies-to**: engineer,qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-11.md
- **Rule**: Every count written into a hand-off bullet — a suite's PASS line total, a CI step count, "N new cases," a coverage total — carries, in the same bullet, the exact command that produced it, verbatim (e.g. `grep -c '^PASS:' <log>`); a count typed from memory or from a mid-task impression is exactly the value most likely to drift from what re-running the command would show.
- **Why**: In one cycle, four separate tasks shipped hand-off counts that drifted from an independent re-measurement — a reported count of new cases against a higher measured count, a described mutation-self-check that did not reproduce literally, a reported full-pass total against a result one short of full — and each was caught only because QA or the cross-provider review re-derived the number itself rather than trusting the hand-off's prose. None of the four blocked a merge, but all four cost an extra round of correction for a mistake a verbatim command would have prevented at the point of writing.
- **How to apply**: Before writing a count into a hand-off bullet, run the command that produces it and paste both the command and its output into that same bullet; a count with no accompanying command is treated by the reading role as unverified narrative rather than as a discharged item, in the same way an unenumerated whole-set claim is treated as incomplete.

## 2026-08-11 — A stacked batch-GO cycle's retro window is declared from the board's merge-chain and merge-base measurements, not from develop's merge history
- **Category**: process
- **Applies-to**: pm-spec
- **Scope**: maintainer
- **Bound-in**: agents/scrum-master.md
- **Status**: active
- **Source**: .shell-team/retros/2026-08-11.md
- **Rule**: While a repository operates under a stacked batch-GO cycle — feature PRs left open and merged in one batch only at the end of the cycle, rather than merged individually as each task completes — the retro's cycle-window declaration is taken from the board's own `merges at the sprint batch GO after PR N` chain, cross-checked with a `git merge-base --is-ancestor` measurement against each PR's tip, and never from a git-merge-commit history walk against the base branch; a merge-commit walk against the base branch necessarily returns zero commits from the current cycle (they have not merged yet) and, worse, can return foreign commits from a stale prior cycle that share no PR number with the one running now.
- **Why**: Two consecutive retros under this repository's stacked batch-GO mode independently hit the same shape: the tool's own merge-commit-based cycle-window input returned a set of PRs that were entirely from a previous cycle, matching zero PR numbers of the cycle actually being retro'd, and both retros had to fall back to the board's own PR-chain prose and a live `git merge-base --is-ancestor` check to reconstruct the true window. Doing this reconstruction from scratch each time it recurs is the same repeated-correction shape a written rule exists to close. This is a maintainer-only practice of this repository's own development process (the stacked batch-GO mode is a private operating convention, never a shipped default), so its real consuming role is the scrum-master agent by name; the corpus's Applies-to enum does not yet include a scrum-master token, so this entry is bound directly into agents/scrum-master.md by hand rather than through the generated per-role playbook mechanism.
- **How to apply**: When a retro runs while the board records tasks as `READY_FOR_MERGE` (stacked, not yet merged to the base branch), do not treat a merge-commit-history tool's cycle-window output as authoritative; instead read each in-scope task's board entry for its `merges at the sprint batch GO after PR N` chain, and independently confirm the chain with `git merge-base --is-ancestor <PR tip> HEAD` for each PR before reporting the cycle window in the retro's summary. This rule is spliced directly into `agents/scrum-master.md`'s own prose, not generated from this entry — a future task extending the corpus's Applies-to enum to cover roles outside the four IN roles could route it through the generator instead. The chain may contain intermediate commits or PRs with no independent board entry of their own (a lesson-promotion chore branched between two tasks' PRs, for instance), which the board's `merges at the sprint batch GO after PR N` prose alone will not reveal; confirm every ADJACENT link of the chain individually with `git merge-base --is-ancestor <predecessor tip> <successor tip>` (not just endpoint-to-HEAD ancestry), and read each in-scope board entry's `stacked:`/branching prose for mentions of intermediate tips before declaring the window complete.
- **Extended by**: 2026-08-13 — a lesson-promotion chore branch sat between two tasks' PRs with no board entry of its own, and was discovered only via the later task's board prose naming it as a branch point; the adjacent-link and intermediate-node discipline above closes that gap. Source: `.shell-team/retros/2026-08-13.md`.

## 2026-08-11 — A spec for a user-visible capability carries an adopter-facing-documentation acceptance criterion as a freeze-time blocker
- **Category**: process
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-11.md
- **Rule**: When a spec's deliverable is a user-visible capability — a new configuration mechanism, a new command, a new adopter-facing behavior — the spec carries an acceptance criterion requiring adopter-facing documentation (README, docs/, a template comment an adopter reads) to ship in the same task, and pm-spec treats a missing one as a freeze-time blocker rather than deferring it to a fast-follow issue; "fast-follow the docs" is not an acceptable default disposition for the artifact that realizes the release's own value.
- **Why**: A release shipped a new executor-binding configuration mechanism — the capability the whole sprint's goal was built around — with zero adopter-facing documentation of how to use it, discovered only after the release was published, as a gap serious enough to need its own follow-up issue and a dedicated mechanization task. The capability existed and worked; nothing told an adopter it existed or how to turn it on, which is functionally equivalent to the capability not shipping at all for anyone who has not read the source.
- **How to apply**: At spec-completion self-check time, for any task whose deliverable an adopter can observe or configure, add an acceptance criterion requiring the corresponding README/docs update to land in the same PR, and refuse to set `READY_FOR_ARCH` if that criterion is missing. This repository's mechanization of the check is the machine-checkable anchor future specs are expected to cite once it exists; until then, the requirement is enforced by pm-spec's own self-check discipline.

## 2026-08-13 — Freeze-time verification cost is priced by the task's deliverable class
- **Category**: verification-discipline
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-13.md
- **Rule**: At spec-completion self-check, before the freeze sweep runs, pm-spec classifies the task's deliverable (a mechanism change vs. wording-only / docs-only / prose-editorial) and prices acceptance-criteria verification accordingly: a task that changes no mechanism restricts every acceptance criterion's verification shape to four allowed forms — string presence/absence grep, byte-scoped diff, checker exit code, records-line existence — and explicitly declares full-population sweeps, CI-equivalent re-runs, and behavior verification of unchanged mechanisms as non-goals.
- **Why**: Across the T-1062 → T-1063 → T-1064 arc, a code-mechanism verification protocol was imported unpriced into an editorial sprint: T-1062's ~4-line release-notes-template bullet fix was governed by an acceptance criterion demanding mutation probes, a CI-equivalent 71-step re-run, and a full-population blast-radius diff across 66-plus specs, and the engineer phase alone consumed more wall-clock than a feature task — drawing 4 review rounds and an operator STOP escalation ("a one-bullet docs fix consumed more than a feature task, and the goal was lost chasing the mechanism"). T-1063 hit the same unpriced-import shape a second time mid-sweep before establishing the deliverable-class pricing; T-1064 applied that pricing from freeze and converged in 1 review round each for QA and the cross-provider review, down from T-1062's 4.
- **How to apply**: At pm-spec's spec-completion self-check, before running the freeze sweep, classify the task's deliverable class; for a task that changes no mechanism, restrict every acceptance criterion's `- check:` shape to the four forms above and add an explicit non-goals statement ruling out full-population sweeps, CI-equivalent re-runs, and behavior verification of mechanisms the task does not touch. Mechanizing this pricing judgment into pm-spec's own self-check prose and into the run/goal skills' freeze-sweep briefing guidance is tracked as issue #258 and lands in a dedicated task (T-1065) — this entry records the pricing rule itself, ahead of that prompt wiring.

## 2026-08-13 — An operator-facing report declares who owns a cited pre-decided disposition
- **Category**: process
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-13.md
- **Rule**: Any operator-facing report — a STOP escalation, a gate firing, a hand-off — that invokes a pre-decided disposition ("per the pre-decided rule", a pre-commitment's trigger firing) declares, in that same report, whose authority the disposition belongs to: AI self-discipline (self-imposed, never operator-ratified) or an operator-ratified ruling — so the operator is never framed as the author of a rule they did not make.
- **Why**: A STOP escalation reported a pre-commitment's trigger firing as "the pre-decided rule," and the operator corrected it on the spot: "I never made such a rule — this class of misattribution is the problem." This is the mirror image of this corpus's existing T-1023-derived lesson on an unratified gate quietly becoming standing practice: there, an AI-invented gate was misread as durable operator-approved practice; here, an AI-internal self-discipline was misread as an operator ruling. Both share the same missing discipline — declaring, at the point of use, who owns a disposition — rather than letting the report's phrasing blur AI self-imposed constraint and human ratification together.
- **How to apply**: Whenever an operator-facing report cites a pre-decided disposition (a loop-guard pre-commitment, a same-class-2 trigger, any "per the pre-decided rule" framing), state in that same report whether the disposition is AI self-discipline or an operator-ratified ruling. This is spliced as a one-sentence requirement into the STOP-escalation report sections of both `skills/run/SKILL.md` and `skills/goal/SKILL.md`.

## 2026-08-15 — A completeness claim is written only as the extraction command plus its pasted output (supersedes the completeness-accounting and bulk-fix inventory entries)
- **Category**: verification-discipline
- **Applies-to**: pm-spec, engineer, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-15.md
- **Rule**: Any completeness or set-comparison claim in a record, spec, or note — 'all/every/none/complete', a cardinality, a difference or intersection between sets — is written only as the population-extraction command plus its output pasted verbatim at the claim site; hand-computed set operations, manual counts, eyeball diffs, and visual enumeration are banned even when an accounting is attached, because a hand-derived accounting reintroduces the same defect the accounting was meant to close.
- **Why**: The predecessor entry required a completeness claim to attach its accounting (population total, selection method, exclusion reasons), yet the class recurred at least nine times in one cycle across two tasks (five instances in one, four in the other), drew two operator halts, and reappeared within the same cycle as a headline rounding error (43.85% written where the measured value was 43.84%) even after three premise changes had claimed to close the class — the surviving generator was the hand-derived arithmetic itself, which an attached-but-manual accounting still permits.
- **How to apply**: At the moment of writing an 'all/every/none/complete' claim, a count, or a set difference into any record, derive it with a command and paste both the command and its verbatim output; the verifying role re-runs the same command rather than re-checking prose arithmetic. Issue #268 tracks mechanizing command-derived set operations in records; once that checker ships, this entry is expected to shrink to a pointer at it (re-evaluation trigger).

## 2026-08-15 — An analysis-note spec's verdict scope prices review depth by consumer and stakes at freeze
- **Category**: process
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: superseded
- **Superseded-by**: 2026-08-16 — Review depth is priced by the artifact's consumer and stakes, at freeze and again in every review briefing (supersedes the analysis-note verdict-scope entry)
- **Source**: .shell-team/retros/2026-08-15.md
- **Rule**: When freezing a spec for an internal analysis-note deliverable — an investigation that changes no shipped mechanism — the '### Verdict scope' block defines that artifact class's deliverable correctness as computed values plus the direction of conclusions, with prose wording explicitly non-gating (notes), so review depth is priced by the artifact's consumer and stakes once at freeze instead of being re-litigated round by round.
- **Why**: An analysis-note task reviewed at code-change strictness drew four review rounds and two self-escalations over prose wording until the operator halted it as means-obsession and set the pricing by ruling; the three analysis-note tasks frozen after that ruling inherited the verdict-scope block by citation and converged in one to two rounds each — the cost difference was the presence of the pricing at freeze, not the artifacts' content.
- **How to apply**: pm-spec writes the verdict-scope block into every analysis-note spec at freeze, naming the consumer and stakes and citing the artifact class's correctness definition; the orchestrator applies that frozen scope when judging same-class escalations instead of ratcheting review depth mid-task. Templating this block as the default for analysis-note specs is a candidate mechanization for a future task.

## 2026-08-15 — A checker's runtime cost is recorded only from a measurement whose locale and input size are stated
- **Category**: verification-discipline
- **Applies-to**: engineer, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-15.md
- **Rule**: A claim about a checker's runtime cost — 'light', 'seconds', an order-of-magnitude comparison — is recorded only from a live measurement taken under stated conditions, locale and input size (board size, section population) at minimum, because a real number measured in a non-representative environment misleads exactly as well as an unmeasured guess.
- **Why**: A verification round concluded a board checker's documented cost was two orders of magnitude wrong based on a measurement near 2.49 seconds that was real but non-representative (C locale, a near-empty active section), and had to be corrected the following round; the same checker's cost later measured 45 to 104 seconds as the board grew, so the original number was an artifact of its conditions, not a property of the checker.
- **How to apply**: When writing any statement about a checker's execution cost into a record or review, run it live first and state the locale and the input's size next to the number; treat an inherited cost figure with no stated conditions as unverified. Issue #269 tracks the locale/content-length root cause; re-price or retire this entry when that lands (re-evaluation trigger).

## 2026-08-15 — A cross-role safety premise quotes each involved agent contract's lines at spec time
- **Category**: process
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-15.md
- **Rule**: When a spec or analysis note states a safety premise spanning multiple agent contracts — for example that two roles read the same frozen tree — it quotes the governing lines of every involved agents/*.md file and reconciles them premise by premise, and an unverified symmetry assumption such as 'both should be read-only' is a freeze blocker, not a default.
- **Why**: A concurrency investigation enumerated five contract surfaces for a parallel-review design and still missed a sixth — one role's test-only edit permission colliding with another role's unpinned working-tree read — which surfaced only in a late review round, because the premise that both readers see the same tree had been assumed symmetric instead of checked against each contract's actual lines; this is the assumption-time counterpart of the existing parallel-surface symmetry-table lesson, which fires when a norm is changed rather than when one is presumed.
- **How to apply**: When pm-spec freezes a spec whose design or analysis rests on multi-role assumptions (concurrency, shared trees, parallel gates), add a premise table quoting the relevant line of each involved agents/*.md file next to each premise, and refuse to freeze while any premise row lacks its quotation.

## 2026-08-16 — A triage that classifies the requester's own headline example as not-yet re-presents that classification, with the requester's verbatim words, at the next human gate
- **Category**: process
- **Applies-to**: tech-lead, pm-spec
- **Scope**: loop
- **Status**: superseded
- **Superseded-by**: 2026-08-31 — A scope or cost qualifier in the requester's canon survives every relay leg verbatim; dropping it converts the approved plan's premise silently (supersedes the headline-example triage entry)
- **Source**: .shell-team/retros/2026-08-16.md
- **Rule**: When an investigation or triage classifies the requester's own originating ask — the headline example they stated in their own words — as not-yet or out-of-scope, that classification is re-presented at the next human gate together with the requester's verbatim words; the fact that the classification happened, not its correctness, is what must reach the requester, because a locally sound triage that never returns to the origin silently converts the requester's budget into work they did not ask for.
- **Why**: The requester's originating example — splitting implementation work across multiple engineer instances to halve implementation time — was classified not-yet by a tier triage, and the gap between what was asked and what proceeded (verification-phase fan-out) crossed one planning approval and roughly ninety hours without ever being shown back with the original words; measurement later confirmed the requester's instinct (the implementation phase was the largest single wall-clock share of the cycle). The requester named it a textbook tree-swing failure: the client watching cost spent on something other than what they asked for.
- **How to apply**: The routing map or spec that consumes a triage result checks whether the originating request's headline example survived into scope; where it did not, the next human-gate presentation (planning approval, batch GO) carries a line quoting the requester's original words and stating which part is deferred and where it is tracked. A planning approval that cannot state the origin trace is incomplete.

## 2026-08-16 — Review depth is priced by the artifact's consumer and stakes, at freeze and again in every review briefing (supersedes the analysis-note verdict-scope entry)
- **Category**: process
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-16.md
- **Rule**: Review depth is a priced decision made from the artifact's consumer and stakes — shipped code an adopter executes earns adversarial depth, an internal note or a development-time test scaffold does not — and the pricing is stated twice: once at freeze (the spec's verdict-scope block, for analysis-class deliverables) and again in each round's review briefing, which names the consumer class of what is under review; a briefing that omits the consumer class invites shipped-code depth by default, and an arms race against a static defence mechanism ends by re-scoping its claim, never by one more round of strengthening.
- **Why**: The freeze-time half of this rule already existed (the analysis-note verdict-scope entry this one supersedes) and worked where it applied; the class then recurred on a different axis — round-by-round review briefings for a tripwire test repeatedly requested full shipped-bin adversarial angles, and each strengthening round produced new count-and-order-preserving defeat mutants until the operator interrupted and the claim was re-scoped to what a static check can honestly promise. The generator was the briefing author's omission, not the reviewer's judgment: the reviewer correctly applied the depth it was asked for.
- **How to apply**: pm-spec writes the verdict-scope pricing into analysis-class specs at freeze, as before; the orchestrator's review briefing additionally names, every round, whether the artifact under review is adopter-executed shipped code, shipped prose, or development-time scaffolding, and what severity calibration follows; when consecutive rounds against one static defence each produce new adversarially-constructed bypasses, the disposition is to re-scope the defence's stated claim rather than strengthen it again.

## 2026-08-16 — An agent collects its own background children synchronously, because a completion notification is not guaranteed to arrive
- **Category**: process
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-16.md
- **Rule**: An agent that launches a background child — a sub-process, a monitored job, a second executor pass — collects that child's result synchronously (reading its output artifact, polling with a bounded loop and an explicit timeout) and never ends its turn waiting for a completion notification, because inside a sub-agent the notification channel is not guaranteed to deliver; this is the launched side's counterpart of the existing launch-side liveness-check rule, which governs whoever starts the agent, not what the agent does about its own children.
- **Why**: Two roles in one cycle — a cross-provider reviewer and an engineer — independently ended their final message with "waiting for the background task's completion notification" and stalled there; both were recovered only by an external nudge. After the coordinating layer began stating "collect background work synchronously; do not wait for notifications" in every launch briefing, the class did not recur for the rest of the cycle.
- **How to apply**: A role that starts background work inside its own run schedules its own bounded collection — poll the output file, cap the wait, and on expiry either re-run the work in the foreground or disclose the gap in the hand-off — and treats "no notification yet" as no information; the coordinating layer keeps the synchronous-collection sentence in its standard launch briefing.

## 2026-08-16 — Mechanizing the count does not mechanize the enumeration: whole-set claims recur until the claim inventory itself is command-derived
- **Category**: verification-discipline
- **Applies-to**: engineer, qa-verifier
- **Scope**: maintainer
- **Bound-in**: bin/derive-populations.sh
- **Status**: active
- **Source**: .shell-team/retros/2026-08-16.md
- **Rule**: A helper that derives populations and counts closes only the arithmetic half of the whole-set-claim class; which claims exist to be checked — the inventory of every all/every/none/count assertion in a record — is a second population that recurs as hand-swept prose until it too is command-derived, so a record-heavy task enumerates its own claim sites mechanically (a grep over the record's own sections) and attaches a reproduce command per site, not only per count.
- **Why**: The cycle after the population-derivation helper shipped, the same defect class recurred four times in one task's reporting — unexecuted matrix rows, a count off by one, an analogy-reasoned cell — and converged only under an operator ruling; the helper had mechanized the computation while the selection of what to compute stayed manual, which is the same generator one level up.
- **How to apply**: When a task's record states multiple set or count claims, the engineer derives the claim-site inventory itself with a command (grep over the engineer-owned sections), fills a reproduce command per site, and QA re-runs the inventory command before trusting any per-site verdict; mechanizing this as a checklist or checker is a candidate next-task.

## 2026-08-17 — A frozen zero-at-base premise about borrowed vocabulary is measured at the branch point, never inferred from the task's own coinage sweep
- **Category**: verification-discipline
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-17.md
- **Rule**: When a spec frozen on a stacked branch asserts a literal count premise (especially `= 0`) about a string token's occurrences at the branch point, and that token is generic, reusable vocabulary (an invariant-lock id, a status flag, any name coined by another document) rather than a coinage unique to this task, the freeze-time premise sweep measures that count at the branch point independently — a sweep scoped to "the new literals this task introduces" says nothing about tokens already carried onto the stack by merged sibling tasks.
- **Why**: T-1080's AC5 froze "`both-gates-green` occurs zero times in `skills/run/SKILL.md` at the branch point"; the token was borrowed from another document's vocabulary and two merged tasks (T-1074/T-1077) had already written it there, so the criterion was unsatisfiable by construction — the engineer escalated BLOCKED and a class-B re-freeze converted it to a base-relative delta. The adjacent corpus entry (write accounting criteria as base-relative deltas, never absolute literals) governs how to write the criterion; this entry governs what the freeze sweep must cover, which is where the defect actually entered.
- **How to apply**: pm-spec's premise sweep classifies every literal count premise as own-coinage or borrowed; borrowed ones get a live measurement command against the branch-point blob quoted in the spec's Assumptions before the freeze, and the orchestrator's freeze attestation treats an unmeasured borrowed-vocabulary count premise as a broken check line.

## 2026-08-17 — A quantitative conclusion's QA PASS is necessary, never sufficient: the conclusion holds when the cross-provider re-derivation reaches it independently
- **Category**: verification-discipline
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-17.md
- **Rule**: For an acceptance criterion whose substance is a narrative conclusion derived from numeric substitution — a break-even inequality's direction, a cost comparison's basis, a specific measured figure's provenance — QA's `PASS` gates progression but does not settle the conclusion; the conclusion is treated as settled only when the cross-provider review's independent re-derivation reaches the same direction from the same recorded inputs. This entry retires when script-generated record tables (issue #268) remove the recall-written numeric prose it guards.
- **Why**: Three times in one cycle (T-1078 rounds 1 and 2, T-1079 round 1), and in earlier cycles before it, the cross-provider reviewer caught a quantitative defect QA had passed — a conclusion contradicting its own inequality, a fabricated substitution of an unobserved value, a units mismatch, a non-reproducing derivation. QA's arithmetic re-checks verify the computation and stay blind to what is being compared; the second model family substituting the numbers itself is the only verification that has repeatedly caught this class.
- **How to apply**: The orchestrator's QA briefing for any task carrying such criteria names them and states that their PASS is provisional; the review briefing asks the reviewer, by name, to substitute the model's own recorded numbers into its own inequality and check the conclusion's direction; neither gate is skipped because the other already ran.

## 2026-08-17 — CI-equivalence is scoped by mechanically reverse-mapping edited files to the suites that read them, never by a conditional trigger someone remembers
- **Category**: verification-discipline
- **Applies-to**: pm-spec, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-17.md (post-retro addendum, ratified 2026-08-17)
- **Rule**: When a task edits shipped files, the set of CI-wired suites its verification must run is derived mechanically — reverse-map each edited path to the suites that read it (`grep -rl -- '<edited-path>' tests/*/run.sh` plus the workflow's dogfood steps naming it) — and that derived list is the reached-steps scope; a conditional full-suite trigger ("run everything only if X changed") silently under-scopes whenever a suite reads a file for its own reasons the condition never anticipated.
- **Why**: T-1080 edited `agents/codex-reviewer.md`; `tests/codex-skeleton-hygiene/run.sh` reads that file and contracts marker→command adjacency inside its fenced blocks. The spec's CI-equivalence clause named two reached suites explicitly and gated the full list behind a loop-guard-executable-change condition that never fired, so three QA rounds and three review rounds all passed a diff that CI then failed — the machine gate was the last line of defence for a scoping decision every human-shaped reviewer had accepted.
- **How to apply**: pm-spec writes the reached-suite list into the spec by running the reverse-map command over the task's declared file set and quoting it; QA re-runs the same command at verification time against the actual diff's file list and treats any suite present in its output but absent from the spec's list as reached, running it rather than arguing scope.

## 2026-08-20 — A closure declaration over a byte-locked record's own completeness claims is unverified until an independent, differently-worded signature grep accompanies it
- **Category**: verification-discipline
- **Applies-to**: engineer, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-20.md
- **Rule**: Once a defect class has recurred even once against a record's self-referential provenance or completeness claims ("resolved", "verbatim", "every X", "swept everywhere"), the next round that declares the class closed attaches the executed grep signature and its hit counts to the hand-off — including a broadened re-grep that searches for the same claim in vocabulary the earlier rounds did not use — or the declaration is treated as unverified and the round does not close.
- **Why**: One sprint enacted this twice: a four-recurrence evidence-claim class closed only when a mechanical signature enumeration replaced prose sweeps that had missed four times, and two tasks later a class-sweep declared complete over "every sibling line" missed a restatement of the disputed comparator sitting in a section the sweep's tables never scoped — caught only by a verifier's own whole-file grep for the signature word. The adjacent corpus entry on command-derived claim inventories governs the author's side; this entry governs the verifier's side — how the next round re-verifies a closure declaration, and specifically that it must re-grep with different wording than the closing round used.
- **How to apply**: The orchestrator's rework instruction for any recurred class names the closure requirement (attach the signature, the hit list, and the per-hit disposition); QA and the cross-provider reviewer re-run the signature themselves plus at least one broadened variant, and treat a closure hand-off without an executed signature as an open finding rather than a judgment call.

## 2026-08-20 — An executor's self-classification of its own action into a governance vocabulary is structurally weak: run the classifier before the attestation
- **Category**: verification-discipline
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-20.md
- **Rule**: When the party about to take an action also classifies that action into a closed governance vocabulary that decides who may approve it (class-M's standing delegation versus class-B's mandatory human GO, or any successor scheme), that self-classification carries a structural bias its own process cannot detect; the mechanical classifier runs and its verdict is read before any self-attested authority is exercised, and where the classifier's verdict lands the action in a human-gated class, the escalation happens before the action, not after a reviewer catches it.
- **Why**: An orchestrator planned a re-freeze as class-M under the standing grant, wrote the plan into its own records, then ran the classifier — which measured class-B — and proceeded on self-attested ratification anyway, reading an adjacent precedent as license; only the cross-provider review's Blocker surfaced that the shipped rule reserves class-B for a human GO, and the operator had to ratify retroactively. Every artifact of the miss was self-produced and self-consistent, which is exactly why the executor's own process could not catch it.
- **How to apply**: Before exercising any standing delegation whose boundary is a classification, the orchestrator runs the boundary's mechanical check first and quotes its verdict in the attestation; a verdict naming a human-gated class converts the step into an escalation with the measured ground attached, and an attestation that classifies without quoting a classifier run is itself a finding.

## 2026-08-20 — A fan-out's per-call timeout sized only from uncontended single-unit cost does not absorb N-way contention inflation
- **Category**: verification-discipline
- **Applies-to**: pm-spec, engineer
- **Scope**: maintainer
- **Bound-in**: skills/run/SKILL.md
- **Status**: active
- **Source**: .shell-team/retros/2026-08-20.md
- **Rule**: When a fan-out spec freezes a per-call harness timeout for its instances, sizing it above the serial pre-arm cost pass's largest single-unit cost is not sufficient: under N-way contention the same unit's cost inflates past its uncontended ceiling, so the frozen protocol either measures a contended sample before fixing the value or states an explicit contention factor over the uncontended maximum, and records which of the two it did.
- **Why**: A live 8-way firing sized its per-call timeout at 600 s over a measured uncontended maximum of 435.8 s; two units exceeded the window under contention and survived only because the harness moved the calls to tracked background continuations — an accident of harness behavior, not a property the protocol had provided — and the recovery path itself then produced a duplicate-claim incident via a false orchestrator premise about what the backgrounded call had written.
- **How to apply**: A spec freezing fan-out mechanics carries either a contended-sample measurement beside its uncontended cost pass or an explicit multiplier with its ground stated; the freeze sweep treats a per-call timeout justified only by the uncontended maximum as an unsatisfiable-under-load clause and routes it back before the freeze.

## 2026-08-22 — Two consecutive review rounds of hypothetical-defeat Majors against a dev-scaffold's own inline guards signal a mispriced gate, not a third patch round
- **Category**: process
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-22.md
- **Rule**: When a spec's own inline check lines draw Major findings for hypothetical defeats — rather than for a wrong computed value, a wrong conclusion direction, or a real instrument defect — for two consecutive review rounds, the orchestrator re-examines whether the review's Major bar for that artifact class is priced at product-surface adversarial depth before authorizing a third patch round: a hand-written finite guard reviewed adversarially never converges, because each repair grows the attack surface it exposes.
- **Why**: One sprint spent two full tasks and five adversarial review rounds on the same guard-weaker-than-prose class (Majors growing 2 to 4 to 6) across two structurally different remedies — a full-population check-line sweep under a class-M re-freeze, then an operator-ratified claim re-scope under class-B — while QA passed every round and the shipped, tested bin/ checkers were never defeated; the loop closed only when the operator re-priced the review scope for dev-only scaffolding (inline check lines reviewed for computed values, conclusion direction and real instrument defects; guard-completeness not a Major class), after which three tasks closed in one to three substance-only rounds each.
- **How to apply**: The orchestrator classifies each round's Majors as computed-value, conclusion-direction or instrument defects versus guard-completeness before writing the rework instruction; two consecutive guard-completeness rounds convert the next step into a pricing question for the operator (or the standing re-pricing rule where one exists) instead of another rework round, and the mechanism alternative (a tested shared checker replacing inline one-liners) is filed as its own tracked issue rather than patched per round.

## 2026-08-22 — A stale completion notification that resumes an agent revives its write access; the resumed agent verifies the checkout's branch matches its own task before writing
- **Category**: process
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-22.md
- **Rule**: An agent resumed by a background-task notification after its task's board flag has already advanced past the state the notification was for treats its write access as revoked: it verifies the shared checkout's current branch matches its own task before writing anything, reports instead of acting when the branch does not match, and never self-corrects a cross-branch write with checkout, cherry-pick or reset on its own authority.
- **Why**: A reviewer agent resumed by stale notifications after its verdict was already processed committed an addendum onto another task's branch in the shared checkout; the recovery was lossless precisely because the agent then held its write boundary — it stopped and reported rather than attempting git surgery — and the coordinating session cherry-picked the commit to its correct branch and reset the polluted one inside a clean-tree window before the other task's engineer had committed.
- **How to apply**: Every write-capable role's briefing carries the branch-check-before-commit obligation (git branch --show-current compared against the task's own branch immediately before any commit, with the output quoted in the hand-off); an agent resumed after its own hand-off treats any further write as requiring that check plus a statement of why the write is still its task's to make.

## 2026-08-22 — A stacked cycle whose chain contains a BLOCKED, unmerged predecessor still reconstructs its retro window from the stacked-on lines, never from merge history
- **Category**: process
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-22.md
- **Rule**: Adjacent to the existing stacked-batch-cycle entry, extending it to chains where a link went BLOCKED and returned to planning — and applies-to reads all because the retro writer (scrum-master) sits outside the playbook role enum: the chain does not rebase onto the default branch when a link stops, so the retro's cycle window is reconstructed from each in-scope task's own stacked-on board line, each adjacent link verified with git merge-base --is-ancestor, and merge-commit history — which returns zero or foreign commits for such a cycle — is never used as the window.
- **Why**: A retro over a five-task cycle whose chain held two BLOCKED, unmerged predecessors found the merge-history window reporting 139 foreign merges from the default branch; the retro was accurate only because the window was rebuilt from the board's stacked-on lines with per-link ancestry checks, and the foreign merge window was pasted verbatim but explicitly flagged as foreign rather than silently adopted.
- **How to apply**: When any in-scope task reads BLOCKED, or the board names unmerged stacked-on predecessors, the retro writer rebuilds the cycle window from those lines plus adjacent ancestry checks before reading any input, and any tool-reported merge window is quoted as flagged-foreign rather than used.

## 2026-08-22 — A hand-off's self-reported tally that required counting is independently recounted by the receiving gate before the round closes
- **Category**: verification-discipline
- **Applies-to**: qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-22.md
- **Rule**: Narrowing the existing do-not-take-self-reports-at-face-value entry to numeric tallies, for QA and equally for the cross-provider review round it hands off to: any count in a hand-off that required actual counting — rather than verbatim transcription from a command's own output — is recounted by the receiving gate with its own command before the report is accepted, and once one tally in a hand-off is caught wrong, the same hand-off's other counted tallies are recounted too rather than only the flagged one.
- **Why**: One sprint reproduced the pattern twice, at two different gates on two different tasks: a QA round failed on a sweep tally whose own sentence contradicted it (twelve-passed-zero-failed written beside two named failures), and a cross-provider round caught a named-steps count off by one — both consistent with the earlier operator-memory finding that self-report error tracks how much of the number required counting versus copying.
- **How to apply**: The receiving gate identifies the counted-not-transcribed values in a hand-off and recounts each with a command of its own; after any one wrong tally, the orchestrator's kickback instruction names the recount-the-rest obligation for that hand-off explicitly.

## 2026-08-24 — A hand-rolled text-extraction gate that still yields new independent defeats after two design-level rewrites is not closable by a fourth patch
- **Category**: process
- **Applies-to**: all
- **Scope**: maintainer
- **Bound-in**: CONTRIBUTING.md
- **Status**: active
- **Source**: .shell-team/retros/2026-08-24.md
- **Rule**: When a mechanical gate classifies free-form markdown headings or verdict strings through ad-hoc normalization, and a third independent defeat class appears after the component has already absorbed two full design-level rewrites, the orchestrator does not authorize another patch round: the next step is the pre-priced removal disposition, and the follow-up issue's acceptance criteria are seeded with the accumulated defeat list verbatim rather than a summary of it.
- **Why**: One close-out backstop absorbed six independently-reproduced defeats across six rounds — internal whitespace, a leading-whitespace boundary defeat in the false-PASS direction, a CRLF record invisible to heading detection, a zero-width/U+00A0 heading defeating both judgments — spanning two rewrites (single-normalization extraction, then CR-strip plus three-way fallback), with QA's own final assessment naming a structural ceiling. The learning was determined by the second defeat; rounds three through six were confirmation bought at one operator ruling each.
- **How to apply**: The orchestrator tracks defeat classes per component across rounds; at the third independent defeat following the second rewrite, it executes the drop disposition on its standing authority and files the carve-out issue with every defeat cited as a requirement, so the next design attempt starts from the complete adversarial map.

## 2026-08-24 — A scratch-clone venue fix scoped to one named branch does not close the class: enumerate every branch literal in the read-set before trusting a FAIL
- **Category**: verification-discipline
- **Applies-to**: qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-24.md
- **Rule**: A fresh `git clone` carries the source checkout's local branches only as remote-tracking refs, so any check line that resolves a branch-name literal (`git merge-base <branch> HEAD` or similar) fails structurally inside the clone; before trusting any check-line FAIL in a scratch clone, the runner greps the full spec and read-set for every branch-name literal a base-ref discriminator can name and recreates each one as a local branch at its correct SHA — fixing only the branch the current failure names leaves the identical mechanism armed for the next literal.
- **Why**: The class bit twice in one task's two consecutive rounds: the first fix recreated the one stacked sibling branch the task depended on, and the very next round the same mechanism produced a false FAIL against `develop` itself, because the fix's mental model ("recreate the branch this task needs") had not generalized to "recreate every literal any discriminator names."
- **How to apply**: The scratch-clone routine carries a standing pre-check step — grep the read-set for branch literals, recreate all of them, then run the checks — rather than relying on remembering the generalized class each time a new discriminator appears; a FAIL observed before that step has run is treated as unmeasured, not as a result.

## 2026-08-24 — Name the drop order and its trigger inside the frozen spec at authoring time, before any review round runs
- **Category**: process
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-24.md
- **Rule**: When a spec's scope contains a component identifiable at authoring time as adversarially fragile or environment-dependent, pm-spec writes the component's Droppable-Nth position and the exact trigger condition into the frozen document before the first review round; when the trigger later fires, executing the drop requires only confirming the trigger's factual precondition — never inventing a disposition mid-task.
- **Why**: A criterion pre-named Droppable-3rd had its trigger (two consecutive rounds each landing an independently-new Major on the same component) actually fire, and the execution cost zero new design judgment and zero host escalation — while an earlier component in the same sprint with no pre-priced disposition consumed six rounds and six operator rulings discovering one defeat at a time before the same conclusion was reached.
- **How to apply**: At spec completion, pm-spec asks which in-scope components are predictably fragile (hand-rolled parsing, live-environment execution, adversarially-reviewable guards) and prices each with a drop order and trigger in the freeze; the orchestrator treats a fired trigger's disposition as the default requiring only factual confirmation, and treats a mid-task drop proposal with no pre-priced disposition as the signal that the spec missed this step. When a trigger counts consecutive independently-new findings, the factual confirmation includes a written classification, made before the trigger decision: is the new round's finding independently new, or a propagation gap introduced by the previous round's own fix? A trigger ruling taken without that written classification is treated as a mis-fire — one cycle exercised this exact call twice on one task, and both times the written classification is what kept a fix's own side effect from advancing the trigger.

## 2026-08-24 — Quantity-claim defect risk tracks a role's exposure to writing raw numeric literals, not the role's identity
- **Category**: verification-discipline
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-24.md
- **Rule**: A role whose standard output format requires transcribing bare numeric literals — population counts, round tallies, byte deltas — will accumulate nearly all of a corpus's quantity-claim defects by construction, regardless of which role or model it is; lessons and checkers about recording accuracy therefore weight exposure (the number of occasions a role writes such a literal) above role identity, and the structural remedy is designs that derive numbers from embedded commands (`- reproduce:` / `- command:` lines) instead of asking anyone to copy them.
- **Why**: An operator-side analysis of record-accuracy defects found they tracked exposure rather than identity, and the sprint that promoted this entry still shipped artifacts carrying heavy hand-transcribed counts (an 18-item read-set, a 98-population sweep, a six-round defeat tally) whose accuracy rests on the same discipline that analysis found erodes under repeated recall — while the same sprint's command-derived numbers carried no such defects. The lesson's first cycle in force then reproduced the pattern twice more in the same authoring seat: a spec's own prose stated six registry rows where five existed and thirty-three lines where thirty-two existed (the thirty-three traced to reading a file reader's last displayed row number as a line count), failing a QA round outright; and a count-premise table's hand-derived working-tree tally was retracted by its own freeze sweep as hand-derived from a read rather than produced by the stated command — both caught downstream, neither at the keyboard.
- **How to apply**: When authoring a spec, a check line, or a lesson that involves recorded quantities, prefer the command-derived form so the number is recomputed rather than remembered; when auditing for quantity defects, rank artifacts by literal-writing exposure rather than by which role produced them. At authoring time specifically: the moment a bare numeric literal describing a count, a line number, or a row tally is written into prose, either co-locate the command that derives it or explicitly flag the value for the freeze sweep to re-derive before the intent hash is recorded — an unflagged hand-written count is the defect itself, not merely a risk of one.
- **Extended by**: 2026-08-30 — broadened beyond numeric literals to any value re-recorded across rounds (model labels, dates, environment identifiers): repeating the previous round's recorded value is generation, not recall, so each round re-measures the value from its source. Measured case: a reviewer transcribed one model label unchanged for three consecutive rounds until round 4 read the live config and measured a different model; every later round then carried an explicit re-measured-not-repeated note. Role Rules for repeat recorders state "never repeat a prior round's value without re-measurement". Source: `.shell-team/retros/2026-08-30.md`.
- **Extended by**: 2026-08-31 — the relay leg is now a measured recurrence site of its own, and prose discipline alone did not close it: with this entry in force, one sprint produced at least four relayed-count defects across three roles (an orchestrator relay got a tally and a divergence direction wrong in one task, a coordinator relayed "+4" where the measurement said "+3", an engineer hand-off said "9 new" where QA's independent re-measurement in a scratch worktree found 8), on top of an earlier-sprint precedent ("11 sites" where 10 existed). The consumer-side half of the remedy is therefore stated explicitly: a downstream consumer (board hand-off reader, QA verdict, retro) re-derives a relayed count from its co-located command instead of quoting the prose number, and a relayed count arriving with no derivation command is handled as the defect, not as data. Promoting this remedy from prose to a checker is filed as its own backlog item. Source: `.shell-team/retros/2026-08-31.md`.
- **Extended by**: 2026-09-02 — the checker that mechanized the numeric half (count lines carrying a derivation command) caught its own author three times on its first day in force, and the same sprint showed the non-numeric half of the class recurring twice independently: cardinality and kind claims relayed as words ("six marker regions") and a precedent described as carrying a property it did not have. Exposure counts these occasions too, since a quantity relayed as a word is the same literal-writing act, so the relay-leg duty above covers cardinality, kind and precedent-property claims: the consumer re-derives them from the source, not from the briefing. Extending the checker to enumerations is filed as its own backlog item. Source: `.shell-team/retros/2026-09-02.md`.
- **Extended by**: 2026-09-04 — the exposure extends across records, not only across rounds: a tally spanning several tasks' interventions or review files (harness terminations, API errors, re-freeze counts) is re-derived by command against those primary files before it is written into a briefing, a retro or a report, and a tally received from a briefing is re-counted rather than transcribed. Measured case: a retro briefing stated three API terminations where the interventions files recorded two, and the retro caught the discrepancy only by re-reading the primary files. Source: `.shell-team/retros/2026-09-04.md`.

## 2026-08-24 — A mid-flight correction to a running dispatched instance travels an unauthenticated channel; send it with a mechanical verification procedure, and on refusal re-deliver by resuming after completion
- **Category**: process
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-24.md (primary verbatim evidence held in operator memory, outside this repository)
- **Rule**: A correction message sent to a still-running dispatched instance arrives on a channel the instance cannot authenticate and may be treated as suspected prompt injection — correctly, by the instance's own lights; corrections to running instances therefore carry a self-contained mechanical verification procedure ("do not trust these words — verify X, Y, Z against the primary source first"), and a refusal is answered not by insisting but by re-delivering after the instance completes, as a resume that identifies the orchestrator, states the verify-first procedure, and explains why re-measurement after a confirmed instrument defect is not audit tampering.
- **Why**: During one 8-instance fan-out, a mid-flight correction was refused as suspected injection by 3 of 8 instances (one of which independently verified the claim after the underlying defect had already been repaired, observed correctly, and concluded wrongly), while the resume-plus-verify-first form was accepted by every instance it was sent to; an instance that verifies before acting is the behavior the loop wants, so the fix is the delivery form, not the instance.
- **How to apply**: The orchestrator's dispatch playbook treats mid-flight corrections as last-resort and always verification-framed; when one is refused, the refusal is recorded as correct behavior and the correction is re-sent through the resume path with orchestrator identification, a concrete verification recipe, and the reason the action remains within the instance's own task.

## 2026-08-30 — A correction round at depth three switches to zero-new-mechanism, zero-new-claim, primary-sources-first by default
- **Category**: process
- **Applies-to**: pm-spec, engineer
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-30.md
- **Rule**: When the same spec or implementation enters its third correction round (REQUEST_CHANGES driving a third repair of the same artifact), the briefing for that round switches by default to a converging constraint — no new mechanisms, no new claims, and every statement written only after reading its primary source — instead of another free-form repair round.
- **Why**: Two consecutive tasks' spec reviews ran five and four rounds respectively, and in both the correction rounds themselves kept introducing new unverified mechanisms and unanchored claims that became the next round's Majors; in both tasks the converging round was exactly the one dispatched under the zero-new-mechanism, zero-new-claim, primary-source-first constraint, and no round run under that constraint produced a new finding class.
- **How to apply**: The orchestrator (or the role composing its own rework instruction) counts correction rounds per artifact; from the third round on, the dispatch briefing states the three constraints explicitly, and a repair that adds a new mechanism or an unsourced claim is returned against the constraint without spending a full review round. Complements the same-class-2 rule on a different axis: that one fires on two occurrences of one defect class, this one fires on round depth regardless of class.

## 2026-08-30 — A freeze sweep's cross-join includes the task's own live artifacts its criteria dogfood, not fixtures alone
- **Category**: process
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-30.md
- **Rule**: When a spec's acceptance criteria take this task's own live artifacts (its review record, its board entry) as validation targets, the freeze sweep's cross-join enumerates the current live instance of each such artifact as a first-class member of the mutual-satisfiability check — sweeping fixtures and criteria alone can pass a freeze whose criteria are jointly unsatisfiable against the real record they dogfood.
- **Why**: One task's freeze sweep caught a self-reference blocker before freezing, but the very next task's sweep passed a freeze whose per-record trigger criterion was jointly unsatisfiable with the pre-mechanism sections its own review record already carried and with the spec's Non-goals; the contradiction surfaced only in implementation review round 1 and cost a host-ratified class-B re-freeze — one full round — to repair.
- **How to apply**: At freeze time, whoever runs the sweep lists every criterion whose subject is an artifact this task itself produces or mutates, opens the current live instance of each, and runs the cross-join against those instances' actual contents; a sweep that checked only fixtures for such a criterion records that gap instead of attesting the freeze.

## 2026-08-30 — A record field capturing verbatim invocations or paths states its normalization convention at design time
- **Category**: security-pii
- **Applies-to**: pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-30.md
- **Rule**: When a new field in a role's record format captures verbatim command invocations, paths, or environment strings, the change that introduces the field also states its normalization convention (for example, replacing the checkout's absolute path with a placeholder such as <repo-root>) — the convention is never left for the first leak to establish.
- **Why**: A newly added executor-invocation field wrote the operator's real home path into a review record twice; the PII-shape checker caught both before push, and the repair had to retrofit a normalization convention across three files at once (the role definition, the checker's header, the adopter docs) — a convention that would have cost one line if stated when the field was designed.
- **How to apply**: Whenever a spec introduces a record field whose value is captured verbatim from a live environment, the spec names the normalization rule and its placeholder vocabulary beside the field definition, and the reviewer treats a verbatim-capture field without one as a finding.

## 2026-08-31 — A reverse-mapped candidate set is a lower bound on a mechanism-class sweep's population, never the population
- **Category**: verification-discipline
- **Applies-to**: pm-spec, qa-verifier
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-31.md
- **Rule**: When a mechanism-class sweep's population is mechanically enumerable, reverse-mapping from the task's edit paths to candidate members is a prioritization heuristic, not a scope cut: the reverse-mapped set is a lower bound on the affected population, and where an isolation precondition makes parallel slices constructible in-session, the sweep runs the full population; a sweep cut down to the reverse-mapped subset records that cut as a disclosed lower-bound gap instead of presenting the subset as coverage.
- **Why**: One task's QA verdict reverse-mapped the edit paths to four candidate members and argued sufficiency from that set, but of the five real disclosed flips, two lay outside those four members and were caught only by the 113-member full-population sweep; the same full sweep, run as six parallel slices, completed both arms in 92 minutes against a ~6h serial projection, so the full population was affordable in exactly the situation where the targeted argument failed. The adjacent CI-equivalence rule (reverse-mapping edited files to the suites that read them) is unaffected: that rule mechanizes which suites must run, this one says the resulting candidate set does not bound which members can flip.
- **How to apply**: At freeze time the sweep design names the full enumerable population and the isolation precondition for slicing it; QA runs the full population when slices are constructible, and treats a reverse-mapped subset as acceptable only with the lower-bound gap stated in the verdict. A verdict that argued sufficiency from a reverse-mapped subset and later meets an out-of-subset flip records the miss as this class.

## 2026-08-31 — A scope or cost qualifier in the requester's canon survives every relay leg verbatim; dropping it converts the approved plan's premise silently (supersedes the headline-example triage entry)
- **Category**: process
- **Applies-to**: tech-lead, pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-31.md
- **Rule**: The superseded entry's duty — re-presenting a not-yet classification of the requester's headline example, with their verbatim words, at the next human gate — broadens to every scope or cost qualifier in the requester's canon (an issue body's "cheap version", a stated budget, an explicitly smaller alternative): each relay leg between the canon and a consuming role carries the qualifier verbatim, and where a briefing instructs verbatim carriage of a source, summarizing that source is a relay violation regardless of the summary's apparent fidelity, because the qualifier is precisely the signal a summary drops first.
- **Why**: The headline-example form of this failure cost ninety hours before its 2026-08-16 promotion; the broadened form then recurred on a different limb — a routing map instructed verbatim carriage of an issue body whose canon said "cheap version", the briefing summarized it instead, and the spec, receiving no cost signal, resolved a decision point toward the larger build under a standing default. The approved plan's version premise broke at that freeze, nothing re-derived it, and the break surfaced only at GO-package assembly; the operator ruled that a broken plan premise lapses the approval itself, making everything past that point unapproved work.
- **How to apply**: The relay author checks, before dispatch, whether the source canon carries a scope or cost qualifier and whether the briefing was instructed to carry the source verbatim; either condition makes verbatim carriage mandatory for that leg. Downstream, a spec that resolves a sizing decision point cites the qualifier it resolved against, and the freeze-time version re-derivation (its own ruled mechanism) treats a missing qualifier citation on a sizing decision as reason to stop and re-check the canon before declaring scope.

## 2026-09-02 — A planning-time version derivation applies the two tests to each backlog item separately and takes the sprint tier as their maximum; a bucket verdict over the whole backlog is not a derivation
- **Category**: process
- **Applies-to**: tech-lead,pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-09-02.md
- **Rule**: When a plan, sprint, or train carries more than one item and a release tier is derived for it, the headline test and the default-reachability test are applied to each item against its own canon (issue body, shipped README claim, shipped default), the per-item results are recorded as a table, and the tier is the maximum of that column; a single sentence judging the whole backlog is a relay of an impression rather than a derivation, and a later freeze-time re-derivation then compares against a premise that was never derived.
- **Why**: An approved sprint premise of PATCH ('every item internal-mechanism') was written as one bucket sentence over five items; the third item's issue body had, since before planning, required falsifying a shipped README claim ('Opt-in only') and changing the adopter's default-path behaviour, which derives MINOR under the two tests. The freeze-time gate caught the break mid-sprint, and the operator ruled the detection timing itself the defect: nothing about the item had changed since planning, so a per-item derivation would have found it before approval.
- **How to apply**: At planning, before the approval request is composed, the planner produces one row per backlog item (item, headline verdict, default-reachability verdict, derived tier, one-line ground) and derives the plan's tier from the column; the authoring-time derivation of each task cites its own row as the premise, so a mismatch at freeze points at a specific row rather than at the whole plan.

## 2026-09-02 — A precedent cited as grounds is a claim, not an observation: re-read the source for the exact property asserted, and treat a prior operator-approved derivation as no independent evidence for the next one
- **Category**: verification-discipline
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-09-02.md
- **Rule**: When a briefing, spec, or derivation cites a prior task, version, decision, or record as carrying a property ('the predecessor already pins X', 'the earlier release earned MINOR for the same shape'), the writer re-reads that source for the exact property before writing the citation, and a prior tier or decision the operator approved is recorded as a derivation they ratified rather than as independent evidence for a new derivation, because citing it argues from one's own earlier output.
- **Why**: In one sprint a briefing described a predecessor spec as carrying a property it did not have and the downstream role built on it; separately, a release-tier argument cited an earlier release's tier as precedent, and under operator review the citation had to be withdrawn as self-citation (the earlier tier was itself a derivation the operator had approved, so it could not corroborate the next), leaving the contract-inversion ground to stand alone. Both are the relayed-premise failure with the writer's own past output as the relay source.
- **How to apply**: Before a citation of any prior artifact leaves the keyboard, open the artifact and point to the line that carries the asserted property; in a version or scope derivation, list only grounds that stand without reference to earlier tiers, and if a precedent is mentioned at all, label it as context rather than as a ground.

## 2026-09-02 — A scripted insertion into an append-only record asserts that its anchor matches exactly one whole line before it writes, and re-runs the region's consuming checker immediately after
- **Category**: verification-discipline
- **Applies-to**: engineer,pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-09-02.md
- **Rule**: Any scripted insertion into the board, a spec, or another append-only record anchors on a whole line, counts exact whole-line matches first, and refuses to write unless the count is exactly one; a substring or first-match anchor is not used even when the target looks unique, because frozen criteria routinely quote the very markers later insertions anchor on, and the write is followed at once by the checker that consumes the region so a mis-landing is caught before the next commit.
- **Why**: The same class fired three times in one sprint at the same seat: an intent-hash append mis-placed by a reverse search, then twice a sweep result landing inside a frozen intent block because the derivation END marker was matched mid-line inside a criterion that quoted it. Each time the coupled checker reported drift within a minute and the blob was reverted, but the prose rule re-adopted after each instance did not hold to the next, and a record without a consuming checker would have kept the corruption. The helper that mechanizes the assertion is filed as its own backlog item.
- **How to apply**: When writing or generating an insertion into an existing record, use a whole-line exact match (for example grep -cxF on the anchor) and stop on any count other than one; once the shared insertion helper ships, use it instead; after any insertion into a checked region, run that region's checker before staging the change.

## 2026-09-02 — A ratification gate whose validity test leaves exactly one viable option discloses that option's cost, security and quality risk; when all three are small the presenter proceeds under its own authority and records the decision instead of requesting approval
- **Category**: process
- **Applies-to**: tech-lead,pm-spec
- **Scope**: loop
- **Status**: active
- **Source**: .shell-team/retros/2026-08-31.md
- **Rule**: Before composing a ratification gate, the presenter tests each option for advancing the goal; an option that fails the test is not presented as a choice, and when exactly one option survives the gate states that option's cost, security and quality risk on three named axes: if all three are assessed small the presenter proceeds under its own authority and records the decision with the three assessments, and if any is not small it requests ratification and names the axis that is the reason.
- **Why**: Twice in one sprint the operator corrected a class-B gate: once because untested options were presented as a neutral menu beside the only viable one, and once because the gate disclosed evidence and scope but not the three risk axes the operator actually decides on, ruling that a request for approval owes those risks and that a unique low-risk choice should question whether approval is needed at all. The operator adopted this rule as stated at the following planning.
- **How to apply**: When a freeze, re-freeze, or scope gate is about to be presented, write the validity-test result per option first; with one survivor, add the three-axis assessment to the gate text and route by it: record-and-proceed when all three are small, ratify with the named axis otherwise.
