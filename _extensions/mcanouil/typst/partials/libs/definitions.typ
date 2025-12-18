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

// Pandoc and Quarto compatibility definitions
// Provides functions required by Pandoc's Typst output and Quarto-specific features
// Author: Mickaël Canouil
// License: MIT

// Import shared utilities
// #import "utilities.typ": is-empty, block-with-new-content

// ============================================================================
// Pandoc compatibility
// ============================================================================

/// Horizontal rule for document separators
#let horizontalrule = line(start: (25%, 0%), end: (75%, 0%))

/// Endnote formatting
/// @param num Note number
/// @param contents Note contents
/// @return Formatted endnote
#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

// ============================================================================
// Quarto code block styling
// ============================================================================

// Note: Code block styling is handled by show rules in typst-template.typ
// using brand-mode aware colour-mix-adaptive() for proper light/dark mode support
// #show raw.where(block: true): set block(
//   fill: luma(230),
//   width: 100%,
//   inset: 8pt,
//   radius: 2pt,
// )

// ============================================================================
// Quarto helper functions
// ============================================================================

// Re-export utilities for compatibility
#let block_with_new_content = block-with-new-content
#let empty = is-empty

// ============================================================================
// Subfloat support
// ============================================================================
// This is a technique adapted from https://github.com/tingerrr/subpar/

#let quartosubfloatcounter = counter("quartosubfloatcounter")

/// Create a super figure containing subfigures
/// @param kind Figure kind
/// @param caption Super figure caption
/// @param label Super figure label
/// @param supplement Supplement text
/// @param position Caption position
/// @param subrefnumbering Subfigure reference numbering format
/// @param subcapnumbering Subfigure caption numbering format
/// @param body Subfigure content
/// @return Super figure with subfigures
#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
        kind: kind,
        supplement: supplement,
        caption: caption,
        {
          show figure.where(kind: kind): set figure(numbering: _ => numbering(
            subrefnumbering,
            n-super,
            quartosubfloatcounter.get().first() + 1,
          ))
          show figure.where(kind: kind): set figure.caption(position: position)

          show figure: it => {
            let num = numbering(subcapnumbering, quartosubfloatcounter.get().first() + 1)
            show figure.caption: it => block({
              num
              [ ]
              it.body
            })

            quartosubfloatcounter.step()
            it
            counter(figure.where(kind: it.kind)).update(n => n - 1)
          }

          quartosubfloatcounter.update(0)
          body
        },
      )#label]
  }
}

// ============================================================================
// Callout support
// ============================================================================

/// Callout rendering show rule
/// This is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  // Safely capitalise kind (check for empty string)
  if kind.len() > 0 {
    kind = upper(kind.first()) + kind.slice(1)
  }

  // Pull apart the callout structure with bounds checking
  // Structure: it.body.children[1].body.children[1] = callout block
  if it.body.children.len() < 2 {
    panic("Callout structure error: expected at least 2 top-level children, found " + str(it.body.children.len()))
  }

  let body_child = it.body.children.at(1)
  if body_child.body.children.len() < 2 {
    panic("Callout structure error: expected at least 2 body children, found " + str(body_child.body.children.len()))
  }

  let old_callout = body_child.body.children.at(1)
  if old_callout.body.children.len() < 1 {
    panic("Callout structure error: expected at least 1 callout child, found " + str(old_callout.body.children.len()))
  }

  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children

  // Extract title (with or without icon)
  let old_title = if children.len() == 0 {
    none
  } else if children.len() == 1 {
    children.at(0) // No icon: title at index 0
  } else {
    children.at(1) // With icon: title at index 1
  }

  // Build new title with callout type and counter
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  // Reassemble with new title
  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() <= 1 {
        new_title // No icon: just the title
      } else {
        children.at(0) + new_title // With icon: preserve icon block + new title
      },
    ),
  )

  // Check for body content before accessing
  if old_callout.body.children.len() < 2 {
    panic(
      "Callout structure error: expected at least 2 callout body children for content, found "
        + str(old_callout.body.children.len()),
    )
  }

  block_with_new_content(old_callout, block(below: 0pt, new_title_block) + old_callout.body.children.at(1))
}

/// Create a callout block
/// NOTE: Parameters use American English spelling (color not colour) for Quarto compatibility
/// @param body Callout content
/// @param title Callout title
/// @param background_color Background colour
/// @param icon Icon to display
/// @param icon_color Icon colour
/// @param body_background_color Body background colour
/// @return Formatted callout block
#let callout(
  body: [],
  title: "Callout",
  background_color: rgb("#dddddd"),
  icon: none,
  icon_color: black,
  body_background_color: white,
) = {
  block(
    breakable: false,
    fill: background_color,
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"),
    width: 100%,
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%,
      below: 0pt,
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt,
      )[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title],
    )
      + if (body != []) {
        block(
          inset: 1pt,
          width: 100%,
          block(fill: body_background_color, width: 100%, inset: 8pt, body),
        )
      },
  )
}
