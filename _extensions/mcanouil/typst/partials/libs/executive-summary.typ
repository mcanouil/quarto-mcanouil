// MIT License
//
// Copyright (c) 2025 Mickaël Canouil
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

/// Executive summary component for prominent document summaries
/// Provides more prominent styling than regular abstracts
/// Author: Mickaël Canouil
/// License: MIT

/// Render an executive summary block
/// @param content Summary content to display
/// @param title Optional custom title (default: "Executive Summary")
/// @param colours Colour dictionary from brand mode
/// @param show-corner-brackets Whether to include corner bracket decoration (default: true)
/// @return Formatted executive summary block
#let render-executive-summary(
  content,
  title: "Executive Summary",
  colours: none,
  show-corner-brackets: true,
) = {
  if colours == none {
    panic("colours parameter is required for render-executive-summary")
  }

  v(2em)

  // Detect dark mode
  let fg-components = colours.foreground.components()
  let is-dark-mode = fg-components.at(0, default: 0%) > 50%

  // Adjust background and border colours for dark mode
  let bg-fill = if is-dark-mode {
    // Dark mode: slightly lighter than background
    color.mix(
      (colours.background, 85%),
      (colours.foreground, 15%),
      space: rgb,
    )
  } else {
    // Light mode: very light grey
    colour-mix-adaptive(colours, 96%)
  }

  let border-fill = if is-dark-mode {
    // Dark mode: more subtle border
    color.mix(
      (colours.background, 70%),
      (colours.foreground, 30%),
      space: rgb,
    )
  } else {
    // Light mode: subtle grey border
    colour-mix-adaptive(colours, 85%)
  }

  let summary-content = block(
    width: 100%,
    fill: bg-fill,
    stroke: (
      left: 6pt + colours.muted,
      top: 2pt + border-fill,
      right: 2pt + border-fill,
      bottom: 2pt + border-fill,
    ),
    inset: 2em,
    radius: 6pt,
    breakable: false,
  )[
    // Title
    #if title != none and title != "" {
      align(center)[
        #text(
          size: 1.3em,
          weight: "bold",
          fill: colours.foreground,
        )[#title-case(title)]
      ]
      v(1em)
      // Decorative line under title
      align(center)[
        #line(
          length: 40%,
          stroke: 2pt + colours.muted,
        )
      ]
      v(1em)
    }

    // Content
    // Disable TOC inclusion and numbering for headings inside executive summary
    #show heading: it => {
      set heading(outlined: false, numbering: none)
      it
    }
    #content
  ]

  // Apply corner brackets if enabled
  if show-corner-brackets {
    corner-brackets(summary-content, colours, size: 1.2em, thickness: 3pt, inset: 1.5em)
  } else {
    summary-content
  }

  v(2em)
}
