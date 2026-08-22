# Subject 01 — frozen interface contract

This is the observable contract every implementation of `csvstats` must
satisfy exactly, whatever its own internal structure looks like. A candidate
is free to choose any module split, algorithm or naming; it is not free to
change one byte of what is declared below.

- interface: `cli/csvstats <file>` — cli-invocation — reads exactly one positional argument, the CSV file path; no flags, no stdin input, no other arguments accepted or required.
- interface: `column=<name> count=<n> sum=<v> min=<v> max=<v> avg=<v>` — stdout-line-grammar — one line per column found to be numeric across every usable data row, columns reported in the header row's own left-to-right order, `avg` computed as `$(( sum / count ))` (bash integer division, truncated toward zero) — never a decimal, never rounded.
- interface: exit-code-contract — exit-semantics — `0` when at least one usable data row was processed, even if zero columns turned out numeric; `1` when the file is readable but zero usable data rows remain after skipping; `2` when the input path cannot be opened for reading.
- interface: `skip: row <n> field-count-mismatch` — stderr-diagnostic — printed once per data row whose comma-split field count differs from the header row's own field count; `<n>` is the 1-based ordinal of that row among all non-empty lines following the header, in file order; that row is excluded from every column's statistics and does not by itself cause a non-zero exit.
- interface: `error: no data rows` / `error: cannot read <path>` — stderr-diagnostic — the two fixed messages paired with exit codes `1` and `2` respectively; `<path>` in the second is the command-line argument exactly as given, with no normalization.

- interface-frozen: The five lines above are frozen for this subject's whole life. A candidate may choose any internal module split, algorithm or variable naming, but must reproduce every declared stdout byte, stderr byte and exit code exactly, so that a later arm's implementation is comparable to this one at the only boundary a judge can actually observe from outside.
