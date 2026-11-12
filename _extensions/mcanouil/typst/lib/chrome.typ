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

// Mark the page that holds the mark as a surface of a kind, for example a
// cover or a chapter divider. chrome-page() gives that page the header,
// footer and background of the kind.
// - kind: key of the surfaces of chrome-page().
#let mc-surface(kind) = [#metadata(kind)<mc-surface>]

// Answer the surface kind of a page, from its first mark, or none.
// - page: page number.
#let surface-at(page) = {
  let marks = query(<mc-surface>).filter(it => it.location().page() == page)
  if marks.len() > 0 { marks.first().value }
}

// Set up the pages of a document.
// - header, footer: content of the header and footer, from slots().
// - edge: draw the gilded left edge on body pages.
// - motif: corner motif of page 1, from motif(), or none. Page 1 then has no
//   header and no edge, so the motif never meets the header.
// - paper: paper size.
// - surfaces: dictionary of the page kinds that mc-surface() marks. Each kind
//   has `header` (true or false), `footer` (content, or auto for the footer)
//   and `background` (content, or auto for the gilded edge of body pages).
#let chrome-page(header, footer, edge: true, motif: none, paper: "a4", surfaces: (:), body) = {
  let colours = tokens()
  let body-page = (header: true, footer: auto, background: auto)
  let surface() = {
    if motif != none and here().page() == 1 {
      (header: false, footer: auto, background: motif)
    } else {
      let kind = surface-at(here().page())
      if kind != none { surfaces.at(kind) } else { body-page }
    }
  }
  let furniture(content) = text(size: 8pt, fill: colours.muted, content)
  set page(
    paper: paper,
    margin: mc-page-margin,
    fill: colours.paper,
    header: context if surface().header {
      block(width: 100%, inset: (bottom: 3pt), stroke: (bottom: 0.5pt + colours.line), furniture(header))
    },
    footer: context {
      let own = surface().footer
      furniture(if own == auto { footer } else { own })
    },
    background: context {
      let own = surface().background
      if own != auto { own } else if edge { gilded-edge(mc-edge-width) }
    },
  )
  body
}
