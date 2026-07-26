# Thread B clean fixture (T-097, fp-zero)

Legitimate forms the DP-7 / DP-8 extended regexes must NOT match — a
false-positive-zero check. None of these lines is a broken-invocation or a
stateful-trace-boundary sentinel; they are the bare/legitimate mentions real
prose in this repo actually uses.

Bare command form (on PATH when the plugin is loaded):
Run `check-provenance.sh tasks/provenance/T-XXX.md` to verify conformance.

Passive fallback mention (the exact legit form Input space class 5 calls out
— must not match the broken-invocation lock):
When invoked directly, resolve it with `check-provenance.sh` — bare on PATH
when the plugin is loaded; else `bin/check-provenance.sh`.

An unrelated standalone mention of loop-guard.sh (not the 4-word DP-8
sequence — no "route ... back ... through ... loop ... guard" phrase here):
This mirrors bin/loop-guard.sh's STOP handling in spirit, not in wire format.

A provenance mention with no "gate:AC<digit>" sentinel attached at all:
The provenance file records decision/reason/grounding triples.
