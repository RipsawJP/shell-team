- intervention: human-interrupt
- intervention: human-correction
- intervention: human-stop
- intervention: assumption-contradicted
- intervention: work-deferred
- intervention: work-abandoned
- intervention: unclassified
A routine gate response — a plain GO, an approval, or an answer to a question you asked — is not an intervention and gets no entry.

Entry template: `<!-- BEGIN interventions: <id> -->` opens the region and `<!-- END interventions: <id> -->` closes it with the same `<id>`; each entry is a `- intervention: <class>` line followed by indented `date: <YYYY-MM-DD>`, `summary: <one line>` and `effect: <one line>` fields.
If the file currently holds the sentinel `no interventions occurred`, the first real entry REPLACES that line rather than being appended after it — the sentinel and an entry cannot coexist in either order (AC5).
