---
description: Set up or update shell-team in the current repository on both hosts (Claude Code and Codex CLI) when the user says "set up shell-team" or "update shell-team" — runs the plugin's own setup script, reports what was done, what was already in place, and what remains the operator's decision
---

The user asked you to **set up shell-team** or **update shell-team** in the
**current repository** (the cwd). This is the same skill and the same flow on
**both hosts**; only the artifacts differ by host. "Update shell-team" is the
same flow re-run after a plugin upgrade, and it is idempotent.

The setup script does the plugin's own part. Everything that is the host's or
the operator's — trust, sandbox, permissions, network, whether commits are
allowed, whether to approve the review transfer — stays the operator's
decision. You report those conditions. You never change them, and you never
propose a change to them as something you apply.

Do this:

1. **Run the setup script from the repository root.** Invoke it as
   `bash "<plugin root>/bin/team-setup.sh"` — never assumed to be on `PATH`,
   even with the plugin loaded; read `<plugin root>` from what your host
   reports, see `docs/adopting.md`'s "Locate the installed plugin root" step
   for how. Run it from inside the repository's work tree; it scaffolds the
   repository root even when started from a subdirectory. Pass `--host` only if
   the user names the host; otherwise it detects it (`CODEX_THREAD_ID` set
   means the Codex CLI host).

   ```
   bash "<plugin root>/bin/team-setup.sh"
   ```

2. **Relay the report as printed.** Its stdout is one header line (host, the
   ground for it, the installed plugin version) and three sections, each item a
   `- ` line: `Done:`, `Already in place:` and `Remains the operator's
   decision:`. Show all three, in that order, without dropping or rewording a
   line. Diagnostics are on stderr; relay them if the exit status is not `0`.

3. **Handle each `- run yourself:` line.** A refused write comes back under
   `Remains the operator's decision:` as `- run yourself: <command>`, with
   absolute paths in single quotes. The command's write set is exactly one of
   the plugin's own artifacts. For each such line do exactly one of two things:
   - request the host's own per-command approval for exactly that command and
     run it (each confirmation you ask for names **one concrete command**), or
   - stop and tell the operator that command, so they can run it themselves.

   Never ask for anything wider to get past a refusal.

4. **Read the exit status.** `0` is complete. `1` means the other provider's
   CLI is missing from `PATH` (reported, never installed). `3` means at least
   one write was refused and its command is printed. `2` means setup could not
   complete: a usage error, not a git work tree, an unsafe path, or a step that
   failed — say what the stderr diagnostic says.

5. **Close with the operator's part.** Point the user at the lines under
   `Remains the operator's decision:`, including the review-transfer line, and
   say that each is their call. Then tell them they can run:

   ```
   /shell-team:run <what you want built>
   ```

Boundary — what you never do in this skill:

- Never ask for a trust, sandbox, writable-root, network or permission grant,
  and never for an approval or permission-mode bypass.
- Never write the host's own settings files, and never add a persistent
  approval or allow rule.
- Never pre-authorize the review transfer on the operator's behalf.
- Never hand-create or edit the artifacts yourself: the script is the single
  deterministic source of the scaffold, the agents and the ignore line, so its
  behavior stays covered by `tests/setup/` and CI.
