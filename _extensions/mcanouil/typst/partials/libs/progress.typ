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

/// Progress bar component for visualising completion and proportions
/// Author: Mickaël Canouil
/// License: MIT

/// Render a progress bar
/// @param value Progress value (0-100)
/// @param label Optional label text displayed above the bar
/// @param colour Colour type or custom colour (default: "info")
/// @param height Bar height (default: 1.5em)
/// @param show-percentage Whether to show percentage label (default: true)
/// @param colours Colour dictionary from brand mode
/// @return Formatted progress bar
#let render-progress(
  value: 0,
  label: none,
  colour: "info",
  height: 1.5em,
  show-percentage: true,
  colours: none,
) = {
  if colours == none {
    panic("colours parameter is required for render-progress")
  }

  // Ensure value is between 0 and 100
  let progress-value = calc.max(0, calc.min(100, value))
  let progress-ratio = progress-value / 100

  // Get progress bar colour using centralised semantic-colour function
  let bar-colour = semantic-colour(colour, colours)

  // Wrap entire progress bar in non-breakable block
  block(
    breakable: false,
    above: 1em,
    below: 1em,
    {
      // Label above bar (if provided)
      if label != none {
        text(size: 0.95em, weight: "semibold", fill: colours.foreground)[#label]
        v(0.3em)
      }

      // Progress bar container
      block(
        width: 100%,
        height: height,
        fill: colour-mix-adaptive(colours, 92%),
        stroke: 1pt + colour-mix-adaptive(colours, 80%),
        radius: calc.min(height / 2, 0.5em),
        clip: true,
      )[
        // Filled portion
        #place(
          left,
          box(
            width: progress-ratio * 100%,
            height: 100%,
            fill: bar-colour,
          )
        )

        // Percentage label overlay (centred)
        #if show-percentage {
          place(
            center + horizon,
            box(
              fill: colours.background.transparentize(20%),
              inset: (x: 0.5em, y: 0.2em),
              radius: 0.3em,
              text(
                size: 0.85em,
                weight: "bold",
                fill: colours.foreground
              )[#progress-value%]
            )
          )
        }
      ]
    }
  )
}
