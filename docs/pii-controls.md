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

Generic, publishable shapes, each identified by a stable pattern id:

- `home-path` — a POSIX home-directory absolute path with a real name segment
  (the placeholder form `/Users/<name>/` is deliberately not a match; see
  below), matched only at a boundary a URL authority cannot provide (so a
  documentation URL is not a false positive).
- `home-path-win` — the Windows `C:` user-directory form (`C:\Users\<name>\`,
  same placeholder convention).
- `home-encoded` — a home-directory path whose separators have been replaced
  by a repeated hyphen or underscore, so the literal `/Users/` or `/home/`
  the two shapes above require never appears (the placeholder forms
  `-Users-<name>-` and `_home_<name>_` are deliberately not a match, same
  convention). Both separators and both roots fire. Not boundary-guarded —
  an encoded segment has no URL-authority false-positive class to close, so
  this rule's bias toward firing applies with no narrowing at all.
- `temp-session` — a machine-local temp or session root (`/private/tmp/`,
  `/tmp/`, `/var/folders/`) carrying a dashed 8-4-4-4-12 hex UUID-shaped
  segment, in any case spelling. A temp/session citation with no
  UUID-shaped segment is not a match, and the placeholder form (a session
  segment written `<session-uuid>`) is deliberately not a match either.
- `email-nonnoreply` — a mailbox-shaped string at a domain that can hold a
  real, deliverable mailbox. Excluded by domain, never by the shape of the
  local part: both GitHub noreply identity shapes —
  `<id>+<login>@users.noreply.github.com` (matched end-anchored on the
  domain, whatever the local part looks like) and the plain web-flow
  `noreply@github.com` — and the domains reserved for documentation and
  testing (RFC 2606 / RFC 6761).
- `private-key` — a PEM private-key header line.
- `token` — a credential-token prefix (GitHub `gh[oprs]_`, an AWS access-key
  id, an OpenAI-style `sk-` key) long enough to be a real key body. The
  `sk-` form additionally requires a left boundary — start-of-line, or one
  character in the class `[^A-Za-z0-9]` — immediately before it, so an
  identifier chain that merely ends in the letters s+k before a hyphen —
  this project's own label convention among them — never matches, however
  long its tail runs; `gh[oprs]_` and `AKIA` carry no such guard. Accepted,
  disclosed exception: that same `[^A-Za-z0-9]` boundary also suppresses a
  real `sk-` key sitting immediately after a letter or a digit with no
  separator, since one character of left context cannot tell the two apart
  — every other boundary this gate reaches still fires.

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
- The deliberate shape-bearing fixtures under tests/ are carried by the test-locked known-shapes list, so --all exits 0 on this tree; --all remains an audit flag and is deliberately not a required CI check.
- The commit-identity gate checks only the non-merge commits a pull request adds; merge commits are excluded because their identity is set by the merging party, not by the author of the change.
- The gate is forward-looking: it does not remove identity metadata from commits that are already published, and the remediation for a past exposure is an operator-side account setting, not a repository change.
- A PII shape in a filename or a path is not inspected; this gate reads file content only.
- Some URL-adjacent and log-prefixed forms may be reported even though they carry no personal data: a file scheme URL, a path wrapped in markdown link syntax, and a path following an IPv6 authority. That noise is accepted deliberately, because a one-character lookbehind cannot tell those apart from a real path in prose; the resolution is to write the placeholder form, never to widen the suppression.
- The home-path shapes match a conservative ASCII name segment only; a name written in non-ASCII characters, and unusual case spellings of the Windows form, are not covered.
- A bare UUID outside a machine-local temp or session path is not covered; the shape this gate matches is a path, not a UUID on its own.
- An embedded whitespace character in the path segment between a temp/session root and its UUID is not covered (an embedded `=` is covered). Not chased, because admitting a bare space would let the match span across unrelated words on the same line before it ever reaches a UUID — a materially larger false-positive surface than one more literal character — and no generator in this repository's own reach emits a space there.
- A hyphen- or underscore-delimited English compound that happens to spell the `home` root (for example inside a longer kebab-case or snake-case identifier) may be reported even though it carries no personal data; the resolution is the placeholder form at the authoring site, never a wider suppression.
- A mailbox shape is not reported when its domain cannot hold a deliverable mailbox: a domain reserved for documentation and testing, or the GitHub noreply domain used for pseudonymous identities. The excluded domains are listed in the checker source.
- The gate reads the committed content of each path the change touches, resolved against the base ref; a change that exists only in the working tree is not scanned, and --all is the mode that reads the working tree.
- A short list of paths that deliberately carry shapes, as fixtures another guard needs, is excluded by name; the list lives in the checker source and its exact contents are asserted by the test suite.

This gate sees shapes only. It is not a complete PII control, and passing it is not evidence that a change is free of PII.
