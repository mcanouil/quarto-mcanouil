#let article(
  title: none,
  subtitle: none,
  authors: none,
  date: none,
  lang: "en",
  region: "US",
  doc,
) = {
  set document(title: if title != none { title } else { "" })
  set text(lang: lang, region: region)
  set page(paper: "a4")
  if title != none {
    align(center, text(size: 1.5em, weight: "bold", title))
  }
  doc
}
