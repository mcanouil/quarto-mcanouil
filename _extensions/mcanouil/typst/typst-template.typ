#let article(
  title: none,
  subtitle: none,
  authors: none,
  date: none,
  lang: "en",
  region: "US",
  mode: "light",
  tokens: (:),
  fonts: (:),
  doc,
) = {
  set document(title: if title != none { title } else { "" })
  set text(lang: lang, region: region, font: fonts.base, fill: tokens.ink)
  set page(paper: "a4", fill: tokens.paper)
  show heading: set text(font: fonts.headings)
  show raw: set text(font: fonts.monospace)
  show link: set text(fill: tokens.link)
  if title != none {
    align(center, text(size: 1.5em, weight: "bold", font: fonts.headings, title))
  }
  doc
}
