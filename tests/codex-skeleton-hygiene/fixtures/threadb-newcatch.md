# Thread B new-catch fixture (T-097)

These lines are NOT real repo content — they are synthetic examples of the
forms the DP-7 (broken-invocation, absolute-path interpreter) and DP-8
(stateful-trace, hyphen<->space symmetric) extended regexes are DESIGNED to
catch, that the T-077 literal regexes miss (the exact `oldmiss` non-vacuous
counterfactual, T-095 pattern).

DP-7 absolute-path interpreter example (old regex requires whitespace/BOL
directly before `bash`/`sh`/`source`/`.` — an absolute path prefix like
`/bin/` breaks that adjacency):
Run /bin/bash bin/check-provenance.sh to validate the provenance file.

DP-8 symmetric hyphen<->space example #1 (old regex's `provenance-gate:AC`
side is a literal hyphen, no space-tolerant class):
Older drafts used a provenance gate:AC3 sentinel to track failures.

DP-8 symmetric hyphen<->space example #2 (old regex's `route-back through
loop-guard.sh` is a literal hyphen phrase with a trailing `.sh` — this line
uses all-space separators and no `.sh` suffix):
That variant would route back through loop guard state.
