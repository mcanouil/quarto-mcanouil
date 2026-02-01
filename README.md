# Mickaël Canouil's Brand Extension For Quarto

A Quarto extension providing branded theming, custom components, and professional styling for HTML documents, Typst (PDF) reports, and Reveal.js presentations.

## Installation

```bash
quarto add mcanouil/quarto-mcanouil@0.11.0
```

This will install the extension under the `_extensions` subdirectory.
If you are using version control, you will want to check in this directory.

## Project Type

The extension contributes a **`mcanouil`** project type, which provides a pre-configured Quarto website with branded navbar, sidebar, footer, favicon, and `mcanouil-html` as the default format.

```yaml
# _quarto.yml
project:
  type: mcanouil
```

## Formats

The extension provides three format families:

- **`mcanouil-html`**: Styled HTML documents with professional or academic layouts.
- **`mcanouil-typst`**: Typst-based PDF output with light/dark modes and multiple document types (report, invoice, letter, CV).
- **`mcanouil-revealjs`**: Reveal.js presentations with light/dark modes, section outlines, and a closing slide.

## Key Features

- **Brand theming**: Consistent colours, typography, and logos across all formats via `brand.yml`.
- **Custom components**: Value boxes, info panels, status badges, dividers, progress bars, card grids, and executive summaries.
- **Code windows**: macOS-style code block headers with filename display.
- **Grid background**: Subtle grid overlay for HTML and Reveal.js.
- **Special sections**: Auto-relocating appendix and supplementary sections with custom numbering (Typst).
- **Accessibility**: PDF/UA-1 compliance, alt text support, and WCAG AA contrast validation (Typst).

## Quick Start

```yaml
---
title: "My Document"
format: mcanouil-html
---
```

```yaml
---
title: "My Report"
format:
  mcanouil-typst:
    style: professional
    brand-mode: light
---
```

```yaml
---
title: "My Presentation"
format:
  mcanouil-revealjs:
    brand-mode: dark
---
```

## Example

Source: [example.qmd](example.qmd).

Rendered outputs:

- [HTML (Professional)](https://m.canouil.dev/quarto-mcanouil/).
- [HTML (Academic)](https://m.canouil.dev/quarto-mcanouil/example-academic.html).
- [Reveal.js (Dark)](https://m.canouil.dev/quarto-mcanouil/example-revealjs-dark.html).
- [Reveal.js (Light)](https://m.canouil.dev/quarto-mcanouil/example-revealjs-light.html).
- [PDF (Dark Professional)](https://m.canouil.dev/quarto-mcanouil/example-dark-professional.pdf).
- [PDF (Light Professional)](https://m.canouil.dev/quarto-mcanouil/example-light-professional.pdf).
- [PDF (Dark Academic)](https://m.canouil.dev/quarto-mcanouil/example-dark-academic.pdf).
- [PDF (Light Academic)](https://m.canouil.dev/quarto-mcanouil/example-light-academic.pdf).

See [example.qmd](example.qmd) for full documentation of all components, configuration options, and YAML parameters.
