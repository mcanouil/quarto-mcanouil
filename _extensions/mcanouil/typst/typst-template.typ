$tokens.typ()$

$labels.typ()$

$slots.typ()$

$decoration.typ()$

$motifs.typ()$

$chrome.typ()$

$logo.typ()$

$authors.typ()$

$title.typ()$

// Side of the corner motif on page 1 of a compact report.
#let mc-first-page-motif-size = 80mm

#let article(
  title: none,
  subtitle: none,
  kicker: none,
  authors: (),
  affiliations: (),
  email: "",
  date: none,
  abstract: none,
  abstract-title: none,
  keywords: (),
  lang: "en",
  region: "US",
  mode: "light",
  tokens: (:),
  fonts: (:),
  header: none,
  footer: none,
  motif-name: none,
  doc,
) = {
  set document(title: if title != none { title } else { "" })
  set text(lang: lang, region: region, font: fonts.base, fill: tokens.ink)
  show heading: set text(font: fonts.headings)
  show raw: set text(font: fonts.monospace)
  show link: set text(fill: tokens.link)
  let corner = if motif-name != none { motif(motif-name, top + right, mc-first-page-motif-size) }
  show: chrome-page.with(header, footer, motif: corner)
  title-block(
    title: title,
    subtitle: subtitle,
    kicker: kicker,
    date: date,
    authors: authors,
    affiliations: affiliations,
    email: email,
    abstract: abstract,
    abstract-title: abstract-title,
    keywords: keywords,
    font: fonts.headings,
    motif-space: if corner != none { mc-first-page-motif-size - mc-page-margin.right },
    motif-height: if corner != none { mc-first-page-motif-size - mc-page-margin.top } else { 0pt },
  )
  doc
}
