# Release notes template

Shipped template for drafting a GitHub Release's title and body (issue #223).
Both rules below are forward-only: they apply starting with the release that
first uses this template, and no past release title or body is edited to
match it.

## Title

The release title is **the tag name, verbatim** — `vX.Y.Z`, nothing prepended
and nothing appended. Do not write "Release vX.Y.Z" or "vX.Y.Z — <summary>".

## Body

Copy everything between the two marker lines below into the release body,
verbatim, then fill it in per the instructions beside each section.

- **No version heading anywhere in the body.** The title already carries the
  version (above); a heading repeating it inside the body would be
  redundant, and this template's markers exist so that rule is checkable
  mechanically.
- **`## Highlights`** — transcribe `CHANGELOG.md`'s newest entry's sub-bullets
  **verbatim**, including their leading two-space indentation, exactly as
  they appear under that entry's top-level `- **vX.Y.Z**` bullet. Omit only
  the parent `- **vX.Y.Z**` bullet line itself — the release title already
  names the version. Do not re-indent, reword, or summarize.
- **`## Migration notes`** — when the release changes something an adopter
  must act on, describe it here. When it does not, the whole section is
  omitted, not left empty: delete the heading and everything under it rather
  than leaving an empty section under a heading that is still present.
- **`## Install / update`** and **`## Links`** are static boilerplate below;
  copy them unchanged — except the compare URL in `## Links`, where `vPREV`
  takes the previous release's tag and `vX.Y.Z` this release's, the same
  fill-in notation the title rule above uses.

<!-- BEGIN release-body -->
## Highlights

  <!-- CHANGELOG.md's newest entry's sub-bullets go here, transcribed
       verbatim including this two-space indentation. Delete this comment. -->

## Migration notes

<!-- Omit this whole section, heading included, when the release changes
     nothing an adopter must act on. -->

## Install / update

```text
/plugin marketplace add RipsawJP/shell-team
/plugin install shell-team@ripsawjp
```

Already installed? Update the marketplace listing:

```text
/plugin marketplace update ripsawjp
```

## Links

- Changelog: [CHANGELOG.md](https://github.com/RipsawJP/shell-team/blob/main/CHANGELOG.md) ([日本語: CHANGELOG.ja.md](https://github.com/RipsawJP/shell-team/blob/main/CHANGELOG.ja.md))
- Compare: https://github.com/RipsawJP/shell-team/compare/vPREV...vX.Y.Z
<!-- END release-body -->
