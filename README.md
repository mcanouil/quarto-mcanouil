# Mickaël Canouil's Brand Extension For Quarto

`mcanouil` gives Quarto three formats that share one look: `mcanouil-typst` for PDF, `mcanouil-html` and `mcanouil-revealjs`.
You pick one of four presets (`gold`, `mono`, `quarto` or `terminal`), and it sets the colours, fonts, style and corner motif of all three.
There are six document types: a compact or full report, an article, a memo, a letter, an invoice and a workshop session.
Accessibility comes first, with WCAG 2.2 AA in HTML and Reveal.js and PDF/UA-1 in every PDF.

Version 1.0 is a rewrite.
The options and components of the 0.x versions are gone, so a 0.x document needs new front matter.

## Installation

```bash
quarto add mcanouil/quarto-mcanouil@1.0.0
```

This installs the extension under the `_extensions` subdirectory.
If you're using version control, check in this directory.

The extension needs Quarto 1.12.1 or later.
Quarto checks the PDF tags with veraPDF, which you can install with `quarto install verapdf`.

## Usage

```yaml
format:
  mcanouil-typst: default
  mcanouil-html: default
  mcanouil-revealjs: default
extensions:
  mcanouil:
    preset: gold
    type: report
    layout: full
```

The extension embeds its own tools, such as code-window, gitlink, veil and typst-extras.
Please don't list them again in your `filters:`, as the formats already run them.

[`example.qmd`](example.qmd) is a starting point you can copy.

## Documentation

The full documentation lives at <https://m.canouil.dev/quarto-mcanouil/>.
It covers every option, each document type and format, the embedded tools and their versions, and the known limitations.

## Licence

[MIT](https://github.com/mcanouil/quarto-mcanouil?tab=MIT-1-ov-file#readme).
