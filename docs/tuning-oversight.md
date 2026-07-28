# Tuning how often the team stops to ask

[English](tuning-oversight.md) | [日本語](tuning-oversight.ja.md)

How often a session checks in with you is a working preference. It differs
between people and between repositories, and this project has no standing to
decide it for you — so it is not baked into the plugin. This page explains which
part is fixed, which part is yours, and where to put your answer.

## What is fixed, and what is yours

**Fixed — the loop's completion gate.** A task is done only when QA reaches
`READY_FOR_REVIEW` *and* the cross-provider review reaches `READY_FOR_MERGE`.
That is carried by status flags in the board, not by conversation, so no
personal setting relaxes it. Merging waits for a human by the same design.

**Yours — everything the main session does around that.** Whether it proposes a
change set before editing, confirms a branch name, asks before filing an issue,
or simply proceeds and tells you what it chose.

## Two kinds of stop, two different fixes

They look the same in a session and are not the same mechanism.

| What you see | Layer | Where to change it |
|---|---|---|
| "Shall I open an issue for this?" · "Is this branch name right?" · a change set presented for approval | Instructions Claude is following | `CLAUDE.local.md` |
| "Allow `Bash(git push …)`?" · a tool-permission prompt | The permission system | `.claude/settings.local.json` |

The distinction matters because only the second is enforcement. Instructions are
context Claude weighs; permission rules are checked by the client regardless of
what Claude decides.

## Where personal settings go

Claude Code reads instructions from broadest to most specific, and later files
are read last:

| Scope | File | Shared with |
|---|---|---|
| All your projects | `~/.claude/CLAUDE.md` | just you, everywhere |
| This project | `./CLAUDE.md` | everyone, via git |
| This checkout | `./CLAUDE.local.md` | just you, here |

`CLAUDE.local.md` is read last, which makes it the right place to qualify a
broader rule for one repository. This repository gitignores it, along with
`.claude/settings.local.json`, so what you write there cannot reach a pull
request.

## Example — fewer interruptions

For someone who wants the loop to run and only wants the merge decision:

```markdown
# Local overrides

The loop's own gate is sufficient oversight here: a task is done only when QA
and the cross-provider review are both green, and merge waits for me.

Do not add conversational gates on top of it:

- Do not ask before creating a branch or filing an issue for work I have already
  asked for. Follow the repo's convention and tell me what you chose.
- Do not stop to have a multi-file change set approved before starting. State
  what you are about to touch, then proceed.
- Do stop before merging, before force-pushing, and before anything that
  destroys work git cannot restore.
```

## Example — more checkpoints

For a team that wants to be consulted earlier:

```markdown
# Local overrides

- Before a change spanning more than one file, state the files, the base branch,
  whether it is additive or destructive, and the issue it serves. Wait.
- Before implementing a feature, agree the issue and the branch name first.
- Get agreement before pushing, opening or merging a pull request, or filing an
  issue.
```

## What is worth keeping in either direction

Two stops earn their cost regardless of preference:

- **Merging**, because it is the point the loop is built around.
- **Anything git cannot undo** — force-pushing, deleting untracked files,
  overwriting a file whose only copy is the one being replaced. When a step is
  safe only because something was preserved first, that preservation should be
  verified before the destructive part runs, not assumed.

## Limits

A `CLAUDE.md` is context, not configuration Claude must obey — loosening or
tightening through it changes the odds, not the mechanism. What has to hold
regardless belongs in CI, as this repository's own checks do, or in a hook.

**This project ships no hooks.** A hook is executable configuration, and a
public repository is the wrong place for one to arrive by default. If you want
enforcement rather than instruction, write the hook in your own checkout, where
you can read it before it runs.
