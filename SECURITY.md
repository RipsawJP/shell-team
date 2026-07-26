# Security policy

## Reporting a vulnerability

Please report security issues **privately**, not in a public issue.

Use GitHub's private vulnerability reporting: open this repository's
**Security** tab and choose **Report a vulnerability**. That channel stays
private between you and the maintainer.

If that option is not available to you, open a regular issue saying only that
you have a security report and asking for a private channel — **do not put the
details in a public issue.**

## What is in scope

This project is a Claude Code plugin. It ships agent definitions, skills, and
shell scripts that run **in your own environment**, with your credentials and
your file access. Reports about that execution surface are the ones that matter
most here. For example:

- a script under `bin/` that can be made to run something other than what it
  documents
- an agent or skill definition that can be steered into destructive or
  data-exfiltrating behavior
- anything that widens what the plugin can reach beyond the repository you are
  running it in

Findings that require an attacker to already control your machine, your Claude
Code configuration, or this repository's own contents are out of scope — at
that point the plugin is not the weakest link.

## What to expect

This is a single-maintainer project, so there is no response-time guarantee. A
valid report is fixed on the same loop as everything else here: specified with
acceptance criteria, implemented, verified against them, and reviewed by a model
from a different provider before it merges.

Only the latest release is maintained. There are no backports to older tags.
