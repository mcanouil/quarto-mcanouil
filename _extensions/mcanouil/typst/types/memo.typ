// mcanouil - memo
// The memo document type, in four kinds: note, minutes, agenda and brief. A
// full-width banner opens page 1, with the ground gradient, the corner motif,
// the kind label, the title and the metadata of the kind as a table. A
// full-width band holds the footer slots at the bottom of every page. There is
// no cover and no table of contents.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Side of the corner motif of the banner. The banner clips what falls below it.
#let mc-memo-motif-size = 70mm

// Height of the band at the bottom of every page.
#let mc-memo-band-height = 14mm

// Space between the text of the banner and the shapes of the motif.
#let mc-memo-motif-gap = 5mm

// Answer the table of the banner metadata: a header row of labels, and a row of values. A field
// with no value is not in `fields`, so the table has no empty column. The header cells are tagged.
// - fields: array of dictionaries with `key` (the label key without its prefix) and `value` (content).
#let memo-fields-table(fields) = {
  if fields.len() == 0 { return }
  let colours = tokens()
  v(0.8em)
  set text(size: 0.9em)
  table(
    columns: fields.map(_ => 1fr),
    column-gutter: 1.2em,
    stroke: none,
    inset: (x: 0pt, y: 2pt),
    align: left,
    table.header(..fields.map(field => table.cell(
      text(size: 0.8em, weight: "bold", tracking: 0.1em, fill: colours.at("on-ground-accent"), upper(mc-labels.at("mcanouil-memo-" + field.key))),
    ))),
    ..fields.map(field => text(fill: colours.at("on-ground-text"), field.value)),
  )
}

// Answer the banner of a memo: full width, at the top of page 1.
// - kind: kind of the memo.
// - title: title of the memo, or none.
// - fields: array of the metadata fields that have a value, see memo-fields-table().
// - font: font family of the title.
// - motif-name: motif name, or none.
#let memo-banner(kind, title, fields, font: none, motif-name: none) = {
  let colours = tokens()
  let margin = mc-page-margin
  let space = if motif-name != none {
    mc-memo-motif-size * (100 - mc-motif-extent(motif-name).left) / 100 + mc-memo-motif-gap
  } else {
    0pt
  }
  pad(top: -margin.top, x: -margin.left, block(
    width: 100%,
    clip: true,
    fill: gradient.linear(colours.at("ground-1"), colours.at("ground-2"), angle: 45deg),
    {
      if motif-name != none { motif(motif-name, top + right, mc-memo-motif-size, dark: true) }
      pad(
        left: margin.left,
        right: calc.max(margin.right, space),
        top: 12mm,
        bottom: 8mm,
        {
          text(size: 0.75em, weight: "bold", tracking: 0.14em, fill: colours.at("on-ground-accent"), upper(mc-labels.at("mcanouil-memo-" + kind)))
          if title != none {
            v(0.5em)
            text(size: 1.7em, weight: "bold", fill: colours.at("on-ground-title"), if font != none { text(font: font, title) } else { title })
          }
          v(0.6em)
          gilded(45%, 2.5pt)
          memo-fields-table(fields)
        },
      )
    },
  ))
  v(1.2em)
}

// Answer the band at the bottom of a page: full width, the ground gradient, the footer slots.
// - footer: content of the footer, from slots().
#let memo-band(footer) = {
  let colours = tokens()
  let margin = mc-page-margin
  align(bottom, pad(x: -margin.left, block(
    width: 100%,
    height: mc-memo-band-height,
    inset: (x: margin.left),
    fill: gradient.linear(colours.at("ground-1"), colours.at("ground-2"), angle: 0deg),
    align(horizon, text(size: 8pt, fill: colours.at("on-ground-text"), footer)),
  )))
}

// Answer a memo.
// - meta: the document, see mcanouil-document(); `kind` is the memo kind and `memo-fields` the banner fields.
// - body: the content of the document.
#let mc-memo(meta, body) = {
  let colours = meta.tokens
  set page(
    paper: "a4",
    margin: mc-page-margin,
    fill: colours.paper,
    footer-descent: 0pt,
    footer: memo-band(meta.footer),
  )
  show heading.where(level: 1): set text(size: 1.15em)
  set heading(numbering: none)
  memo-banner(
    meta.kind,
    meta.at("title", default: none),
    meta.at("memo-fields", default: ()),
    font: meta.fonts.headings,
    motif-name: meta.at("motif-name", default: none),
  )
  body
}
