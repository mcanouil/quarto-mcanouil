// mcanouil - workshop
// The workshop type: the handout of one session. Page 1 has the corner motif
// and the title block, with the session as the kicker and the duration beside
// the date. The blocks of the session (objectives, prerequisites, exercises,
// solutions and checkpoints) are boxes with a text label, so none relies on
// colour alone. Solutions sit in their exercise, are left out, or are
// collected at the end behind a "Solution: page n" link, as the Lua filter
// writes them. Code has no ligatures (see mcanouil-document()).
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Side of the corner motif on page 1 of a handout.
#let mc-workshop-motif-size = 60mm

// Answer a workshop block: a box with its label on top.
// - kind: objectives, prerequisites, exercise, solution or checkpoint.
// - label: text of the label, for example "Exercise 2.1 · 15 min · pairs".
// - body: content of the block.
#let mc-ws-block(kind, label, body) = {
  let colours = tokens()
  let dashed = mc-preset == "terminal"
  let edge(paint, thickness: 0.75pt) = (paint: paint, thickness: thickness, dash: if dashed { "dashed" } else { none })
  let styles = (
    objectives: (fill: colours.tint, stroke: edge(colours.line, thickness: 0.5pt), ink: colours.at("accent-text")),
    prerequisites: (fill: colours.tint, stroke: edge(colours.line, thickness: 0.5pt), ink: colours.at("accent-text")),
    exercise: (
      fill: none,
      stroke: if mc-preset == "mono" { (left: 3pt + colours.accent) } else { edge(colours.accent) },
      ink: colours.at("accent-text"),
    ),
    solution: (fill: none, stroke: (top: edge(colours.line, thickness: 0.5pt)), ink: colours.muted),
    checkpoint: (fill: colours.tint, stroke: (left: 3pt + colours.tip), ink: colours.at("tip-text")),
  )
  let style = styles.at(kind)
  let inset = if kind == "solution" { (top: 0.6em, x: 0pt, bottom: 0pt) } else { 0.8em }
  block(
    width: 100%,
    breakable: true,
    above: 1em,
    below: 1em,
    fill: style.fill,
    stroke: style.stroke,
    radius: if kind == "checkpoint" or mc-preset == "mono" { 0pt } else { 2pt },
    inset: inset,
    {
      text(size: 0.8em, weight: "bold", tracking: 0.06em, fill: style.ink, label)
      v(0.4em, weak: true)
      body
    },
  )
}

// Answer the link from an exercise to its solution at the end: "Solution: page n".
// - target: label of the heading of the solution.
#let mc-ws-solution-link(target) = context {
  let number = counter(page).at(target).first()
  block(above: 0.8em, text(size: 0.9em, link(target, mc-labels.at("mcanouil-solution-page").replace("{page}", str(number)))))
}

// Answer the heading of the solutions at the end of a handout, on a new page.
// - title: text of the heading.
#let mc-ws-solutions-heading(title) = {
  pagebreak(weak: true)
  heading(level: 1, title)
}

// Answer the heading of one solution at the end of a handout. The Lua filter
// writes the label of the heading after the call.
// - title: text of the heading, for example "Solution 2.1".
#let mc-ws-solution-heading(title) = heading(level: 2, title)

// Answer a workshop handout.
// - meta: the document, see mcanouil-document(); `session` is the session
//   text and `duration` the duration of the session, each when it is set.
// - body: the content of the document.
#let mc-workshop(meta, body) = {
  let fonts = meta.fonts
  let motif-name = meta.at("motif-name", default: none)
  let extent = if motif-name != none { mc-motif-extent(motif-name) }
  let corner = if motif-name != none { motif(motif-name, top + right, mc-workshop-motif-size) }
  let date = meta.at("date", default: none)
  let duration = meta.at("duration", default: none)
  let when = if duration != none {
    let length = [#mc-labels.at("mcanouil-duration"): #duration]
    if date != none { [#date #sym.dot.c #length] } else { length }
  } else {
    date
  }
  set heading(numbering: none)
  show: chrome-page.with(meta.header, meta.footer, motif: corner)
  title-block(
    title: meta.at("title", default: none),
    subtitle: meta.at("subtitle", default: none),
    kicker: meta.at("session", default: none),
    date: when,
    authors: meta.at("authors", default: ()),
    affiliations: meta.at("affiliations", default: ()),
    email: meta.at("email", default: ""),
    font: fonts.headings,
    motif-space: if corner != none {
      calc.max(0pt, mc-workshop-motif-size * (100 - extent.left) / 100 + mc-motif-gap - mc-page-margin.right)
    },
    motif-bottom: if corner != none { mc-workshop-motif-size * extent.bottom / 100 + mc-motif-gap },
  )
  body
}
