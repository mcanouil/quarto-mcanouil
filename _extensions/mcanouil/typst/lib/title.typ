// mcanouil - Typst title block
// The title block of page 1: kicker, title, gilded rule, subtitle, authors,
// affiliations, legends, date, abstract and keywords.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Answer a block that keeps clear of the corner motif: on page 1, while it
// starts above the bottom of the motif, it is as wide as the text less the
// space of the motif.
// - below: space under the block.
// - motif-space: width that the corner motif takes beside the text, or none.
// - motif-bottom: distance from the top of the page to the bottom of the motif.
// - content: the content of the block.
#let beside-motif(below, motif-space, motif-bottom, content) = context {
  let position = here().position()
  let narrow = motif-space != none and position.page == 1 and position.y < motif-bottom
  block(width: if narrow { 100% - motif-space } else { 100% }, below: 0pt, content)
  v(below)
}

// Answer the space that moves the text below the corner motif, when the title
// block ends above the bottom of the shapes of the motif.
// - motif-bottom: distance from the top of the page to the bottom of the shapes, or none.
#let clear-motif(motif-bottom) = context {
  let position = here().position()
  if motif-bottom != none and position.page == 1 and position.y < motif-bottom {
    v(motif-bottom - position.y)
  }
}

// Answer the title block of a document.
// - title, subtitle, kicker, date, abstract: content, or none.
// - authors: array of author dictionaries, see author-line().
// - affiliations: array of affiliation lines.
// - email: email of the corresponding author, shown in the legend.
// - keywords: array of content.
// - abstract-title: heading of the abstract.
// - font: font family of the title and the subtitle, or none for the text font.
// - motif-space: width that the shapes of the corner motif take beside the text, or none.
// - motif-bottom: distance from the top of the page to the bottom of those shapes, or none.
#let title-block(
  title: none,
  subtitle: none,
  kicker: none,
  date: none,
  authors: (),
  affiliations: (),
  email: "",
  abstract: none,
  abstract-title: none,
  keywords: (),
  font: none,
  motif-space: none,
  motif-bottom: none,
) = {
  let colours = tokens()
  let small(content) = text(size: 0.85em, fill: colours.muted, content)
  let in-font(content) = if font != none { text(font: font, content) } else { content }
  let row(below, content) = beside-motif(below, motif-space, motif-bottom, content)
  if kicker != none {
    row(0.6em, text(size: 0.75em, weight: "bold", tracking: 0.14em, fill: colours.at("accent-text"), upper(kicker)))
  }
  if title != none {
    row(0.5em, text(size: 1.9em, weight: "bold", in-font(title)))
  }
  row(0.8em, gilded(45%, 2.5pt))
  if subtitle != none {
    row(1.2em, text(size: 1.15em, fill: colours.muted, in-font(subtitle)))
  }
  if authors.len() > 0 {
    row(1.2em, stack(spacing: 0.4em, ..authors.map(author-line)))
    if affiliations.len() > 0 {
      row(0.5em, small(affiliation-lines(affiliations)))
    }
    let legends = author-legends(authors, email: email)
    if legends != none {
      row(0.5em, small(legends))
    }
  }
  if date != none {
    row(1em, small(date))
  }
  if abstract != none {
    beside-motif(
      0.8em,
      motif-space,
      motif-bottom,
      block(
        width: 100%,
        fill: colours.tint,
        stroke: (left: 2pt + colours.accent),
        inset: 0.8em,
        {
          if abstract-title != none {
            text(weight: "bold", abstract-title)
            parbreak()
          }
          abstract
        },
      ),
    )
  }
  if keywords.len() > 0 {
    row(1em, small[*#mc-labels.at("mcanouil-keywords"):* #keywords.join[, ]])
  }
  clear-motif(motif-bottom)
}
