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

// Typography configuration
// Matches the website's Alegreya Sans font family
// Author: Mickaël Canouil
// License: MIT

// ============================================================================
// Font configuration
// ============================================================================

/// Font families for different text types with fallbacks
#let fonts = (
  body: ("Alegreya Sans", "Helvetica Neue", "Arial", "sans-serif"),
  headings: ("Alegreya Sans", "Helvetica Neue", "Arial", "sans-serif"),
  mono: ("Fira Code", "Menlo", "Monaco", "Courier New", "monospace"),
)

// ============================================================================
// Heading configuration
// ============================================================================

/// Heading sizes for levels 1-6
#let heading-sizes = (24pt, 18pt, 14pt, 12pt, 11pt, 11pt)

/// Heading font weights for levels 1-6
#let heading-weights = ("bold", "bold", "semibold", "semibold", "medium", "medium")

/// Get heading style for a given level
/// @param level Heading level (1-6)
/// @param colours Colour dictionary
/// @param heading-weight Optional custom font weight
/// @param heading-style Optional custom font style
/// @param heading-colour Optional custom colour
/// @param heading-line-height Optional custom line height
/// @return Dictionary with font, size, weight, style, and fill properties
#let get-heading-style(
  level,
  colours,
  heading-weight: none,
  heading-style: none,
  heading-colour: none,
  heading-line-height: none,
) = {
  let idx = calc.min(level - 1, 5)
  (
    font: fonts.headings,
    size: heading-sizes.at(idx),
    weight: if heading-weight != none { heading-weight } else { heading-weights.at(idx) },
    style: if heading-style != none { heading-style } else { "normal" },
    fill: if heading-colour != none { heading-colour } else { colours.foreground },
  )
}

// ============================================================================
// Paragraph configuration
// ============================================================================

/// Default paragraph settings
#let paragraph-settings = (
  justify: true,
  leading: 0.75em, // Increased from 0.65em for better readability
  first-line-indent: 0em,
)
