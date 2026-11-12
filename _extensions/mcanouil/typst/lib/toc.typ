// mcanouil - Typst contents
// The main table of contents of a document, and the contents page of a
// chapter. Every entry is a link to its heading; the dot leaders are artefacts.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// The kind of the part of the document in force: chapter, references,
// appendix or supplementary. The code that starts a special section updates it.
#let mc-part = state("mc-part", "chapter")

// Answer dot leaders that fill the rest of a line, tagged as an artefact.
#let leaders() = {
  let colours = tokens()
  box(width: 1fr, pdf.artifact(text(fill: colours.muted, repeat[.])))
}

// Answer the main table of contents.
// - depth: deepest heading level that it lists.
#let main-contents(depth: 2) = {
  let colours = tokens()
  show link: set text(fill: colours.ink)
  show outline.entry.where(level: 1): set block(above: 1.1em)
  show outline.entry.where(level: 1): set text(weight: "bold")
  set outline.entry(fill: leaders())
  outline(title: mc-labels.at("mcanouil-contents"), depth: depth)
}

// Answer the headings of a chapter that its contents page lists.
// - chapter: the level 1 heading of the chapter.
// - depth: how many heading levels under the chapter it lists.
#let chapter-entries(chapter, depth) = {
  let next = query(heading.where(level: 1).after(chapter.location(), inclusive: false))
  let scope = selector(heading).after(chapter.location(), inclusive: false)
  if next.len() > 0 {
    scope = scope.before(next.first().location(), inclusive: false)
  }
  query(scope).filter(it => it.outlined and it.level > 1 and it.level <= depth + 1)
}

// Answer the label of the part of a heading and its number, for example
// "Chapter 3" or "Appendix A".
// - chapter: a numbered level 1 heading.
#let chapter-label(chapter) = {
  let part = mc-part.at(chapter.location())
  let key = if part in ("appendix", "supplementary") { "mcanouil-" + part } else { "mcanouil-chapter" }
  mc-labels.at(key) + " " + numbering(chapter.numbering, ..counter(heading).at(chapter.location()))
}

// Answer the contents page of a chapter: the label of the chapter, the
// heading of the page, and one linked entry for each section, with dot
// leaders and the page number. A long list flows onto the next pages; each
// entry marks its page as a contents surface, so every page of the list has
// the same furniture.
// - chapter: the level 1 heading of the chapter.
// - depth: how many heading levels under the chapter it lists.
#let chapter-contents(chapter, depth) = {
  let colours = tokens()
  let entry(it) = {
    let level = it.level - 1
    let number = if it.numbering != none {
      text(fill: colours.at("accent-text"), numbering(it.numbering, ..counter(heading).at(it.location())))
      h(0.6em)
    }
    let page = text(number-width: "tabular", str(counter(page).at(it.location()).first()))
    let line = [#number#it.body#h(0.4em)#leaders()#h(0.4em)#page]
    block(
      above: if level == 1 { 0.9em } else { 0.45em },
      below: 0pt,
      inset: (left: (level - 1) * 1.6em),
      link(it.location(), if level == 1 { text(weight: "bold", line) } else { text(fill: colours.muted, line) }),
    )
  }
  show link: set text(fill: colours.ink)
  mc-surface("contents")
  block(below: 0.4em, text(size: 0.75em, weight: "bold", tracking: 0.14em, fill: colours.at("accent-text"), upper(chapter-label(chapter))))
  heading(level: 2, numbering: none, outlined: false, bookmarked: false, mc-labels.at("mcanouil-in-this-chapter"))
  block(above: 0.6em, below: 1em, gilded(30%, 2.5pt))
  for it in chapter-entries(chapter, depth) {
    mc-surface("contents")
    entry(it)
  }
}
