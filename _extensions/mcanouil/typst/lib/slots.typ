// mcanouil - Typst header and footer slots
// The three slots of a header or footer, and the fields that only Typst can
// resolve: the page number and the current chapter title.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Lay out a header or footer as three cells: aligned left, centred and aligned
// right. An empty cell renders nothing.
#let slots(left: none, centre: none, right: none) = grid(
  columns: (1fr, auto, 1fr),
  column-gutter: 1em,
  align: (std.left, std.center, std.right),
  left, centre, right,
)

// Answer the page number as "n / total", with tabular figures.
#let page-number() = context text(number-width: "tabular")[
  #counter(page).get().first() / #counter(page).final().first()
]

// Answer the title of the current chapter: the first level 1 heading of the
// page, or else the last one before it, with its number when it has one.
#let chapter-title() = context {
  let chapters = heading.where(level: 1)
  let on-page = query(chapters).filter(it => it.location().page() == here().page())
  let before = query(chapters.before(here()))
  let chapter = if on-page.len() > 0 { on-page.first() } else if before.len() > 0 { before.last() }
  if chapter != none {
    if chapter.numbering != none {
      numbering(chapter.numbering, ..counter(heading).at(chapter.location()))
      h(0.5em)
    }
    chapter.body
  }
}
