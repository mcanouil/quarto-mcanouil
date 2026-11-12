// mcanouil - Typst title block
// The title block of page 1: kicker, title, gilded rule, subtitle, authors,
// affiliations, legends, date, abstract and keywords.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Answer the title block of a document.
// - title, subtitle, kicker, date, abstract: content, or none.
// - authors: array of author dictionaries, see author-line().
// - affiliations: array of affiliation lines.
// - email: email of the corresponding author, shown in the legend.
// - keywords: array of content.
// - abstract-title: heading of the abstract.
// - font: font family of the title and the subtitle, or none for the text font.
// - motif-space: width that the corner motif takes beside the head of the block, or none.
// - motif-height: least height of the head of the block beside the motif.
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
  motif-height: 0pt,
) = {
  let colours = tokens()
  let small(content) = text(size: 0.85em, fill: colours.muted, content)
  let in-font(content) = if font != none { text(font: font, content) } else { content }
  let head = {
    if kicker != none {
      block(below: 0.6em, text(size: 0.75em, weight: "bold", tracking: 0.14em, fill: colours.at("accent-text"), upper(kicker)))
    }
    if title != none {
      block(below: 0.5em, text(size: 1.9em, weight: "bold", in-font(title)))
    }
    block(below: 0.8em, gilded(45%, 2.5pt))
    if subtitle != none {
      block(below: 1.2em, text(size: 1.15em, fill: colours.muted, in-font(subtitle)))
    }
    if authors.len() > 0 {
      block(below: 0.6em, stack(spacing: 0.4em, ..authors.map(author-line)))
      if affiliations.len() > 0 {
        block(below: 0.5em, small(affiliation-lines(affiliations)))
      }
      let legends = author-legends(authors, email: email)
      if legends != none {
        block(below: 0.5em, small(legends))
      }
    }
    if date != none {
      block(below: 1em, small(date))
    }
  }
  if motif-space != none {
    grid(columns: (1fr, motif-space), head, box(height: motif-height))
  } else {
    head
  }
  if abstract != none {
    block(
      width: 100%,
      fill: colours.tint,
      stroke: (left: 2pt + colours.accent),
      inset: 0.8em,
      below: 0.8em,
      {
        if abstract-title != none {
          text(weight: "bold", abstract-title)
          parbreak()
        }
        abstract
      },
    )
  }
  if keywords.len() > 0 {
    block(below: 1em, small[*#mc-labels.at("mcanouil-keywords"):* #keywords.join[, ]])
  }
}
