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

// Distance below the top margin within which a chapter heading counts as the
// start of its page.
#let mc-chapter-top-tolerance = 2pt

// Answer the title of the chapter in force at the top of the page: the last
// level 1 heading on an earlier page, or at the very top of this page, with
// its number when it has one. A chapter that starts lower on the page shows
// from the next page on.
#let chapter-title() = context {
  let page = here().page()
  let top = mc-page-margin.top + mc-chapter-top-tolerance
  let in-force = query(heading.where(level: 1)).filter(it => {
    let position = it.location().position()
    position.page < page or (position.page == page and position.y <= top)
  })
  if in-force.len() > 0 {
    let chapter = in-force.last()
    if chapter.numbering != none {
      numbering(chapter.numbering, ..counter(heading).at(chapter.location()))
      h(0.5em)
    }
    chapter.body
  }
}
