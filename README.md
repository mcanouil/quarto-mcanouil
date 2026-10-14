# Mickaël Canouil's Brand Extension For Quarto

One extension carrying a personal brand across three outputs: a Quarto project type for websites, and `mcanouil-html`, `mcanouil-typst`, and `mcanouil-revealjs` formats sharing a `brand.yml`, a component set, and a look.

## Installation

```bash
quarto add mcanouil/quarto-mcanouil@0.22.0
```

This will install the extension under the `_extensions` subdirectory.
If you're using version control, you will want to check in this directory.

## Documentation

The full documentation lives at <https://m.canouil.dev/quarto-mcanouil/>: the project type, the three format families, the components they share, the RevealJS options, and a report rendered by the site itself.

[`example.qmd`](example.qmd) is a starting point you can copy.

## Quarto workarounds

The extension works around a few Quarto CLI bugs.
Each workaround goes once its issue is fixed in a Quarto release the extension requires.

- Typst logo paths lose the backslashes Pandoc adds to metadata strings ([quarto-dev/quarto-cli#15056](https://github.com/quarto-dev/quarto-cli/issues/15056)).
- External links from `format-links` open in a new window ([quarto-dev/quarto-cli#10730](https://github.com/quarto-dev/quarto-cli/issues/10730)).
- The code annotation line highlight keeps to the code block ([quarto-dev/quarto-cli#13448](https://github.com/quarto-dev/quarto-cli/issues/13448)).
- The copy button stays clear of the code annotation markers ([quarto-dev/quarto-cli#13444](https://github.com/quarto-dev/quarto-cli/issues/13444)).

## Licence

[MIT](https://github.com/mcanouil/quarto-mcanouil?tab=MIT-1-ov-file#readme).
