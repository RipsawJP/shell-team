#!/usr/bin/env bash
# check-readme-version.sh — keep the README version badge in sync with the
# canonical plugin version (the machine-enforced form of the tasks/lessons.md
# rule "update README version on every release").
#
# The source of truth is the `version` field in `.claude-plugin/plugin.json`
# (the plugin manifest). For each README on the command line, the static version
# badge `img.shields.io/badge/version-<VERSION>` must equal that version.
#
# VERSION is `X.Y.Z` with an optional semver pre-release suffix (`-beta`,
# `-rc.1`, …). shields.io's path form escapes a literal `-` in the badge message
# as `--`, so a `0.2.0-beta` manifest version is written `version-0.2.0--beta` in
# the badge URL; this script decodes `--` back to `-` before comparing.
#
# Why a STATIC badge and a manifest comparison (not a dynamic shields.io
# `github/v/tag` badge): a static badge always renders and does not depend on an
# external API lookup at page-load time; this check is what stops it from going
# stale. (A dynamic tag badge is a viable alternative — adopting one would make
# this guard unnecessary.) The manifest —
# not a git tag — is the reference because `git describe` is unreliable off the
# release merge commits (e.g. on `develop`) and `actions/checkout` does not fetch
# tags by default, whereas plugin.json is always in the working tree.
#
# Scope note: README prose `(v0.1.0)` mentions ("Loop Engineering (v0.1.0)", the
# Versioning section) are historical "introduced-at" references, not current
# version claims, so this check looks ONLY at the badge.
#
# Reads only. Pure bash + coreutils — no jq/yq/python. Prints `<file>:<reason>`
# per violation to stderr.
#
# Usage:  check-readme-version.sh <README.md> [<README.md>...]
# Env:    VERSION_MANIFEST=<path>  override the manifest (default:
#         <repo-root>/.claude-plugin/plugin.json). Used by the test suite.
# Exit:   0 = all in sync, 1 = violation(s), 2 = usage / unreadable file/manifest.

set -euo pipefail

if [[ "$#" -lt 1 ]]; then
  printf 'usage: check-readme-version.sh <README.md> [<README.md>...]\n' >&2 || true
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${VERSION_MANIFEST:-$ROOT/.claude-plugin/plugin.json}"

if [[ ! -r "$MANIFEST" ]]; then
  printf '%s: cannot read plugin manifest\n' "$MANIFEST" >&2 || true
  exit 2
fi

# Canonical version from the manifest's `"version": "X.Y.Z[-prerelease]"` field.
MANIFEST_RAW="$(cat "$MANIFEST")"
if [[ "$MANIFEST_RAW" =~ \"version\"[[:space:]]*:[[:space:]]*\"([0-9]+[.][0-9]+[.][0-9]+(-[A-Za-z0-9.]+)?)\" ]]; then
  WANT="${BASH_REMATCH[1]}"
else
  printf '%s: no "version":"X.Y.Z[-prerelease]" field found in manifest\n' "$MANIFEST" >&2 || true
  exit 2
fi

violations=0
emit() { printf '%s:%s\n' "$1" "$2" >&2; violations=$((violations + 1)); }

for FILE in "$@"; do
  if [[ ! -r "$FILE" ]]; then
    printf '%s: cannot read file\n' "$FILE" >&2 || true
    exit 2
  fi

  # The static version badge: `img.shields.io/badge/version-<VERSION>`, where a
  # literal '-' in VERSION is shields.io-escaped as '--' (decoded below).
  if [[ "$(cat "$FILE")" =~ img[.]shields[.]io/badge/version-([0-9]+[.][0-9]+[.][0-9]+(--[A-Za-z0-9.]+)*) ]]; then
    got="${BASH_REMATCH[1]//--/-}"
    if [[ "$got" != "$WANT" ]]; then
      emit "$FILE" "version badge is $got but plugin.json is $WANT — bump the badge to $WANT (or the manifest) so they match"
    fi
  else
    emit "$FILE" "no static version badge found (expected img.shields.io/badge/version-${WANT})"
  fi
done

[[ "$violations" -gt 0 ]] && exit 1
exit 0
