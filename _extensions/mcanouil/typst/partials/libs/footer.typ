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

// Page footer with branding
// Layout: ─────────────────────────────
//         [Author] [Page X / Y] [Website]
// Author: Mickaël Canouil
// License: MIT

// ============================================================================
// Constants for professional footer style
// ============================================================================

#let FOOTER-PROFESSIONAL-TEXT-SIZE = 9pt
#let FOOTER-PROFESSIONAL-PAGE-WEIGHT = "bold"
#let FOOTER-PROFESSIONAL-BORDER-THICKNESS = 2pt
#let FOOTER-PROFESSIONAL-PADDING-VERTICAL = 0.5cm  // Increased by 20% (15pt * 1.2)
#let FOOTER-PROFESSIONAL-PADDING-HORIZONTAL = 0cm  // Increased by 20% (30pt * 1.2)

// ============================================================================
// Footer functions
// ============================================================================

/// Create academic style page footer with flexible content
/// @param left-content Content for left section (default: none)
/// @param centre-content Content for centre section (default: page counter)
/// @param right-content Content for right section (default: none)
/// @param colours Colour dictionary
/// @return Formatted academic footer content
#let mcanouil-footer-academic(
  left-content: none,
  centre-content: none,
  right-content: none,
  colours: none,
) = {
  line(length: 100%, stroke: 0.5pt + colours.muted)
  v(0.5em)
  grid(
    columns: (1fr, auto, 1fr),
    align: (left + horizon, center + horizon, right + horizon),
    gutter: 0em,
    {
      if left-content != none {
        text(size: 8pt, fill: colours.muted)[#left-content]
      }
    },
    {
      // Default centre content: page counter
      let default-centre = if centre-content != none {
        centre-content
      } else {
        context [
          #counter(page).display("1 / 1", both: true)
        ]
      }
      text(size: 8pt, fill: colours.muted)[#default-centre]
    },
    {
      if right-content != none {
        text(size: 8pt, fill: colours.muted)[#right-content]
      }
    },
  )
}

/// Create professional style page footer
/// @param left-content Content for left section (company or author)
/// @param centre-content Content for centre section (page counter, bold)
/// @param right-content Content for right section (confidential label)
/// @param colours Colour dictionary
/// @param margin Page margins dictionary (fallback, uses page.margin when available)
/// @return Formatted professional footer content
#let mcanouil-footer-professional(
  left-content: none,
  centre-content: none,
  right-content: none,
  colours: none,
  margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2.5cm),
) = context {
  // Use current margin from state (dynamically adapts to margin changes mid-document)
  let current-margin = current-margin-state.get()
  let left-margin = current-margin.left
  let right-margin = current-margin.right
  let total-horizontal = left-margin + right-margin

  place(
    bottom + left,
    dx: -left-margin,
    dy: 0cm,
    block(
      width: 100% + total-horizontal,
      fill: colours.foreground,
      inset: (
        left: left-margin + FOOTER-PROFESSIONAL-PADDING-HORIZONTAL,
        right: right-margin + FOOTER-PROFESSIONAL-PADDING-HORIZONTAL,
        top: FOOTER-PROFESSIONAL-PADDING-VERTICAL,
        bottom: FOOTER-PROFESSIONAL-PADDING-VERTICAL,
      ),
      {
        grid(
          columns: (1fr, auto, 1fr),
          align: (left + horizon, center + horizon, right + horizon),
          gutter: 0em,
          {
            // Left: Company or author
            if left-content != none {
              text(
                size: FOOTER-PROFESSIONAL-TEXT-SIZE,
                fill: colours.background,
              )[#left-content]
            }
          },
          {
            // Centre: Bold page number
            let default-centre = if centre-content != none {
              centre-content
            } else {
              context [
                #counter(page).display("1 / 1", both: true)
              ]
            }
            text(
              size: FOOTER-PROFESSIONAL-TEXT-SIZE,
              weight: FOOTER-PROFESSIONAL-PAGE-WEIGHT,
              fill: colours.background,
            )[#default-centre]
          },
          {
            // Right: Confidential label
            if right-content != none {
              text(
                size: FOOTER-PROFESSIONAL-TEXT-SIZE,
                fill: colours.background,
              )[#right-content]
            }
          },
        )
      },
    ),
  )
}

/// Create branded page footer (dispatcher)
/// @param style Footer style ("academic" or "professional")
/// @param left-content Content for left section
/// @param centre-content Content for centre section
/// @param right-content Content for right section
/// @param colours Colour dictionary
/// @param margin Page margins dictionary
/// @return Formatted footer content based on style
#let mcanouil-footer(
  style: "academic",
  left-content: none,
  centre-content: none,
  right-content: none,
  colours: none,
  margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2.5cm),
) = {
  if style == "professional" {
    mcanouil-footer-professional(
      left-content: left-content,
      centre-content: centre-content,
      right-content: right-content,
      colours: colours,
      margin: margin,
    )
  } else {
    mcanouil-footer-academic(
      left-content: left-content,
      centre-content: centre-content,
      right-content: right-content,
      colours: colours,
    )
  }
}
