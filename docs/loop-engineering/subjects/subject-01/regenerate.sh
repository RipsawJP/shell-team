#!/usr/bin/env bash
# regenerate.sh — materialises subject-01's starting-state venue from
# committed bytes.
#
# Usage: regenerate.sh <target-dir>
#
# <target-dir> may already exist (empty or not yet created — this driver
# creates it if missing). It is populated with a byte-identical copy of this
# subject's own brief, interface contract, manifest and acceptance oracle,
# and nothing else: no candidate-declared file and no candidate-declared
# extra directory is ever created here. Running this driver twice, into two
# separate fresh directories, produces byte-identical trees every time —
# nothing here reads the clock, a random source, or the caller's own
# environment beyond the one argument.
set -euo pipefail

usage() {
  printf 'usage: %s <target-dir>\n' "${0##*/}" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

target="$1"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$target" || { printf 'error: cannot create %s\n' "$target" >&2; exit 1; }

for f in README.md interface.md manifest.txt acceptance.sh; do
  cp "$here/$f" "$target/$f"
done

exit 0
