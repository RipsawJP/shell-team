# PII controls

[![English](https://img.shields.io/badge/lang-English-1f6feb?style=flat-square)](pii-controls.md)
[![日本語](https://img.shields.io/badge/lang-日本語-lightgrey?style=flat-square)](pii-controls.ja.md)

shell-team develops in the open, which turns PII exposure into a per-commit
risk rather than a one-time migration risk. `bin/check-pii-shapes.sh` is the
mechanical gate against that risk: by default it reads the full committed
content of every path a change touches, resolved against a base ref, never
the whole tree — and it is fail-closed — a run that cannot evaluate its
input never reports clean. It never parses `git diff`'s textual rendering;
changed paths are enumerated from `git`'s own machine-readable output and
their content is read through `git cat-file`, so a colour setting, an
external diff driver, or content that merely looks like diff syntax can
never change the verdict.

## What it checks for

Five generic, publishable shapes, each identified by a stable pattern id:

- `home-path` — a POSIX home-directory absolute path with a real name segment
  (the placeholder form `/Users/<name>/` is deliberately not a match; see
  below), matched only at a boundary a URL authority cannot provide (so a
  documentation URL is not a false positive).
- `home-path-win` — the Windows `C:` user-directory form (`C:\Users\<name>\`,
  same placeholder convention).
- `email-nonnoreply` — a mailbox-shaped string at a domain that can hold a
  real, deliverable mailbox. Excluded by domain, never by the shape of the
  local part: both GitHub noreply identity shapes —
  `<id>+<login>@users.noreply.github.com` (matched end-anchored on the
  domain, whatever the local part looks like) and the plain web-flow
  `noreply@github.com` — and the domains reserved for documentation and
  testing (RFC 2606 / RFC 6761).
- `private-key` — a PEM private-key header line.
- `token` — a credential-token prefix (GitHub `gh[oprs]_`, an AWS access-key
  id, an OpenAI-style `sk-` key) long enough to be a real key body, not a
  short lookalike such as this project's own `task-0NN` label convention.

## Running it

```bash
bin/check-pii-shapes.sh                 # change-scoped against the default base
bin/check-pii-shapes.sh --base develop  # change-scoped against an explicit ref
bin/check-pii-shapes.sh --all           # full-tree audit (see below)
```

Exit codes: `0` clean, `1` one or more findings, `2` usage or structural
error (an unresolvable base ref, an unreadable input, an unknown flag, or
`--all` combined with `--base`). A finding never echoes the matched text —
only the pattern id, the path, and a line number (when available) are
reported — so a public CI log never carries the byte that tripped the gate.

`--all` is a full-tree audit mode, not a required CI check. A short,
per-file, test-locked list in the checker source excludes the paths that
deliberately carry a PII shape as fixtures for another guard's own suite
(`tests/rollup-track/run.sh`) — so `--all` currently exits `0` (clean) on
this repository; a newly added shape-bearing path anywhere else would still
be reported. Use it locally when you want to sweep further than the current
change.

## What this gate does not cover

- Named entities — customer names, internal hostnames, project codes — cannot be matched by shape and are not covered by this gate.
- The patterns that would match named entities cannot live in this public repository, because the patterns themselves are the sensitive data; they belong in an operator-local check outside the repo.
- Semantic sensitivity — a design decision or a context from which a reader can infer a business relationship — is not a PII shape and is not covered.
- Image content is not inspected; metadata only, if anything.
- The deliberately PII-shaped adversarial fixtures that already live under tests/ are known findings of --all; --all is an audit flag and is deliberately not a required CI check.
- The commit-identity gate checks only the non-merge commits a pull request adds; merge commits are excluded because their identity is set by the merging party, not by the author of the change.
- The gate is forward-looking: it does not remove identity metadata from commits that are already published, and the remediation for a past exposure is an operator-side account setting, not a repository change.
- A PII shape in a filename or a path is not inspected; this gate reads file content only.
- A home-path shape written inside a URL is not reported: the pattern requires the path to begin at a boundary that a URL authority does not provide, which is the same rule that keeps a documentation URL from being a false positive.
- The home-path shapes match a conservative ASCII name segment only; a name written in non-ASCII characters, and unusual case spellings of the Windows form, are not covered.
- A mailbox shape is not reported when its domain cannot hold a deliverable mailbox: a domain reserved for documentation and testing, or the GitHub noreply domain used for pseudonymous identities. The excluded domains are listed in the checker source.
- The gate reads the committed content of each path the change touches, resolved against the base ref; a change that exists only in the working tree is not scanned, and --all is the mode that reads the working tree.
- A short list of paths that deliberately carry shapes, as fixtures another guard needs, is excluded by name; the list lives in the checker source and its exact contents are asserted by the test suite.

This gate sees shapes only. It is not a complete PII control, and passing it is not evidence that a change is free of PII.
