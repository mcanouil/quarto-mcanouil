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

// Timeline component for displaying chronological events
// Author: Mickaël Canouil
// License: MIT

// Import utilities and colour functions
// #import "utilities.typ": has-content, is-empty
// Note: Functions from utilities.typ are available via template.typ inclusion

// ============================================================================
// Constants for timeline
// ============================================================================

#let TIMELINE-LINE-WIDTH = 2pt
#let TIMELINE-MARKER-RADIUS = 6pt
#let TIMELINE-SPACING = 1.5em
#let TIMELINE-DATE-WIDTH = 6em
#let TIMELINE-GAP = 1em
#let TIMELINE-CONTENT-INSET = 0.5em

// ============================================================================
// Timeline rendering functions
// ============================================================================

/// Render a vertical timeline with events.
/// Creates a professional vertical timeline with dates, titles, and descriptions.
/// Events are displayed chronologically with visual markers and a continuous connecting line.
///
/// @param events Array of event dictionaries with keys: date, title, description (optional)
/// @param colours Colour scheme dictionary
/// @param marker-colour Optional custom marker colour (default: uses foreground colour)
/// @return Content Timeline visualisation
///
/// @usage
/// ```typst
/// #render-timeline(
///   (
///     (date: "2024", title: "Project Launch", description: "Started the project"),
///     (date: "2025", title: "First Release", description: "Released version 1.0"),
///   ),
///   colours
/// )
/// ```
#let render-timeline(events, colours, marker-colour: none) = {
  // Determine marker colour
  let marker-col = if marker-colour != none {
    marker-colour
  } else {
    colours.foreground
  }

  // Line colour is more muted
  let line-col = colours.muted

  // Build all events in a single table structure for continuous line
  table(
    columns: (TIMELINE-DATE-WIDTH, auto, 1fr),
    column-gutter: TIMELINE-GAP,
    row-gutter: TIMELINE-SPACING,
    align: (right + top, center + top, left + top),
    stroke: none,
    inset: 0pt,

    ..for (index, event) in events.enumerate() {
      let is-first = index == 0
      let is-last = index == events.len() - 1

      // Extract event data
      let event-date = event.at("date", default: "")
      let event-title = event.at("title", default: "")
      let event-description = event.at("description", default: none)
      let has-description = event-description != none and has-content(event-description)

      (
        // Date column
        text(
          size: 0.9em,
          fill: colours.muted,
          weight: "semibold",
          event-date,
        ),
        // Marker and line column
        {
          // Create a container for the marker with line extending through
          block(
            width: TIMELINE-MARKER-RADIUS * 2,
            {
              // Draw connecting line from above FIRST (bottom layer)
              if not is-first {
                place(
                  center + top,
                  dy: -TIMELINE-SPACING,
                  rect(
                    width: TIMELINE-LINE-WIDTH,
                    height: TIMELINE-SPACING,
                    fill: line-col,
                    stroke: none,
                  ),
                )
              }

              // Draw connecting line to below SECOND (middle layer, before marker)
              if not is-last {
                place(
                  center + top,
                  dy: TIMELINE-MARKER-RADIUS,
                  rect(
                    width: TIMELINE-LINE-WIDTH,
                    height: TIMELINE-SPACING + TIMELINE-MARKER-RADIUS + 3em,
                    fill: line-col,
                    stroke: none,
                  ),
                )
              }

              // Draw marker circle LAST (top layer - appears on top of all lines)
              place(
                center + top,
                circle(
                  radius: TIMELINE-MARKER-RADIUS,
                  fill: marker-col,
                  stroke: TIMELINE-LINE-WIDTH + colours.background,
                ),
              )

              // Reserve space for marker
              v(TIMELINE-MARKER-RADIUS * 2)
            },
          )
        },
        // Content column
        {
          // Title
          text(
            weight: "semibold",
            size: 1em,
            fill: colours.foreground,
            event-title,
          )

          // Description (if provided)
          if has-description {
            v(TIMELINE-CONTENT-INSET)
            text(
              size: 0.9em,
              fill: colours.foreground,
              event-description,
            )
          }
        },
      )
    }.flatten()
  )
}

/// Render a horizontal timeline with events.
/// Creates a horizontal timeline layout suitable for smaller numbers of events.
///
/// @param events Array of event dictionaries with keys: date, title
/// @param colours Colour scheme dictionary
/// @param marker-colour Optional custom marker colour
/// @return Content Horizontal timeline visualisation
#let render-horizontal-timeline(events, colours, marker-colour: none) = {
  // Determine marker colour
  let marker-col = if marker-colour != none {
    marker-colour
  } else {
    colours.foreground
  }

  let line-col = colours.muted
  let num-events = events.len()

  // Create columns for events
  let columns = ()
  for i in range(num-events) {
    columns.push(1fr)
    if i < num-events - 1 {
      columns.push(auto)
    }
  }

  grid(
    columns: columns,
    column-gutter: 0.5em,
    align: center + top,

    ..for (index, event) in events.enumerate() {
      let event-date = event.at("date", default: "")
      let event-title = event.at("title", default: "")

      let items = (
        {
          // Marker
          circle(
            radius: TIMELINE-MARKER-RADIUS,
            fill: marker-col,
            stroke: TIMELINE-LINE-WIDTH + colours.background,
          )

          v(0.3em)

          // Date
          text(
            size: 0.85em,
            fill: colours.muted,
            weight: "semibold",
            event-date,
          )

          v(0.2em)

          // Title
          text(
            size: 0.9em,
            fill: colours.foreground,
            weight: "medium",
            event-title,
          )
        },
      )

      // Add connecting line (if not last)
      if index < num-events - 1 {
        items.push(
          place(
            center + top,
            dy: TIMELINE-MARKER-RADIUS,
            line(
              start: (-0.5em, 0pt),
              end: (2.5em, 0pt),
              stroke: TIMELINE-LINE-WIDTH + line-col,
            ),
          ),
        )
      }

      items
    }.flatten()
  )
}
