$tokens.typ()$

$labels.typ()$

$decoration.typ()$

$quote.typ()$

$motifs.typ()$

$chrome.typ()$

$slots.typ()$

$logo.typ()$

$authors.typ()$

$title.typ()$

$toc.typ()$

$report.typ()$

$article.typ()$

$memo.typ()$

// The document types, each a function (meta, body) -> content.
#let mc-types = (
  report: mc-report,
  article: mc-article,
  memo: mc-memo,
)

// Answer the document of a type: the text, heading, code and link styles that
// every type shares, then the function of the type.
// - type: key of mc-types.
// - layout: layout of the type.
// - kind: kind of the type, or none.
// - meta: dictionary of the document: title, subtitle, kicker, date, authors,
//   affiliations, email, abstract, abstract-title, keywords, lang, region,
//   version, licence, copyright, toc-depth, mode, tokens, fonts, header,
//   footer and motif-name.
// - body: the content of the document.
#let mcanouil-document(type, layout, kind, meta, body) = {
  let tokens = meta.tokens
  let fonts = meta.fonts
  set document(title: meta.at("title", default: ""))
  set text(lang: meta.lang, region: meta.region, font: fonts.base, fill: tokens.ink)
  show heading: set text(font: fonts.headings)
  show raw: set text(font: fonts.monospace)
  show link: set text(fill: tokens.link)
  show: mc-quotes.with(meta)
  mc-types.at(type)(meta + (layout: layout, kind: kind), body)
}
