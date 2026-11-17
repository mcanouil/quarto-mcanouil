// mcanouil - Typst page chrome
// Page set-up shared by every document type: paper, margins, the header and
// footer, the gilded left edge of body pages, and the corner motif of the
// first page.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Page margins of every document type.
#let mc-page-margin = (top: 25mm, bottom: 25mm, left: 20mm, right: 20mm)

// Width of the gilded left edge of body pages.
#let mc-edge-width = 2mm

// Set up the pages of a document.
// - header, footer: content of the header and footer, from slots().
// - edge: draw the gilded left edge on body pages.
// - motif: corner motif of page 1, from motif(), or none. Page 1 then has no
//   header and no edge, so the motif never meets the header.
// - paper: paper size.
#let chrome-page(header, footer, edge: true, motif: none, paper: "a4", body) = {
  let colours = tokens()
  let first-surface() = motif != none and here().page() == 1
  let furniture(content) = text(size: 8pt, fill: colours.muted, content)
  set page(
    paper: paper,
    margin: mc-page-margin,
    fill: colours.paper,
    header: context if not first-surface() {
      block(width: 100%, inset: (bottom: 3pt), stroke: (bottom: 0.5pt + colours.line), furniture(header))
    },
    footer: furniture(footer),
    background: context if first-surface() { motif } else if edge { gilded-edge(mc-edge-width) },
  )
  body
}
