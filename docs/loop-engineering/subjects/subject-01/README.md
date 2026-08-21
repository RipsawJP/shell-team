# Subject 01 — csvstats: a per-column CSV summarizer

**What you are building.** A small, real-shaped shell tool, `csvstats`, that
reads a comma-separated file whose first line is a header row and prints one
summary line per column whose values are integers in every usable data row.
This is a from-scratch, whole implementation: there is no partition and no
partial credit for shipping one library file without the other — build the
CLI and both of its libraries together, from nothing.

**Shape you must follow.** Two library files plus one CLI entrypoint,
implemented as one whole rather than split across instances or partitioned
by file. This mirrors the one shape this repository has a recorded
per-implementation cost figure for (a two-library-plus-CLI pure-bash tool),
so a later measurement stays comparable to that figure. `manifest.txt` names
the exact three files you must produce and the one extra directory you may
use for your own tests.

**What is frozen and what is yours to decide.** `interface.md`'s interface
lines are the contract you must satisfy byte-for-byte: the exact stdout
format, the exact stderr messages, and the exact exit codes. Everything else
— how you split logic between `lib/csvparse.sh` and `lib/colstats.sh`, what
functions you name, how `cli/csvstats` is structured internally — is your
own decision.

**What the oracle claims, and what it does not.** `acceptance.sh` is an
enumerated-case instrument: it verifies that your implementation reproduces
the exact stdout bytes, stderr bytes and exit code its eleven cases specify,
for the inputs those cases construct, and nothing beyond them. Passing every
case is not proof that every byte of `interface.md`'s frozen contract is
satisfied on every input — see `docs/loop-engineering/tier2-subject-harness.md`'s
own `- oracle-claim:` and `- claim-limit:` lines for the named boundary
(T-1089).

**The CSV grammar this subject uses, stated once so nothing is left to
guess.** Fields are separated by a single comma; there is no quoted-field
escaping to implement and no fixture will ever need one — a value never
contains a comma of its own. The first line of any readable input is always
the header row, whatever it contains. Every subsequent line that is not
entirely empty (zero characters) is a candidate data row.

**Do not do these things** (frozen candidate rules — a later judge checks
these, never this subject's own oracle):

- candidate-rule: oracle-not-edited — your venue holds a copy of
  `acceptance.sh` for your own reference; scoring always runs the committed
  copy at its own path outside your venue, so editing your venue's copy
  changes nothing about your score.
- candidate-rule: interface-not-changed — do not print a different message,
  reorder a field, or return a different exit code than `interface.md`
  declares, even where a different shape would read better to you;
  comparability across arms depends on every implementation honoring the
  same contract.
- candidate-rule: paths-confined-to-manifest — write only the three
  `candidate-path:` files `manifest.txt` names, plus, optionally, your own
  test files under the single `candidate-extra-dir:` it names. Anything else
  you create sits outside the manifest's declared scope.
- candidate-rule: zero-dependency-bash — implement this in plain bash plus
  ordinary POSIX text utilities (`sed`, `grep`, `cut`, `tr`, and the like),
  exactly as this repository's own committed shell scripts do. No Python, no
  Perl, no `bc`, no `awk` arithmetic, no interpreter or package you would
  need to install.

**The subject's own frozen acceptance criteria.** Read verbatim — a
candidate does not get to loosen or re-derive these; a future judge scores
against them exactly as written here.

- subject-ac: 1 — Given a nonexistent or unreadable input path, the tool
  prints `error: cannot read <path>` to stderr, where `<path>` is the
  argument exactly as given on the command line, and exits `2`; nothing is
  printed to stdout.
- subject-ac: 2 — The first line of a readable input is always the header
  row, whatever it contains, split on commas into column names; every
  subsequent line that is not entirely empty is a candidate data row, tested
  against the header row's own field count.
- subject-ac: 3 — A data row whose comma-split field count differs from the
  header row's own field count is excluded from every column's statistics
  and reported, once, to stderr as `skip: row <n> field-count-mismatch`,
  where `<n>` is that row's 1-based ordinal among all non-empty lines
  following the header, in file order; a skipped row never contributes to
  any column's count, sum, minimum, maximum or to the exit code.
- subject-ac: 4 — If zero data rows remain usable after skipping (including
  the case of a header-only file with no further lines), the tool prints
  `error: no data rows` to stderr and exits `1`; nothing is printed to
  stdout.
- subject-ac: 5 — A column is reported if and only if every usable row's
  value in that column matches `^-?[0-9]+$` (an optional leading minus, then
  one or more digits, nothing else, no leading/trailing whitespace). For
  each such column, in the header row's own left-to-right order, the tool
  prints exactly one stdout line: `column=<name> count=<n> sum=<v>
  min=<v> max=<v> avg=<v>`, where `avg` is `$(( sum / count ))` — bash's own
  truncating integer division.
- subject-ac: 6 — A non-numeric column (any usable row whose value in that
  column fails the pattern above) is silently omitted from stdout: it is
  never reported as an error, and it never aborts processing of the other
  columns.
- subject-ac: 7 — Given at least one usable data row, the tool exits `0`,
  even when zero columns turn out to be numeric — in that case stdout is
  simply empty and the exit code is still `0`, never an error path.
- subject-ac: 8 — A value matching subject-ac 5's pattern is read as a `10#`-normalized **decimal** integer, never as an octal or other non-decimal base.
  A leading zero (e.g. `010`, `-010`) never changes the value's magnitude or
  sign, and `00` denotes zero. This closure exists because bash's own
  `$(( ))` arithmetic would otherwise silently reinterpret a leading-zero
  decimal spelling as octal, or error outright on an invalid octal digit —
  a class named in `docs/loop-engineering/tier2-subject-harness.md`'s own
  `- claim-limit: zero-padded-arithmetic-class` line (T-1089).

**What you receive in your venue and what you produce.** Your venue holds a
copy of this brief, `interface.md`, `manifest.txt` and `acceptance.sh` —
regenerated from committed bytes, identical every time. You produce exactly
`lib/csvparse.sh`, `lib/colstats.sh` and `cli/csvstats` at the paths
`manifest.txt` names, and, optionally, your own tests under `check/`. Your
own tests are not scored; the committed oracle at its own path is what a
later arm's score comes from.
