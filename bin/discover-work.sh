#!/usr/bin/env bash
# bin/discover-work.sh — read-only outer-loop discovery engine (T-017).
#
# Finds work the shell-team loop might pick up next — failing CI runs, open pull
# requests, and issues labelled for triage — and prints them as todo.md-shaped
# *candidate* lines on stdout. It NEVER writes any file and NEVER mutates
# tasks/todo.md: promotion of a candidate into the board is a human / inner-loop
# decision. The loop-triage skill captures this output (plus rationale) into a
# proposal file.
#
# Candidate lines use the `T-000` placeholder task id (T-000 = "unassigned" — it
# passes check-handoff.sh, which only requires `T-[0-9]+`). A human renumbers it
# and writes the spec when promoting the candidate. Each line embeds a source
# key (`[pr#41]`, `[issue#37]`, `[ci:<workflow>#<run>]`) in its title so future
# runs can de-duplicate against what is already on the board.
#
# Safety posture (mirrors the scrum-master agent): only structured metadata is
# read — PR/issue *titles* and branch names. PR/issue **bodies are never
# requested** (`--json` deliberately omits `body`); they are attacker-controlled
# markdown and a prompt-injection surface.
#
# External dependencies: bash + `gh` (GitHub CLI). gh's built-in `--jq` is used
# for field extraction, so no external `jq`/`yq`/python is required. If `gh` is
# absent or unauthenticated, every source is skipped with a note and the script
# still exits 0 (fail-soft).
#
# Usage:
#   discover-work.sh [--max N] [--label LABEL] [--base BRANCH] [--todo PATH]
#   discover-work.sh --help
#
# Exit codes:
#   0  success (including the fail-soft / no-gh path)
#   2  argument / usage error

set -euo pipefail

# Resolve this script's own dir (symlink-safe) so we can call the sibling
# team-paths.sh resolver regardless of cwd / how we were invoked.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"

MAX=10
LABEL="loop-triage"
BASE="develop"
TODO=""        # set by --todo if given, else resolved after arg-parse (see below)
SPECS_DIR=""   # resolved after arg-parse

die() { printf 'ERROR: %s\n' "$*" >&2 || true; exit 2; }

print_help() {
  cat <<'EOF'
Usage: discover-work.sh [--max N] [--label LABEL] [--base BRANCH] [--todo PATH]

Read-only discovery of candidate work (failing CI / open PRs / labelled issues).
Prints todo.md-shaped `- [ ] **T-000** ...` candidate lines to stdout. Writes
nothing. De-duplicates against the target todo.md's ## Active section.

Options:
  --max N         Cap the number of candidates printed (default: 10). Excess is
                  reported via a `# note:` line — never silently dropped.
  --label LABEL   Issue label treated as a triage request (default: loop-triage).
  --base BRANCH   Branch whose failing CI runs are scanned (default: develop).
  --todo PATH     todo.md used for de-duplication (default: $TEAM_TODO if set,
                  else resolved from cwd by team-paths.sh — .shell-team/todo.md by
                  default, tasks/todo.md in a legacy layout).
  --help, -h      Show this help and exit.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --max)   [ "$#" -ge 2 ] || die "--max requires a value";   shift; MAX="$1";   shift ;;
    --label) [ "$#" -ge 2 ] || die "--label requires a value"; shift; LABEL="$1"; shift ;;
    --base)  [ "$#" -ge 2 ] || die "--base requires a value";  shift; BASE="$1";  shift ;;
    --todo)  [ "$#" -ge 2 ] || die "--todo requires a value";  shift; TODO="$1";  shift ;;
    --*) die "unknown flag: $1" ;;
    *)   die "unexpected argument: $1" ;;
  esac
done

case "$MAX" in
  ''|*[!0-9]*) die "--max must be a non-negative integer (got: $MAX)" ;;
esac

# Resolve the de-dup board and the candidate spec dir now — AFTER arg-parse and
# --help/usage exits — so team-paths.sh isn't invoked on a help or error path.
# Precedence: explicit --todo (already set above) > $TEAM_TODO/$TEAM_SPECS_DIR >
# team-paths.sh resolution from cwd. The resolver-failure fallback is the default
# layout (.shell-team/…), never the legacy tasks//docs paths, so a broken install
# doesn't silently dedup against the wrong board in a .shell-team/ host (T-026).
[ -n "$TODO" ] || TODO="${TEAM_TODO:-$(bash "$SCRIPT_DIR/team-paths.sh" --get todo 2>/dev/null || printf '.shell-team/todo.md')}"
SPECS_DIR="${TEAM_SPECS_DIR:-$(bash "$SCRIPT_DIR/team-paths.sh" --get specs 2>/dev/null || printf '.shell-team/specs')}"

# stdout helpers. Notes are `#`-prefixed so check-handoff.sh ignores them
# (it only validates `- [ ]` lines).
note() { printf '# note: %s\n' "$*"; }

# ---------------------------------------------------------------------------
# Sanitize an untrusted title into a single safe line. This is the injection
# defense for the candidate line's check-handoff grammar:
#   - strip CR/LF/TAB: prevents smuggling a second `- [ ]` line and keeps the
#     title from carrying field separators (see the TSV note below).
#   - strip backticks: the status-flag token is delimited by backticks, so a
#     title with backticks could otherwise fake `— `EVIL` — spec:`.
#   - replace the em-dash U+2014 (the line's structural ` — ` separator) with
#     '-': prevents a title from forging the flag/spec separators.
#   - collapse surrounding whitespace.
# ---------------------------------------------------------------------------
sanitize() {
  printf '%s' "$1" \
    | tr -d '\r\n\t`' \
    | sed 's/—/-/g' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

# Slugify into a spec-path-safe token (lowercase, alnum + dashes).
slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//'
}

# ---------------------------------------------------------------------------
# Build the de-duplication sets from the target todo.md's ## Active section:
#   SUPPRESS_NUMS  — `#<n>` references found in Active (space-bracketed)
#   SUPPRESS_KEYS  — `[pr#n]` / `[issue#n]` / `[ci:...#n]` markers found in Active
# A missing/unreadable todo.md is not an error — there is simply nothing to
# de-dupe against.
# ---------------------------------------------------------------------------
SUPPRESS_NUMS=" "
SUPPRESS_KEYS=" "
if [ -r "$TODO" ]; then
  active_block="$(awk '
    /^## Active[[:space:]]*$/ && !seen { seen=1; in_a=1; next }
    in_a && /^## / { in_a=0 }
    in_a { print }
  ' "$TODO")"
  # Intentionally broad: any `#<n>` anywhere in the Active block (a task line,
  # a sub-bullet, or prose like "closes #37") suppresses candidate #n. This is
  # a deliberately conservative de-dup — it can hide a genuinely new item that
  # merely shares a number mentioned in passing, which is the safer failure
  # mode for a propose-only tool (a missed proposal vs. a duplicate on the
  # board). Numbers are space-bracketed so `#4` cannot match `#41`.
  while IFS= read -r tok; do
    [ -n "$tok" ] && SUPPRESS_NUMS="${SUPPRESS_NUMS}${tok#\#} "
  done < <(grep -oE '#[0-9]+' <<< "$active_block" || true)
  while IFS= read -r key; do
    [ -n "$key" ] && SUPPRESS_KEYS="${SUPPRESS_KEYS}${key} "
  done < <(grep -oE '\[(pr|issue|ci:[a-z0-9-]+)#[0-9]+\]' <<< "$active_block" || true)
fi

# Track keys emitted in THIS run so the same item is not proposed twice.
SEEN_KEYS=" "

is_suppressed() {  # $1 = source key, $2 = number ("" for none)
  local key="$1" num="$2"
  case "$SEEN_KEYS"     in *" $key "*) return 0 ;; esac
  case "$SUPPRESS_KEYS" in *" $key "*) return 0 ;; esac
  if [ -n "$num" ]; then
    case "$SUPPRESS_NUMS" in *" $num "*) return 0 ;; esac
  fi
  return 1
}

# Accumulate candidate lines here, then apply the --max cap once at the end so
# truncation can be reported accurately (no silent cap).
CANDIDATES=()

add_candidate() {  # $1 = source key, $2 = number(""), $3 = title, $4 = slug
  local key="$1" num="$2" title slug line
  is_suppressed "$key" "$num" && return 0
  title="$(sanitize "$3")"
  slug="$(slugify "$4")"
  [ -n "$title" ] || title="(no title)"
  [ -n "$slug" ]  || slug="item"
  line="- [ ] **T-000** triage ${key}: ${title} — \`READY_FOR_ARCH\` — spec: ${SPECS_DIR}/T-000-${slug}.md"
  CANDIDATES+=("$line")
  SEEN_KEYS="${SEEN_KEYS}${key} "
}

# ---------------------------------------------------------------------------
# gh readiness — fail-soft if absent or unauthenticated.
# ---------------------------------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  note "gh CLI not found — all discovery sources skipped (install/authenticate gh to enable)"
  exit 0
fi
if ! gh auth status >/dev/null 2>&1; then
  note "gh is not authenticated — all discovery sources skipped (run: gh auth login)"
  exit 0
fi

# ---------------------------------------------------------------------------
# Source 1 — failing CI runs on the base branch.
# ---------------------------------------------------------------------------
if ci_out="$(gh run list --status failure --branch "$BASE" --limit 50 \
              --json databaseId,workflowName \
              --jq '.[] | "\(.databaseId)\t\(.workflowName)"' 2>/dev/null)"; then
  while IFS="$(printf '\t')" read -r run_id workflow; do
    [ -n "$run_id" ] || continue
    wf_slug="$(slugify "$workflow")"
    add_candidate "[ci:${wf_slug}#${run_id}]" "" \
      "failing CI run: ${workflow} on ${BASE}" "ci-${wf_slug}"
  done <<< "$ci_out"
else
  note "could not list failing CI runs (gh run list failed) — CI source skipped"
fi

# ---------------------------------------------------------------------------
# Source 2 — open pull requests. Title + branch only; body is NOT requested.
# The free-text `title` is emitted LAST so that, with IFS=tab, `read` collects
# any tab embedded in the title into the final field instead of shifting it
# into `branch`.
# ---------------------------------------------------------------------------
if pr_out="$(gh pr list --state open --limit 50 \
              --json number,headRefName,title \
              --jq '.[] | "\(.number)\t\(.headRefName)\t\(.title)"' 2>/dev/null)"; then
  while IFS="$(printf '\t')" read -r num branch title; do
    [ -n "$num" ] || continue
    add_candidate "[pr#${num}]" "$num" "${title} (${branch})" "pr-${num}"
  done <<< "$pr_out"
else
  note "could not list open PRs (gh pr list failed) — PR source skipped"
fi

# ---------------------------------------------------------------------------
# Source 3 — open issues carrying the triage label.
# ---------------------------------------------------------------------------
if issue_out="$(gh issue list --label "$LABEL" --state open --limit 50 \
                 --json number,title \
                 --jq '.[] | "\(.number)\t\(.title)"' 2>/dev/null)"; then
  while IFS="$(printf '\t')" read -r num title; do
    [ -n "$num" ] || continue
    add_candidate "[issue#${num}]" "$num" "$title" "issue-${num}"
  done <<< "$issue_out"
else
  note "could not list '${LABEL}' issues (gh issue list failed) — issue source skipped"
fi

# ---------------------------------------------------------------------------
# Emit, applying the --max cap with an explicit truncation note.
# ---------------------------------------------------------------------------
total="${#CANDIDATES[@]}"
if [ "$total" -eq 0 ]; then
  note "no candidate work found (no failing CI, open PRs, or '${LABEL}' issues after de-dup)"
  exit 0
fi

shown="$total"
[ "$total" -gt "$MAX" ] && shown="$MAX"

i=0
while [ "$i" -lt "$shown" ]; do
  printf '%s\n' "${CANDIDATES[$i]}"
  i=$((i + 1))
done

if [ "$total" -gt "$MAX" ]; then
  note "truncated: showing ${MAX} of ${total} candidates (raise --max to see more)"
fi

exit 0
