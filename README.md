# Mickaël Canouil's Brand Extension For Quarto

A Quarto extension that provides brand theming and styling for documents (HTML, Typst) and presentations (Reveal.js).

## Installation

```bash
quarto add mcanouil/quarto-mcanouil
```

This will install the extension under the `_extensions` subdirectory.
If you're using version control, you will want to check in this directory.

## Usage

This extension applies Mickaël Canouil's brand theming to Quarto documents using a brand configuration file.

To use this extension, you need to:

1. Ensure your project has a `_quarto.yml` file (required for the brand configuration to take effect)
2. The extension will automatically apply the branding based on the `brand.yml` file

The extension contributes brand theming that affects:

- Colours and typography
- Layout and styling
- Visual identity elements

**Note:** A `_quarto.yml` file is required at the project root for the brand configuration to take effect.

## Example

Here is the source code for a minimal example: [example.qmd](example.qmd).

Outputs of `example.qmd`:

- [HTML](https://m.canouil.dev/quarto-mcanouil/)
- [Typst Dark (PDF)](https://m.canouil.dev/quarto-mcanouil/example-typst-dark.pdf)
- [Typst Light (PDF)](https://m.canouil.dev/quarto-mcanouil/example-typst-light.pdf)
- [Reveal.js Dark (HTML)](https://m.canouil.dev/quarto-mcanouil/example-revealjs-dark.html)
- [Reveal.js Light (HTML)](https://m.canouil.dev/quarto-mcanouil/example-revealjs-light.html)
