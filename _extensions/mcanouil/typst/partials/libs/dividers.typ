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

// Divider and decorative separator components
// Provides visual separation between sections without headings
// Author: Mickaël Canouil
// License: MIT

// ============================================================================
// Divider rendering
// ============================================================================

/// Render a divider with optional label and various styles
/// @param style Divider style ("solid", "dashed", "dotted", "ornamental", "gradient")
/// @param label Optional label text to display in centre of divider
/// @param thickness Line thickness (default: 1pt)
/// @param colours Colour dictionary
/// @param width Line width as percentage (default: 50%)
/// @return Formatted divider
#let render-divider(
  style: "solid",
  label: none,
  thickness: 1pt,
  colours: none,
  width: 50%,
) = {
  if colours == none {
    panic("colours parameter is required for render-divider")
  }

  // Helper to create a horizontal line with optional dash style
  let make-line(dash: none) = {
    let stroke-style = if dash != none {
      (paint: colours.muted, thickness: thickness, dash: dash)
    } else {
      thickness + colours.muted
    }
    line(length: 100%, stroke: stroke-style)
  }

  // Helper for grid-based divider with centre element
  let centred-divider(centre-content, container-width: 100%) = {
    align(center)[
      #box(width: container-width)[
        #grid(
          columns: (1fr, auto, 1fr),
          column-gutter: 0.5em,
          align: (right, center, left),
          place(horizon, make-line()), centre-content, place(horizon, make-line()),
        )
      ]
    ]
  }

  v(1em)

  if label != none {
    // Divider with centred label
    centred-divider(text(size: 0.9em, fill: colours.muted, style: "italic")[#label])
  } else if style == "solid" or style == "dashed" or style == "dotted" {
    // Simple line styles
    let dash = if style == "dashed" { "dashed" } else if style == "dotted" { "dotted" } else { none }
    align(center, block(width: width, make-line(dash: dash)))
  } else if style == "gradient" {
    // Gradient effect using multiple lines with varying opacity
    align(center)[
      #block(width: width)[
        #stack(
          dir: ltr,
          spacing: 0pt,
          ..for i in range(20) {
            let opacity-val = if i < 10 { (i + 1) * 10% } else { (20 - i) * 10% }
            (
              line(
                length: 5%,
                stroke: (paint: colours.muted.transparentize(100% - opacity-val), thickness: thickness),
              ),
            )
          },
        )
      ]
    ]
  } else if style == "ornamental" {
    // Ornamental divider with decorative diamond
    centred-divider(sym.diamond.filled, container-width: width)
  } else {
    // Fallback to solid
    align(center, block(width: width, make-line()))
  }

  v(1em)
}
