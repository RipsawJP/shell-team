#!/usr/bin/env bash
# gen-codex-agents.sh — derive one Codex CLI custom-agent TOML per shipped
# inner-loop role from the unmodified agents/<role>.md, so a Codex CLI
# session can dispatch the same role prose Claude Code dispatches, with
# zero duplicated bytes of role prose anywhere (T-1134; GitHub issue #484;
# .shell-team/specs/T-1134-codex-host-slice1.md).
#
# For each role in ROLES (default: tech-lead pm-spec engineer qa-verifier —
# the Specify-to-Validate chain, per D2 in the spec above):
#   1. Read agents/<role>.md from --root, unmodified. Validate its
#      frontmatter has both a `---` opener and closer, that its
#      `description:` field is non-empty and carries no `"` or `\` (a TOML
#      basic string cannot carry either), and that the body after the
#      frontmatter is a shape a TOML multi-line LITERAL string (`'''...'''`)
#      can carry faithfully: no `'''` run, the source file itself ends with
#      a trailing newline, and no control character other than tab/newline
#      (a lone carriage return included) anywhere in the source. ANY
#      violation refuses the WHOLE run non-zero with NOTHING written to
#      --out-dir — never a partial generation (a single bad source must
#      never look like N-1 good files and a silent gap).
#   2. Derive `sandbox_mode` from the role's own frontmatter `tools:` list:
#      any of Write/Edit/Bash present -> workspace-write, else read-only.
#      Declarative documentation of intent only — a comment in the
#      generated file says so in the fixed words "not an enforcement
#      boundary", because the parent Codex session's own sandbox governs
#      at runtime (measured; see docs/adopting.md).
#   3. Resolve `model` / `model_reasoning_effort` through this script's own
#      resolve-executor.sh sibling (`--print-resolved`, probe-free,
#      write-free) — NEVER through --root, which may hold no bin/ at all
#      (a fixture root carrying only agents/*.md must still generate).
#      Both keys are emitted only when the resolved adapter is `codex-cli`;
#      `model` is additionally skipped for the `provider-configured`
#      placeholder and `model_reasoning_effort` for an unset `-` effort.
#      Under the shipped default binding every role is `claude-cli`, so
#      neither key is emitted and the Codex parent session's own model
#      governs.
#   4. Emit `developer_instructions` LAST, as a TOML multi-line literal
#      string whose body is byte-identical to the role file's own content
#      after the frontmatter's closing `---` — the file's final line is
#      always the closing `'''`, which is what makes the body mechanically
#      extractable without a TOML parser.
#   5. Write shell-team-<role>.toml into --out-dir, overwriting only its
#      own files — an adopter's own Codex agent TOMLs already there, or a
#      *.toml not named shell-team-<role>.toml, are never touched.
#
# bin/check-codex-agents.sh (its check-only sibling) then verifies an
# out-dir stays in sync with a fresh run of THIS script — running this
# script again after editing a role file or after a plugin upgrade is how
# you refresh that sync.
#
# Fail-closed, whole-run validation (no partial output): every requested
# role's source is validated and its TOML content built into a scratch
# temp file BEFORE anything is written to --out-dir. --out-dir is created
# (if needed) and populated only once every requested role has validated.
#
# Script-directory resolution is symlink-safe (`cd DIR && pwd -P`, never a
# bare logical `pwd`) — same shape as bin/gen-playbook-blocks.sh, so an
# ancestor directory symlink cannot misresolve the resolve-executor.sh
# sibling call.
#
# Usage:
#   gen-codex-agents.sh [--root DIR] [--out-dir DIR] [--roles "r1 r2 ..."]
#
#   --root      directory holding agents/<role>.md. Default: this script's
#               OWN plugin root (the parent of its own bin/ directory,
#               resolved symlink-safe), never the caller's current working
#               directory — an adopted repository has no agents/ of its
#               own, so a cwd default would silently read (or fail to find)
#               the wrong tree. This is NOT the shell-team operating base
#               dir (`.shell-team` / `tasks`) — it is simply the parent of
#               the agents/ directory being read. The executor-binding read
#               below never goes through this value.
#   --out-dir   where the generated shell-team-<role>.toml files land.
#               Default: $PWD/.codex/agents — the adopter's own current
#               directory (where they run this command), NOT --root's
#               directory: --root defaults to this plugin's own tree, and an
#               adopter running the default form expects the output in the
#               repository they are standing in, not inside the plugin
#               install. Documented in docs/adopting.md. NOTE: under Codex
#               CLI's own `codex exec --sandbox workspace-write`, this
#               script's own `mkdir -p "$OUT_DIR"` below is refused
#               (`Operation not permitted`) if OUT_DIR is under a `.codex/`
#               that does not already exist — that sandbox refuses creating
#               or writing `.codex/` itself, the same policy it applies to
#               `.git/`. Running this script from your own shell, outside a
#               Codex session, is the default and avoids this entirely; see
#               docs/adopting.md's "Using shell-team from Codex CLI" step 3
#               for the writable-roots form when Codex must run it in-session.
#   --roles     space-separated role-list override (default: the four
#               roles this task's Goal names: "tech-lead pm-spec engineer
#               qa-verifier")
#   --help, -h  show this header and exit 0
#
# Exit: 0 = generated (every requested role); 1 = a source role file cannot
#       be faithfully carried by a TOML multi-line literal string, or its
#       frontmatter is malformed — nothing written to --out-dir; 2 = usage
#       error or the executor binding did not resolve — nothing written to
#       --out-dir.

set -euo pipefail

fail() { printf 'gen-codex-agents: %s\n' "$1" >&2 || true; exit 1; }
die()  { printf 'gen-codex-agents: %s\n' "$1" >&2 || true; exit 2; }

# Resolve this script's own directory (symlink-safe) so the sibling
# resolve-executor.sh can be invoked regardless of --root or cwd — same
# pattern as bin/gen-playbook-blocks.sh / bin/resolve-executor.sh. `cd DIR
# && pwd -P` (T-1057, issue #218), not a bare logical `pwd`: an ANCESTOR
# directory symlink would otherwise survive untouched and could misresolve
# a sibling script's location.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd -P)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd -P)"

ROOT=""
OUT_DIR=""
ROLES="tech-lead pm-spec engineer qa-verifier"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)     [ "$#" -ge 2 ] || die "--root requires a value"; shift; ROOT="$1"; shift ;;
    --out-dir)  [ "$#" -ge 2 ] || die "--out-dir requires a value"; shift; OUT_DIR="$1"; shift ;;
    --roles)    [ "$#" -ge 2 ] || die "--roles requires a value"; shift; ROLES="$1"; shift ;;
    --help|-h)  sed -n '2,98p' "$script_path" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          die "unknown argument: $1" ;;
  esac
done

# --root default: this script's OWN plugin root (parent of its own bin/
# directory), never the caller's cwd — an adopted repository has no
# agents/ of its own to fall back to. SCRIPT_DIR is already symlink-safe
# and physical, so a plain `cd .. && pwd -P` is enough here.
[ -n "$ROOT" ] || ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

[ -d "$ROOT" ] || die "root path is not a directory: $ROOT"
ROOT="${ROOT%/}"
[ -n "$ROOT" ] || ROOT="."
# --out-dir default: the caller's OWN current directory, deliberately
# independent of --root (see header comment above).
[ -n "$OUT_DIR" ] || OUT_DIR="$PWD/.codex/agents"

# --- executor binding: this script's own sibling, never --root (see header
#     comment above and the spec's D3-model / freeze-attestation note) -----
RESOLVER="$SCRIPT_DIR/resolve-executor.sh"
[ -x "$RESOLVER" ] || die "cannot find sibling resolve-executor.sh next to gen-codex-agents.sh: $RESOLVER"

resolver_rc=0
RESOLVED_OUT="$(bash "$RESOLVER" --print-resolved 2>/dev/null)" || resolver_rc=$?
if [ "$resolver_rc" -ne 0 ] || [ -z "$RESOLVED_OUT" ]; then
  die "the executor binding did not resolve (resolve-executor.sh --print-resolved exited $resolver_rc with no usable output) — refusing to guess a model/effort mapping rather than treating a refusal as absence"
fi

# resolved_field <role> <field> — field in {provider,model,effort,adapter};
# prints the value on stdout, returns 1 (with nothing printed) if the
# resolved binding carries no row for that role.
resolved_field() {
  local role="$1" field="$2" line
  line="$(printf '%s\n' "$RESOLVED_OUT" | awk -v r="$role" '$1=="resolved" && $2==r {print; exit}')"
  [ -n "$line" ] || return 1
  # shellcheck disable=SC2086  # intentional word-splitting of a fixed-shape "resolved <role> <provider> <model> <effort> <adapter>" line
  set -- $line
  case "$field" in
    provider) printf '%s\n' "${3:-}" ;;
    model)    printf '%s\n' "${4:-}" ;;
    effort)   printf '%s\n' "${5:-}" ;;
    adapter)  printf '%s\n' "${6:-}" ;;
  esac
}

trim() {  # prints $1 with leading/trailing whitespace stripped
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# --- pass 1: validate every requested role and build its TOML content into
#     a scratch temp file — nothing is written to --out-dir until every
#     requested role has validated (AC3's whole-run, no-partial-output
#     refusal). CONTENT_FILES/CONTENT_ROLE stay parallel arrays (this
#     repo's bin/ scripts avoid associative arrays for bash 3.2 portability
#     — see bin/resolve-executor.sh's own indexed-array lookups).
# shellcheck disable=SC2206  # ROLES is a fixed, simple space-separated word list
ROLES_ARR=($ROLES)
[ "${#ROLES_ARR[@]}" -ge 1 ] || die "--roles produced an empty role list"

CONTENT_FILES=()
CONTENT_ROLE=()
# shellcheck disable=SC2329  # invoked indirectly via the EXIT trap below
cleanup() { rm -f "${CONTENT_FILES[@]}" 2>/dev/null || true; }
trap cleanup EXIT

for role in "${ROLES_ARR[@]}"; do
  SRC="$ROOT/agents/$role.md"
  [ -f "$SRC" ] && [ -r "$SRC" ] || fail "cannot read role file: $SRC"

  # Input class 7 (NUL, checked first and separately from the rest of the
  # control-character range below): bash's own $'\x00' ANSI-C quoting
  # truncates at the first NUL byte when it builds an argv entry, so a
  # single `grep -q $'[...\x00...]'` invocation can never actually search
  # for a NUL — the byte silently drops out of the pattern before grep
  # ever receives it (this is why the range below starts at \x01, and why
  # it must NOT be "fixed" by just prepending \x00 to that same pattern).
  # Detected instead by byte count: deleting every NUL with `tr` and
  # comparing the resulting length to the source's own length never
  # depends on passing a NUL through argv.
  src_len="$(wc -c < "$SRC" | tr -d ' ')"
  nonul_len="$(LC_ALL=C tr -d '\000' < "$SRC" | wc -c | tr -d ' ')"
  [ "$nonul_len" = "$src_len" ] || fail "role file contains a NUL byte (0x00), a control character other than tab and newline that a TOML literal string cannot carry: $SRC"

  first_line="$(head -n 1 "$SRC")"
  [ "$first_line" = "---" ] || fail "role file has no frontmatter opening '---' as its first line: $SRC"

  close_ln="$(awk 'NR>1 && $0=="---" {print NR; exit}' "$SRC")"
  [ -n "$close_ln" ] || fail "role file has an opening '---' but no closing '---' (unterminated frontmatter): $SRC"

  desc="$(awk -v c="$close_ln" 'NR>1 && NR<c && $0 ~ /^description: / { sub(/^description: /, ""); print; exit }' "$SRC")"
  [ -n "$desc" ] || fail "role file frontmatter carries no non-empty description: field: $SRC"
  case "$desc" in
    *'"'*) fail "role file's description: value contains a double quote, which a TOML basic string cannot carry: $SRC" ;;
  esac
  case "$desc" in
    *"\\"*) fail "role file's description: value contains a backslash, which a TOML basic string cannot carry: $SRC" ;;
  esac

  tools_line="$(awk -v c="$close_ln" 'NR>1 && NR<c && $0 ~ /^tools: / { sub(/^tools: /, ""); print; exit }' "$SRC")"
  sandbox_mode="read-only"
  if [ -n "$tools_line" ]; then
    IFS=',' read -ra __tok <<< "$tools_line"
    for t in "${__tok[@]}"; do
      tt="$(trim "$t")"
      case "$tt" in
        Write|Edit|Bash) sandbox_mode="workspace-write" ;;
      esac
    done
  fi

  # Input class 6: the SOURCE FILE itself must end with a trailing newline
  # — the only shape in which a trailing apostrophe in the body could abut
  # the closing ''' delimiter and form a four-quote sequence.
  last_nl="$(tail -c1 "$SRC" | wc -l | tr -d ' ')"
  [ "$last_nl" = "1" ] || fail "role file does not end with a trailing newline: $SRC"

  # Input class 7 (continued): no control character other than tab (0x09)
  # and newline (0x0A) anywhere in the source, a lone carriage return
  # (0x0D) included. NUL (0x00) is this same class and was already refused
  # above, separately, for the argv-truncation reason given there. Explicit
  # byte ranges under LC_ALL=C — NOT [[:cntrl:]]/[[:space:]], which would
  # let 0x0C/0x0B/0x0D slip through as "space" (design note, freeze sweep
  # 2026-09-10). Deliberately still starts at \x01, not \x00: adding \x00
  # to this bracket expression looks like the obvious one-line fix but does
  # nothing, since the pattern argument itself would already be truncated
  # before grep runs.
  if LC_ALL=C grep -q $'[\x01\x02\x03\x04\x05\x06\x07\x08\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\x7f]' "$SRC"; then
    fail "role file contains a control character other than tab and newline (a lone carriage return included): $SRC"
  fi

  BODY_FILE="$(mktemp "${TMPDIR:-/tmp}/gen-codex-agents-body.XXXXXX")"
  tail -n "+$((close_ln + 1))" "$SRC" > "$BODY_FILE"

  # Input class 5: the three-character TOML literal-string terminator must
  # not occur anywhere in the body. Two or even two-on-a-line-end
  # apostrophes are legal (AC3's own positive control) — only the full
  # three-quote run is refused.
  if grep -qF -- "'''" "$BODY_FILE"; then
    rm -f "$BODY_FILE"
    fail "role file body contains the TOML multi-line literal-string terminator ''' (a body must not carry this run): $SRC"
  fi

  model="$(resolved_field "$role" model || true)"
  effort="$(resolved_field "$role" effort || true)"
  adapter="$(resolved_field "$role" adapter || true)"
  if [ -z "$adapter" ]; then
    rm -f "$BODY_FILE"
    die "the resolved executor binding carries no row for role: $role"
  fi

  CONTENT_FILE="$(mktemp "${TMPDIR:-/tmp}/gen-codex-agents-toml.XXXXXX")"
  CONTENT_FILES+=("$CONTENT_FILE")
  CONTENT_ROLE+=("$role")

  {
    printf '# Generated by bin/gen-codex-agents.sh from agents/%s.md — do not edit by hand.\n' "$role"
    printf '# Re-run bin/gen-codex-agents.sh after editing that role file or after a plugin\n'
    printf '# upgrade; bin/check-codex-agents.sh reports drift against the current source.\n'
    printf 'name = "shell-team-%s"\n' "$role"
    printf 'description = "%s"\n' "$desc"
    printf '#\n'
    printf "# sandbox_mode below is declarative documentation of this role's own intended\n"
    printf '# write scope, derived from its agents/%s.md frontmatter tools: list — it is\n' "$role"
    printf "# not an enforcement boundary: the parent Codex session's own sandbox governs\n"
    printf '# at runtime regardless of this value (measured; see docs/adopting.md).\n'
    printf 'sandbox_mode = "%s"\n' "$sandbox_mode"
    if [ "$adapter" = "codex-cli" ]; then
      if [ -n "$model" ] && [ "$model" != "provider-configured" ]; then
        printf 'model = "%s"\n' "$model"
      fi
      if [ -n "$effort" ] && [ "$effort" != "-" ]; then
        printf 'model_reasoning_effort = "%s"\n' "$effort"
      fi
    fi
    printf "developer_instructions = '''\n"
    cat "$BODY_FILE"
    printf "'''\n"
  } > "$CONTENT_FILE"

  rm -f "$BODY_FILE"
done

# --- pass 2: every requested role validated — write into --out-dir. Only
#     this generator's own shell-team-<role>.toml files are ever touched;
#     any other file already in --out-dir (an adopter's own Codex agent, or
#     a stale file this run does not own) is left exactly as found. -------
mkdir -p "$OUT_DIR" || die "cannot create out-dir: $OUT_DIR"
idx=0
for role in "${CONTENT_ROLE[@]}"; do
  cat "${CONTENT_FILES[$idx]}" > "$OUT_DIR/shell-team-$role.toml"
  printf 'gen-codex-agents: generated %s/shell-team-%s.toml\n' "$OUT_DIR" "$role"
  idx=$((idx + 1))
done

exit 0
