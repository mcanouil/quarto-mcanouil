$tokens.typ()$

$labels.typ()$

$decoration.typ()$

$quote.typ()$

$code-window.typ()$

$motifs.typ()$

$chrome.typ()$

$slots.typ()$

$logo.typ()$

$authors.typ()$

$address.typ()$

$title.typ()$

$toc.typ()$

$report.typ()$

$article.typ()$

$memo.typ()$
$letter.typ()$

$invoice.typ()$

$workshop.typ()$

// The document types, each a function (meta, body) -> content.
#let mc-types = (
  report: mc-report,
  article: mc-article,
  memo: mc-memo,
  letter: mc-letter,
  invoice: mc-invoice,
  workshop: mc-workshop,
)

// Answer a reference. Several types leave their headings unnumbered, and
// Typst cannot reference a heading without a number, so a reference to an
// unnumbered heading links to it with the supplement and the heading text,
// such as "Section Introduction". Any other reference stays as Typst writes it.
// - it: the reference.
#let mc-heading-ref(it) = {
  let target = it.element
  if target == none or target.func() != heading or target.numbering != none {
    return it
  }
  let supplement = if it.supplement == auto {
    target.supplement
  } else if type(it.supplement) == function {
    (it.supplement)(target)
  } else {
    it.supplement
  }
  let words = if supplement in (none, []) { target.body } else { [#supplement~#target.body] }
  link(target.location(), words)
}

// Answer the document of a type: the text, heading, code and link styles that
// every type shares, then the function of the type. Code has no ligatures and
// no contextual alternates, so it reads as typed.
// - type: key of mc-types.
// - layout: layout of the type.
// - kind: kind of the type, or none.
// - meta: dictionary of the document: title, document-title (the PDF title of a
//   document with no title), subtitle, kicker, date, authors,
//   affiliations, email, abstract, abstract-title, keywords, lang, region (none when unset),
//   version, licence, copyright, toc-depth, mode, tokens, fonts, header,
//   footer, motif-name, and for a workshop session and duration.
// - body: the content of the document.
#let mcanouil-document(type, layout, kind, meta, body) = {
  let tokens = meta.tokens
  let fonts = meta.fonts
  set document(title: meta.at("title", default: meta.at("document-title", default: "")))
  set text(lang: meta.lang, region: meta.at("region", default: none), font: fonts.base, fill: tokens.ink)
  show heading: set text(font: fonts.headings)
  show raw: set text(font: fonts.monospace, ligatures: false, features: ("calt": 0))
  show link: set text(fill: tokens.link)
  show: mc-quotes.with(meta)
  show: mc-code-windows.with(meta)
  show ref: mc-heading-ref
  mc-types.at(type)(meta + (layout: layout, kind: kind), body)
}
