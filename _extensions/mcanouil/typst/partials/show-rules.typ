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

// Show rule functions for document styling
// Each function encapsulates styling logic for better readability
// Author: Mickaël Canouil
// License: MIT

// ============================================================================
// Show rule functions
// ============================================================================

/// Apply heading styling
/// The heading's numbering property is set directly by the Lua filter,
/// so no special section state tracking is needed.
/// @param it Heading element
/// @param colours Colour dictionary
/// @param font-headings Heading font family
/// @param section-pagebreak Whether to add breaks before level 1 headings
/// @param show-heading-underlines Whether to show underlines
/// @param heading-weight Heading font weight
/// @param heading-style Heading font style
/// @param heading-colour Heading colour
/// @param heading-line-height Heading line height
/// @return Styled heading block
#let apply-heading-style(
  it,
  colours,
  font-headings,
  section-pagebreak,
  show-heading-underlines,
  heading-weight: none,
  heading-style: none,
  heading-colour: none,
  heading-line-height: none,
) = {
  let style = get-heading-style(
    it.level,
    colours,
    heading-weight: heading-weight,
    heading-style: heading-style,
    heading-colour: heading-colour,
    heading-line-height: heading-line-height,
  )
  set text(
    font: font-headings,
    size: style.size,
    weight: style.weight,
    style: style.style,
    fill: style.fill,
  )

  // Configurable break before level 1 headings
  // Uses colbreak for multi-column layouts, pagebreak for single-column
  if it.level == 1 and section-pagebreak {
    conditional-break()
  }

  block(
    above: if it.level == 1 { 1.5em } else { 1.2em },
    below: 0em,
    breakable: false, // Prevent heading from breaking across pages
    {
      // Display numbering if present (set directly by Lua filter)
      if it.numbering != none {
        context {
          let h-counter = counter(heading).at(here())
          if h-counter.len() > 0 {
            // Use the heading's numbering directly (includes prefix if applicable)
            if type(it.numbering) == function {
              (it.numbering)(..h-counter)
            } else {
              numbering(it.numbering, ..h-counter)
            }
            h(0.5em)
          }
        }
      }
      it.body
      linebreak()
      v(-0.8em)
      if show-heading-underlines {
        heading-underline(colours, level: it.level)
      }
      v(0.5em)

      // Orphan prevention: keep at least 2 lines with heading
      v(2.4em, weak: true)
    },
  )
}

/// Apply link styling with optional underline
/// @param it Link element
/// @param colours Colour dictionary
/// @param link-colour Optional custom link colour
/// @param link-underline Whether to underline external links
/// @param link-underline-opacity Underline opacity percentage
/// @return Styled link
#let apply-link-style(it, colours, link-colour, link-underline, link-underline-opacity) = {
  set text(fill: if link-colour != none { link-colour } else { colours.foreground })
  // Only apply underline to external links (URLs), not internal document links
  if type(it.dest) == str and link-underline {
    underline(
      stroke: 1pt + colours.foreground.transparentize(100% - link-underline-opacity),
      offset: 2pt,
      it,
    )
  } else {
    it
  }
}

/// Apply code block styling with optional page breaks
/// @param it Code block element
/// @param colours Colour dictionary
/// @param breakable-settings Breakable configuration
/// @return Styled code block
#let apply-code-block-style(it, colours, breakable-settings) = {
  let code-block = block(
    width: 100%,
    fill: colour-mix(colours, 95%),
    inset: 8pt,
    radius: 4pt,
    stroke: 1pt + colour-mix(colours, 50%),
    it,
  )

  if breakable-settings.code == auto {
    code-block
  } else {
    block(breakable: breakable-settings.code, code-block)
  }
}

/// Apply inline code styling with brand-mode aware background
/// @param it Inline code element
/// @param colours Colour dictionary
/// @return Styled inline code
#let apply-inline-code-style(it, colours) = {
  // Use regular colour-mix for subtle background that's just slightly different
  // This gives us a subtle tint without inverting contrast
  box(
    fill: colour-mix(colours, 90%),
    inset: (x: 3pt, y: 0pt),
    outset: (y: 3pt),
    radius: 2pt,
    text(fill: colours.foreground, it),
  )
}

/// Apply blockquote styling with decorative quotes
/// @param it Quote element
/// @param colours Colour dictionary
/// @param quote-width Quote block width
/// @param quote-align Quote block alignment
/// @param breakable-settings Breakable configuration
/// @return Styled blockquote
#let apply-quote-style(it, colours, quote-width, quote-align, breakable-settings) = {
  let quote-block = align(quote-align)[
    #block(
      above: 0.5em,
      below: 0.5em,
      width: quote-width,
      spacing: 0em,
      fill: colour-mix(colours, 95%),
      inset: (left: 24pt, right: 24pt, top: 16pt, bottom: 16pt),
      radius: 5pt,
      stroke: (left: 3pt + colours.foreground),
      breakable: breakable-settings.quote,
      {
        // Opening quotation mark - top left
        place(
          top + left,
          dx: -18pt,
          dy: -10pt,
          text(size: 3em, fill: colours.foreground.transparentize(70%), font: "Georgia", ["]),
        )
        it.body
        // Closing quotation mark - bottom right
        place(
          bottom + right,
          dx: 18pt,
          dy: 24pt,
          text(size: 3em, fill: colours.foreground.transparentize(70%), font: "Georgia", ["]),
        )
      },
    )
  ]

  quote-block
}

/// Apply definition list styling
/// @param it Terms element
/// @param colours Colour dictionary
/// @param breakable-settings Breakable configuration
/// @return Styled definition list
#let apply-terms-style(it, colours, breakable-settings) = {
  let terms-content = it
    .children
    .map(child => [
      #block(below: 0.2em)[#strong[#child.term]]
      #block(
        above: 0em,
        fill: colour-mix(colours, 95%),
        inset: (left: 1.5em, right: 0.5em, top: 0.3em, bottom: 0.3em),
        radius: 3pt,
      )[#child.description]
    ])
    .join()

  if breakable-settings.terms == auto {
    terms-content
  } else {
    block(breakable: breakable-settings.terms, terms-content)
  }
}

/// Apply table styling with optional page breaks
/// @param it Table element
/// @param breakable-settings Breakable configuration
/// @return Styled table
#let apply-table-style(it, breakable-settings) = {
  if breakable-settings.table == auto {
    it
  } else {
    block(breakable: breakable-settings.table, it)
  }
}

/// Apply figure styling with image borders
/// @param it Figure element
/// @param colours Colour dictionary
/// @return Styled figure
#let apply-figure-style(it, colours) = {
  // Check if content is already wrapped (avoid infinite recursion)
  let body-repr = repr(it.body)

  // Check if this is an image figure (kind is image or body contains image)
  let is-image = it.kind == image or body-repr.contains("image(")

  // Check if this is a super figure containing subfigures
  let is-super-figure = body-repr.contains("figure(")

  // Check if already styled (featured image or border already applied)
  // Look for the border wrapper's characteristic "clip: true" which is unique to image-border
  let is-styled = (
    body-repr.contains("mcanouil-featured-image")
      or (body-repr.contains("clip: true") and body-repr.contains("stroke:"))
  )

  if is-image and not is-styled and not is-super-figure {
    // Apply border using a nested show rule instead of creating a new figure
    // This automatically preserves all figure properties including labels
    // Skip border for super figures (they contain subfigures which get borders instead)
    show image: img => image-border(img, colours)
    it
  } else {
    // Pass through - already styled, not an image, super figure, or table/other content
    it
  }
}

/// Apply callout styling with branded design
/// @param it Callout figure element
/// @param colours Colour dictionary
/// @param breakable-settings Breakable configuration
/// @return Styled callout
#let apply-callout-style(it, colours, breakable-settings) = {
  // Extract callout type from kind (e.g., "quarto-callout-note" -> "note")
  let callout-type = it.kind.replace("quarto-callout-", "")

  // Get the appropriate colour for this callout type
  let colour = callout-colour(callout-type)

  // Extract title from caption if present
  let title-content = if it.caption != none {
    it.caption.body
  } else {
    none
  }

  // Render the styled callout
  let styled-callout = render-callout(
    callout-type,
    colour,
    title-content,
    it.body,
    colours,
  )

  // Apply breakable setting
  if breakable-settings.callout == false {
    block(breakable: false, styled-callout)
  } else {
    styled-callout
  }
}
