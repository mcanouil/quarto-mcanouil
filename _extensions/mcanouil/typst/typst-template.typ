$tokens.typ()$

$slots.typ()$

$decoration.typ()$

$motifs.typ()$

$chrome.typ()$

// Side of the corner motif on page 1 of a compact report.
#let mc-first-page-motif-size = 80mm

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
  let title-block = if title != none {
    text(size: 1.5em, weight: "bold", font: fonts.headings, title)
  }
  if corner != none {
    grid(
      columns: (1fr, mc-first-page-motif-size - mc-page-margin.right),
      title-block, box(height: mc-first-page-motif-size - mc-page-margin.top),
    )
  } else if title-block != none {
    title-block
  }
  doc
}
