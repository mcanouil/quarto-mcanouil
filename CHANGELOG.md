# Changelog

## Unreleased

No user-facing changes.

## 0.16.1 (2026-02-21)

### New Features

- feat: Rename element-attributes to attributes and add classes section (#94).

## 0.16.0 (2026-02-21)

### New Features

- feat: Update component renderers and schema for enhanced functionality.
- feat: Add language detection for code blocks.
- feat: Add _schema.yml for configuration validation and IDE support (#90).

### Bug Fixes

- fix: Add code-window options and correct icon field type (#91).
- fix: Update quarto version requirement and syntax highlighting.

## 0.15.6 (2026-02-11)

No user-facing changes.

## 0.15.5 (2026-02-07)

### Style

- style: Update sidebar configuration and enhance tab content borders.

## 0.15.4 (2026-02-06)

### Bug Fixes

- fix: Disable sidebar by default.

## 0.15.3 (2026-02-06)

### Style

- style: Update border styles for improved visibility and consistency.

## 0.15.2 (2026-02-06)

### Style

- style: Comment out unused sidebar and footer styles.

## 0.15.1 (2026-02-06)

### Style

- style: Update sidebar text colours for better visibility.

## 0.15.0 (2026-02-06)

### Style

- style: Comment out unused CSS rules for navbar, footer, and sidebar.

## 0.14.1 (2026-02-06)

### New Features

- feat: Add code-link and code-tools options, and enable respect-user-color-scheme.

### Refactoring

- refactor: Simplify styling.

### Style

- style: Improve sidebar text colour handling.
- style: Tweak brand layering.

## 0.14.0 (2026-02-04)

### New Features

- feat: Enhance sidebar theming for dark mode support.

### Bug Fixes

- fix: Correct license type in brand configuration.

## 0.13.2 (2026-02-04)

### New Features

- feat: Enhance navbar and sidebar icons theming.

## 0.13.1 (2026-02-04)

### Refactoring

- refactor: Compute muted colour handling in colour scheme.

## 0.13.0 (2026-02-04)

### New Features

- feat: Brand support for typst.

### Bug Fixes

- fix: Support codefont from Quarto.
- fix: Safeguard for logo.

## 0.12.3 (2026-02-03)

### Refactoring

- refactor: Rename functions for clarity and consistency.

### Style

- style: Adjust ORCID display formatting for improved clarity.

## 0.12.2 (2026-02-02)

### Style

- style: Increase callout background opacity for better visibility.

## 0.12.1 (2026-02-01)

No user-facing changes.

## 0.12.0 (2026-02-01)

### New Features

- feat: Code-annotation support.
- feat: Expand auto-width boxes for image centring.

### Bug Fixes

- fix: Expand auto-width boxes for image centring.

## 0.11.1 (2026-02-01)

### Bug Fixes

- fix: Use google for Typst fonts instead of bunny.

## 0.11.0 (2026-02-01)

### New Features

- feat: Update typography settings and font sources.

## 0.10.0 (2026-01-31)

### New Features

- feat: Add numbering definitions and integrate marginalia support.
- feat: Add page-break-inside filter for Typst compatibility.

## 0.9.0 (2026-01-29)

### New Features

- feat: Add grid background toggle filter.
- feat: Add animated underline style for content links.

### Bug Fixes

- fix: Reset section page state inside the page call.
- fix: Add function to count consecutive backticks.
- fix: Adjust margin for code-with-filename class.

### Documentation

- docs: Update installation command in README for clarity.
- docs: Enhance README for clarity and detail.
- docs: Update example.qmd for template clarity.

### Style

- style: Adjust spacing for link selectors in theme.scss.
- style: Simple underline for reveal.js.

## 0.8.0 (2026-01-27)

### New Features

- feat: Add code annotation click functionality and improve styling.

### Bug Fixes

- fix: Patch annotation tooltips to prevent overflow clipping.
- fix: Remove unnecessary z-index for tippy tooltips.
- fix: Code-annotation conflcit with code-window.

## 0.7.4 (2026-01-26)

No user-facing changes.

## 0.7.3 (2026-01-26)

### Bug Fixes

- fix: Update format links for HTML output styles.

## 0.7.2 (2026-01-26)

### Bug Fixes

- fix: Update output file name for academic format.

## 0.7.1 (2026-01-26)

No user-facing changes.

## 0.7.0 (2026-01-26)

### New Features

- feat: Enhance format options for mcanouil templates.

### Bug Fixes

- fix: Typo.
- fix: Skip unlisted headings and slides in subsection collection.

## 0.6.2 (2026-01-26)

### New Features

- feat: Add configuration options for mcanouil extensions.

### Bug Fixes

- fix: Update module path resolution for utils.
- fix: Update affiliation from Consultant to Contractor.

## 0.6.1 (2026-01-25)

### Style

- style: Fix keyword title formatting in title block.

## 0.6.0 (2026-01-25)

### Style

- style: Replace radial-gradient backgrounds with SVG images for traffic lights.

## 0.5.0 (2026-01-25)

### New Features

- feat: Add high contrast mode support for accessibility.
- feat: Enable macOS-style code window in mcanouil extension.
- feat: Implement professional style support and remove magazine style.
- feat: Enhance HTML templates and styles for academic and magazine formats.
- feat: Add author styling with degrees and ORCID support.
- feat: Display degrees after author names.
- feat: Set more default options.

### Bug Fixes

- fix: Update code annotation workaround and improve link selector.
- fix: Degrees field in author metadata and license text in footer.
- fix: Correct license text formatting in footer.
- fix: Correct logo paths and enhance sidebar configuration.

### Refactoring

- refactor: Replace html_utils functions with utils module equivalents.
- refactor: Remove code-window configuration from extensions.
- refactor: Add geometric background and corner bracket mixins.
- refactor: Update callout background colour mixing for compatibility.
- refactor: Update media queries to use breakpoint variables.
- refactor: Update date element selectors for professional and academic styles.
- refactor: Add responsive design variables and improve transition effects.

### Style

- style: Format code for improved readability.
- style: Remove unnecessary spaces in card grid styles.
- style: Remove unnecessary margin and content from value box.
- style: Adjust text-muted colour mix for better contrast.
- style: Override Quarto defaults with !important for specificity.
- style: Add will-change property for link hover effect.
- style: Add convention note for desktop-first media queries.
- style: Update colour mixing functions for consistency.
- style: Adjust heading margins for improved spacing.

## 0.4.0 (2026-01-23)

### New Features

- feat: Add pagination control for print/PDF output.
- feat: Add print pagination styles for code windows.
- feat: Enhance document configuration and styling options.
- feat: Add author details and affiliations to metadata.
- feat: Add logo configuration to brand.yml.
- feat: Add panel tabset filter for Typst format.
- feat: Refactor code annotation fragments plugin.
- feat: Synchronise annotations with line highlighting.
- feat: Enhance project metadata and styling.

### Bug Fixes

- fix: Enable normalise-extension-paths filter post-render.
- fix: Workaround bad resource paths in typst output.
- fix: Correct logo paths for light and dark modes.
- fix: Light/dark logo switching.
- fix: Update copyright and license links in footer.
- fix: Marginalia workaround.
- fix: Update quarto version requirement and improve code formatting.

### Refactoring

- refactor: Scope extension settings.
- refactor: Improve JS code.

## 0.3.0 (2026-01-19)

### New Features

- feat: Add styles for aside footnotes and stack layout.
- feat: Add code annotation fragments plugin for Reveal.js.
- feat: Add line fragment indices plugin for Reveal.js.
- feat: Math alt-text filter.
- feat: Enhance card and callout components with new styling and functionality.
- feat: Add macOS-style code window support.
- feat: Enhance figure numbering with section prefixes.
- feat: Share components across formats.
- feat: Add custom UI components for Reveal.js presentations.
- feat: Enhance styling for thumbnail and featured images.
- feat: Document type dispatcher for Typst templates.
- feat: Reveal.js integration with branding and accessibility improvements (#35).
- feat: Typst format (#34).
- feat: Website project and html format.
- feat: Rework basic (S)CSS styles (#33).
- feat: Add scss theme.

### Bug Fixes

- fix: Correct logic for showing corner brackets in executive summary.
- fix: Reformat and fix reveal.js layout.
- fix: Refine empty div and paragraph hiding logic.
- fix: Outline decorations alignment and spacing.
- fix: Drop long CSS.

### Style

- style: Adjust gap in social links and add fragment list markers.
- style: Prettier formatting.
- style: Add callout colours for consistency with Typst theme.
- style: Add featured image styling for blog posts.

## 0.1.6 (2025-10-10)

### Bug Fixes

- fix: Set code block border.

### Style

- style: Move back to top button above footer.

## 0.1.5 (2025-10-10)

### Bug Fixes

- fix: Enforce about-links styling on mobile.

## 0.1.4 (2025-09-26)

### Bug Fixes

- fix: Overload code annotations gutters CSS rules.

## 0.1.3 (2025-09-26)

### Bug Fixes

- fix: Code-annotation line highlight.
- fix: Ensure code in table is properly styled.

### Documentation

- docs: Add links to Decktape PDF.

## 0.1.2 (2025-09-25)

### Bug Fixes

- fix: Inherits background when code nested in paragraphs, list items and table cells.

## 0.1.1 (2025-08-16)

### Bug Fixes

- fix: Hide title on mobile.

## 0.1.0 (2025-08-14)

### New Features

- feat: Brand files.

### Refactoring

- refactor: Rename extension directory to avid "mcanouil/mcanouil" path.
