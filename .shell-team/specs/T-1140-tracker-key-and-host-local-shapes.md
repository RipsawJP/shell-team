# Issue-tracker key and machine-local host name become mechanical findings

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1140

## Problem

`bin/check-pii-shapes.sh` gates a change on the shapes a loop record is most likely to pick up from the environment it runs in — a mailbox, a home-directory path, an encoded home segment, a machine-local session path, a private-key header, a credential prefix. Two further environment-derived shapes reach a record just as readily and no shipped rule looks for either: an issue-tracker key, which carries an adopter's tracker namespace into a record that may be published; and a workstation host name in the `.local` form a shell prompt and a system-information command print, which a measurement note or a provenance record can quote verbatim. Neither is a shape a reviewer reliably notices in prose, and both are mechanically detectable — so the gate, not authoring discipline, is where they belong.

The two are not symmetric, and the measurements in `## Blast radius` are what make the asymmetry decidable rather than a matter of taste. The host-name outline has three same-outline tokens in tracked content and a named class closes two of them; the tracker-key outline has dozens, most of them written in the very label vocabulary this plugin teaches its adopters to use.

## Summarized sources

- `bin/check-pii-shapes.sh:1`–`:190` (header comment) — the shape catalogue in the `#   <id>  <text>` form, the exit-code contract (`0` clean, `1` findings, `2` usage or structural error), DP-1's no-literal-in-the-tree rule (`:165`–`:169`), DP-8's per-file other-guard-only known-shapes charter (`:158`–`:163`), DP-10's ratified bias toward firing (`:117`–`:137`), and the fact that `print_help()` (`:229`–`:245`) derives `--help` output from this comment by locating `set -euo pipefail` dynamically. Distinction carried over: the header is the command-line help an adopter reads, so it is an adopter-facing surface rather than commentary, and any new configuration mechanism must be documented in it.
- `bin/check-pii-shapes.sh:273`–`:278` — measured: the rule decomposition sentence reads "There are eleven independently load-bearing rules: seven patterns, plus four exclusions". Distinction carried over: that numeral is *shipped adopter-visible text* that a new rule falsifies, and no shipped check counts it.
- `bin/check-pii-shapes.sh:280`–`:431` (anchoring/boundary inventory) — a standing per-regex audit whose own claim is "every regex this script ships, audited mechanically". Distinction carried over: a new regex with no inventory entry falsifies that claim outright.
- `bin/check-pii-shapes.sh:434`–`:462` — measured: thirteen top-level `^RE_[A-Z0-9_]+=` assignment lines, of which two (`RE_HOME_PATH`, `RE_TEMP_SESSION`) are compositions whose right-hand side references other `RE_` variables, giving the eleven independent rules the header states. Also measured: not one shipped regex uses `\b`; every boundary is written as an explicit character class or alternation. Distinction carried over: the `RE_TEMP_SESSION_ROOT` / `RE_TEMP_SESSION` pair is the established way to make an exclusion provably load-bearing — a broad outline half that a negative control can be shown to reach, composed with the requirement that excludes it.
- `bin/check-pii-shapes.sh:464`–`:483` — `KNOWN_SHAPE_PATHS`, four per-file entries, no directory and no glob. Distinction carried over: it is explicitly other-guard-only and explicitly never this task's own files.
- `bin/check-pii-shapes.sh:547`–`:556` — `scan_content_file()` calls `report_pattern_lines` once per line-level pattern and `scan_email_candidates()` once. Distinction carried over: the candidate-enumerating scanner exists only because the mailbox rule must judge every candidate on a line against per-candidate exclusions; a rule with no per-candidate exclusion needs none of that machinery and joins as a `report_pattern_lines` sibling.
- `tests/check-pii-shapes/run.sh:5`–`:55` — the runtime fragment-assembly discipline, the single `mktemp` work root with one `EXIT` trap (`:67`–`:70`), and the header's own statement of which literal classes may be written directly. Distinction carried over: a placeholder form and a class that cannot carry a real value may be written literally; everything that carries a real shape is assembled at runtime.
- `tests/check-pii-shapes/run.sh:144`, `:155`, `:169` — `assert_finding` / `assert_clean` / `assert_positive_reports`, and `run_checker` (`:134`–`:140`), whose signature already accepts trailing extra arguments and whose child process inherits the suite's environment. Distinction carried over: the POS/NEG idiom asserts the *reported id*, not merely a non-zero exit.
- `tests/check-pii-shapes/run.sh:486`–`:513` (`assert_reaches_temp_root`) and `:627`–`:645` (`assert_reaches_email_candidates`) — the precondition idiom that reads a regex out of the checker's own source to prove a negative fixture is clean because of a *guard* rather than because it never matched. Distinction carried over: this is the only thing that separates "reaches the rule and is correctly excluded" from "never reached the rule at all", and a negative control without it proves nothing.
- `tests/check-pii-shapes/run.sh:800`–`:823` — the placeholder-forms fixture and its assertion label `placeholder forms are not findings (all six documented forms, one change, clean)`. Distinction carried over: that label string is matched verbatim by a merged frozen criterion, so a new placeholder form is added **alongside** it with its own label and never by rewording it.
- `tests/check-pii-shapes/run.sh:955`–`:1017` and `:1019`–`:1084` — `assert_neutralised_pattern_unreported` (seven call sites, measured) and the exclusion-mutation block. Measured: seven `^assert_meta_fails ` call sites. Distinction carried over: both duties are universally quantified over patterns, so a new pattern must satisfy them or falsify the quantifier.
- `docs/pii-controls.md:17`–`:57` and `:81`–`:100`; `docs/pii-controls.ja.md:15`–`:54` and `:76`–`:91` — the adopter-facing shape catalogue (one bullet per pattern id, with no count sentence) and the declared-limitations section. Measured distinction carried over: `docs/pii-controls.md:83`–`:84` and `docs/pii-controls.ja.md:77`–`:78` state that named entities — customer names, internal host names, project codes — cannot be matched by shape and are not covered, and that the patterns which would match them cannot live in this repository because the patterns themselves are the sensitive data.
- `.shell-team/specs/T-111-pii-shape-checker.md:200`, `:206`–`:236`, `:237`–`:244` — measured at their own text: **AC16** requires `--all` to exit 0 on this tree and the workflow to contain no `--all` occurrence; **AC18** and **AC19** match a fixed set of documentation lines **whole-line-exact**, the two named-entity lines in each language among them, and state explicitly that other tasks may add their own lines freely because nothing there constrains the file shape or line count; **AC20** adds the "shapes only" sentence and the badge-compound absence lock; **AC21** requires a same-line `|| true` on every non-comment stderr write. Distinction carried over: the named-entity claim is **whole-line frozen**, so reconciling it is an additive act, never an edit to those lines.
- `.shell-team/specs/T-112-commit-identity-and-ignore-lock.md:163`–`:172` — **AC21** and **AC22** likewise match documentation lines whole-line-exact in both languages. Distinction carried over: the same additive constraint applies to this task's documentation work.
- `.shell-team/specs/T-1051-inspection-ux-polish.md:289`–`:294` and `:313`–`:329` — measured at their own check lines: **AC2** reads `git show e57c287:bin/check-pii-shapes.sh` and asserts the count of `^RE_[A-Z0-9_]+=` lines at HEAD **equals** that pinned base's; **AC5** asserts every line of both documentation files **outside** the `token` bullet is byte-identical to that same pinned base. Distinction carried over: both pin a fixed commit rather than a moving ref, so neither is repaired by time, and both were already falsified by rules and bullets that landed after that pin — this task is not their cause.
- `.shell-team/specs/T-1101-pii-path-shapes.md` — measured at its own criteria: **AC1**'s floor of twelve `RE_*=` lines, **AC3**'s and **AC4**'s floors of seven mutation and seven meta call sites, **AC9**'s verbatim placeholder label, **AC10**'s three value-independent invariants (every `RE_*` variable present in the inventory region; set equality between the ids `scan_content_file()` reports and the ids the header names; absence of three falsified count literals), **AC11**'s documentation assertions, **AC12**'s `KNOWN_SHAPE_PATHS` byte-identity, and **AC14**'s workflow byte-identity. Distinction carried over: every one of those is a **floor or an equality this task must keep satisfiable**, and **AC10**'s id-set equality in particular means a new id must appear in both the header list and `scan_content_file()` or the criterion reds.
- `.github/workflows/check-handoff.yml:28`–`:29`, `:244`–`:245`, `:247`–`:248` — measured: the shellcheck argument list already names both files this task edits under `bin/` and `tests/`; a fixture-suite step runs the suite; a separate step runs the checker diff-scoped with `--base "origin/${GITHUB_BASE_REF:-develop}"`; and the string `--all` appears nowhere in the file. Distinction carried over: **no workflow edit is owed**, and adding one that mentions `--all` would red a merged frozen criterion.

## Goal

<!-- BEGIN intent-block: T-1140 -->

- user-visible: yes — `bin/check-pii-shapes.sh` ships in the plugin and adopters execute it; this task adds a shape their gate will refuse and a configuration mechanism they must know exists in order to turn the other one on, and `print_help()` prints the header comment itself, so the adopter-facing catalogue in `docs/pii-controls.md` and `docs/pii-controls.ja.md` is owed in this same task rather than deferred.
- verification-class: mechanism — this task's diff reaches an executing surface (`bin/check-pii-shapes.sh`'s pattern block and `scan_content_file()`, `tests/check-pii-shapes/run.sh`, and the two CI steps that run both), so every item of the freeze self-check applies as written.
- verification-ceiling: unit-and-static — every criterion below is settled by running the shipped checker, the shipped fixture suite, `shellcheck`, or a scoped `grep`/`cmp`/`git grep` over committed blobs; nothing here needs an adopter machine, a network service or a CI-only surface, and at least **AC1**, **AC2**, **AC6**, **AC7** and **AC10** are verified at exactly this ceiling.
- base-ref-discriminator: not-applicable — this branch has no open predecessor branch; it was cut from the integration branch `develop`, which is its own actual base ref, so every criterion below that reads a base-side blob resolves it as `B=$(git merge-base develop HEAD)` and no two-arm existence test applies.

`bin/check-pii-shapes.sh` reports two further shapes as fail-closed findings under stable pattern ids. **`host-local`** is on in the shipped default: it matches a name token immediately followed by the machine-local host suffix, and a per-repository configuration file name of the `<name>.local.<ext>` class is excluded by a named class rather than by a list of file names, while the placeholder form `<host>.local` is a non-match by construction exactly as the shapes already shipped are. **`tracker-key`** matches an upper-case letters-only namespace, a hyphen and digits, and it is **off in the shipped default**, enabled only by an explicit mechanism the header and both adopter documents name: a namespace of a single character and a namespace containing a digit are excluded by the outline itself, so the task-id convention this repository uses stays clean by construction, but the remaining same-outline population cannot be separated from a real tracker key by any shape — it is dominated by the design-point label vocabulary this plugin teaches its adopters to write — so the shipped default is silence and the enabling mechanism is what an adopter opts into. Neither exclusion is an enumerated list of prefixes or of file names, and none ships. Each new id has its own positive and near-miss negative fixtures assembled at runtime from fragments, its own mutation lock proving it is individually load-bearing, its own fixture-side meta-assertion, and a negative control proven to **reach** its rule's outline half and be excluded by the named class rather than never to have matched at all — so the universally-quantified mutation and meta duties the merged suite already carries stay true rather than being quietly narrowed. The header's `--help`-derived catalogue, its rule decomposition and its per-regex inventory describe the shipped regexes exactly, tied by invariants that derive both sides at run time rather than by a transcribed numeral. The adopter documentation lands in both language mirrors **additively**: every documentation line a merged criterion matches whole-line-exact survives byte-for-byte, the standing claim that named entities are not covered is reconciled by a new line stating that both rules match a generic outline and that no pattern naming a specific customer, host or project ships here, and the accepted-noise class the opt-in carries is declared rather than chased in the regex. Observable from outside: `bash tests/check-pii-shapes/run.sh` exits 0 with the new POS/NEG, mutation, meta, precondition, opt-in and family assertions present; `bash bin/check-pii-shapes.sh --all` and `bash bin/check-pii-shapes.sh --base develop` both exit 0 on this tree in the shipped default mode; and a scoped `git grep` finds no token of the new shape left standing outside the configuration-file class — the single measured occurrence being a configuration file base name written without its extension, which this task resolves at its authoring site in the two records that carry it rather than by widening the rule — with an exit status that distinguishes a clean absence from a failed read.

## Non-goals

- **Changing any existing pattern id, boundary rule or exclusion.** `home-path`, `home-path-win`, `home-encoded`, `temp-session`, `email-nonnoreply`, `private-key` and `token` keep their current semantics, their current ids and their current regex lines. The ratified bias toward firing and the final narrow home-path boundary are not reopened.
- **Growing the known-shapes list.** No new entry, no directory entry, no glob, no inline allow marker. A site that the extended checker reports is resolved at its authoring site by the documented placeholder convention, never by list growth.
- **Shipping a pattern that names a specific entity.** No customer name, host name, project code or tracker namespace is written into any regex, into any exclusion, or into any allow-list in the checker; both new rules match a generic outline only.
- **Shipping an enumerated prefix allow-list for the tracker-key outline.** The exclusions that ship are shape rules with named classes; a list of namespace prefixes, of standards abbreviations, or of configuration file base names is excluded from the design.
- **Adding, removing or editing any CI step.** The shellcheck argument list, the fixture-suite step and the diff-scoped step already cover this work, and a step naming `--all` would red a merged frozen criterion.
- **Adding any file under `tests/check-pii-shapes/`.** A merged criterion asserts that directory holds exactly one file; every new fixture is assembled at runtime inside the existing suite.
- **Re-freezing, widening or repairing any merged task's frozen criterion.** Criteria this task's change flips are disclosed in `## Blast radius` and never repaired here.
- **A general hygiene sweep of the corpus.** Only the sites the extended checker actually reports in its shipped default mode are in scope.
- **Merging.** Both gates must be green and the pull request joins the stacked train awaiting the batch GO.

## Acceptance criteria

Every `check:` runs from the repository root under `bash`. `$B` below is always `git merge-base develop HEAD`, per the `- base-ref-discriminator:` declaration.

- [ ] **AC1** Two new pattern ids ship, each as an individually neutralisable rule wired into the line-level scan. `bin/check-pii-shapes.sh` contains the literals `tracker-key` and `host-local`; `scan_content_file()` calls `report_pattern_lines` exactly once for each of them (the sibling shape of the shipped calls, not a candidate-enumerating scanner — neither new rule carries a per-candidate exclusion, which is the only thing the mailbox scanner's machinery exists for); each new regex lives on its own top-level `^RE_[A-Z0-9_]+=` assignment line so the suite's one-line neutralisation idiom can reach exactly one at a time; neither new id contains any shipped id as a substring; no assignment line of any regex uses `\b`, keeping boundary expression at parity with every rule already shipped and free of a construct that is not portable across the greps this script must run under; the script stays shellcheck-clean and introduces no runtime dependency outside bash and standard POSIX tools.
  - check: rc=0; export LC_ALL=C; S=bin/check-pii-shapes.sh; test -r "$S" || exit 1; for t in 'tracker-key' 'host-local'; do grep -qF -- "$t" "$S" || rc=1; done; test "$(grep -cE '^[[:space:]]*report_pattern_lines tracker-key ' "$S" || true)" = "1" || rc=1; test "$(grep -cE '^[[:space:]]*report_pattern_lines host-local ' "$S" || true)" = "1" || rc=1; for t in 'home-path' 'home-path-win' 'home-encoded' 'temp-session' 'email-nonnoreply' 'private-key' 'token'; do case 'tracker-key' in *"$t"*) rc=1 ;; esac; case 'host-local' in *"$t"*) rc=1 ;; esac; done; n=$(grep -cE '^RE_[A-Z0-9_]+=' "$S" || true); test "$n" -ge 15 || rc=1; test "$(grep -E '^RE_[A-Z0-9_]+=' "$S" | grep -cF '\b' || true)" -eq 0 || rc=1; shellcheck "$S" || rc=1; test "$(grep -vE '^[[:space:]]*#' "$S" | grep -cwE 'jq|yq|python|python3|perl|gawk' || true)" -eq 0 || rc=1; test "$rc" -eq 0
    - stale-at: a task adds or removes a top-level `RE_*=` assignment line in `bin/check-pii-shapes.sh`, at which point the floor of 15 (the 13 measured at this branch's base plus the 2 this task adds at minimum) no longer describes the rule set this criterion counts. It is a floor rather than an equality precisely so a later addition does not red it; only a removal does.

- [ ] **AC2** Each new id has a positive fixture reported under exactly that id and a near-miss negative that is not, both assembled at runtime from fragments, with the canonical labels present verbatim. The suite carries `POS/NEG pair: tracker-key` and `POS/NEG pair: host-local`, each asserting the reported id, and each near-miss differs from its positive in exactly the one feature that makes the positive a real shape: for `host-local`, the same name token followed by a configuration-file extension rather than standing alone; for `tracker-key`, the same outline with a single-character namespace and the same outline with a digit inside the namespace.
  - check: rc=0; export LC_ALL=C; T=tests/check-pii-shapes/run.sh; test -r "$T" || exit 1; bash "$T" >/dev/null 2>&1 || rc=1; for l in 'POS/NEG pair: tracker-key' 'POS/NEG pair: host-local'; do grep -qF -- "$l" "$T" || rc=1; done; test "$rc" -eq 0

- [ ] **AC3** Each new pattern is proven individually load-bearing by a mutation lock. Neutralising exactly that one regex line in a throwaway copy makes that pattern's own already-proven positive fixture go unreported; the number of `assert_neutralised_pattern_unreported` call sites is at least the seven shipped plus the two added; and the two new mutation labels are present verbatim.
  - check: rc=0; export LC_ALL=C; T=tests/check-pii-shapes/run.sh; test -r "$T" || exit 1; bash "$T" >/dev/null 2>&1 || rc=1; c=$(grep -cE '^assert_neutralised_pattern_unreported ' "$T" || true); test "$c" -ge 9 || rc=1; for l in 'mutation: pattern is load-bearing (tracker-key neutralised -> its own positive fixture reports nothing)' 'mutation: pattern is load-bearing (host-local neutralised -> its own positive fixture reports nothing)'; do grep -qF -- "$l" "$T" || rc=1; done; test "$rc" -eq 0
    - stale-at: a task adds or removes a pattern id in `bin/check-pii-shapes.sh`, at which point the floor of 9 call sites no longer describes the pattern set the merged suite's mutation duty quantifies over.

- [ ] **AC4** The merged "for every pattern" meta-assertion duty stays true rather than being narrowed. The suite calls its own positive-assertion helper against each new pattern's *neutralised* fixture in a subshell and requires that call to FAIL, with one `assert_meta_fails` call site per new id and both labels present verbatim, so a new fixture that silently stopped carrying its shape cannot pass.
  - check: rc=0; export LC_ALL=C; T=tests/check-pii-shapes/run.sh; test -r "$T" || exit 1; bash "$T" >/dev/null 2>&1 || rc=1; c=$(grep -cE '^assert_meta_fails ' "$T" || true); test "$c" -ge 9 || rc=1; for l in 'meta: neutralised positive fixture makes the assertion FAIL (tracker-key)' 'meta: neutralised positive fixture makes the assertion FAIL (host-local)'; do grep -qF -- "$l" "$T" || rc=1; done; test "$rc" -eq 0
    - stale-at: a task adds or removes a pattern id in `bin/check-pii-shapes.sh`, at which point the floor of 9 call sites no longer describes the pattern set the merged suite's meta-assertion duty quantifies over.

- [ ] **AC5** Every negative control is clean for a *boundary* reason, proven rather than observed. Each new rule is decomposed so that a broader outline half exists as its own named, independently neutralisable assignment line, and each negative-control fixture is asserted to match that outline half — read out of the checker's own source, in the idiom the shipped preconditions already establish — while the whole rule does not match it. Three controls: a configuration file name of the `<name>.local.<ext>` class; a single-character namespace of the tracker-key outline; and a namespace containing a digit. All labels present verbatim.
  - check: rc=0; export LC_ALL=C; T=tests/check-pii-shapes/run.sh; test -r "$T" || exit 1; bash "$T" >/dev/null 2>&1 || rc=1; for l in 'negative control: a per-repository configuration file name stays clean' 'precondition: each host-local negative control reaches the host-local outline but not its reported rule' 'negative control: a single-character namespace stays clean with tracker-key enabled' 'negative control: a namespace containing a digit stays clean with tracker-key enabled' 'precondition: each tracker-key negative control reaches the tracker-key outline but not its reported rule'; do grep -qF -- "$l" "$T" || rc=1; done; test "$rc" -eq 0

- [ ] **AC6** The whole corpus is clean at HEAD in the shipped default mode, in both scanning modes, so the merged criteria that run this checker keep passing. `bash bin/check-pii-shapes.sh --all` exits 0, `bash bin/check-pii-shapes.sh --base develop` exits 0, and `bash bin/check-pii-shapes.sh --base "$B"` exits 0. Each invocation is asserted to have actually run — the script readable, `develop` resolvable, `$B` non-empty — before its status is credited, so an unresolvable ref cannot read as clean.
  - check: rc=0; export LC_ALL=C; S=bin/check-pii-shapes.sh; test -r "$S" || exit 1; git rev-parse --verify --quiet 'develop^{commit}' >/dev/null || exit 1; B=$(git merge-base develop HEAD) || exit 1; test -n "$B" || exit 1; bash "$S" --all >/dev/null 2>&1 || rc=1; bash "$S" --base develop >/dev/null 2>&1 || rc=1; bash "$S" --base "$B" >/dev/null 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC7** The opt-in is load-bearing in both directions, proven on a fixture rather than assumed. One fixture carrying a real tracker-key shape is clean in the shipped default mode and is reported as `pattern=tracker-key` when the rule is explicitly enabled; and enabling it changes no other pattern id's verdict on that same content. The three labels are present verbatim, so a future change that quietly flips the shipped default, or that quietly couples the opt-in to another rule, fails this suite.
  - check: rc=0; export LC_ALL=C; T=tests/check-pii-shapes/run.sh; test -r "$T" || exit 1; bash "$T" >/dev/null 2>&1 || rc=1; for l in 'opt-in: the tracker-key rule is silent in the shipped default mode' 'opt-in: the tracker-key rule fires when it is explicitly enabled' 'opt-in: enabling the tracker-key rule changes no other pattern id verdict'; do grep -qF -- "$l" "$T" || rc=1; done; test "$rc" -eq 0

- [ ] **AC8** The header's `--help`-derived enumeration and its per-regex inventory describe the shipped regexes exactly, tied by invariants that derive both sides at run time rather than by a transcribed numeral. Four things hold. (i) **For-all inventory coverage**: every top-level `RE_[A-Z0-9_]+` variable name assigned in the script appears in the anchoring/boundary inventory region, with the iterated variable count asserted at a floor first so a loop that read nothing cannot satisfy a for-all over an empty set. (ii) **Id-set equality**: the set of pattern ids `scan_content_file()` actually reports equals the set of ids the header's shape list names, both derived at run time, so neither an unlisted shape nor a listed-but-unreported shape can survive. (iii) **The falsified numeral is gone**: the literal `eleven independently load-bearing rules` is absent from the script, and the independent-rule count derived at run time — top-level `RE_*=` lines minus composition lines whose right-hand side references another `RE_` variable — is at its floor. (iv) The opt-in mechanism is documented in the header, which is what `--help` prints.
  - check: rc=0; export LC_ALL=C; S=bin/check-pii-shapes.sh; test -r "$S" || exit 1; D=$(mktemp -d "${TMPDIR:-/tmp}/t1140ac8.XXXXXX") || exit 1; awk '/^# Anchoring\/boundary inventory/{f=1} f&&/^# shellcheck/{exit} f{print}' "$S" > "$D/inv.txt"; test -s "$D/inv.txt" || rc=1; grep -oE '^RE_[A-Z0-9_]+' "$S" | sort -u > "$D/vars.txt"; v=$(grep -c . "$D/vars.txt" || true); test "$v" -ge 15 || rc=1; while IFS= read -r vn; do test -n "$vn" || continue; grep -qF -- "$vn" "$D/inv.txt" || rc=1; done < "$D/vars.txt"; awk '/^scan_content_file\(\)/{f=1} f&&/^}/{exit} f{print}' "$S" > "$D/scan.txt"; test -s "$D/scan.txt" || rc=1; { grep -oE 'report_pattern_lines [a-z-]+' "$D/scan.txt" | awk '{print $2}'; grep -qF 'scan_email_candidates' "$D/scan.txt" && printf 'email-nonnoreply\n'; } | sort -u > "$D/ids.txt"; i=$(grep -c . "$D/ids.txt" || true); test "$i" -ge 9 || rc=1; grep -oE '^#   [a-z][a-z-]+ ' "$S" | sed -E 's/^#   //; s/ *$//' | sort -u > "$D/hdrids.txt"; cmp -s "$D/ids.txt" "$D/hdrids.txt" || rc=1; if grep -qF -- 'eleven independently load-bearing rules' "$S"; then rc=1; fi; a=$(grep -cE '^RE_[A-Z0-9_]+=' "$S" || true); c=$(grep -cE '^RE_[A-Z0-9_]+="\$\{RE_' "$S" || true); test "$((a - c))" -ge 13 || rc=1; bash "$S" --help > "$D/help.txt" 2>&1 || rc=1; grep -qF -- 'tracker-key' "$D/help.txt" || rc=1; grep -qF -- 'host-local' "$D/help.txt" || rc=1; grep -qF -- 'off in the shipped default' "$D/help.txt" || rc=1; rm -rf "$D"; test "$rc" -eq 0
    - stale-at: a task adds or removes a pattern id or a top-level `RE_*=` assignment in `bin/check-pii-shapes.sh`, at which point the floors of 15 variables, 9 ids and 13 independent rules no longer describe the rule set this criterion counts. All three are floors rather than equalities, so a later addition does not red them; a removal does, and that is the intended signal.

- [ ] **AC9** No exemption route was taken. `KNOWN_SHAPE_PATHS` is byte-identical to its base-ref blob, carries no directory or glob entry, and names no file this task touches; the script carries no inline allow marker; and no non-comment line contains a literal `.shell-team/` or `tasks/todo` path, so the merged criteria asserting the list's exact contents and the operating-path discipline both stay green.
  - check: rc=0; export LC_ALL=C; S=bin/check-pii-shapes.sh; test -r "$S" || exit 1; B=$(git merge-base develop HEAD) || exit 1; test -n "$B" || exit 1; D=$(mktemp -d "${TMPDIR:-/tmp}/t1140ac9.XXXXXX") || exit 1; git show "$B:$S" > "$D/base.sh" 2>/dev/null || rc=1; test -s "$D/base.sh" || rc=1; sed -n '/^KNOWN_SHAPE_PATHS=(/,/^)/p' "$S" > "$D/now.list"; sed -n '/^KNOWN_SHAPE_PATHS=(/,/^)/p' "$D/base.sh" > "$D/base.list"; test -s "$D/base.list" || rc=1; cmp -s "$D/now.list" "$D/base.list" || rc=1; if grep -qE '"[^"]*(/"|\*|\?|\[)' "$D/now.list"; then rc=1; fi; if grep -qE 'pii-controls|todo\.md|T-1140' "$D/now.list"; then rc=1; fi; test "$(grep -vE '^[[:space:]]*#' "$S" | grep -cE '\.shell-team/|tasks/todo' || true)" -eq 0 || rc=1; rm -rf "$D"; test "$rc" -eq 0

- [ ] **AC10** The adopter-facing documentation lands in this same task, in both language mirrors, **additively**, without disturbing a single whole-line-locked canonical line. Each document names both new ids in its shape catalogue and carries three new canonical lines verbatim: the opt-in and its shipped default together with the accepted-noise class the opt-in carries; the configuration-file-name exclusion together with the declared limit that a bare host name with no machine-local suffix is not covered; and the reconciliation of the standing named-entity claim — both new rules match a generic outline, no pattern naming a specific customer, host or project ships here, so that claim still holds. Every documentation line a merged criterion matches whole-line-exact, the two named-entity lines in each language among them, is still present byte-for-byte, re-asserted here rather than assumed, together with the "shapes only" sentences and the badge-shaped absence lock.
  - adopter-surface: `docs/pii-controls.md` and `docs/pii-controls.ja.md` (`## What it checks for` / `## 何を検出するか` and `## What this gate does not cover` / `## このゲートが扱わないもの`), plus the `--help`-derived header comment of `bin/check-pii-shapes.sh`, which is the surface an adopter reads from the command line.
  - check: rc=0; export LC_ALL=C; for f in docs/pii-controls.md docs/pii-controls.ja.md; do test -s "$f" || exit 1; for t in 'tracker-key' 'host-local'; do grep -qF -- "$t" "$f" || rc=1; done; done; grep -qxF -- '- The tracker-key rule is off in the shipped default and must be enabled explicitly, because a project-label convention this plugin itself teaches shares the same outline; with it enabled, standards identifiers of the same outline (a character-set or digest name, a date-format or vulnerability id, an RFC or HTTP status spelling) are reported as accepted noise, and the resolution is triage at the authoring site, never a prefix allow-list in this checker.' docs/pii-controls.md || rc=1; grep -qxF -- '- A configuration file name of the <name>.local.<ext> class is not reported as a host name, and a bare host name carrying no machine-local suffix is not covered at all.' docs/pii-controls.md || rc=1; grep -qxF -- '- The tracker-key and host-local rules match a generic outline, not a named entity: no pattern naming a specific customer, host or project ships in this repository, so the named-entity limitation above still holds.' docs/pii-controls.md || rc=1; grep -qxF -- '- tracker-key の規則は出荷時の既定では無効であり、明示的に有効化する必要がある。このプラグイン自身が教えるラベル規約が同じ形状を共有するためである。有効にすると、同じ形状を持つ標準識別子（文字コードやダイジェストの名前、日付形式や脆弱性 id、RFC や HTTP ステータスの表記）は許容される雑音として報告される。解消は書いた場所での仕分けであって、このチェッカーに接頭辞の許可リストを置くことではない。' docs/pii-controls.ja.md || rc=1; grep -qxF -- '- <name>.local.<ext> の形の設定ファイル名はホスト名としては報告しない。また machine-local の接尾辞を伴わない裸のホスト名は対象外である。' docs/pii-controls.ja.md || rc=1; grep -qxF -- '- tracker-key と host-local の規則が一致させるのは汎用的な形状であって固有名詞ではない。特定の顧客名・ホスト名・プロジェクト名を名指しするパターンはこのリポジトリには置かないため、上の固有名詞に関する制限はそのまま成り立つ。' docs/pii-controls.ja.md || rc=1; grep -qxF -- '- Named entities — customer names, internal hostnames, project codes — cannot be matched by shape and are not covered by this gate.' docs/pii-controls.md || rc=1; grep -qxF -- '- The patterns that would match named entities cannot live in this public repository, because the patterns themselves are the sensitive data; they belong in an operator-local check outside the repo.' docs/pii-controls.md || rc=1; grep -qxF -- '- 固有名詞（顧客名・内部ホスト名・プロジェクトコード）は形状では一致させられないため、このゲートの対象外である。' docs/pii-controls.ja.md || rc=1; grep -qxF -- '- 固有名詞に一致させるためのパターン自体が機密であるため、この公開リポジトリには置けない。リポジトリ外のオペレータ手元のチェックに置く。' docs/pii-controls.ja.md || rc=1; grep -qxF '## What this gate does not cover' docs/pii-controls.md || rc=1; grep -qxF '## このゲートが扱わないもの' docs/pii-controls.ja.md || rc=1; grep -qxF 'This gate sees shapes only. It is not a complete PII control, and passing it is not evidence that a change is free of PII.' docs/pii-controls.md || rc=1; grep -qxF 'このゲートは形状だけを見る。PII 対策として完全ではなく、通過したことは変更に PII が含まれないことの証拠にはならない。' docs/pii-controls.ja.md || rc=1; grep -qxF -- '- A PII shape in a filename or a path is not inspected; this gate reads file content only.' docs/pii-controls.md || rc=1; grep -qxF -- '- The deliberate shape-bearing fixtures under tests/ are carried by the test-locked known-shapes list, so --all exits 0 on this tree; --all remains an audit flag and is deliberately not a required CI check.' docs/pii-controls.md || rc=1; grep -qxF -- '- ファイル名やパス自体に含まれる PII 形状は検査しない。このゲートはファイルの内容だけを読む。' docs/pii-controls.ja.md || rc=1; if grep -F -e 'PII-gated' -e 'PII-free' -e 'PII-clean' -e 'PII-safe' docs/pii-controls.md docs/pii-controls.ja.md README.md README.ja.md >/dev/null 2>&1; then rc=1; fi; test "$rc" -eq 0

- [ ] **AC11** No byte of the new host-name shape enters the tree, and the placeholder discipline extends to it. `tests/check-pii-shapes/` still holds exactly one file and no fixtures directory; every new host-name fixture is assembled from fragments at runtime, evidenced by the tracked operational paths carrying no name token immediately followed by the machine-local host suffix and nothing further — a token carrying any dot-led continuation after the suffix, a real extension and the documented `<ext>` placeholder alike, is part of a file name rather than a host name and is exempt — read with an exit status distinguishing a clean absence from a failed read, so a read that could not complete never passes as silence; and a single fixture carrying the placeholder form together with the forms already documented is clean, asserted under its own new label **added alongside** the existing placeholder label, which stays present byte-for-byte.
  - check: rc=0; export LC_ALL=C; T=tests/check-pii-shapes/run.sh; test -r "$T" || exit 1; test ! -e tests/check-pii-shapes/fixtures || rc=1; test ! -L tests/check-pii-shapes/fixtures || rc=1; test "$(find tests/check-pii-shapes -type f | wc -l | tr -d ' ')" = "1" || rc=1; grep -qF 'mktemp' "$T" || rc=1; grep -qF -- 'placeholder forms are not findings (all six documented forms, one change, clean)' "$T" || rc=1; grep -qF -- 'placeholder forms are not findings (the host placeholder form, clean)' "$T" || rc=1; D=$(mktemp -d "${TMPDIR:-/tmp}/t1140ac11.XXXXXX") || exit 1; git grep -nE -- '[A-Za-z0-9-]\.local' -- 'bin' 'tests' 'docs' 'agents' 'skills' 'templates' '.shell-team' '*.md' > "$D/hits.txt" 2>/dev/null; g=$?; case "$g" in 0|1) : ;; *) rc=1 ;; esac; test "$(grep -vE '\.local\.' "$D/hits.txt" | grep -c . || true)" -eq 0 || rc=1; rm -rf "$D"; test "$rc" -eq 0

- [ ] **AC12** No CI step was added, removed or edited. `.github/workflows/check-handoff.yml` is byte-identical to its base-ref blob, so the shellcheck argument list, the fixture-suite step and the diff-scoped step are all exactly as measured, and the merged criterion requiring the workflow to contain no `--all` occurrence stays green.
  - check: rc=0; export LC_ALL=C; W=.github/workflows/check-handoff.yml; test -s "$W" || exit 1; B=$(git merge-base develop HEAD) || exit 1; test -n "$B" || exit 1; D=$(mktemp -d "${TMPDIR:-/tmp}/t1140ac12.XXXXXX") || exit 1; git show "$B:$W" > "$D/base.yml" 2>/dev/null || rc=1; test -s "$D/base.yml" || rc=1; cmp -s "$D/base.yml" "$W" || rc=1; if grep -qF -- '--all' "$W"; then rc=1; fi; rm -rf "$D"; test "$rc" -eq 0

- [ ] **AC13** Fail-closed behaviour is preserved, not merely unbroken by accident. The documented exit-code contract still holds — `--help` exits 0 and documents `--all` and `--base`, an unknown flag exits 2, and `--all` combined with `--base` exits 2 — every non-comment stderr write still carries a same-line `|| true` guard so a write failure cannot downgrade a contract exit of 2 to errexit's own 1, and none of the three diff-rendering parsing anchors appears on a non-comment line, so the new rules were added to the content scan and not to a rendering parser.
  - check: rc=0; export LC_ALL=C; S=bin/check-pii-shapes.sh; test -r "$S" || exit 1; bash "$S" --help | grep -qF -- '--all' || rc=1; bash "$S" --help | grep -qF -- '--base' || rc=1; bash "$S" --bogus >/dev/null 2>&1; test $? -eq 2 || rc=1; bash "$S" --all --base develop >/dev/null 2>&1; test $? -eq 2 || rc=1; test "$(grep -vE '^[[:space:]]*#' "$S" | grep -c '>&2' || true)" -gt 0 || rc=1; test "$(grep -vE '^[[:space:]]*#' "$S" | grep '>&2' | grep -vc '|| true' || true)" -eq 0 || rc=1; grep -qF 'cat-file' "$S" || rc=1; test "$(grep -vE '^[[:space:]]*#' "$S" | grep -cF -e '+++' -e '@@' -e 'Binary files' || true)" -eq 0 || rc=1; test "$rc" -eq 0

- [ ] **AC14** Each new rule fires on its whole shape family, not only on the one spelling a single fixture happens to carry. Positive fixtures exist and fire for: a host name token containing a hyphen and one containing a digit, and the same token reached at more than one left boundary — line start, after a space, and after a prompt-style separator; and, with the tracker-key rule enabled, a namespace at the short end of the range the rule claims and one at the long end, with a single-digit issue number and with a many-digit one. The suite carries the two family labels verbatim, and the engineer reports in the hand-off which further spellings were tried and what each did.
  - check: rc=0; export LC_ALL=C; T=tests/check-pii-shapes/run.sh; test -r "$T" || exit 1; bash "$T" >/dev/null 2>&1 || rc=1; for l in 'family: the host-local rule fires on hyphenated and digit-bearing host tokens at every reachable left boundary' 'family: the tracker-key rule fires across the namespace-length and issue-number-length range it claims'; do grep -qF -- "$l" "$T" || rc=1; done; test "$rc" -eq 0

- [ ] **AC15** Scope lock: the branch's changed-and-added file set — the committed range, the staged delta, the unstaged delta and the untracked strays, unioned, each `git diff` read spelled with `--no-renames` so a rename's source path is never invisible to all four reads at once — contains the required deliverables and nothing outside the allow-list in `## Notes for engineer`. **This criterion is merge-point-scoped and expected to go stale after merge**; do not widen its base-ref resolution, re-derive it per rework round, or otherwise try to keep it evergreen, because merge-ranging it trades away the confinement it exists to provide.
  - check: rc=0; export LC_ALL=C; B=$(git merge-base develop HEAD) || exit 1; test -n "$B" || exit 1; D=$(mktemp -d "${TMPDIR:-/tmp}/t1140ac15.XXXXXX") || exit 1; { git diff --no-renames --name-only "$B"...HEAD; git diff --no-renames --cached --name-only; git diff --no-renames --name-only; git ls-files --others --exclude-standard; } | sort -u | grep -v '^$' > "$D/set.txt"; test -s "$D/set.txt" || rc=1; while IFS= read -r p; do test -n "$p" || continue; case "$p" in bin/check-pii-shapes.sh|tests/check-pii-shapes/run.sh|docs/pii-controls.md|docs/pii-controls.ja.md|.shell-team/test-recipe.md|.shell-team/todo.md|.shell-team/interventions/T-1109.md|.shell-team/reviews/T-1110.md|.shell-team/specs/T-1140-tracker-key-and-host-local-shapes.md|.shell-team/provenance/T-1140.md|.shell-team/interventions/T-1140.md|.shell-team/reviews/T-1140.md|.shell-team/reviews/T-1140-codex-round*.txt) : ;; *) rc=1 ;; esac; done < "$D/set.txt"; for req in .shell-team/specs/T-1140-tracker-key-and-host-local-shapes.md .shell-team/provenance/T-1140.md .shell-team/reviews/T-1140.md; do grep -qxF -- "$req" "$D/set.txt" || rc=1; done; rm -rf "$D"; test "$rc" -eq 0

- [ ] **AC16** This task's own records exist and are schema-conformant: a decision provenance file, an interventions ledger and a review record, each validated by its own shipped checker with the file path supplied as the positional argument those checkers require, and the board entry validated by the hand-off linter.
  - check: rc=0; export LC_ALL=C; bash bin/check-provenance.sh .shell-team/provenance/T-1140.md >/dev/null 2>&1 || rc=1; bash bin/check-interventions.sh --task T-1140 .shell-team/interventions/T-1140.md >/dev/null 2>&1 || rc=1; test -r .shell-team/reviews/T-1140.md || rc=1; bash bin/check-handoff.sh "$(bash bin/team-paths.sh --get todo)" >/dev/null 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC17** Verification duties discharged and reported, each as its own named item in the hand-off — this criterion carries no `check:` line because its subject is the engineer's and QA's own procedure rather than an artifact property. (a) **Mutation self-check**: every `- check:` line above had its own guard broken, observed red, restored, observed green; and for each new pattern both facets of a control are probed separately — its *naming* (the reported id corresponds to logic actually exercised) and its *wiring* (the neutralised copy's execution path passes through the real verdict branch). (b) **Execution-context matrix**: every documented command run in this checkout's root without the plugin on `PATH`, and again in an adopter-shaped repository with `bin/` reached by bare name. (c) **CI-equivalence**, scoped by mechanically reverse-mapping each edited path to the suites and workflow steps that read it rather than by a remembered trigger, with every step judged inapplicable named individually together with its reason. (d) **Downstream impact**: the mechanism-class full-population two-arm diff is **not** run per task under this cycle's operating mode — it is the single release-time sweep — so `## Blast radius` below carries predictions that the sweep settles, and any prediction it does not confirm is reported there as a finding about the prediction rather than silently corrected. (e) **shellcheck** over the workflow's exact argument list, extracted verbatim from the workflow rather than retyped. (f) **Plural-corpus read**: the new documentation and header prose read against a corpus instance where the governed thing occurs more than once, so no singular determiner smuggles in a cardinality-one assumption. (g) **PII-shape self-check before first commit**: `bin/check-pii-shapes.sh` run against this spec and every new record before either is committed, the CI diff-time check being the backstop and not the primary defence.

## Input space

**Reachable input classes** — what tracked content really contains, and which the two new rules must therefore handle correctly:

1. Name tokens carrying the machine-local host suffix as they actually occur today: measured, exactly four distinct tokens tree-wide — two are per-repository configuration file names of the `<name>.local.<ext>` class, one is the placeholder form `<host>.local`, and one is a configuration file base name written **without** its extension, occurring in two tracked records. **No workstation host name exists in tracked content.** The unextended base name is the one reachable class the named exclusion cannot close, and this task resolves both of its occurrences at their authoring site by appending the extension — never by widening the rule and never by list growth.
2. A workstation host name in the machine-local form as a record can quote it: standing alone in prose, inside a system-information line, and after a prompt-style separator. This is the class the rule exists to catch; it has no live carrier in tracked content, which is what makes the shipped default safe to leave on.
3. Host-name tokens whose name part carries a hyphen or a digit, which the shape family must cover.
4. Tracker-key-outline tokens in tracked content: measured, 84 distinct with a digit admitted anywhere in the namespace and 48 distinct with a letters-only namespace; of the 48, 37 are this repository's design-point label convention, 8 are standards identifiers, and 3 are fixture names. A further 354 distinct tokens use a single-character namespace.
5. Genuine tracker keys as an adopter writes them: a namespace of two letters through ten, and an issue number of one digit through many.
6. Placeholder forms written deliberately in documentation: the forms already documented, plus `<host>.local` and a tracker key written with an angle-bracketed namespace.
7. Markdown prose in English and in Japanese including full-width punctuation, bash source containing regex literals that themselves spell the shapes, YAML and JSONL — the classes already declared, unchanged.
8. Path shapes git tracks: a symbolic link whose scanned content is its stored target string, and a NUL-bearing blob that must be skipped with an announcement. Unchanged by this task and re-exercised by the existing suite.
9. Both supported layouts, every operating path resolved through `bin/team-paths.sh`.

**Out-of-scope synthetic extremes** — declined deliberately, so a reviewer or QA finding built on one of these is not grounds for rework:

1. **Separating a standards identifier of the tracker-key outline from a genuine tracker key by shape.** Declined on a measured ground: 8 such tokens exist in tracked content and no shape distinguishes them from an adopter's tracker key, so the mechanism is the shipped-default silence plus a declared accepted-noise class, never a prefix allow-list. Tightening the outline to require more digits or a longer namespace was measured to leave lookalikes standing while manufacturing a false-negative class, which is the one thing a gate of this kind must not do.
2. **A tracker key with a single-character namespace.** Declined: the outline requires at least two letters, which is what keeps the 354 measured single-character-namespace tokens clean by construction.
3. **A tracker key whose namespace contains a digit.** Declined: measured, 36 such tokens exist in tracked content and every one of them is a line-range or label reference rather than a tracker key.
4. **A tracker key written in lower case or mixed case.** Declined: the outline is upper-case, at parity with the shape an adopter's tracker actually emits.
5. **A machine-local host suffix other than the one this rule names** — other private-network or link-local suffixes. Declined: nothing in reach emits one and none occurs in tracked content; adding them would widen the outline against a population of zero.
6. **A bare host name carrying no machine-local suffix.** Declared as a limitation in the adopter documentation rather than chased, because a bare host name is a named entity and this gate matches shapes.
7. **Deliberately obfuscated or encoded values**: base64, percent-encoding, homoglyphs, zero-width characters splitting a shape, a shape spread across two physical lines. A shape checker cannot see these and this spec does not claim to.
8. **Adversarially large inputs as a performance probe**: ever-longer namespaces, ever-longer digit runs, megabyte lines, an ever-larger change set.
9. **A hostile author who edits the checker in the same commit to disable it.** This is a discipline aid for a trusted, reviewed artifact, not a security boundary against the person writing the commit; pull-request review is that layer.

<!-- END intent-block: T-1140 -->

## Decision points, resolved

**DP-1 — `tracker-key` is opt-in and off in the shipped default; `host-local` is on.** Decided against the derived lookalike populations in `## Blast radius`, not against taste. Three grounds, in descending weight.

1. **The lookalike population is this plugin's own vocabulary.** Measured with a letters-only namespace: 48 distinct same-outline tokens in tracked content outside the fixture directory, of which **37** are the design-point label convention — `DP-`, `US-`, `AC-`, `DS-`, `MED-`, `NEEDS-`, `NEW-`, `NF-`, `NR-`, `SA-`, `STOP-`, `DATE-`, `DECISION-` prefixes. That vocabulary is not incidental to this repository: it is what the plugin's own role prompts and spec template teach an adopter to write, so a default-on rule would red every adopter's spec corpus by construction of the thing they installed.
2. **No shape separates the remainder.** The 8 standards identifiers of the same outline differ from a genuine tracker key in no mechanically readable way. Two narrowing designs were considered and rejected on measurement: requiring two or more digits leaves four of the eight standing and silences a genuine one-digit issue number; requiring a namespace of three or more letters leaves five standing and silences a two-letter namespace, which is the shortest an adopter's tracker actually issues. A narrowing that manufactures a false-negative class in a gate of this kind is the one move the ratified asymmetry forbids.
3. **The asymmetry's own carve-out applies.** The bias toward firing is ratified for the case where a rule cannot separate its populations *and* the noise is small. Here the noise is the corpus, measured at 182 board lines carrying a letters-only lookalike plus dozens each in specs and reviews — the same circumstance the undashed-hex form was already declared out of scope for.

`host-local` goes the other way on the same measurement: three same-outline tokens tree-wide, two closed by a named class and one a placeholder non-match by construction, so default-on costs zero findings and catches the identity-bearing shape.

**DP-2 — the exclusions are shape rules with named classes; no enumerated list ships.** Four classes, each named and each independently neutralisable:

| Class | Rule | What it closes |
|---|---|---|
| Single-character namespace | The outline requires at least two letters | This repository's own task-id convention — 354 distinct tokens, clean by construction rather than by listing the prefix |
| Digit-bearing namespace | The outline requires a letters-only namespace | 36 measured line-range and label references |
| Configuration file name | A machine-local host suffix immediately followed by a dot and an extension is a file name, not a host name | Both measured configuration-file tokens, without naming either file |
| Placeholder form | The name class admits no angle bracket | `<host>.local`, a non-match by construction — measured: the generic outline returned only the two configuration-file tokens and never the placeholder |

The standards-identifier class is **not** closed by a rule, and that is recorded as a deviation from the routing recommendation rather than applied silently: no shape closes it, so the mechanism is DP-1's shipped-default silence plus a declared accepted-noise class in both adopter documents. A prefix allow-list is excluded by Non-goals for the same reason the known-shapes list is: a list of an adopter's namespaces is itself the sensitive data this repository must not carry.

**DP-3 — the reconciliation of the standing named-entity claim is additive, never an edit.** Measured: the two named-entity lines in each language are matched **whole-line-exact** by merged frozen criteria, and those criteria state in their own bodies that other tasks may add lines freely because nothing there constrains the file's shape or line count. Editing either line would be a class-B re-freeze of merged frozen intent, which Non-goals forbids; so **AC10** adds a new line stating the boundary — both new rules match a generic outline, no pattern naming a specific customer, host or project ships here — and re-asserts the original lines byte-for-byte in the same check.

**DP-4 — the new rules are decomposed so their exclusions are provably load-bearing.** The established pair shape — a broad outline half as its own named assignment line, composed with the requirement that narrows it — is what lets a negative control be **shown to reach** the outline and be excluded by the named class, rather than merely never to have matched. Without it, a negative control for a single-regex rule proves nothing, which is the vacuity the shipped precondition idiom exists to prevent. This is why **AC5** requires the decomposition and the precondition together.

**DP-5 — the opt-in must be reachable by the suite's existing assertion helpers without changing their signatures.** The merged mutation and meta duties are quantified over patterns and their call-site counts are floored by merged criteria; a mechanism the helpers cannot reach would force either a signature change that breaks those counts or a second parallel helper that leaves the new pattern outside the quantifier. The spec fixes the requirement, not the spelling: an environment-carried mechanism satisfies it because the helpers' child processes inherit the environment, and a trailing optional argument satisfies it because the call-site greps count the call, not its arity.

## Body-to-AC correspondence

| # | Normative directive stated in the body | Promoted to |
|---|---|---|
| 1 | Two new pattern ids, `tracker-key` and `host-local`, each fail-closed | **AC1**, **AC2**, **AC13** |
| 2 | Both are `report_pattern_lines` siblings in `scan_content_file()`, not candidate-enumerating scanners | **AC1** |
| 3 | Each new regex on its own top-level `RE_*=` line so one-at-a-time neutralisation works | **AC1**, **AC3** |
| 4 | Neither new id contains a shipped id as a substring | **AC1** |
| 5 | No regex assignment line uses `\b`, keeping boundary expression at parity with the shipped rules | **AC1** |
| 6 | POS/NEG pair per new id, with the reported id asserted | **AC2** |
| 7 | A mutation lock per new pattern proving it is individually load-bearing | **AC3** |
| 8 | The merged "for every pattern" meta-assertion duty extended, not narrowed | **AC4** |
| 9 | Each new rule is decomposed into a named outline half plus the requirement that narrows it (DP-4) | **AC5** |
| 10 | Every negative control is proven to reach its rule's outline rather than never to have matched | **AC5** |
| 11 | The configuration-file-name class is excluded by a named class, not by a list of file names | **AC5**, **AC10** |
| 12 | The single-character and digit-bearing namespace classes are excluded by the outline itself | **AC5**, **AC14** |
| 13 | The corpus is clean at HEAD in the shipped default mode, in both scanning modes | **AC6** |
| 14 | `tracker-key` is off in the shipped default and enabled only explicitly | **AC7**, **AC8**(iv), **AC10** |
| 15 | `host-local` is on in the shipped default | **AC2**, **AC6**, **AC14** — its positive fixture is asserted to fire with no mechanism enabled |
| 16 | Enabling the opt-in changes no other pattern id's verdict | **AC7** |
| 17 | The header's enumeration and inventory match the shipped regexes exactly | **AC8** |
| 18 | The falsified rule-count literal is gone and the count is derived, never transcribed | **AC8** |
| 19 | The opt-in mechanism is documented in the header, which is what `--help` prints | **AC8**(iv) |
| 20 | No exemption route: the known-shapes list is unchanged, per-file, naming no file this task touches | **AC9** |
| 21 | No inline allow marker; no literal `.shell-team/` on a non-comment line | **AC9** |
| 22 | Adopter-facing documentation lands in the same task, in both language mirrors | **AC10** |
| 23 | The documentation work is additive: every whole-line-locked canonical line survives byte-for-byte | **AC10** |
| 24 | The standing named-entity claim is reconciled by a new line, never by editing the locked ones (DP-3) | **AC10** |
| 25 | The accepted-noise class the opt-in carries is declared in both documents | **AC10** |
| 26 | No byte of the new host-name shape enters the tree; fixtures are assembled at runtime | **AC11** |
| 27 | The placeholder label already frozen is added alongside, never reworded | **AC11** |
| 28 | No new file under `tests/check-pii-shapes/` | **AC11** |
| 29 | No CI step is added, removed or edited | **AC12** |
| 30 | The exit-code contract, the `\|\| true` stderr guard and the parsing-anchor absence all survive | **AC13** |
| 31 | Each rule fires on its whole shape family, not one spelling | **AC14** |
| 32 | Scope lock, merge-point-scoped and expected to go stale | **AC15** |
| 33 | Provenance, interventions and review records exist and validate | **AC16** |
| 34 | Mutation self-check, naming and wiring probed separately per new control | **AC17**(a) |
| 35 | Execution-context matrix for every documented command | **AC17**(b) |
| 36 | CI-equivalence scoped by reverse-mapping edited paths to the suites that read them | **AC17**(c) |
| 37 | Downstream impact is the release-time sweep's measurement; predictions are disclosed here | **AC17**(d) |
| 38 | shellcheck over the workflow's verbatim argument list | **AC17**(e) |
| 39 | Plural-corpus read of the new documentation and header prose | **AC17**(f) |
| 40 | `bin/check-pii-shapes.sh` run against every new record before its first commit | **AC17**(g) |
| 41 | No existing pattern id, boundary rule or exclusion changes | **AC8** (the shipped ids remain in the id set), **AC9** (the list is unchanged), **AC13** (the contract is unchanged), Non-goals |
| 42 | No enumerated prefix allow-list ships (DP-2) | **AC9** re-asserts that no list grew and the checker carries no allow marker; the positive half is Non-goals, because a criterion asserting the absence of a mechanism this task deliberately does not build has no artifact to read |
| 43 | The opt-in must be reachable by the existing assertion helpers (DP-5) | **AC3**, **AC4** — the call-site floors are exactly what a mechanism the helpers cannot reach would break |
| 44 | The standards-identifier class is not closed by a rule (DP-2 deviation) | Input space, out-of-scope 1 — a declared boundary, not a detection duty; promoting it would mean asserting the absence of a rule this task deliberately does not add |
| 45 | Criteria this change flips in merged specs are disclosed, never repaired | **AC17**(d) records the measurement's owner; `## Blast radius` records the disposition; Non-goals forbids the repair |
| 46 | Two narrowing designs were considered and rejected on measurement (DP-1 ground 2) | info-only (not promoted to AC) — a record of a rejected design; its observable half is **AC14**, whose family positives fail if the outline is later narrowed to either rejected form |
| 47 | A reviewer or QA report that some input looks like a false positive is not grounds for widening a suppression | info-only (not promoted to AC) — a rule about how future rework rounds are handled, inherited from the checker's ratified asymmetry; **AC14**'s family positives are what make a quiet narrowing fail |
| 48 | The one measured unextended configuration base name is resolved at its authoring site in the two records that carry it, never by widening the rule or growing a list | **AC6** (the corpus is clean only once both are resolved), **AC15** (the two paths are allow-listed for this and no other reason), **AC9** (no list grew) |
| 49 | Nothing else in either of those two records is changed | **AC15** — the scope lock is what confines the edit to those paths; the intra-file confinement is stated in `## Notes for engineer`, no criterion asserting it, because a byte-diff of an append-only record cannot distinguish an authorised token repair from an unauthorised one without re-encoding the repair itself |
| 50 | The verification axis is priced as a single work type under this cycle's operating mode | info-only (not promoted to AC) — the board rows are the orchestrator's to transcribe at the seam; `pm-spec` never writes a `- dispatch:` sub-bullet, and a criterion asserting a row this role may not write would be unsatisfiable at freeze |

## Verification duty pricing

This task records the **parent `verify` axis**, value `serial`, and neither refinement. Ground: under this cycle's operating mode the mechanism-class full-population two-arm diff runs once before release rather than per task, so this task's own verification duty is one work type — fixture suites whose cases share a single `mktemp` work root under `$TMPDIR` with one `EXIT` trap and run sequentially in one bash process, creating throwaway git repositories inside that root. That is not a mechanically-enumerable population of independent read-only units, so the fan-out trigger's first conjunct is unsatisfied and the unconditional `serial` default stands. Because the duty is genuinely one kind, a second row would have no ground, and the grammar forbids recording the parent alongside a refinement. **The row itself is not written by this role**; it is transcribed onto the board at the Specify-to-Implement seam.

## Pre-commitment

Frozen before round 1. **Authority: AI self-discipline, self-imposed by this loop, never operator-ratified** — any report citing this pre-commitment says so, and none of it is presented as the operator's ruling.

- **factual-trigger**: two consecutive review rounds landing an independently-new Blocker or Major on the same component (the standing threshold; no loosening is claimed).
- **contextual-trigger**: before a third round of rework on that component begins.
- **trigger-priority**: the **factual** trigger governs when the two disagree.
- **never-dropped**: (i) mechanical, fail-closed detection of the **`host-local`** shape, together with the negative control that a configuration file name of the `<name>.local.<ext>` class keeps passing; (ii) the exit-code contract `0`/`1`/`2` and its fail-closed direction; (iii) the property that no byte of the new host-name shape enters the tree, every fixture being assembled at runtime. Defeat of any of the three **stops the task and returns it to planning** — it does not buy a patch round, because the same mechanism defeated across consecutive design generations is evidence about the design premise rather than about the implementation's craft.
- **droppable-1st**: the **`tracker-key`** rule in full — the id, its opt-in mechanism, its fixtures, its documentation bullet and its header entry. It is the droppable half on a measured ground rather than a guess: it ships off by default, so dropping it removes no detection an adopter is relying on, and its whole difficulty is the inseparable lookalike population DP-1 measures, which a follow-up can reopen with a different mechanism rather than a further narrowing of this one. Dropping it also removes the only component whose correctness argument depends on a judgment about vocabulary rather than on a shape.
- **droppable-2nd**: the family-coverage breadth of **AC14** beyond the minimum each rule requires — the boundary and length ranges shrink to one spelling per property, and the declared narrowing is recorded in the header inventory and the hand-off.
- **droppable-3rd**: the header's anchoring/boundary-inventory prose polish beyond the minimum the new rules require — **AC8**'s for-all coverage stays, the rewriting of neighbouring entries goes.
- **drop-disposition**: the dropped component is filed as its own issue carrying that round's findings **verbatim** as its requirement list, never re-derived there, and the board entry records which component was dropped and why it was the droppable one.

## Two-tier verdict scope for the reviewer's briefing

- **Tier 1 — full adversarial strength**: `bin/check-pii-shapes.sh` itself, `tests/check-pii-shapes/run.sh`, and the CI steps that run them. Consumer class: this repository's every-pull-request required gate **and** adopters who execute the script. The development-scaffold carve-out does not reach a shared `bin/` checker.
- **Tier 2 — computed-value correctness, conclusion direction and real instrument defects only**: this spec's own inline `- check:` lines. No adopter executes them; adversarial guard-mutation completeness of a check line is **not** a Major.

## Blast radius

Predictions, not measurements: `pm-spec` holds no shell, and under this cycle's operating mode the full-population criterion-by-criterion diff is the release-time sweep's measurement (**AC17**(d)). Any prediction the sweep does not confirm is reported there as a finding about this prediction rather than silently corrected.

- predicted-already-red, and named as already-red rather than as this task's doing: `.shell-team/specs/T-1051-inspection-ux-polish.md` **AC2** — measured at its own check line, it reads a **pinned** commit's blob of the checker and asserts the count of `^RE_[A-Z0-9_]+=` lines at HEAD **equals** that base's. Rules added after that pin already broke the equality, so this task inherits a red criterion rather than reddening a green one. Its base is pinned rather than a moving ref, so this is not merge-point staleness that time repairs. Disposition: disclosed, not repaired.
- predicted-already-red: `.shell-team/specs/T-1051-inspection-ux-polish.md` **AC5** — asserts that every line of both adopter documents **outside** the `token` bullet is byte-identical to that same pinned base. Bullets added after the pin already broke it; **AC10** adds three more, also outside the `token` bullet. The sweep settles whether it is already red at this branch's base, which decides whether this task is a cause at all. Disposition: disclosed, not repaired.
- predicted-red: `.shell-team/specs/T-1101-pii-path-shapes.md` **AC17** — a merge-point-scoped scope lock over that task's own allow-list; this task's paths sit outside the set it was authored against. Stale by construction at its own merge point, exactly as its own body says it will be.
- predicted-green, and stated because it is the criterion most at risk: `.shell-team/specs/T-1101-pii-path-shapes.md` **AC10** — its id-set equality compares the ids `scan_content_file()` reports against the ids the header's shape list names, both derived at run time. It stays green only if both new ids appear in **both** places and no other line of the header accidentally matches the header-id pattern. **AC8** re-asserts the same invariant with raised floors precisely so this is verified here rather than inherited.
- predicted-green: `.shell-team/specs/T-1101-pii-path-shapes.md` **AC1**, **AC3**, **AC4** — all three are floors, and this task only adds. **AC9** — its placeholder label is matched verbatim and **AC11** requires the new placeholder assertion to be added alongside it rather than to reword it. **AC12** and **AC14** — the known-shapes list and the workflow are locked byte-identical here too.
- predicted-green: `.shell-team/specs/T-111-pii-shape-checker.md` **AC10**, **AC11**, **AC12**, **AC13**, **AC15**, **AC16**, **AC18**, **AC19**, **AC20**, **AC21**, **AC22**, **AC25** — each is a property this task's own criteria are written to preserve and re-assert. **AC16**'s clause that the workflow contains no `--all` occurrence is the reason **AC12** locks the workflow byte-identical instead of adding an audit step.
- predicted-green: `.shell-team/specs/T-112-commit-identity-and-ignore-lock.md` **AC17**, **AC21**, **AC22** and `.shell-team/specs/T-113-lessons-deidentification.md` **AC10**, **AC11** — all run this checker change-scoped and the fixture suite, or match documentation lines whole-line-exact; **AC6**, **AC2** and **AC10** keep all three green.
- **frozen-prose staleness, disclosed rather than repaired**: the shipped rule-decomposition sentence's numeral is replaced by **AC8**, but the same numeral is also quoted inside a merged frozen block, where no check line reads it. Repairing that quotation would be a class-B re-freeze of merged frozen intent, which Non-goals forbids; it is collected for a batched editorial pass instead.
- predicted-unknown, and named as unknown rather than guessed: every merged spec carrying a base-relative scope lock or a whole-tree diff allow-list authored at an earlier merge point. That population is not enumerable by eye and is exactly what the release-time sweep settles. A criterion that reaches its target through indirection — a path built at run time from `bin/team-paths.sh --get todo`, a file named only through a variable — matches no search for that path's literal bytes, so the sweep runs those criteria rather than grepping for them.

Populations of the two outlines in the tracked corpus — derived, never counted by eye.

- reproduce: bash bin/derive-populations.sh --label T-1140-tracker-key-lookalikes --set "all=git grep -I -o -h -P '\b[A-Z][A-Z0-9]{1,9}-[0-9]+\b' -- . ':!tests/check-pii-shapes' | sort -u" --set "letters-only=git grep -I -o -h -P '\b[A-Z]{2,10}-[0-9]+\b' -- . ':!tests/check-pii-shapes' | sort -u" --set "t-id=git grep -I -o -h -P '\bT-[0-9]+\b' -- . ':!tests/check-pii-shapes' | sort -u" --set "dp-label=git grep -I -o -h -P '\b(DP|US|AC|MED|NEEDS|NEW|NF|NR|SA|STOP|DS|DATE|DECISION)-[0-9]+\b' -- . ':!tests/check-pii-shapes' | sort -u" --set "technical=git grep -I -o -h -P '\b(UTF|SHA|ISO|CVE|RFC|HTTP|SC|SIGKILL|IEEE|GPT|CC|BY|RLENGTH)-[0-9]+\b' -- . ':!tests/check-pii-shapes' | sort -u"

<!-- BEGIN derivation: T-1140-tracker-key-lookalikes -->
- derived-by: bin/derive-populations.sh
- locale: LC_ALL=C
- set: all — status: 0 — lines: 84 — items: 84 — command: git grep -I -o -h -P '\b[A-Z][A-Z0-9]{1,9}-[0-9]+\b' -- . ':!tests/check-pii-shapes' | sort -u
- set: letters-only — status: 0 — lines: 48 — items: 48 — command: git grep -I -o -h -P '\b[A-Z]{2,10}-[0-9]+\b' -- . ':!tests/check-pii-shapes' | sort -u
- set: t-id — status: 0 — lines: 354 — items: 354 — command: git grep -I -o -h -P '\bT-[0-9]+\b' -- . ':!tests/check-pii-shapes' | sort -u
- set: dp-label — status: 0 — lines: 37 — items: 37 — command: git grep -I -o -h -P '\b(DP|US|AC|MED|NEEDS|NEW|NF|NR|SA|STOP|DS|DATE|DECISION)-[0-9]+\b' -- . ':!tests/check-pii-shapes' | sort -u
- set: technical — status: 0 — lines: 8 — items: 8 — command: git grep -I -o -h -P '\b(UTF|SHA|ISO|CVE|RFC|HTTP|SC|SIGKILL|IEEE|GPT|CC|BY|RLENGTH)-[0-9]+\b' -- . ':!tests/check-pii-shapes' | sort -u
- union: items: 438
- bucket: all — items: 36
  - AC1-5
  - AC18-20
  - AC4-13
  - AC4-7
  - AC9-27
  - L194-199
  - L194-210
  - L196-211
  - L2-74
  - L206-207
  - L226-240
  - L242-244
  - L302-320
  - L308-317
  - L350-366
  - L428-434
  - L45-48
  - L49-51
  - L51-59
  - L606-647
  - L643-660
  - L68-80
  - L98-143
  - R1-1
  - R1-2
  - R1-3
  - R1-4
  - R1-5
  - R1-6
  - R1-7
  - R1-8
  - R1-9
  - R2-1
  - R2-2
  - R2-3
  - Z0-9
- bucket: all+letters-only — items: 3
  - XYZZY-42
  - ZERO-010
  - ZERO-08
- bucket: all+letters-only+dp-label — items: 37
  - AC-1
  - AC-2
  - DATE-2
  - DECISION-4
  - DP-1
  - DP-10
  - DP-11
  - DP-12
  - DP-13
  - DP-14
  - DP-15
  - DP-2
  - DP-3
  - DP-330
  - DP-4
  - DP-5
  - DP-6
  - DP-7
  - DP-8
  - DP-9
  - DS-1
  - DS-2
  - DS-3
  - DS-4
  - DS-5
  - DS-6
  - DS-7
  - DS-8
  - MED-1
  - NEEDS-10
  - NEW-1
  - NEW-2
  - NEW-3
  - NF-2
  - NR-1
  - SA-1
  - STOP-1
- bucket: all+letters-only+technical — items: 8
  - GPT-5
  - ISO-8601
  - RFC-2606
  - RLENGTH-4
  - SHA-1
  - SHA-256
  - UTF-16
  - UTF-8
- bucket: t-id — items: 354
  - T-000
  - T-001
  - T-002
  - T-003
  - T-004
  - T-005
  - T-006
  - T-009
  - T-012
  - T-013
  - T-014
  - T-015
  - T-016
  - T-017
  - T-019
  - T-020
  - T-021
  - T-022
  - T-023
  - T-024
  - T-025
  - T-026
  - T-028
  - T-029
  - T-030
  - T-031
  - T-032
  - T-033
  - T-034
  - T-036
  - T-037
  - T-038
  - T-039
  - T-040
  - T-042
  - T-043
  - T-044
  - T-045
  - T-046
  - T-047
  - T-048
  - T-050
  - T-051
  - T-053
  - T-054
  - T-055
  - T-058
  - T-060
  - T-061
  - T-063
  - T-066
  - T-068
  - T-070
  - T-071
  - T-072
  - T-073
  - T-074
  - T-075
  - T-076
  - T-077
  - T-078
  - T-079
  - T-085
  - T-087
  - T-088
  - T-089
  - T-0900
  - T-0901
  - T-091
  - T-095
  - T-096
  - T-097
  - T-098
  - T-099
  - T-1
  - T-10
  - T-100
  - T-1000
  - T-1001
  - T-1002
  - T-1003
  - T-1004
  - T-1005
  - T-1006
  - T-1007
  - T-1008
  - T-1009
  - T-101
  - T-1010
  - T-1011
  - T-1012
  - T-1013
  - T-1014
  - T-1015
  - T-1016
  - T-1017
  - T-1018
  - T-1019
  - T-102
  - T-1020
  - T-1021
  - T-1022
  - T-1023
  - T-1024
  - T-1025
  - T-1026
  - T-1027
  - T-1028
  - T-1029
  - T-103
  - T-1030
  - T-1031
  - T-1032
  - T-1033
  - T-1034
  - T-1035
  - T-1036
  - T-1037
  - T-1038
  - T-1039
  - T-104
  - T-1040
  - T-1041
  - T-1042
  - T-1043
  - T-1044
  - T-1045
  - T-1046
  - T-1047
  - T-1048
  - T-1049
  - T-105
  - T-1050
  - T-1051
  - T-1052
  - T-1053
  - T-1054
  - T-1055
  - T-1056
  - T-1057
  - T-1058
  - T-1059
  - T-106
  - T-1060
  - T-1061
  - T-1062
  - T-1063
  - T-1064
  - T-1065
  - T-1066
  - T-1067
  - T-1068
  - T-1069
  - T-107
  - T-1070
  - T-1071
  - T-1072
  - T-1073
  - T-1074
  - T-1075
  - T-1076
  - T-1077
  - T-1078
  - T-1079
  - T-108
  - T-1080
  - T-1081
  - T-1082
  - T-1083
  - T-1084
  - T-1085
  - T-1086
  - T-1087
  - T-1088
  - T-1089
  - T-109
  - T-1090
  - T-1091
  - T-1092
  - T-1093
  - T-1094
  - T-1095
  - T-1096
  - T-1097
  - T-1098
  - T-1099
  - T-11
  - T-110
  - T-1100
  - T-1101
  - T-1102
  - T-1103
  - T-1104
  - T-1105
  - T-1106
  - T-1107
  - T-1108
  - T-1109
  - T-111
  - T-1110
  - T-1111
  - T-1112
  - T-1113
  - T-1114
  - T-1115
  - T-1116
  - T-1117
  - T-1118
  - T-1119
  - T-112
  - T-1120
  - T-1121
  - T-1126
  - T-1127
  - T-1128
  - T-1129
  - T-113
  - T-1130
  - T-1131
  - T-1132
  - T-1133
  - T-1134
  - T-1135
  - T-1136
  - T-1137
  - T-1138
  - T-1139
  - T-12
  - T-123
  - T-150
  - T-151
  - T-152
  - T-160
  - T-2
  - T-200
  - T-2000
  - T-201
  - T-202
  - T-210
  - T-220
  - T-230
  - T-300
  - T-301
  - T-302
  - T-303
  - T-401
  - T-500
  - T-501
  - T-502
  - T-600
  - T-601
  - T-602
  - T-777
  - T-800
  - T-801
  - T-802
  - T-899
  - T-9
  - T-90
  - T-900
  - T-9001
  - T-9002
  - T-901
  - T-902
  - T-903
  - T-904
  - T-905
  - T-906
  - T-907
  - T-908
  - T-909
  - T-950
  - T-951
  - T-960
  - T-961
  - T-962
  - T-963
  - T-970
  - T-971
  - T-972
  - T-973
  - T-974
  - T-975
  - T-976
  - T-977
  - T-978
  - T-979
  - T-980
  - T-981
  - T-982
  - T-983
  - T-984
  - T-985
  - T-986
  - T-987
  - T-988
  - T-989
  - T-990
  - T-991
  - T-992
  - T-993
  - T-994
  - T-995
  - T-99501
  - T-99505
  - T-99506
  - T-99507
  - T-99508
  - T-99509
  - T-99510
  - T-99511
  - T-99512
  - T-99513
  - T-99514
  - T-99515
  - T-99516
  - T-99517
  - T-99518
  - T-99519
  - T-99520
  - T-99521
  - T-99522
  - T-99523
  - T-99601
  - T-99602
  - T-99603
  - T-99604
  - T-99605
  - T-99606
  - T-99607
  - T-99608
  - T-99609
  - T-99610
  - T-99611
  - T-99701
  - T-99702
  - T-99703
  - T-99704
  - T-99705
  - T-99706
  - T-99707
  - T-99801
  - T-99802
  - T-99803
  - T-99804
  - T-999
  - T-99901
  - T-99902
  - T-99903
  - T-99904
  - T-99905
  - T-9999
  - T-99999
  - T-999999
<!-- END derivation: T-1140-tracker-key-lookalikes -->

**The two authoring-site resolutions this task performs, and why the block below carries a token of the very shape it measures.** The `all` set's command ends in a negative lookahead, so it emits only tokens with **nothing** after the machine-local suffix — exactly the shape the `host-local` rule reports. Measured: one such token, occurring in two tracked records where a configuration file is named without its extension. Those two occurrences are this task's whole corpus work: each is resolved at its authoring site by appending the extension, never by widening the rule and never by list growth, which is why **AC15**'s allow-list names those two paths and `## Notes for engineer` names the edit. The block as pasted therefore carries that bare token itself; after the two resolutions the engineer re-runs the `- reproduce:` line so the `all` bucket is empty and this spec carries no bare token of its own, and replaces the block verbatim before the commit that ships the rule. **AC11** is the instrument that catches this if it is not done, and it is expected to fail at freeze for exactly this reason — the instrument working rather than a line to repair.

- reproduce: bash bin/derive-populations.sh --label T-1140-host-local-lookalikes --set "all=git grep -o -h -i -P '\b[A-Za-z0-9-]+\.local(?![.A-Za-z0-9-])' -- . | sort -u" --set "config-file=git grep -o -h -i -P '\b[A-Za-z0-9-]+\.local\.(md|json|yaml|yml|conf|toml)\b' -- . | sort -u" --set "placeholder=git grep -o -h -P '<host>\.local' -- . | sort -u"

<!-- BEGIN derivation: T-1140-host-local-lookalikes -->
- derived-by: bin/derive-populations.sh
- locale: LC_ALL=C
- set: all — status: 0 — lines: 1 — items: 1 — command: git grep -o -h -i -P '\b[A-Za-z0-9-]+\.local(?![.A-Za-z0-9-])' -- . | sort -u
- set: config-file — status: 0 — lines: 2 — items: 2 — command: git grep -o -h -i -P '\b[A-Za-z0-9-]+\.local\.(md|json|yaml|yml|conf|toml)\b' -- . | sort -u
- set: placeholder — status: 0 — lines: 1 — items: 1 — command: git grep -o -h -P '<host>\.local' -- . | sort -u
- union: items: 4
- bucket: all — items: 1
  - CLAUDE.local
- bucket: config-file — items: 2
  - CLAUDE.local.md
  - settings.local.json
- bucket: placeholder — items: 1
  - <host>.local
<!-- END derivation: T-1140-host-local-lookalikes -->

Two facts the host-name block settles, both load-bearing above. First, **no workstation host name exists in tracked content**: every measured occurrence of the outline is a configuration file name — two carrying their extension, which DP-2's named class keeps clean, and one base name written without its extension, which that class cannot reach and which the two authoring-site resolutions close — so the shipped default costs zero findings once this task's own corpus work lands. Second, the `all` set does **not** contain the placeholder form, which the `placeholder` set found separately — measured confirmation that the placeholder is a non-match by construction rather than by exemption.

## Assumptions

- **Measured first-hand, not relayed** (each re-read at its primary source during authoring): the checker's thirteen top-level `RE_*=` assignment lines and its two composition lines, giving the eleven independent rules its own header states; the absence of `\b` from every shipped regex; the seven header shape-list ids; the seven `assert_neutralised_pattern_unreported` and seven `assert_meta_fails` call sites; the shipped precondition idiom and the placeholder assertion's label; the whole-line-exact documentation locks in both languages, the two named-entity lines among them; the pinned-base equality and byte-identity criteria that are already falsified; and the workflow's shellcheck argument list, its two checker steps and the absence of `--all` from the file.
- **Measured borrowed-vocabulary count premises.** Every literal count premise this spec rests on is classified and enumerated here; the freeze run measures each at the branch point's committed blob and records the value beside this line.
  - `tracker-key` and `host-local` as pattern ids — **own-coinage**, introduced by this task; expected **0** at the branch point. Branch-point command: `B=$(git merge-base develop HEAD); git grep -cF -e 'tracker-key' "$B" -- .` and the same for `host-local`.
  - The tracker-key outline populations (84 / 48 / 354 / 37 / 8) — **borrowed**, every token being vocabulary another document coined. Branch-point command: the `- reproduce:` line of the first derivation block above, run against the branch point.
  - The machine-local host-suffix populations (the bare-token set, the extension-bearing set and the placeholder set, union 4) — **borrowed** for the three configuration-file tokens, **own-coinage** for the placeholder form this task documents. The bare-token set is expected to be **non-empty at the branch point** and **empty at HEAD**, the two authoring-site resolutions being what moves it. Branch-point command: the `- reproduce:` line of the second derivation block above, run against the branch point.
  - `eleven independently load-bearing rules` as a literal in the checker — **borrowed** (coined by an earlier task's header prose): expected **1** occurrence at the branch point, which **AC8** requires to be **0** at HEAD. Branch-point command: `B=$(git merge-base develop HEAD); git grep -cF -e 'eleven independently load-bearing rules' "$B" -- bin/check-pii-shapes.sh`.
  - `off in the shipped default` as the header anchor **AC8** greps — **own-coinage**, introduced by this task; expected **0** at the branch point. Branch-point command: `B=$(git merge-base develop HEAD); git grep -cF -e 'off in the shipped default' "$B" -- .`.
  - The three canonical documentation lines per language **AC10** greps — **own-coinage**; expected **0** at the branch point. Branch-point command: `B=$(git merge-base develop HEAD); git grep -cF -e 'The tracker-key rule is off in the shipped default' "$B" -- docs`.
- **Unverified by `pm-spec` (no shell)**: that every `- check:` line above runs as written. The freeze run executes each one live and repairs any line that is mechanically broken, vacuous, or measured-contradictory with its own prose, before the intent hash is recorded — meaning-preservingly, and routed back here if the repair would change what a criterion claims. **AC11** is expected to **fail** at that run for the two disclosed reasons stated in `## Blast radius` — the two records still carrying the unextended base name, and the pasted derivation block still carrying that same token as its own measurement — both of which the implementation closes, so the failure is the instrument working and not a line to repair.
- `shellcheck` is available at the version CI pins. **AC1** and **AC17**(e) fail loudly rather than skipping if it is absent.
- The `git grep` invocations in the `- reproduce:` lines use PCRE, which resolved in this checkout when the derivations were produced. If a re-run environment lacks it, the derivation refuses rather than emitting a wrong population, and that refusal is reported rather than worked around.

## Open questions

None blocking. DP-1 through DP-5 are resolved above with their grounds; the engineer does not reopen them. One item is surfaced rather than left silent: the routing recommendation asked for a named-class rule covering the standards-identifier population as well, and DP-2 records that no shape closes it, so the mechanism there is the shipped-default silence plus a declared accepted-noise class. That deviation is flagged in the hand-off.

## Notes for engineer

**Files likely touched (this is AC15's allow-list):** `bin/check-pii-shapes.sh` (the header shape list, the rule-decomposition sentence, the anchoring/boundary inventory, the pattern block, and `scan_content_file()` — the header is `--help`'s source, so it is code); `tests/check-pii-shapes/run.sh`; `docs/pii-controls.md`; `docs/pii-controls.ja.md`; `.shell-team/test-recipe.md` (append the procedure you establish); `.shell-team/todo.md`; `.shell-team/interventions/T-1109.md` and `.shell-team/reviews/T-1110.md` (the two authoring-site resolutions below, and nothing else in either file); this spec; and this task's provenance, interventions and review records.

**The two authoring-site resolutions, and why they are in scope at all.** Measured: one configuration file base name is written **without** its extension in two tracked records — `.shell-team/interventions/T-1109.md:25` and `.shell-team/reviews/T-1110.md:23`, in a parenthetical naming a standing rule. The `host-local` rule reports both, so **AC6** cannot hold until they are resolved, and the resolution is the documented one: append the extension so each reads as the configuration file name it means, which puts it inside the named class. Change nothing else in either record — no verdict, no severity, no finding text, no surrounding prose — and note that both are append-only records, so this is a repair of two existing tokens rather than an append. These two paths are in **AC15**'s allow-list for exactly this reason and for no other.

**The id-set equality is the sharpest edge in the task.** A merged criterion compares the id set `scan_content_file()` reports against the id set the header names, both derived at run time, and the header side is derived by matching header lines of the form `#   <lowercase-id> `. Two consequences. First, both new ids must appear in **both** places, in exactly that header form. Second, **any** new header comment line whose text begins with three spaces and a lower-case word followed by a space joins the header id set and reds that criterion — so write the opt-in's explanation as ordinary header prose, never indented to that depth with a lower-case first word.

**The self-reference trap, and where it does and does not bite.** The host-name regex literal is safe by construction: in `\.local` the character before the suffix is a backslash, and in a name class followed by `+` it is a metacharacter, so neither assignment line matches itself. The prose is where it bites — write the placeholder form `<host>.local` and the class form `<name>.local.<ext>` everywhere you must discuss the shape, in this spec, in the header, in both adopter documents and in every record. The one place it already bit is recorded in `## Blast radius`: a derivation block whose emitted items carry the suffix without an extension. Verify by running the checker against its own file and against the whole tree, never by reading the regex.

**The opt-in mechanism is yours to choose, within one constraint.** DP-5 fixes the requirement rather than the spelling: the suite's existing assertion helpers must reach it without a signature change, because their call-site counts are floored by merged criteria. An environment-carried mechanism satisfies this for free — `run_checker` and the mutation helpers all fork children that inherit the environment — and a trailing optional argument satisfies it too, since the call-site greps count the call rather than its arity. Whichever you pick, `--help` must name it and the shipped default must be off.

**Decompose before you write the negative controls.** A single-regex rule cannot have a negative control that proves anything: if the outline itself excludes the input, the input never reached the rule and the fixture is vacuous. Give each new rule a broad outline half on its own assignment line and compose the narrowing requirement on top, the way the shipped temp-root pair already does, then read the outline half out of the checker's own source in the precondition idiom. **AC5** is unsatisfiable otherwise.

**Add labels alongside, never rewrite one.** The existing placeholder assertion's label is matched verbatim by a merged criterion. Add your host placeholder form under a new label with its own fixture, and leave that one byte-identical.

**Commit before running the corpus criteria.** The change-scoped mode reads *committed* content, so an uncommitted fix is invisible to **AC6** and to every base-relative criterion.

**Triage rule if the checker reds on something unexpected.** A real leak is disclosed separately to the orchestrator and never silently fixed. Legitimate documentation-about-the-class goes through the placeholder convention at its authoring site — never list growth, never an inline marker.

**Sensitive-scoping duty.** New fixtures use synthetic host names and synthetic tracker namespaces only, assembled from fragments at runtime — never a real host name from the machine you are running on and never an adopter's real namespace. Run `bin/check-pii-shapes.sh` against every new record **before its first commit**; the CI diff-time check is the backstop, not the primary defence.

**Measured-at-ref labels**: `not applicable` does not hold here. The `- reproduce:` lines and the branch-point commands in `## Assumptions` each name a ref and read that ref's committed blobs through `git grep <rev>` rather than the working tree; keep that property when you re-derive them, and if you add a measured-at-ref label anywhere in the records, its printed command must read that ref's blob too.
