Any population total, set delta or bucket split that a record states is produced by `bin/derive-populations.sh`, never counted by eye or hand-derived.
Embed the emitted `<!-- BEGIN derivation: <label> -->` / `<!-- END derivation: <label> -->` block verbatim, each one preceded by its own `- reproduce: <command>` line carrying the exact command that regenerates it.
A record may carry more than one such block — every one of them is produced this way, not only the first.
A relayed count carries its own derivation too: write `- count: <label> — <value> — command: <cmd>` on the task's own board entry so a downstream consumer re-runs the command instead of quoting the number.
