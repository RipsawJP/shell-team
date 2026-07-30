# Tuning how often the team stops to ask

[English](tuning-oversight.md) | [日本語](tuning-oversight.ja.md)

How often a session checks in with you is a working preference. It differs
between people and between repositories, and this project has no standing to
decide it for you — so it is not baked into the plugin. This page explains which
part is fixed, which part is yours, and where to put your answer.

## What is fixed, and what is yours

**Fixed — the loop's completion gate.** A task is done only when QA reaches `READY_FOR_REVIEW` *and* the cross-provider review reaches `READY_FOR_MERGE`. That is carried by status flags in the board, not by conversation, so no personal setting relaxes it. The loop never merges on its own — merging is a human action, by the same design. That is a claim about authority, not about interruption: the loop cannot merge for you, but whether a given merge earns a conversational stop is the tunable layer covered below, and narrowing it there leaves this fixed layer exactly where it was.

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

For someone who wants the loop to run, and to be asked only where a stop earns its cost:

```markdown
# Local overrides

The loop's own gate is sufficient oversight here: a task is done only when QA
and the cross-provider review are both green, and the loop never merges on its
own.

Do not add conversational gates on top of it:

- Do not ask before creating a branch or filing an issue for work I have already
  asked for. Follow the repo's convention and tell me what you chose.
- Do not stop to have a multi-file change set approved before starting. State
  what you are about to touch, then proceed.
- Do stop before a merge that changes what runs — in this repository that means
  anything under `bin/`, `agents/`, `skills/`, `templates/prompt-blocks/`,
  `CLAUDE.md`, or the workflow.
- A merge of records only — a retro, a board close-out, a provenance record —
  needs no stop: nothing takes effect and one command reverts it.
- Do stop before force-pushing, and before anything that destroys work git
  cannot restore.
```

That path list is this repository's own instantiation of the criterion, not the criterion itself — substitute the surfaces that execute in your own repository before you paste this block.

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

- **A merge that changes what runs** — anything under `bin/`, `agents/`, `skills/`, `templates/prompt-blocks/`, `CLAUDE.md`, or the workflow, in this repository's own terms. A merge of records only — a retro, a board close-out, a provenance record — needs no stop, for the same reason the example above does not ask for one.
- **Anything git cannot undo** — force-pushing, deleting untracked files,
  overwriting a file whose only copy is the one being replaced. When a step is
  safe only because something was preserved first, that preservation should be
  verified before the destructive part runs, not assumed.

The first stop fires on whether the merge changes what runs — not on which branch you are merging into, and not on the word "merge". A records-only merge has no point where the human is the guarantor, because nothing there takes effect, so a stop costs an interruption and buys nothing.

Naming it is a discipline the operator imposes on themselves, not a rule the loop enforces: nothing stops a personal setting from asking for a stop anywhere, but keeping this one exactly at the point of real effect keeps responsibility where the operator decided it belongs, instead of letting accountability drift toward whichever moment felt safest to ask about.

**The trap: file extension is not the signal.** In a repository whose product is prompt content, "it's only docs" is not a safe test — the criterion is whether the content executes, not what the file is called. `templates/prompt-blocks/playbook-*.md` files are `.md`, they are generated artefacts, they read like documentation, and they are spliced into `agents/*.md`, which ship; `bin/check-prompt-sync.sh` enforces that splice, so this is a mechanism you can verify rather than a warning to take on faith.

## Limits

A `CLAUDE.md` is context, not configuration Claude must obey — loosening or
tightening through it changes the odds, not the mechanism. What has to hold
regardless belongs in CI, as this repository's own checks do, or in a hook.

**This project ships no hooks.** A hook is executable configuration, and a
public repository is the wrong place for one to arrive by default. If you want
enforcement rather than instruction, write the hook in your own checkout, where
you can read it before it runs.

## The one sample hook, and why it ships inert

This project still ships no active hook: nothing in `.claude-plugin/plugin.json`
registers one, and nothing lands on a hook load path when you install the
plugin. What ships is an inert, readable sample you install yourself —
`docs/interventions-reminder-hook.sample.sh` — which is exactly what the
Limits paragraph above already told you to do if you wanted enforcement rather
than instruction.

### What it does

On every `UserPromptSubmit` event, the sample checks whether the current
repository's board carries an in-flight task and, if so, prints a one-line
reminder to classify the moment and record it in the task's interventions file
before acting on the message — the mechanical version of an instruction that
otherwise lives only as prose. It never reads your message, and it degrades to
a silent no-op on every failure path; read the script's own header comment for
the full contract before you decide whether to install it.

### Install it yourself, and read it first

Copy the sample into your own hooks directory, read the script before you register it, then add an entry like this to your Claude Code settings:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/hooks/interventions-reminder.sh"
          }
        ]
      }
    ]
  }
}
```

### The capture-fidelity asymmetry, stated honestly

In the shipped default, the at-the-moment property of trigger-1 capture is
instruction-strength, carried by a standing instruction in
`skills/run/SKILL.md` that is followed while it is fresh. With the sample
installed, that same property is mechanically prompted at every prompt
submission instead. Neither state proves that every intervention was
recorded: `bin/check-interventions.sh` proves a record exists and is
well-formed, never that every intervention was recorded.
