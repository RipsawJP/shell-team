#!/usr/bin/env bash
# bin/consolidate-proposals.sh — outer-loop triage consolidation (T-021, + T-051
# Source C).
#
# Merges three outer-loop signals into ONE de-duplicated, BUDGET-capped proposal
# file for a human to act on:
#   1. Discovery (T-017, bin/discover-work.sh) — failing CI / open PRs / labelled
#      issues, as `- [ ] **T-000** triage [key]: ...` candidate lines on stdout.
#   2. Telemetry escalations (T-020, bin/rollup-runs.sh) — each run the roll-up
#      summary flags `⚠` (a status in {error,timeout,stopped} or a verdict in
#      {FAIL,REQUEST_CHANGES}) is an escalation candidate worth attention.
#   3. Cross-run failure clusters (T-044, bin/cluster-failures.sh) — a
#      `cluster <PHASE>:<REASON>  count=<n>  run <run_id>` line means that
#      failure shape recurred <n> times across runs; each distinct signature is
#      a recurring-failure candidate, appended after (not replacing) Sources
#      A/B. bin/cluster-failures.sh itself is never touched or invoked by this
#      script (T-044's output contract stays byte-identical) — same
#      capture-then-pass regime as Sources A/B.
#
# It is PROPOSE-ONLY and opt-in: it NEVER writes tasks/todo.md and adds no status
# flag — promotion of a candidate onto the board is a human / inner-loop decision.
# It consumes the three tools' *stdout text* (passed as files), never PR/issue
# bodies and never `gh ... --json body`: the prompt-injection narrowing of T-009 /
# discover-work is preserved by construction (this script does not call gh at all).
#
# Candidate lines reuse discover-work's `T-000` placeholder id and source-key
# model (`[pr#n]` / `[issue#n]` / `[ci:<workflow>#n]`), extended with
# `[run:<run_id>]` for telemetry escalations and `[cluster:<PHASE>:<REASON>]`
# for cross-run clusters — a dedicated namespace, distinct from `[run:<id>]`,
# so a run that is both individually escalated AND a cluster's representative
# run never collides (docs/specs/T-051-cluster-triage-wiring.md Design
# decision (c)). De-dup is by source-key string across the merged set
# (source-key match only; semantic dedup is a non-goal) so the same key
# surfacing twice — whether a duplicate in one stream or the same item in
# both — is emitted exactly once.
#
# Graceful degrade: absent / empty inputs (including the case where discover-work
# itself emitted only a `# note:` because gh was missing/unauthenticated) yield a
# proposal file that carries the gap as a `# note:` line and still exits 0.
#
# External dependencies: bash + coreutils only — no jq/yq/python, and no bash-4
# features (associative arrays, `${x,,}`), so it runs under macOS bash 3.2 as well
# as GNU bash. It does NOT call gh; the caller captures discover-work /
# rollup-runs / cluster-failures output and passes the files in.
#
# Usage:
#   consolidate-proposals.sh [--discovery FILE] [--rollup FILE] [--clusters FILE]
#                            [--max N] [--out-dir DIR] [--date YYYY-MM-DD]
#   consolidate-proposals.sh --help
#
# On success it writes ONE proposal file and prints its path to stdout.
#
# Exit codes:
#   0  success (including the graceful-degrade / no-candidate path)
#   2  argument / usage error
set -euo pipefail

# Byte-wise locale so bracket-key sorting/matching is byte-stable regardless of
# the caller's locale. printf still emits raw bytes for the ⚠ glyph.
export LC_ALL=C

# Resolve this script's own dir (symlink-safe) so the sibling team-paths.sh
# resolver is reachable regardless of cwd / how we were invoked.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"

DISCOVERY=""
ROLLUP=""
CLUSTERS=""
MAX=10
OUT_DIR=""
DATE=""

die() { printf 'ERROR: %s\n' "$*" >&2 || true; exit 2; }

print_help() {
  cat <<'EOF'
Usage: consolidate-proposals.sh [--discovery FILE] [--rollup FILE] [--clusters FILE]
                                [--max N] [--out-dir DIR] [--date YYYY-MM-DD]

Merge discover-work.sh output (T-017), rollup-runs.sh escalations (T-020), and
cluster-failures.sh recurring-failure clusters (T-044) into ONE de-duplicated,
--max-capped triage proposal file. Propose-only: tasks/todo.md is never written.
Prints the written file's path to stdout.

Options:
  --discovery FILE  Pre-captured `discover-work.sh` stdout (candidate + # note:
                    lines). Absent/empty → noted, not an error.
  --rollup FILE     Pre-captured `rollup-runs.sh` stdout (run summary text).
                    Absent/empty → noted, not an error.
  --clusters FILE   Pre-captured `cluster-failures.sh` stdout (`cluster
                    <PHASE>:<REASON>  count=<n>  run <run_id>` lines).
                    Absent/empty → noted, not an error.
  --max N           Cap on consolidated candidates (default: 10). Excess is
                    reported via a `# note:` line — never silently dropped.
  --out-dir DIR     Directory for the proposal file (default: $TEAM_RUNS_DIR if
                    set, else resolved from cwd by team-paths.sh — .shell-team/runs
                    by default, tasks/runs in a legacy layout).
  --date YYYY-MM-DD Date stamp for the filename (default: today, local date).
  --help, -h        Show this help and exit.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)   print_help; exit 0 ;;
    --discovery) [ "$#" -ge 2 ] || die "--discovery requires a value"; shift; DISCOVERY="$1"; shift ;;
    --rollup)    [ "$#" -ge 2 ] || die "--rollup requires a value";    shift; ROLLUP="$1";    shift ;;
    --clusters)  [ "$#" -ge 2 ] || die "--clusters requires a value";  shift; CLUSTERS="$1";  shift ;;
    --max)       [ "$#" -ge 2 ] || die "--max requires a value";       shift; MAX="$1";       shift ;;
    --out-dir)   [ "$#" -ge 2 ] || die "--out-dir requires a value";   shift; OUT_DIR="$1";   shift ;;
    --date)      [ "$#" -ge 2 ] || die "--date requires a value";      shift; DATE="$1";      shift ;;
    --*) die "unknown flag: $1" ;;
    *)   die "unexpected argument: $1" ;;
  esac
done

case "$MAX" in
  ''|*[!0-9]*) die "--max must be a non-negative integer (got: $MAX)" ;;
esac

# Resolve the output dir AFTER arg-parse / --help so team-paths.sh isn't invoked
# on a help or error path. Precedence: explicit --out-dir > $TEAM_RUNS_DIR >
# team-paths.sh resolution from cwd. The resolver-failure fallback is the default
# layout (.shell-team/runs), never a legacy path, so a broken install doesn't write
# to the wrong place in a .shell-team/ host (mirrors discover-work / T-026).
[ -n "$OUT_DIR" ] || OUT_DIR="${TEAM_RUNS_DIR:-$(bash "$SCRIPT_DIR/team-paths.sh" --get runs 2>/dev/null || printf '.shell-team/runs')}"

# Date stamp. --date wins (test determinism); else today's local date. Validate
# the shape so a bad value can't smuggle path separators into the filename.
[ -n "$DATE" ] || DATE="$(date +%F)"
case "$DATE" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) : ;;
  *) die "--date must be YYYY-MM-DD (got: $DATE)" ;;
esac

# ---------------------------------------------------------------------------
# sanitize — collapse an untrusted string into a single safe token for a
# candidate line, mirroring discover-work.sh's injection defense: strip
# CR/LF/TAB and backticks (the status-flag delimiter), turn the em-dash (the
# line's ` — ` separator) into '-', trim surrounding whitespace.
# ---------------------------------------------------------------------------
sanitize() {
  printf '%s' "$1" \
    | tr -d '\r\n\t`' \
    | sed 's/—/-/g' \
    | LC_ALL=C tr -cd '[:print:]' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

note_lines=()   # carried-forward / generated `# note:` strings (no leading '# note: ')
CANDIDATES=()   # final candidate lines, in emit order, pre-cap
SEEN_KEYS=" "   # space-bracketed set of source keys already emitted

note() { note_lines+=("$*"); }

# add_candidate <source-key> <full-candidate-line>
# De-dups by source-key across the merged set; first occurrence wins.
add_candidate() {
  local key="$1" line="$2"
  case "$SEEN_KEYS" in *" $key "*) return 0 ;; esac
  CANDIDATES+=("$line")
  SEEN_KEYS="${SEEN_KEYS}${key} "
}

# Resolve the specs dir for the synthesized telemetry candidate's spec path, so
# the line matches discover-work's grammar. Same precedence/fallback posture.
SPECS_DIR="${TEAM_SPECS_DIR:-$(bash "$SCRIPT_DIR/team-paths.sh" --get specs 2>/dev/null || printf '.shell-team/specs')}"

# ---------------------------------------------------------------------------
# Source A — discovery output (T-017). Pass candidate lines through verbatim
# (they are already check-handoff-shaped), keyed by their embedded source key
# for de-dup. Carry forward any `# note:` lines so the gh-degrade / truncation
# context discover-work emitted is not lost.
# ---------------------------------------------------------------------------
if [ -n "$DISCOVERY" ] && [ -r "$DISCOVERY" ]; then
  dcand=0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      '# note:'*)
        note "from discovery: ${line#\# note: }"
        ;;
      '- [ ] '*'**T-'*)
        dcand=$((dcand + 1))
        key="$(grep -oE '\[(pr|issue|ci:[a-z0-9-]+)#[0-9]+\]' <<< "$line" | head -n1 || true)"
        # A `[run:<id>]` key may carry an ISO-8601 run_id (colons etc.); match any
        # run id up to the closing bracket, not just [A-Za-z0-9._-]+.
        [ -n "$key" ] || key="$(grep -oE '\[run:[^]]+\]' <<< "$line" | head -n1 || true)"
        if [ -n "$key" ]; then
          add_candidate "$key" "$line"
        else
          # discover-work ALWAYS embeds a source key, so a keyless candidate line
          # is malformed / adversarial. Record it as a gap note rather than
          # emitting it: this neither hides it (it is reported) nor lets junk
          # lines consume the --max budget ahead of valid keyed candidates.
          note "skipped a discovery candidate with no recognizable source key"
        fi
        ;;
    esac
  done < "$DISCOVERY"
  [ "$dcand" -gt 0 ] || note "discovery input had no candidate lines (only notes / empty)"
elif [ -n "$DISCOVERY" ]; then
  note "discovery input not readable: $DISCOVERY — discovery source skipped"
else
  note "no discovery input given (--discovery) — discovery source skipped"
fi

# ---------------------------------------------------------------------------
# Source B — telemetry escalations (T-020). Each roll-up run header line
# `run <id>  [loop <id>]  ⚠` is an escalation. Synthesize a candidate in
# discover-work's grammar keyed `[run:<id>]`. We match on the literal ⚠ glyph
# rather than a regex so multibyte handling stays byte-safe under LC_ALL=C.
# ---------------------------------------------------------------------------
if [ -n "$ROLLUP" ] && [ -r "$ROLLUP" ]; then
  esc=0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      "run "*)
        # Anchor the ⚠ escalation marker to the trailing flag field (the line is
        # `run <id>  [loop <id>]  <flag>`, so the flag is the LAST char) — a ⚠
        # appearing elsewhere (e.g. inside a loop id) must not escalate a ✓ run.
        case "$line" in
          *"⚠")
            rest="${line#run }"
            rid="$(sanitize "${rest%% *}")"
            # Validate the run_id BEFORE building the `[run:<rid>]` key. The key is
            # bracket-delimited, so the only chars that break it are `[`/`]`
            # (premature close) — a `:` is unambiguous because `]` terminates, and
            # run ids are legitimately ISO-8601 UTC times (e.g. 2026-06-18T12:00:00Z,
            # per skills/run/SKILL.md), so they MUST be accepted. CR/LF/TAB/
            # backtick and the em-dash separator are already stripped by sanitize().
            # An id with a bracket char (or empty) is skipped with a gap note.
            case "$rid" in
              ''|*'['*|*']'*)
                note "skipped a telemetry escalation: run_id is empty or contains a bracket char (got: '$(printf '%.64s' "$rid")')"
                continue ;;
            esac
            rid_slug="$(printf '%s' "$rid" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//')"
            [ -n "$rid_slug" ] || rid_slug="run"
            cand="- [ ] **T-000** triage [run:${rid}]: telemetry escalation: run ${rid} flagged - investigate failing/stopped spans — \`READY_FOR_ARCH\` — spec: ${SPECS_DIR}/T-000-run-${rid_slug}.md"
            add_candidate "[run:${rid}]" "$cand"
            esc=$((esc + 1))
            ;;
        esac
        ;;
    esac
  done < "$ROLLUP"
  [ "$esc" -gt 0 ] || note "no telemetry escalations (no ⚠ runs in the roll-up summary)"
elif [ -n "$ROLLUP" ]; then
  note "rollup input not readable: $ROLLUP — telemetry source skipped"
else
  note "no telemetry input given (--rollup) — telemetry source skipped"
fi

# ---------------------------------------------------------------------------
# Source C — cross-run failure clusters (T-044, bin/cluster-failures.sh). Each
# line is `cluster <PHASE>:<REASON>  count=<n>  run <run_id>` (cluster-failures.sh's
# own emit contract, unchanged — Non-goal: this script never touches or invokes
# it). The whole line is validated against ONE anchored grammar (below) before
# any field is trusted, then sanitize()/bracket-char validation (Design
# decision (b), reused verbatim from Source B) runs on the extracted fields.
#
# round2 rework2 note: round1 fixed a marker-existence-only guard (missing
# `count=`/`run ` substrings silently garbled a candidate); round2 found the
# SAME root-cause class one layer deeper — marker presence alone doesn't
# validate the signature's own `<PHASE>:<REASON>` shape (no-colon / empty-PHASE
# / empty-REASON all still slipped through) nor that `count` is the positive
# integer a real cluster line always is. Per this project's own same-class-2x
# discipline, both layers are now closed by ONE anchored whole-line regex
# instead of another incremental guard — see CLUSTER_LINE_RE below.
#
# round3 rework3 note: rework2's regex constrained BOTH sides of the `:` to
# exclude whitespace, which is stricter than the real producer contract —
# `log-run.sh --phase` (and `check-run.sh`) place NO charset/shape constraint
# on `phase` beyond non-empty (docs/specs/T-043-rollup-guard-hardening.md's
# own Non-goals settle this: `--run-id`/`--phase` are *intentionally free-text*
# telemetry fields, a charset constraint was evaluated and explicitly declined
# there). A legitimate `--phase "pre deploy"` run makes cluster-failures.sh
# emit `cluster PRE DEPLOY:ERROR  count=2  run <id>` — real, valid producer
# output — which rework2's regex silently dropped as if malformed. Fixed by
# anchoring on the side of the `:` that IS a fixed, closed vocabulary —
# `REASON` — instead of constraining the free-text `PHASE` side. `PHASE` is
# now `(.+)`, unconstrained, matching the settled T-042/T-043 contract; a
# `PHASE` containing its own literal `:` (e.g. a Windows-path-style telemetry
# value) is resolved to the RIGHTMOST enum match, since `.+` is greedy and the
# enum alternation only anchors at the true trailing `:<REASON>` boundary —
# this is the correct reading of a producer-built `<phase>:<reason>` string,
# where `reason` is always the last segment.
#
# Keyed `[cluster:<PHASE>:<REASON>]`, a namespace DISTINCT from Source B's
# `[run:<id>]` (Design decision (c), the most consequential decision in this
# task): the same run_id surfacing as both a Source B escalation and a Source C
# cluster's representative run must retain BOTH candidate lines (2 lines,
# distinct keys) — never collapse one into the other, and two distinct cluster
# signatures sharing one representative run_id must also both be retained.
#
# Lines are consumed top-to-bottom in the exact order cluster-failures.sh
# already ranked them (descending count, first-seen tie-break) — Source C
# performs NO re-sort/re-rank of its own (Design decision (e)); a bare
# `(no failure clusters found)` sentinel line (cluster-failures.sh's own
# empty-input marker) simply does not match `cluster `* below and is skipped
# like any other non-candidate line, with the ccand==0 note covering that case.
# ---------------------------------------------------------------------------

# CLUSTER_LINE_RE — the FULL grammar of a cluster-failures.sh line's content
# after the `cluster ` prefix, anchored start-to-end (bash's `[[ =~ ]]` +
# BASH_REMATCH, same pure-bash-regex technique bin/check-acs.sh already uses;
# bash 3.2-compatible, no bash-4-only construct). Derived directly from
# cluster-failures.sh's own emit line (`printf 'cluster %s  count=%s  run %s\n'
# "${SIG[$best]}" "${CNT[$best]}" "${RUNID[$best]}"`, where
# `SIG[$best]="$(upper "$phase"):${reason}"`) and its `reason=` assignment
# logic (bin/cluster-failures.sh:116-124), which is the enum's canonical
# source, re-verified by reading that code for this round: `reason` is set
# to EITHER the literal `verdict` when `verdict` is `FAIL`/`REQUEST_CHANGES`,
# OR `upper(status)` when `status` is `error`/`timeout`/`stopped` — the exact
# same 5-value enum bin/rollup-runs.sh's own `⚠` condition uses (rollup-runs.sh
# line ~18: "any status in {error,timeout,stopped} OR any verdict in
# {FAIL,REQUEST_CHANGES}"). No other value of `reason` can ever be produced.
#   PHASE   — free text, unconstrained (`.+`, greedy). `log-run.sh --phase` /
#     `check-run.sh` place no charset/shape constraint on it beyond non-empty
#     (docs/specs/T-043-rollup-guard-hardening.md Non-goals: intentionally
#     free-text). A `PHASE` containing its own `:` resolves to the RIGHTMOST
#     `:<REASON>` match — correct, since `cluster-failures.sh` always builds
#     the signature as `<phase>:<reason>` with `reason` the trailing segment.
#   REASON  — anchored to the fixed enum above, never free text. This also
#     rules out an empty PHASE (`.+` requires >=1 char before the LAST `:`
#     that precedes a valid enum token) and an empty/malformed REASON (only
#     an exact enum token matches — anything else, including no `:` at all,
#     fails the whole-line match).
#   count   — a positive integer, no leading zero (`count=0` can never be
#     emitted by a real cluster line — a cluster exists only because it
#     recurred >=1 time).
#   run_id  — everything after the final `  run ` to end of line, free text
#     like PHASE (ISO-8601 run ids legitimately contain colons, same
#     acceptance Source B already extends); bracket/empty validated below,
#     unchanged since rework1 — Codex round3 confirmed this greedy capture is
#     correct-by-design, not a residual gap, given run_id's own free-text
#     contract and the post-match bracket/empty check that already bounds it.
# A line that does not match this grammar end-to-end is skipped with a gap
# note before any field is extracted — no partial-shape line is ever trusted.
CLUSTER_LINE_RE='^(.+):(FAIL|REQUEST_CHANGES|ERROR|TIMEOUT|STOPPED)  count=([1-9][0-9]*)  run (.+)$'

if [ -n "$CLUSTERS" ] && [ -r "$CLUSTERS" ]; then
  ccand=0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      "cluster "*)
        rest="${line#cluster }"
        if [[ "$rest" =~ $CLUSTER_LINE_RE ]]; then
          sig_raw="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
          cnt_raw="${BASH_REMATCH[3]}"
          rid_raw="${BASH_REMATCH[4]}"
        else
          note "skipped a cluster candidate: line does not match 'cluster <PHASE>:<REASON>  count=<positive-int>  run <rid>' (got: '$(printf '%.64s' "$line")')"
          continue
        fi

        sig="$(sanitize "$sig_raw")"
        rid="$(sanitize "$rid_raw")"
        cnt="$(sanitize "$cnt_raw")"

        # Bracket-char / empty validation on BOTH the signature and the run_id
        # — both feed the `[cluster:<sig>]` key's bracket delimiters, so either
        # breaking it means skip with a gap note rather than forging a broken
        # key (same rationale as Source B's run_id validation). Still needed
        # even though CLUSTER_LINE_RE already requires non-empty captures:
        # sanitize() can strip a capture down to empty (e.g. a capture made
        # entirely of a backtick), which the regex alone cannot see.
        case "$sig" in
          ''|*'['*|*']'*)
            note "skipped a cluster candidate: signature is empty or contains a bracket char (got: '$(printf '%.64s' "$sig_raw")')"
            continue ;;
        esac
        case "$rid" in
          ''|*'['*|*']'*)
            note "skipped a cluster candidate: run_id is empty or contains a bracket char (got: '$(printf '%.64s' "$rid_raw")')"
            continue ;;
        esac

        sig_slug="$(printf '%s' "$sig" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//')"
        [ -n "$sig_slug" ] || sig_slug="cluster"
        cand="- [ ] **T-000** triage [cluster:${sig}]: recurring failure: ${sig} recurred ${cnt}x - starting at run ${rid} — \`READY_FOR_ARCH\` — spec: ${SPECS_DIR}/T-000-cluster-${sig_slug}.md"
        add_candidate "[cluster:${sig}]" "$cand"
        ccand=$((ccand + 1))
        ;;
    esac
  done < "$CLUSTERS"
  [ "$ccand" -gt 0 ] || note "no cluster candidates (no recurring failure clusters in the input)"
elif [ -n "$CLUSTERS" ]; then
  note "clusters input not readable: $CLUSTERS — cluster source skipped"
else
  note "no cluster input given (--clusters) — cluster source skipped"
fi

# ---------------------------------------------------------------------------
# Apply the --max BUDGET cap with an explicit truncation note (no silent drop).
# ---------------------------------------------------------------------------
total="${#CANDIDATES[@]}"
shown="$total"
if [ "$total" -gt "$MAX" ]; then
  shown="$MAX"
  note "truncated: showing ${MAX} of ${total} candidates (raise --max to see more)"
fi
[ "$total" -gt 0 ] || note "no candidate work after consolidation + de-dup"

# ---------------------------------------------------------------------------
# Resolve the output path with the never-overwrite numeric-suffix collision rule
# (mirrors the loop-triage / scrum-master run-file convention).
# ---------------------------------------------------------------------------
mkdir -p "$OUT_DIR"
base="$OUT_DIR/triage-rollup-${DATE}.md"
out="$base"
n=2
# -L as well as -e: a DANGLING symlink is invisible to -e, but `{ ... } > "$out"`
# would follow it and write outside OUT_DIR. Treat any occupant — file, dir, or
# symlink of either kind — as a collision and advance to the next suffix.
while [ -e "$out" ] || [ -L "$out" ]; do
  out="${OUT_DIR}/triage-rollup-${DATE}-${n}.md"
  n=$((n + 1))
done

# ---------------------------------------------------------------------------
# Write the proposal artifact.
# ---------------------------------------------------------------------------
{
  printf '# Triage rollup — %s\n\n' "$DATE"
  printf 'Consolidated, de-duplicated triage proposal merging outer-loop discovery\n'
  printf '(discover-work.sh, T-017), Operating-Loop telemetry escalations\n'
  printf '(rollup-runs.sh, T-020), and cross-run failure clusters\n'
  printf '(cluster-failures.sh, T-044). PROPOSE-ONLY: tasks/todo.md is NOT modified —\n'
  printf 'a human promotes a candidate (renumber T-000, write its spec) when adopting it.\n\n'
  printf '## Candidates\n\n'
  if [ "$shown" -gt 0 ]; then
    i=0
    while [ "$i" -lt "$shown" ]; do
      printf '%s\n' "${CANDIDATES[$i]}"
      i=$((i + 1))
    done
  else
    printf '# note: (none)\n'
  fi
  if [ "${#note_lines[@]}" -gt 0 ]; then
    printf '\n## Notes\n\n'
    for nl in "${note_lines[@]}"; do
      printf '# note: %s\n' "$nl"
    done
  fi
} > "$out"

printf '%s\n' "$out"
exit 0
