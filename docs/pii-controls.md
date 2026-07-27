# PII controls

[![English](https://img.shields.io/badge/lang-English-1f6feb?style=flat-square)](pii-controls.md)
[![日本語](https://img.shields.io/badge/lang-日本語-lightgrey?style=flat-square)](pii-controls.ja.md)

shell-team develops in the open, which turns PII exposure into a per-commit
risk rather than a one-time migration risk. `bin/check-pii-shapes.sh` is the
mechanical gate against that risk: by default it looks only at what a change
ADDS (diff-scoped against a base ref, never the whole tree), and it is
fail-closed — a run that cannot evaluate its input never reports clean.

## What it checks for

Five generic, publishable shapes, each identified by a stable pattern id:

- `home-path` — a POSIX home-directory absolute path with a real name segment
  (the placeholder form `/Users/<name>/` is deliberately not a match; see
  below).
- `home-path-win` — the Windows `C:` user-directory form (`C:\Users\<name>\`,
  same placeholder convention).
- `email-nonnoreply` — a mailbox-shaped string at a real domain. Both GitHub
  noreply identity shapes — `<id>+<login>@users.noreply.github.com` and the
  plain web-flow `noreply@github.com` — are deliberately not findings: they
  are public identifiers by GitHub's own design, not PII.
- `private-key` — a PEM private-key header line.
- `token` — a credential-token prefix (GitHub `gh[oprs]_`, an AWS access-key
  id, an OpenAI-style `sk-` key) long enough to be a real key body, not a
  short lookalike such as this project's own `task-0NN` label convention.

## Running it

```bash
bin/check-pii-shapes.sh                 # diff-scoped against the default base
bin/check-pii-shapes.sh --base develop  # diff-scoped against an explicit ref
bin/check-pii-shapes.sh --all           # full-tree audit (see below)
```

Exit codes: `0` clean, `1` one or more findings, `2` usage or structural
error (an unresolvable base ref, an unreadable input, an unknown flag, or
`--all` combined with `--base`). A finding never echoes the matched text —
only the pattern id, the path, and a line number (when available) are
reported — so a public CI log never carries the byte that tripped the gate.

`--all` is a full-tree audit mode, not a required CI check: it necessarily
reports the deliberately PII-shaped adversarial fixtures that already live
under `tests/` (used to prove this project's own guards actually fire), so
running it always finds something on this repository. Use it locally when
you want to sweep further than the current diff.

## What this gate does not cover

- Named entities — customer names, internal hostnames, project codes — cannot be matched by shape and are not covered by this gate.
- The patterns that would match named entities cannot live in this public repository, because the patterns themselves are the sensitive data; they belong in an operator-local check outside the repo.
- Semantic sensitivity — a design decision or a context from which a reader can infer a business relationship — is not a PII shape and is not covered.
- Image content is not inspected; metadata only, if anything.
- The deliberately PII-shaped adversarial fixtures that already live under tests/ are known findings of --all; --all is an audit flag and is deliberately not a required CI check.
- The commit-identity gate checks only the non-merge commits a pull request adds; merge commits are excluded because their identity is set by the merging party, not by the author of the change.
- The gate is forward-looking: it does not remove identity metadata from commits that are already published, and the remediation for a past exposure is an operator-side account setting, not a repository change.

This gate sees shapes only. It is not a complete PII control, and passing it is not evidence that a change is free of PII.

## Known limitation

Untracked files carry no diff and are therefore not scanned in the default,
diff-scoped mode — `--all` is the mode that sees them.
