# Tests

The test suite uses [quarto-extension-test](https://github.com/mcanouil/quarto-extension-test).
Each case is a `.qmd` file in an area directory, for example `types/report-full-gold.qmd`.
A directory with its own `_quarto.yml`, such as `book/`, is a project case.

## Commands

Run these commands from the root of the repository.

Run the full suite:

```bash
quarto pandoc lua tests/_extensions/mcanouil/extension-test/run.lua --root "$PWD"
```

Run only the render layer while you work on a change:

```bash
quarto pandoc lua tests/_extensions/mcanouil/extension-test/run.lua --root "$PWD" --layer render
```

Run the unit tests of the Lua modules:

```bash
quarto pandoc lua tests/unit/run.lua
```

The full suite takes several minutes.
Run it in the foreground.

## Requirements

- veraPDF, for the PDF/UA-1 checks: `quarto install verapdf`.
- Poppler (`pdftotext`, `pdftoppm`, `pdfinfo`), for the PDF checks.
- Node.js and a Chromium-based browser, for the HTML and deck checks. The checks look at `CHROME_PATH`, then `QUARTO_CHROMIUM`, then the installed browsers.

## Stale Typst files

Many cases set `keep-typ: true`, so a render by hand leaves a `.typ` file next to the case.
The runner stops on a case when its `.typ` file already exists before the render.
Remove the stale `.typ` files before you run the suite:

```bash
find tests -name '*.typ' -not -path '*/_extensions/*' -not -path '*/.quarto/*' -not -path 'tests/_output/*' -print
```

Read the list, then run the same command with `-delete` in place of `-print`.
Git ignores these files, so `git status` does not show them.

## Check hooks

The check hooks are in `_checks/`, one script for each area.
Each hook prints TAP lines.
Shared helpers are in `_checks/lib.sh`.
Accepted axe findings are in `_axe-baseline.json`, each with a note that gives the reason.
