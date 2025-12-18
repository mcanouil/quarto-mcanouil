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

// Page header with branding
// Layout: [Logo] ... [DOCUMENT TITLE]
//         ─────────────────────────────
// Author: Mickaël Canouil
// License: MIT

// ============================================================================
// Constants for professional header style
// ============================================================================

#let HEADER-PROFESSIONAL-TITLE-SIZE = 2em
#let HEADER-PROFESSIONAL-SUBTITLE-SIZE = 1.25em
#let HEADER-PROFESSIONAL-TITLE-WEIGHT = 600
#let HEADER-PROFESSIONAL-SUBTITLE-OPACITY = 90%
#let HEADER-PROFESSIONAL-LOGO-HEIGHT = 100%
#let HEADER-PROFESSIONAL-BORDER-THICKNESS = 2pt
#let HEADER-PROFESSIONAL-PADDING-VERTICAL = 0.5cm  // Increased by 20% (20pt * 1.2)
#let HEADER-PROFESSIONAL-PADDING-HORIZONTAL = 0cm  // Increased by 20% (30pt * 1.2)

// ============================================================================
// Header functions
// ============================================================================

/// Create academic style page header
/// @param title Document title (displayed in uppercase on right)
/// @param logo Path to logo image file
/// @param logo-alt Alternative text for logo image
/// @param colours Colour dictionary
/// @param show-logo Whether to display the logo
/// @return Formatted academic header content
#let mcanouil-header-academic(
  title: none,
  logo: none,
  logo-alt: none,
  colours: none,
  show-logo: true,
) = {
  v(0.5em)
  grid(
    rows: 2.5cm,
    columns: (1fr, auto),
    align: (left + horizon, right + horizon),
    gutter: 0em,
    {
      if show-logo and logo != none {
        image(logo, height: 1.5em, alt: if logo-alt != none { logo-alt } else { "" })
      }
    },
    {
      if title != none {
        text(
          size: 9pt,
          fill: colours.muted,
          weight: "medium",
          upper(title),
        )
      }
    },
  )
  line(length: 100%, stroke: 0.5pt + colours.muted)
}

/// Create professional style page header
/// @param title Document title (displayed on left, stacked with subtitle)
/// @param subtitle Document subtitle (displayed below title, optional)
/// @param logo Path to logo image file
/// @param logo-alt Alternative text for logo image
/// @param colours Colour dictionary
/// @param show-logo Whether to display the logo
/// @param margin Page margins dictionary (fallback, uses page.margin when available)
/// @return Formatted professional header content
#let mcanouil-header-professional(
  title: none,
  subtitle: none,
  logo: none,
  logo-alt: none,
  colours: none,
  show-logo: true,
  margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2.5cm),
) = context {
  // Use current margin from state (dynamically adapts to margin changes mid-document)
  let current-margin = current-margin-state.get()
  let left-margin = current-margin.left
  let right-margin = current-margin.right
  let total-horizontal = left-margin + right-margin
  let top-margin = current-margin.top

  place(
    top + left,
    dx: -left-margin,
    dy: 0cm,
    block(
      width: 100% + total-horizontal,
      fill: colours.foreground,
      inset: (
        left: left-margin + HEADER-PROFESSIONAL-PADDING-HORIZONTAL,
        right: right-margin + HEADER-PROFESSIONAL-PADDING-HORIZONTAL,
        top: HEADER-PROFESSIONAL-PADDING-VERTICAL,
        bottom: HEADER-PROFESSIONAL-PADDING-VERTICAL,
      ),
      {
        grid(
          columns: (1fr, auto),
          align: (left + horizon, right + horizon),
          column-gutter: 3em,
          {
            // Left: Title and subtitle stacked
            stack(
              dir: ttb,
              spacing: 0.5em,
              {
                if title != none {
                  text(
                    size: HEADER-PROFESSIONAL-TITLE-SIZE,
                    weight: HEADER-PROFESSIONAL-TITLE-WEIGHT,
                    fill: colours.background,
                    title,
                  )
                }
              },
              {
                if subtitle != none {
                  text(
                    size: HEADER-PROFESSIONAL-SUBTITLE-SIZE,
                    fill: colours.background.transparentize(
                      100% - HEADER-PROFESSIONAL-SUBTITLE-OPACITY,
                    ),
                    subtitle,
                  )
                }
              },
            )
          },
          {
            // Right: Logo with constrained height
            if show-logo and logo != none {
              image(
                logo,
                fit: "contain",
                height: HEADER-PROFESSIONAL-LOGO-HEIGHT,
                alt: if logo-alt != none { logo-alt } else { "" },
              )
            }
          },
        )
      },
    ),
  )
  // Spacing to account for the banner height (padding + logo height)
  v(HEADER-PROFESSIONAL-PADDING-VERTICAL * 2 + HEADER-PROFESSIONAL-LOGO-HEIGHT)
}

/// Create branded page header (dispatcher)
/// @param style Header style ("academic" or "professional")
/// @param title Document title
/// @param subtitle Document subtitle (used in professional style)
/// @param logo Path to logo image file
/// @param logo-alt Alternative text for logo image
/// @param colours Colour dictionary
/// @param show-logo Whether to display the logo
/// @param margin Page margins dictionary
/// @return Formatted header content based on style
#let mcanouil-header(
  style: "academic",
  title: none,
  subtitle: none,
  logo: none,
  logo-alt: none,
  colours: none,
  show-logo: true,
  margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2.5cm),
) = {
  if style == "professional" {
    mcanouil-header-professional(
      title: title,
      subtitle: subtitle,
      logo: logo,
      logo-alt: logo-alt,
      colours: colours,
      show-logo: show-logo,
      margin: margin,
    )
  } else {
    mcanouil-header-academic(
      title: title,
      logo: logo,
      logo-alt: logo-alt,
      colours: colours,
      show-logo: show-logo,
    )
  }
}
