# The reviewer prompts and the distribution docs say a `codex exec` launch line starts with `codex` and carries nothing before or after it

**Status**: READY_FOR_ENG
**Owner**: pm-spec
**Task ID**: T-1187

## Problem

On 2026-10-11, the first code-review round under the 2.9.0 plugin snapshot failed to start. The `code-reviewer` sub-agent launched its primary pass as `cd <repo>; codex exec --sandbox read-only --cd <repo> review --base develop --json -o "<RAW_OUT>"`. The host's `sandbox.excludedCommands` entries are `codex` and `codex *` (**relayed**: the coordinating session's measurement of the host settings). Since Claude Code 2.1.278 a command is exempted only when every part of it matches, so the leading `cd …;` part made the whole line run inside the sandbox, where Codex fails with `workspace routing discovery failed` → `turn.failed` (board record: T-1186's codex-reviewer line in `.shell-team/todo.md`). Every other review that day began with the bare token `codex` and succeeded (**relayed**), and a retry whose briefing stated the condition succeeded.

The shipped prose names only trailing parts. `agents/code-reviewer.md` line 46 and `agents/drift-evaluator.md` line 104 say "Do not close stdin yourself — a redirect or any other added part makes the line multi-part …", and the 2.1.278 matching-rule paragraph at line 89 of `docs/distribution.md` and `docs/distribution.ja.md` is phrased around a trailing redirection. Read that way, a leading `cd <dir>;`, an assignment, `env`, a subshell or `time` looks allowed.

- user-visible: yes — the reviewer prompts run in the adopter's own environment, and the distribution docs are the adopter's reference for the `sandbox.excludedCommands` setting.
- shipped-docs: docs/distribution.md — this-task
- shipped-docs: docs/distribution.ja.md — this-task
- stacked-on: T-1186 (hotfix/720-crlf-line-endings @ 7cd6f4d1); PR base develop; ships in v2.9.1 with T-1186 (operator ruling 2026-10-11)

## Acceptance criteria

Every check line runs from the repository root. `P=7cd6f4d1` is this branch's cut point, T-1186's close-out commit. Using it as the base excludes T-1186's own files from every diff below.

- [ ] **AC1** `agents/code-reviewer.md` and `agents/drift-evaluator.md` each state the positive invariant on the line that holds "Do not close stdin yourself". The phrase "Do not close stdin" stays on that line. The invariant is that the Bash command launching `codex exec` is that one command and nothing else. Its first token is `codex`. Nothing comes before it: no `cd`, no assignment, no `env`, no subshell, no `time`. Nothing comes after it: no pipe, redirection, `;`, `&&`, `||`, `&`, command substitution or line continuation. The working directory is passed with `--cd`. The same line names `` `cd <repo>;` `` as the observed counterexample, in backticks and mid-line. It must never start a line, because `tests/codex-skeleton-hygiene/run.sh` line 837 counts lines matching `^[[:space:]]*codex exec ` and expects 3 in code-reviewer and 1 in drift-evaluator. That line contains the fixed phrase `is that one command and nothing else` exactly once in the file, plus the backticked tokens `` `cd <repo>;` ``, `` `--cd` ``, `` `env` `` and `` `time` ``. No line in either file starts with `cd <repo>;`, with or without a leading backtick. Each file's bare-line count is unchanged from `P`.
  - check: rc=0; P=7cd6f4d1; git cat-file -e "$P^{commit}" || exit 1; for F in agents/code-reviewer.md agents/drift-evaluator.md; do test -r "$F" || exit 1; n=$(grep -cF -- 'is that one command and nothing else' "$F"); test "$n" = 1 || rc=1; m=$(grep -F -- 'Do not close stdin' "$F" | grep -F -- 'is that one command and nothing else' | grep -F -- '`cd <repo>;`' | grep -F -- '`--cd`' | grep -F -- '`env`' | grep -cF -- '`time`'); test "$m" = 1 || rc=1; grep -qE '^[[:space:]]*`?cd <repo>;' "$F"; r=$?; test "$r" = 1 || rc=1; h=$(grep -cE '^[[:space:]]*codex exec ' "$F"); b=$(git show "$P:$F" | grep -cE '^[[:space:]]*codex exec '); test -n "$h" && test "$h" -ge 1 && test "$h" = "$b" || rc=1; done; test "$rc" -eq 0

- [ ] **AC2** `docs/distribution.md` and `docs/distribution.ja.md` each gain one sentence in the 2.1.278 matching-rule paragraph. The sentence says that a leading part (`cd <dir>;`, an assignment, `env`, a subshell) is a non-matching part under the same rule, and it names `cd` as `` `cd <dir>;` ``. The change is pure addition, so the sentence goes on a new line directly after the paragraph's existing line, with no blank line between them, which keeps it in the same Markdown paragraph. Each file has exactly one `git diff --numstat` row against `P`, and that row shows 0 deletions. The line containing `cd <dir>;` belongs to the paragraph that opens `**The matching rule changed in Claude Code 2.1.278.**` (EN) or `**一致のルールは Claude Code 2.1.278 で変わりました。**` (JA), with no blank line between the opener and it.
  - check: rc=0; P=7cd6f4d1; git cat-file -e "$P^{commit}" || exit 1; for F in docs/distribution.md docs/distribution.ja.md; do test -r "$F" || exit 1; git diff --no-renames --numstat "$P"...HEAD -- "$F" > "${TMPDIR:-/tmp}/t1187-ac2.ns" || exit 1; awk -F '\t' 'END { exit !(NR == 1 && $2 == 0 && $1 > 0) } { }' "${TMPDIR:-/tmp}/t1187-ac2.ns" || rc=1; awk -v e='**The matching rule changed in Claude Code 2.1.278.**' -v j='**一致のルールは Claude Code 2.1.278 で変わりました。**' -v t='cd <dir>;' 'index($0, e) == 1 || index($0, j) == 1 { inp = 1 } inp && $0 == "" { inp = 0 } inp && index($0, t) { ok = 1 } END { exit !ok }' "$F" || rc=1; done; test "$rc" -eq 0

- [ ] **AC3** `tests/codex-skeleton-hygiene/run.sh` exits 0. It runs under `ulimit -f 400000`, with its output capped by `head -c`.
  - check: ulimit -f 400000 2>/dev/null; T=$(mktemp -d "${TMPDIR:-/tmp}/t1187-ac3.XXXXXX") || exit 1; bash tests/codex-skeleton-hygiene/run.sh < /dev/null 2>&1 | head -c 20000000 > "$T/out"; s=("${PIPESTATUS[@]}"); test "${s[0]}" -eq 0 && test "${s[1]}" -eq 0

- [ ] **AC4** `bin/check-prompt-sync.sh` exits 0. `bin/check-codex-agents.sh` exits 0 against an out-dir freshly generated by `bin/gen-codex-agents.sh` under `$TMPDIR`. Both scripts take `--root` as this checkout. The repository's own `.codex/agents` is gitignored, so it is never read or written.
  - check: ulimit -f 400000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1187-ac4.XXXXXX") || exit 1; bash bin/check-prompt-sync.sh < /dev/null > "$T/ps.out" 2>&1 || exit 1; bash bin/gen-codex-agents.sh --root "$R" --out-dir "$T/agents" < /dev/null > "$T/gen.out" 2>&1 || exit 1; test -d "$T/agents" || exit 1; bash bin/check-codex-agents.sh --root "$R" --out-dir "$T/agents" < /dev/null > "$T/chk.out" 2>&1

- [ ] **AC5** The scope lock. This task's measured set must be a subset of `agents/code-reviewer.md`, `agents/drift-evaluator.md`, `docs/distribution.md`, `docs/distribution.ja.md` and paths under `.shell-team/`. The measured set is the union of four reads:
  - the committed range `P...HEAD`;
  - the staged delta;
  - the unstaged delta;
  - untracked files.

  Each of the three `git diff` reads uses `--no-renames`. The set must also contain `agents/code-reviewer.md`, so the lock is not vacuous. This criterion is tied to this merge point and is expected to go stale once later work lands on the same base. Do not widen its base to keep it evergreen.
  - check: P=7cd6f4d1; git cat-file -e "$P^{commit}" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1187-ac5.XXXXXX") || exit 1; { git diff --no-renames --name-only "$P"...HEAD && git diff --no-renames --cached --name-only && git diff --no-renames --name-only && git ls-files --others --exclude-standard; } > "$T/set" || exit 1; grep -qxF agents/code-reviewer.md "$T/set" || exit 1; grep -vxE 'agents/code-reviewer\.md|agents/drift-evaluator\.md|docs/distribution\.md|docs/distribution\.ja\.md|\.shell-team/.*' "$T/set" > "$T/bad"; r=$?; test "$r" -le 1 || exit 1; test ! -s "$T/bad"

## Notes

- Shellcheck does not apply here, because this task changes nothing under `bin/`.
- Two premises in `## Problem` are **relayed**: the host's `sandbox.excludedCommands` entries, and the claim that the other reviews that day began with a bare `codex` and succeeded. The coordinating session holds the primary measurement for both, and no criterion depends on either.
- `P=7cd6f4d1` is a literal base, as the coordinating session instructed. T-1186's branch is the predecessor. If it is rebased or squash-merged before this task merges, AC1, AC2 and AC5 are a route-back, not something to repair inside a criterion.

## Out of scope

- `skills/run/SKILL.md` (around line 260) and `templates/prompt-blocks/alternate-executor-invocation.md` (around line 29) both say an exclusion "matches on its first token alone". These sentences describe the orchestrator's alternate-executor path, which the Routing Map left out of this task. Do not edit them here. Track the correction in a follow-up issue.
