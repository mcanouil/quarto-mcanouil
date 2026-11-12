// mcanouil - report
// The report document type, compact layout: no cover, the title block, the
// abstract and the body start on page 1, and level 1 headings run inline.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Side of the corner motif on page 1 of a compact report.
#let mc-first-page-motif-size = 80mm

// Space kept between the shapes of the corner motif and the text.
#let mc-motif-gap = 3mm

// Answer a report.
// - meta: the document, see mcanouil-document().
// - body: the content of the document.
#let mc-report(meta, body) = {
  let tokens = meta.tokens
  let fonts = meta.fonts
  let motif-name = meta.at("motif-name", default: none)
  let extent = if motif-name != none { mc-motif-extent(motif-name) }
  let corner = if motif-name != none { motif(motif-name, top + right, mc-first-page-motif-size) }
  show: chrome-page.with(meta.header, meta.footer, motif: corner)
  title-block(
    title: meta.at("title", default: none),
    subtitle: meta.at("subtitle", default: none),
    kicker: meta.at("kicker", default: mc-labels.at("mcanouil-report")),
    date: meta.at("date", default: none),
    authors: meta.at("authors", default: ()),
    affiliations: meta.at("affiliations", default: ()),
    email: meta.at("email", default: ""),
    abstract: meta.at("abstract", default: none),
    abstract-title: meta.at("abstract-title", default: none),
    keywords: meta.at("keywords", default: ()),
    font: fonts.headings,
    motif-space: if corner != none {
      calc.max(0pt, mc-first-page-motif-size * (100 - extent.left) / 100 + mc-motif-gap - mc-page-margin.right)
    },
    motif-bottom: if corner != none { mc-first-page-motif-size * extent.bottom / 100 + mc-motif-gap },
  )
  body
}
