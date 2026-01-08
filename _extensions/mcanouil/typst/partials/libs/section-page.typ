// MIT License
//
// Copyright (c) 2026 Mickaël Canouil
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// Section page rendering for level-1 headings
// Creates dedicated pages with banner and subsection outline
// Author: Mickaël Canouil
// License: MIT

// ============================================================================
// Constants for section page layout
// ============================================================================

/// Banner position from top of page (20%)
#let SECTION-PAGE-BANNER-TOP = 20%

/// Banner width as percentage of page width (75% from left)
#let SECTION-PAGE-BANNER-WIDTH = 75%

/// Banner internal padding
#let SECTION-PAGE-BANNER-PADDING = 1.5em

/// Banner title font size
#let SECTION-PAGE-BANNER-TITLE-SIZE = 24pt

/// Outline indent per level
#let SECTION-PAGE-OUTLINE-INDENT = 1em

/// Gap between columns in two-column outline
#let SECTION-PAGE-OUTLINE-COLUMN-GAP = 2em

/// Minimum entries before considering two columns
#let SECTION-PAGE-OUTLINE-MIN-FOR-COLUMNS = 4

/// Outline box internal padding
#let SECTION-PAGE-OUTLINE-INSET = 1.5em

/// Corner bracket size for outline decoration
#let SECTION-PAGE-OUTLINE-BRACKET-SIZE = 12pt

/// Corner bracket thickness for outline decoration
#let SECTION-PAGE-OUTLINE-BRACKET-THICKNESS = 2pt

/// Bracket curve factor (matches callout style)
#let SECTION-PAGE-OUTLINE-BRACKET-CURVE = 0.6

/// Bracket quad factor (matches callout style)
#let SECTION-PAGE-OUTLINE-BRACKET-QUAD = 0.4

// Note: section-page-state is defined in utilities.typ and used by margin-section.typ
// to skip rendering on section pages

// ============================================================================
// Section page functions
// ============================================================================

/// Render the section banner with title
/// @param heading The heading element
/// @param colours Colour dictionary
/// @param font-headings Heading font family
/// @param margin Page margins
/// @return Content for the banner
#let section-page-banner(
  heading,
  colours,
  font-headings,
  margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2.5cm),
) = context {
  let page-w = page.width
  let page-h = page.height
  let banner-top = page-h * SECTION-PAGE-BANNER-TOP - margin.top

  // Build title content with optional numbering
  let title-content = {
    if heading.numbering != none {
      let h-counter = counter(heading.func()).at(heading.location())
      if h-counter.len() > 0 {
        if type(heading.numbering) == function {
          (heading.numbering)(..h-counter)
        } else {
          numbering(heading.numbering, ..h-counter)
        }
        h(0.5em)
      }
    }
    heading.body
  }

  // Inverted underline (background to foreground gradient, since banner has inverted colours)
  let inverted-underline = {
    set par(first-line-indent: 0pt)
    stack(
      dir: ttb,
      spacing: 0pt,
      // Gradient box (inverted: background -> foreground)
      box(
        width: HEADING-UNDERLINE-WIDTHS.at(0),
        height: HEADING-UNDERLINE-HEIGHTS.at(0),
        fill: gradient.linear(
          colours.background,
          colours.foreground,
          angle: 0deg,
        ),
      ),
      // Full-width line (using background colour instead of foreground)
      line(
        length: 100%,
        stroke: HEADING-UNDERLINE-THICKNESS + colours.background.transparentize(HEADING-UNDERLINE-OPACITY),
      ),
    )
  }

  // Position banner from left edge to 75% of page width
  place(
    top + left,
    dx: -margin.left,
    dy: banner-top,
    box(
      width: page-w * SECTION-PAGE-BANNER-WIDTH,
      fill: colours.foreground,
      inset: SECTION-PAGE-BANNER-PADDING,
      {
        set text(
          font: font-headings,
          size: SECTION-PAGE-BANNER-TITLE-SIZE,
          weight: "bold",
          fill: colours.background,
        )
        title-content
        linebreak()
        v(-0.8em)
        inverted-underline
      },
    ),
  )
}

/// Render the subsection outline for a section
/// Positioned at bottom-right with optional two-column layout and corner brackets
/// @param heading The level-1 heading element
/// @param colours Colour dictionary
/// @param font-headings Heading font family
/// @param toc-depth Maximum heading depth to include
/// @param margin Page margins
/// @return Content for the outline
#let section-page-outline(
  heading,
  colours,
  font-headings,
  toc-depth: 3,
  margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2.5cm),
) = context {
  let page-w = page.width
  let page-h = page.height

  // Calculate available space for outline
  // Banner ends around 35% from top (20% position + banner height)
  let outline-top-boundary = page-h * 0.35
  let available-height = page-h - outline-top-boundary - margin.bottom

  // Query all headings in the document
  let all-headings = query(heading.func())

  // Find current heading's position
  let my-loc = heading.location()
  let my-idx = all-headings.position(h => h.location() == my-loc)

  if my-idx == none {
    return
  }

  // Find next level-1 heading (end boundary)
  let rest = all-headings.slice(my-idx + 1)
  let next-h1-idx = rest.position(h => h.level == 1)
  let end-idx = if next-h1-idx != none { my-idx + 1 + next-h1-idx } else { all-headings.len() }

  // Get subsections (level 2 to toc-depth)
  let subsections = all-headings.slice(my-idx + 1, end-idx).filter(h => h.level > 1 and h.level <= toc-depth)

  if subsections.len() == 0 {
    return
  }

  // Build outline entries as content blocks
  let entries = subsections.map(h => {
    let indent = (h.level - 2) * SECTION-PAGE-OUTLINE-INDENT
    let entry-content = {
      if h.numbering != none {
        let h-counter = counter(h.func()).at(h.location())
        if h-counter.len() > 0 {
          if type(h.numbering) == function {
            (h.numbering)(..h-counter)
          } else {
            numbering(h.numbering, ..h-counter)
          }
          box(width: 0.5em)
        }
      }
      link(h.location(), h.body)
    }
    block(
      above: 0.5em,
      below: 0em,
      inset: (left: indent),
      entry-content,
    )
  })

  // Create single-column content for measurement
  let single-column-content = {
    set text(font: font-headings, fill: colours.foreground)
    entries.join()
  }

  // Measure the content height
  let content-size = measure(single-column-content)

  // Determine if we need two columns
  let use-two-columns = content-size.height > available-height and subsections.len() >= SECTION-PAGE-OUTLINE-MIN-FOR-COLUMNS

  // Build inner content (entries with optional two-column layout)
  let inner-content = {
    set text(font: font-headings, fill: colours.foreground)
    if use-two-columns {
      // Split entries into two columns
      let mid = calc.ceil(entries.len() / 2)
      let col1 = entries.slice(0, mid)
      let col2 = entries.slice(mid)

      // Calculate column width (half of body width minus gap and insets)
      let body-width = page-w - margin.left - margin.right - 2 * SECTION-PAGE-OUTLINE-INSET
      let col-width = (body-width - SECTION-PAGE-OUTLINE-COLUMN-GAP) / 2

      grid(
        columns: (col-width, col-width),
        column-gutter: SECTION-PAGE-OUTLINE-COLUMN-GAP,
        align: (left, left),
        col1.join(),
        col2.join(),
      )
    } else {
      entries.join()
    }
  }

  // Build rounded corner bracket (same style as callouts)
  let bracket = curve(
    stroke: (
      paint: colours.foreground,
      thickness: SECTION-PAGE-OUTLINE-BRACKET-THICKNESS,
      cap: "round",
      join: "round",
    ),
    curve.line((0pt, 0pt)),
    curve.line((SECTION-PAGE-OUTLINE-BRACKET-SIZE * SECTION-PAGE-OUTLINE-BRACKET-CURVE, 0pt)),
    curve.quad(
      (SECTION-PAGE-OUTLINE-BRACKET-SIZE, 0pt),
      (SECTION-PAGE-OUTLINE-BRACKET-SIZE, -SECTION-PAGE-OUTLINE-BRACKET-SIZE * SECTION-PAGE-OUTLINE-BRACKET-QUAD),
    ),
    curve.line((SECTION-PAGE-OUTLINE-BRACKET-SIZE, -SECTION-PAGE-OUTLINE-BRACKET-SIZE)),
  )

  let inset = SECTION-PAGE-OUTLINE-INSET

  // Build final content with corner brackets at all four corners
  let final-content = box(
    inset: inset,
    {
      // Top-right corner bracket (original orientation)
      place(bottom + right, dx: inset, dy: inset, bracket)
      // Bottom-left corner bracket (rotated 180deg)
      place(top + left, dx: -inset, dy: -inset, rotate(180deg, bracket))
      // Top-left corner bracket (rotated 90deg)
      place(bottom + left, dx: -inset, dy: inset, rotate(90deg, bracket))
      // Bottom-right corner bracket (rotated 270deg)
      place(top + right, dx: inset, dy: -inset, rotate(270deg, bracket))

      // Ensure content is left-aligned within the box
      align(left, inner-content)
    },
  )

  // Position outline at bottom-right
  place(
    bottom + right,
    final-content,
  )
}

/// Render a complete section page for level-1 headings
/// @param it The heading element
/// @param colours Colour dictionary
/// @param font-headings Heading font family
/// @param margin Page margins (symmetric for section page)
/// @param cols Number of columns to restore after section page
/// @param toc-depth Maximum heading depth for outline
/// @param heading-weight Optional heading font weight
/// @param heading-style Optional heading font style
/// @param heading-colour Optional heading colour
/// @param heading-line-height Optional heading line height
/// @return Content for the section page
#let render-section-page(
  it,
  colours,
  font-headings,
  margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2.5cm),
  cols: 1,
  toc-depth: 3,
  heading-weight: "bold",
  heading-style: "normal",
  heading-colour: none,
  heading-line-height: none,
) = {
  // Use symmetric margins for section page
  let symmetric-margin = (
    top: margin.top,
    bottom: margin.bottom,
    left: margin.left,
    right: margin.left, // Use left margin for right to ensure symmetry
  )

  // Page break before section page
  pagebreak(weak: true)

  // Mark as section page (suppresses margin section)
  section-page-state.update(true)

  // Section page content with single column and symmetric margins
  {
    set page(margin: symmetric-margin, columns: 1)

    // Render banner
    section-page-banner(it, colours, font-headings, margin: symmetric-margin)

    // Render subsection outline
    section-page-outline(it, colours, font-headings, toc-depth: toc-depth, margin: symmetric-margin)

    // Hidden heading for TOC and PDF bookmarks
    // Use display: none style but keep it in the document structure
    hide[
      #set text(size: 0pt)
      #it
    ]
  }

  // Page break after section page
  pagebreak(weak: true)

  // Reset section page state
  section-page-state.update(false)

  // Restore column layout
  {
    set page(columns: cols)
  }
}
