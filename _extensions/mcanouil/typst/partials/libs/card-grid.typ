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

// Card grid component for displaying content in card layouts
// Author: Mickaël Canouil
// License: MIT

// Import utilities and colour functions
// #import "utilities.typ": has-content, is-empty
// Note: Functions from utilities.typ are available via template.typ inclusion

// ============================================================================
// Constants for card grid
// ============================================================================

#let CARD-RADIUS = 8pt
#let CARD-BORDER-WIDTH = 1pt
#let CARD-INSET = 1em
#let CARD-GAP = 1em
#let CARD-TITLE-SIZE = 1.1em
#let CARD-TITLE-WEIGHT = "semibold"

// ============================================================================
// Card rendering functions
// ============================================================================

/// Render a single card with optional title, content, and footer.
///
/// @param config Card configuration dictionary
/// @param colours Colour scheme dictionary
/// @return Content Rendered card
///
/// Configuration keys:
/// - title: Card title (optional)
/// - content: Main card content
/// - footer: Footer content (optional)
/// - colour: Card accent colour (default: muted)
/// - style: Card style - "subtle", "outlined", "filled" (default: "subtle")
#let render-card(config, colours) = {
  let card-title = config.at("title", default: none)
  let card-content = config.at("content", default: none)
  let card-footer = config.at("footer", default: none)
  let card-colour = config.at("colour", default: colours.muted)
  let card-style = config.at("style", default: "subtle")

  // Determine card styling based on style
  let (bg-colour, border-colour, title-colour) = if card-style == "filled" {
    (card-colour, card-colour.darken(10%), colours.background)
  } else if card-style == "outlined" {
    (colours.background, card-colour, colours.foreground)
  } else {
    // "subtle" style
    (get-adaptive-background(card-colour, colours), get-adaptive-border(card-colour, colours), colours.foreground)
  }

  box(
    width: 100%,
    fill: bg-colour,
    stroke: CARD-BORDER-WIDTH + border-colour,
    radius: CARD-RADIUS,
    inset: CARD-INSET,
    {
      // Title
      if card-title != none and has-content(card-title) {
        text(
          size: CARD-TITLE-SIZE,
          weight: CARD-TITLE-WEIGHT,
          fill: title-colour,
          card-title
        )
        v(0.5em)
      }

      // Content
      if card-content != none and has-content(card-content) {
        text(
          fill: if card-style == "filled" { colours.background } else { colours.foreground },
          card-content
        )
      }

      // Footer
      if card-footer != none and has-content(card-footer) {
        v(0.5em)
        line(length: 100%, stroke: 0.5pt + border-colour)
        v(0.5em)
        text(
          size: 0.9em,
          fill: if card-style == "filled" { colours.background.lighten(20%) } else { colours.muted },
          card-footer
        )
      }
    }
  )
}

/// Render a grid of cards with consistent styling.
/// Creates a responsive grid layout for displaying multiple cards.
///
/// @param cards Array of card configuration dictionaries
/// @param columns Number of columns (default: 3)
/// @param colours Colour scheme dictionary
/// @return Content Card grid layout
///
/// @usage
/// ```typst
/// #render-card-grid(
///   (
///     (title: "Feature 1", content: "Description of feature 1"),
///     (title: "Feature 2", content: "Description of feature 2", footer: "Learn more"),
///     (title: "Feature 3", content: "Description of feature 3", colour: red),
///   ),
///   columns: 3,
///   colours
/// )
/// ```
#let render-card-grid(cards, columns: 3, colours) = {
  // Create column specification
  let cols = ()
  for _ in range(columns) {
    cols.push(1fr)
  }

  grid(
    columns: cols,
    gutter: CARD-GAP,
    ..cards.map(card => render-card(card, colours))
  )
}

/// Render a feature comparison grid.
/// Specialised card grid for comparing features across different options.
///
/// @param features Array of feature dictionaries with name and options array
/// @param options Array of option names
/// @param colours Colour scheme dictionary
/// @return Content Feature comparison grid
///
/// @usage
/// ```typst
/// #render-feature-grid(
///   features: (
///     (name: "Storage", options: ("10GB", "100GB", "Unlimited")),
///     (name: "Users", options: ("1", "10", "Unlimited")),
///   ),
///   options: ("Basic", "Pro", "Enterprise"),
///   colours
/// )
/// ```
#let render-feature-grid(features, options, colours) = {
  let num-cols = options.len() + 1

  // Create table with header row and feature rows
  table(
    columns: (auto,) + (1fr,) * options.len(),
    stroke: CARD-BORDER-WIDTH + get-adaptive-border(colours.muted, colours),
    fill: (col, row) => {
      if row == 0 {
        get-adaptive-background(colours.muted, colours)
      } else if calc.rem(row, 2) == 0 {
        colours.background
      } else {
        get-adaptive-background(colours.muted, colours).lighten(50%)
      }
    },
    inset: 0.8em,
    align: (col, row) => if col == 0 { left } else { center },

    // Header row
    table.header(
      [],
      ..options.map(opt => text(weight: "semibold", opt))
    ),

    // Feature rows
    ..features.map(feature => {
      (
        text(weight: "medium", feature.name),
        ..feature.options.map(val => text(val))
      )
    }).flatten()
  )
}
