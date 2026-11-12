// mcanouil - report
// The report document type. Compact layout: no cover, the title block, the
// abstract and the body start on page 1, and level 1 headings run inline.
// Full layout: a cover, the table of contents, a divider page and a contents
// page for each chapter, the body, and a closing page.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Side of the corner motif on page 1 of a compact report.
#let mc-first-page-motif-size = 80mm

// Space kept between the shapes of the corner motif and the text.
#let mc-motif-gap = 3mm

// Answer a compact report.
// - meta: the document, see mcanouil-document().
// - body: the content of the document.
#let mc-report-compact(meta, body) = {
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

// Side of the corner motif of the cover: 80% of the page width.
#let mc-cover-motif-size = 168mm

// Side of the corner motif of a chapter divider: the page width.
#let mc-divider-motif-size = 210mm

// Size of the chapter number of a divider page.
#let mc-chapter-number-size = 7em

// Answer the space from the top margin to below the shapes of a motif.
// - name: motif name, or none.
// - size: side of the motif.
#let motif-clearance(name, size) = {
  if name == none { return 0pt }
  calc.max(0pt, size * mc-motif-extent(name).bottom / 100 + mc-motif-gap - mc-page-margin.top)
}

// Answer the cover of a full report: the corner motif, then the kicker, the
// title, the gilded rule, the subtitle, the authors and the date, below the
// shapes of the motif.
// - meta: the document, see mcanouil-document().
#let cover(meta) = {
  mc-surface("cover")
  v(motif-clearance(meta.at("motif-name", default: none), mc-cover-motif-size))
  v(1fr)
  title-block(
    title: meta.at("title", default: none),
    subtitle: meta.at("subtitle", default: none),
    kicker: meta.at("kicker", default: mc-labels.at("mcanouil-report")),
    date: meta.at("date", default: none),
    authors: meta.at("authors", default: ()),
    affiliations: meta.at("affiliations", default: ()),
    email: meta.at("email", default: ""),
    font: meta.fonts.headings,
    title-size: 2.6em,
  )
  v(1fr)
  pagebreak()
}

// Answer the background of a chapter divider: the ground gradient and the
// corner motif, both artefacts.
// - motif-name: motif name, or none.
#let divider-ground(motif-name) = {
  let colours = tokens()
  pdf.artifact(place(top + left, rect(
    width: 100%,
    height: 100%,
    stroke: none,
    fill: gradient.linear(colours.at("ground-1"), colours.at("ground-2"), angle: 45deg),
  )))
  if motif-name != none { motif(motif-name, top + right, mc-divider-motif-size, dark: true) }
}

// Answer a level 1 heading of a full report. A numbered chapter starts a
// divider page: its number with a gradient fill, and its title, below the
// shapes of the motif. An unnumbered one starts a new page with its title.
// - it: the heading.
// - motif-name: motif name, or none.
#let chapter-divider(it, motif-name) = {
  let colours = tokens()
  pagebreak(weak: true)
  if it.numbering == none {
    block(below: 1em, text(size: 1.9em, weight: "bold", it.body))
  } else {
    mc-surface("divider")
    v(motif-clearance(motif-name, mc-divider-motif-size))
    v(1fr)
    let number = context numbering(it.numbering, ..counter(heading).at(it.location()))
    block(below: 0.2em, box(text(
      size: mc-chapter-number-size,
      weight: "bold",
      fill: gradient.linear(colours.at("accent-high"), colours.at("on-ground-accent"), angle: 90deg),
      number,
    )))
    block(text(size: 2.4em, weight: "bold", fill: colours.at("on-ground-title"), it.body))
  }
}

// End the divider page of a chapter, after its heading: the gilded rule and
// the introduction line. Then write the contents page of the chapter, when it
// has sections, and start its body on a new page.
// - depth: how many heading levels under the chapter its contents page lists.
// - intro: introduction line of the chapter, or none.
#let chapter-opening(depth: 2, intro: none) = {
  let colours = tokens()
  block(above: 1em, below: 1em, gilded(35%, 2.5pt))
  if intro != none {
    block(width: 85%, text(size: 1.1em, fill: colours.at("on-ground-text"), intro))
  }
  v(1fr)
  context {
    let chapter = query(heading.where(level: 1).before(here())).last()
    if chapter-entries(chapter, depth).len() > 0 {
      pagebreak()
      mc-surface("contents")
      chapter-contents(chapter, depth)
    }
  }
  pagebreak()
}

// Answer the closing page of a full report: the contact of each author, with
// the ORCID, the licence and the colophon.
// - meta: the document, see mcanouil-document().
#let closing-page(meta) = {
  let colours = tokens()
  let part(label, content) = block(above: 1.6em, {
    block(below: 0.6em, text(size: 0.85em, weight: "bold", fill: colours.at("accent-text"), label))
    content
  })
  pagebreak(weak: true)
  mc-surface("closing")
  v(1fr)
  gilded(30%, 2.5pt)
  let contacts = meta.at("authors", default: ()).filter(it => it.email != "" or it.orcid != "")
  if contacts.len() > 0 {
    part(mc-labels.at("mcanouil-closing-contact"), stack(spacing: 0.6em, ..contacts.map(it => {
      let parts = (text(weight: "bold", it.name),)
      if it.email != "" { parts.push(link("mailto:" + it.email, it.email)) }
      if it.orcid != "" { parts.push(link("https://orcid.org/" + it.orcid)[#orcid-badge(it.orcid) #it.orcid]) }
      parts.join(h(0.8em))
    })))
  }
  let licence = meta.at("licence", default: none)
  let copyright = meta.at("copyright", default: none)
  if licence != none or copyright != none {
    part(mc-labels.at("mcanouil-closing-licence"), (copyright, licence).filter(it => it != none).join(linebreak()))
  }
  let fonts = meta.fonts
  part(mc-labels.at("mcanouil-closing-colophon"), [
    #mc-labels.at("mcanouil-closing-typeset")
    #linebreak()
    #mc-labels.at("mcanouil-closing-fonts"): #(fonts.base.first(), fonts.headings.first(), fonts.monospace.first()).dedup().join(", ").
  ])
}

// Answer a full report.
// - meta: the document, see mcanouil-document().
// - body: the content of the document.
#let mc-report-full(meta, body) = {
  let motif-name = meta.at("motif-name", default: none)
  let version = meta.at("version", default: none)
  let licence = meta.at("licence", default: none)
  let footer-of-cover = slots(left: none, centre: version, right: licence)
  let surfaces = (
    cover: (
      header: false,
      footer: footer-of-cover,
      background: if motif-name != none { motif(motif-name, top + right, mc-cover-motif-size) },
    ),
    divider: (header: false, footer: none, background: divider-ground(motif-name)),
    contents: (header: false, footer: auto, background: auto),
    closing: (header: false, footer: auto, background: none),
  )
  set heading(numbering: "1.1")
  show heading.where(level: 1): it => chapter-divider(it, motif-name)
  show: chrome-page.with(meta.header, meta.footer, surfaces: surfaces)
  cover(meta)
  let abstract = meta.at("abstract", default: none)
  if abstract != none {
    block(width: 100%, fill: tokens().tint, stroke: (left: 2pt + tokens().accent), inset: 0.8em, {
      text(weight: "bold", meta.at("abstract-title", default: none))
      parbreak()
      abstract
    })
    pagebreak()
  }
  main-contents(depth: meta.at("toc-depth", default: 2))
  body
  closing-page(meta)
}

// Answer a report in its layout, compact or full.
// - meta: the document, see mcanouil-document().
// - body: the content of the document.
#let mc-report(meta, body) = {
  if meta.layout == "full" { mc-report-full(meta, body) } else { mc-report-compact(meta, body) }
}
