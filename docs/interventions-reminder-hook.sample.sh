#!/usr/bin/env bash
# docs/interventions-reminder-hook.sample.sh — an OPT-IN, INERT sample
# UserPromptSubmit hook (task T-1004).
#
# This file is a SAMPLE. It is never bundled by team-init, and it is never on any load path.
# It is activated only by the adopter's own settings file (see
# docs/tuning-oversight.md's install snippet, which tells you to read this
# script before you register it). It ships committed non-executable precisely
# because nothing in this repository or plugin ever invokes it on its own —
# copying it into your own hooks configuration is what turns it on.
# CI does lint this file and run its fixture suite, so "inert" does not mean
# "unverified".
#
# What it does, once you register it as a UserPromptSubmit hook: on every
# prompt, it resolves the current repository's board through
# `team-paths.sh --get todo` (a bare name on PATH — this script deliberately
# has no bin/-relative fallback, so it only fires usefully where the plugin is
# enabled) and asks one cheap question: does that board carry an in-flight
# task line? If the board is absent, unreadable, a directory, or carries no
# in-flight line — or the resolver isn't reachable on PATH at all — this
# script is a SILENT NO-OP: exit 0, byte-empty stdout, byte-empty stderr. That
# silence is load-bearing: you register this hook once, user-wide, so it fires
# in every repository you ever open, and it must cost almost nothing and say
# nothing everywhere shell-team is not in play. Otherwise it prints one line
# of JSON on stdout (the hookSpecificOutput.additionalContext form) reminding
# you to classify the message and record it in the task's interventions file,
# now, before acting on it.
#
# This script never reads your message: it drains stdin without parsing it,
# and inspects no field of the event JSON (not the prompt field, not the cwd
# field). Classification is a judgment for the session that receives this
# reminder, not for this script — its whole job is to prompt that judgment at
# the right moment. Every failure path degrades to the same silent no-op
# (fail-open, on purpose: a hook runs inside your session and must never
# break it, unlike this repository's checkers, which fail closed).
#
# Zero new runtime dependency: pure bash and grep only.

set -u

# Drain stdin without parsing it, so a harness write can never land on a
# closed pipe, and so no byte of the event is ever inspected before this
# script decides whether to emit anything.
cat >/dev/null 2>&1 || true

# Resolve the board through the resolver alone — no path is hardcoded here.
# If the resolver isn't reachable on PATH at all, fail open silently.
board="$(team-paths.sh --get todo 2>/dev/null)" || exit 0
[ -n "$board" ] || exit 0
[ -f "$board" ] || exit 0
[ -r "$board" ] || exit 0

# In-flight detection reuses bin/check-handoff.sh's own enforced line grammar
# (LINE_RE), with the seven-flag enum substituted for its generic flag
# capture: detection keys off a checked invariant, not a convention. The end
# anchor is deliberately absent so a CRLF board still matches, and a line that
# does not conform (an unbacktick'd flag, a half-written entry) reads as NOT
# in flight — this errs toward silence, never toward a false alarm.
# shellcheck disable=SC2016
IN_FLIGHT_RE='^- \[ \] \*\*T-[0-9]+\*\* .* — `(READY_FOR_ARCH|READY_FOR_ENG|READY_FOR_QA|READY_FOR_REVIEW|READY_FOR_MERGE|BLOCKED|REWORK)` — spec: '

grep -E -q -- "$IN_FLIGHT_RE" "$board" 2>/dev/null || exit 0

# All output comes from exactly one printf, at the very end: nothing above
# this point can leave a partial JSON object on stdout, and nothing above it
# ever writes a diagnostic to stdout or stderr.
printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"shell-team: a task is in flight. If this message interrupts, corrects, or stops the work, classify it and append the entry to the task interventions file (team-paths.sh --get interventions) NOW, before acting on the message, then commit it immediately. Use one of the seven classes the run skill lists (canonical source: templates/prompt-blocks/interventions-classes.md). A routine gate response (a plain GO, an approval, or an answer to a question you asked) is not an intervention and gets no entry."}}'
exit 0
