// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)
        show figure.where(kind: kind): set figure(outlined: false)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}



// mcanouil - Typst tokens
// Colour tokens, scheme and motif of the preset, as Lua delivers them for the
// render mode. No colour value is written here; every colour comes from the
// preset data files through the `mcanouil-tokens` metadata.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

#let mc-tokens = (
  accent: rgb("#b5830a"),
  accent-high: rgb("#e8c65a"),
  accent-low: rgb("#6b4a05"),
  accent-text: rgb("#876208"),
  caution: rgb("#a58300"),
  caution-text: rgb("#7a6300"),
  chrome: rgb("#111827"),
  ground-1: rgb("#111827"),
  ground-2: rgb("#3a2a06"),
  important: rgb("#cc0000"),
  important-text: rgb("#b00000"),
  ink: rgb("#111827"),
  line: rgb("#e3dccb"),
  link: rgb("#876208"),
  muted: rgb("#4b5563"),
  note: rgb("#0066cc"),
  note-text: rgb("#0055b3"),
  on-ground-accent: rgb("#e8c65a"),
  on-ground-text: rgb("#f0dfa8"),
  on-ground-title: rgb("#ffffff"),
  paper: rgb("#fafafa"),
  tint: rgb("#f7f4ec"),
  tip: rgb("#009955"),
  tip-text: rgb("#00723f"),
  warning: rgb("#cc6600"),
  warning-text: rgb("#964c00"),
)
#let mc-mode = "light"
#let mc-motif = "facets"

// Answer the colour tokens of the render mode.
#let tokens() = mc-tokens

// mcanouil - Typst labels
// The labels of the document language, as Lua delivers them through the
// `mcanouil-labels` metadata. The label text lives only in the language files.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

#let mc-labels = (
  mcanouil-author-corresponding: "Corresponding author",
  mcanouil-author-deceased: "Deceased",
  mcanouil-author-equal: "Equal contribution",
  mcanouil-author-orcid: "ORCID",
  mcanouil-checkpoint: "Checkpoint",
  mcanouil-closing-colophon: "Colophon",
  mcanouil-closing-contact: "Contact",
  mcanouil-closing-licence: "Licence",
  mcanouil-credit-equal: "Equal",
  mcanouil-credit-lead: "Lead",
  mcanouil-credit-supporting: "Supporting",
  mcanouil-duration: "Duration",
  mcanouil-exercise: "Exercise",
  mcanouil-in-this-chapter: "In this chapter",
  mcanouil-invoice-bank: "Bank details",
  mcanouil-invoice-description: "Description",
  mcanouil-invoice-due: "Payment due date",
  mcanouil-invoice-exempted: "VAT exempt",
  mcanouil-invoice-issued: "Issued on",
  mcanouil-invoice-number: "Invoice number",
  mcanouil-invoice-payment: "Payment",
  mcanouil-invoice-quantity: "Quantity",
  mcanouil-invoice-reference: "Reference",
  mcanouil-invoice-subtotal: "Subtotal",
  mcanouil-invoice-terms: "Terms",
  mcanouil-invoice-title: "Invoice",
  mcanouil-invoice-total: "Total",
  mcanouil-invoice-unit-price: "Unit price",
  mcanouil-invoice-vat: "VAT",
  mcanouil-keywords: "Keywords",
  mcanouil-letter-cc: "Cc",
  mcanouil-letter-enclosures: "Enclosures",
  mcanouil-letter-postscript: "P.S.",
  mcanouil-letter-reference: "Reference",
  mcanouil-letter-subject: "Subject",
  mcanouil-memo-absent: "Absent",
  mcanouil-memo-action: "Action",
  mcanouil-memo-actions: "Actions",
  mcanouil-memo-agenda: "Agenda",
  mcanouil-memo-audience: "Audience",
  mcanouil-memo-brief: "Brief",
  mcanouil-memo-date: "Date",
  mcanouil-memo-date-time: "Date and time",
  mcanouil-memo-decisions: "Decisions",
  mcanouil-memo-due: "Due",
  mcanouil-memo-from: "From",
  mcanouil-memo-minutes: "Minutes",
  mcanouil-memo-note: "Note",
  mcanouil-memo-owner: "Owner",
  mcanouil-memo-participants: "Participants",
  mcanouil-memo-place: "Place",
  mcanouil-memo-present: "Present",
  mcanouil-memo-purpose: "Purpose",
  mcanouil-memo-to: "To",
  mcanouil-objectives: "Objectives",
  mcanouil-prerequisites: "Prerequisites",
  mcanouil-session: "Session",
  mcanouil-solution: "Solution",
  mcanouil-solution-page: "Solution: page {page}",
)
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
// mcanouil - Typst decoration
// The gilded gradient of rules and of the left page edge. Every piece is
// tagged as an artefact, so a screen reader skips it.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Answer a gilded rule: accent-low, accent-high, accent-low from left to right.
#let gilded(length, thickness) = {
  let colours = tokens()
  pdf.artifact(box(
    width: length,
    height: thickness,
    radius: thickness / 2,
    fill: gradient.linear(colours.at("accent-low"), colours.at("accent-high"), colours.at("accent-low")),
  ))
}

// Answer the gilded left page edge of body pages, from top to bottom:
// accent-high, accent, accent-low. It is placed in the page background.
#let gilded-edge(thickness) = {
  let colours = tokens()
  pdf.artifact(place(top + left, rect(
    width: thickness,
    height: 100%,
    stroke: none,
    fill: gradient.linear(
      (colours.at("accent-high"), 0%),
      (colours.accent, 45%),
      (colours.at("accent-low"), 100%),
      angle: 90deg,
    ),
  )))
}
// mcanouil - Typst corner motifs
// The corner motif of each preset, drawn for the top right corner of a 100 by
// 100 view box. The same shapes are in html/motifs/<name>.svg; the
// motif-geometry-match check compares the two from mc-motif-lines().
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Shapes of each motif. `points` holds the polygon corners as x, y pairs, the
// x, y, width and height of a rectangle, or the centre x, y and the radius of a
// circle. `opacity` is the opacity on a dark surface; a light surface uses 85% of it.
#let mc-motif-geometry = (
  facets: (
    (kind: "polygon", points: (100, 0, 38, 0, 100, 62), opacity: 0.18),
    (kind: "polygon", points: (100, 0, 62, 0, 100, 40), opacity: 0.3),
    (kind: "polygon", points: (100, 0, 80, 0, 100, 46), opacity: 0.22),
    (kind: "polygon", points: (100, 0, 52, 0, 86, 20), opacity: 0.26),
    (kind: "polygon", points: (100, 0, 88, 0, 100, 18), opacity: 0.55),
  ),
  steps: range(4)
    .map(i => range(4 - i).map(j => (
      kind: "rect",
      points: (88 - 13 * i, 13 * j, 12, 12),
      opacity: calc.round(calc.max(0.75 - 0.16 * (i + j), 0.08), digits: 2),
    )))
    .flatten(),
  ribbon: ((0, 12, 0.55), (16, 22, 0.35), (26, 29, 0.25)).map(((a, b, o)) => (
    kind: "polygon",
    points: (40 + a, 0, 40 + b, 0, 100, 60 - b, 100, 60 - a),
    opacity: o,
  )),
  dots: range(10)
    .map(i => range(10).map(j => (i: i, j: j, o: 0.75 - calc.sqrt(i * i + j * j) * 0.085)))
    .flatten()
    .filter(it => it.o > 0.04)
    .map(it => (kind: "circle", points: (96 - it.i * 7, 4 + it.j * 7, 1.3), opacity: calc.round(it.o, digits: 2))),
)

// Answer every shape of every motif as one line of text:
// "<motif> <kind> <numbers> <opacity>".
#let mc-motif-lines() = (
  mc-motif-geometry
    .pairs()
    .map(((name, shapes)) => shapes.map(shape => (name, shape.kind, ..shape.points.map(str), str(shape.opacity)).join(" ")))
    .flatten()
)

// Answer a corner motif, tagged as an artefact and placed in its page corner
// so that it bleeds to both edges. Place it in the page background.
// - name: motif name, a key of mc-motif-geometry.
// - corner: page corner, for example top + right; the drawing is mirrored for the others.
// - size: side of the square motif.
// - dark: true on a dark surface; auto follows the render mode.
// - dx, dy: offset from the corner.
#let motif(name, corner, size, dark: auto, dx: 0pt, dy: 0pt) = {
  assert(name in mc-motif-geometry, message: "mcanouil: unknown motif \"" + name + "\"; use one of " + mc-motif-geometry.keys().join(", ") + ".")
  let colours = tokens()
  let on-dark = if dark == auto { mc-mode == "dark" } else { dark }
  let strength = if on-dark { 1 } else { 0.85 }
  let unit = size / 100
  let shade(colour, opacity) = colour.transparentize(100% - opacity * strength * 100%)
  let draw(shape) = {
    let p = shape.points
    let o = shape.opacity
    if shape.kind == "polygon" {
      let fill = gradient.linear(
        (shade(colours.at("accent-high"), o), 0%),
        (shade(colours.accent, o), 55%),
        (shade(colours.at("accent-low"), o), 100%),
        angle: 45deg,
      )
      place(top + left, polygon(fill: fill, stroke: none, ..p.chunks(2).map(((x, y)) => (x * unit, y * unit))))
    } else if shape.kind == "rect" {
      let colour = if on-dark { colours.at("accent-high") } else { colours.accent }
      place(top + left, dx: p.at(0) * unit, dy: p.at(1) * unit, rect(
        width: p.at(2) * unit,
        height: p.at(3) * unit,
        stroke: none,
        fill: shade(colour, o),
      ))
    } else {
      place(top + left, dx: (p.at(0) - p.at(2)) * unit, dy: (p.at(1) - p.at(2)) * unit, circle(
        radius: p.at(2) * unit,
        stroke: none,
        fill: shade(colours.at("accent-high"), o),
      ))
    }
  }
  let drawing = box(width: size, height: size, mc-motif-geometry.at(name).map(draw).join())
  let flipped = scale(
    x: if corner.x == left { -100% } else { 100% },
    y: if corner.y == bottom { -100% } else { 100% },
    drawing,
  )
  pdf.artifact(place(corner, dx: dx, dy: dy, flipped))
}
// mcanouil - Typst page chrome
// Page set-up shared by every document type: paper, margins, the header and
// footer, the gilded left edge of body pages, and the corner motif of the
// first page.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Page margins of every document type.
#let mc-page-margin = (top: 25mm, bottom: 25mm, left: 20mm, right: 20mm)

// Width of the gilded left edge of body pages.
#let mc-edge-width = 2mm

// Set up the pages of a document.
// - header, footer: content of the header and footer, from slots().
// - edge: draw the gilded left edge on body pages.
// - motif: corner motif of page 1, from motif(), or none. Page 1 then has no
//   header and no edge, so the motif never meets the header.
// - paper: paper size.
#let chrome-page(header, footer, edge: true, motif: none, paper: "a4", body) = {
  let colours = tokens()
  let first-surface() = motif != none and here().page() == 1
  let furniture(content) = text(size: 8pt, fill: colours.muted, content)
  set page(
    paper: paper,
    margin: mc-page-margin,
    fill: colours.paper,
    header: context if not first-surface() {
      block(width: 100%, inset: (bottom: 3pt), stroke: (bottom: 0.5pt + colours.line), furniture(header))
    },
    footer: furniture(footer),
    background: context if first-surface() { motif } else if edge { gilded-edge(mc-edge-width) },
  )
  body
}
// mcanouil - Typst logo
// The logo of the document: the user brand logo, or else the logo of the
// preset, with its alternative text.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Answer the logo as an image. Arguments are those of image(), for example height.
#let mc-logo(..args) = image(
  bytes((60, 63, 120, 109, 108, 32, 118, 101, 114, 115, 105, 111, 110, 61, 34, 49, 46, 48, 34, 32, 101, 110, 99, 111, 100, 105, 110, 103, 61, 34, 85, 84, 70, 45, 56, 34, 32, 115, 116, 97, 110, 100, 97, 108, 111, 110, 101, 61, 34, 110, 111, 34, 63, 62, 10, 60, 115, 118, 103, 10, 32, 32, 32, 118, 105, 101, 119, 66, 111, 120, 61, 34, 48, 32, 48, 32, 51, 48, 48, 32, 49, 50, 48, 34, 10, 32, 32, 32, 118, 101, 114, 115, 105, 111, 110, 61, 34, 49, 46, 49, 34, 10, 32, 32, 32, 105, 100, 61, 34, 115, 118, 103, 50, 34, 10, 32, 32, 32, 104, 101, 105, 103, 104, 116, 61, 34, 49, 50, 48, 34, 10, 32, 32, 32, 119, 105, 100, 116, 104, 61, 34, 51, 48, 48, 34, 10, 32, 32, 32, 115, 111, 100, 105, 112, 111, 100, 105, 58, 100, 111, 99, 110, 97, 109, 101, 61, 34, 108, 111, 103, 111, 45, 108, 105, 103, 104, 116, 46, 115, 118, 103, 34, 10, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 118, 101, 114, 115, 105, 111, 110, 61, 34, 49, 46, 52, 46, 51, 32, 40, 48, 100, 49, 53, 102, 55, 53, 44, 32, 50, 48, 50, 53, 45, 49, 50, 45, 50, 53, 41, 34, 10, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 101, 120, 112, 111, 114, 116, 45, 102, 105, 108, 101, 110, 97, 109, 101, 61, 34, 108, 111, 103, 111, 45, 108, 105, 103, 104, 116, 46, 112, 110, 103, 34, 10, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 101, 120, 112, 111, 114, 116, 45, 120, 100, 112, 105, 61, 34, 57, 53, 46, 48, 54, 51, 49, 49, 34, 10, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 101, 120, 112, 111, 114, 116, 45, 121, 100, 112, 105, 61, 34, 57, 53, 46, 48, 54, 51, 49, 49, 34, 10, 32, 32, 32, 120, 109, 108, 110, 115, 58, 105, 110, 107, 115, 99, 97, 112, 101, 61, 34, 104, 116, 116, 112, 58, 47, 47, 119, 119, 119, 46, 105, 110, 107, 115, 99, 97, 112, 101, 46, 111, 114, 103, 47, 110, 97, 109, 101, 115, 112, 97, 99, 101, 115, 47, 105, 110, 107, 115, 99, 97, 112, 101, 34, 10, 32, 32, 32, 120, 109, 108, 110, 115, 58, 115, 111, 100, 105, 112, 111, 100, 105, 61, 34, 104, 116, 116, 112, 58, 47, 47, 115, 111, 100, 105, 112, 111, 100, 105, 46, 115, 111, 117, 114, 99, 101, 102, 111, 114, 103, 101, 46, 110, 101, 116, 47, 68, 84, 68, 47, 115, 111, 100, 105, 112, 111, 100, 105, 45, 48, 46, 100, 116, 100, 34, 10, 32, 32, 32, 120, 109, 108, 110, 115, 61, 34, 104, 116, 116, 112, 58, 47, 47, 119, 119, 119, 46, 119, 51, 46, 111, 114, 103, 47, 50, 48, 48, 48, 47, 115, 118, 103, 34, 10, 32, 32, 32, 120, 109, 108, 110, 115, 58, 115, 118, 103, 61, 34, 104, 116, 116, 112, 58, 47, 47, 119, 119, 119, 46, 119, 51, 46, 111, 114, 103, 47, 50, 48, 48, 48, 47, 115, 118, 103, 34, 62, 10, 32, 32, 60, 115, 111, 100, 105, 112, 111, 100, 105, 58, 110, 97, 109, 101, 100, 118, 105, 101, 119, 10, 32, 32, 32, 32, 32, 105, 100, 61, 34, 110, 97, 109, 101, 100, 118, 105, 101, 119, 50, 34, 10, 32, 32, 32, 32, 32, 112, 97, 103, 101, 99, 111, 108, 111, 114, 61, 34, 35, 53, 48, 53, 48, 53, 48, 34, 10, 32, 32, 32, 32, 32, 98, 111, 114, 100, 101, 114, 99, 111, 108, 111, 114, 61, 34, 35, 101, 101, 101, 101, 101, 101, 34, 10, 32, 32, 32, 32, 32, 98, 111, 114, 100, 101, 114, 111, 112, 97, 99, 105, 116, 121, 61, 34, 49, 34, 10, 32, 32, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 115, 104, 111, 119, 112, 97, 103, 101, 115, 104, 97, 100, 111, 119, 61, 34, 48, 34, 10, 32, 32, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 112, 97, 103, 101, 111, 112, 97, 99, 105, 116, 121, 61, 34, 48, 34, 10, 32, 32, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 112, 97, 103, 101, 99, 104, 101, 99, 107, 101, 114, 98, 111, 97, 114, 100, 61, 34, 48, 34, 10, 32, 32, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 100, 101, 115, 107, 99, 111, 108, 111, 114, 61, 34, 35, 53, 48, 53, 48, 53, 48, 34, 10, 32, 32, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 122, 111, 111, 109, 61, 34, 51, 46, 48, 55, 49, 53, 54, 50, 55, 34, 10, 32, 32, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 99, 120, 61, 34, 49, 49, 54, 46, 55, 49, 53, 56, 52, 34, 10, 32, 32, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 99, 121, 61, 34, 54, 52, 46, 57, 53, 48, 54, 53, 51, 34, 10, 32, 32, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 119, 105, 110, 100, 111, 119, 45, 119, 105, 100, 116, 104, 61, 34, 49, 53, 49, 50, 34, 10, 32, 32, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 119, 105, 110, 100, 111, 119, 45, 104, 101, 105, 103, 104, 116, 61, 34, 56, 50, 56, 34, 10, 32, 32, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 119, 105, 110, 100, 111, 119, 45, 120, 61, 34, 48, 34, 10, 32, 32, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 119, 105, 110, 100, 111, 119, 45, 121, 61, 34, 49, 51, 49, 34, 10, 32, 32, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 119, 105, 110, 100, 111, 119, 45, 109, 97, 120, 105, 109, 105, 122, 101, 100, 61, 34, 48, 34, 10, 32, 32, 32, 32, 32, 105, 110, 107, 115, 99, 97, 112, 101, 58, 99, 117, 114, 114, 101, 110, 116, 45, 108, 97, 121, 101, 114, 61, 34, 115, 118, 103, 50, 34, 32, 47, 62, 10, 32, 32, 60, 100, 101, 102, 115, 10, 32, 32, 32, 32, 32, 105, 100, 61, 34, 100, 101, 102, 115, 49, 34, 62, 10, 32, 32, 32, 32, 60, 115, 116, 121, 108, 101, 10, 32, 32, 32, 32, 32, 32, 32, 105, 100, 61, 34, 115, 116, 121, 108, 101, 49, 34, 62, 10, 32, 32, 32, 32, 32, 32, 46, 102, 105, 114, 115, 116, 110, 97, 109, 101, 32, 123, 10, 32, 32, 32, 32, 32, 32, 32, 32, 102, 111, 110, 116, 45, 102, 97, 109, 105, 108, 121, 58, 32, 39, 71, 101, 111, 114, 103, 105, 97, 39, 44, 32, 39, 84, 105, 109, 101, 115, 32, 78, 101, 119, 32, 82, 111, 109, 97, 110, 39, 44, 32, 115, 101, 114, 105, 102, 59, 10, 32, 32, 32, 32, 32, 32, 32, 32, 102, 111, 110, 116, 45, 115, 105, 122, 101, 58, 32, 51, 56, 112, 120, 59, 10, 32, 32, 32, 32, 32, 32, 32, 32, 102, 111, 110, 116, 45, 119, 101, 105, 103, 104, 116, 58, 32, 51, 48, 48, 59, 10, 32, 32, 32, 32, 32, 32, 32, 32, 102, 111, 110, 116, 45, 115, 116, 121, 108, 101, 58, 32, 105, 116, 97, 108, 105, 99, 59, 10, 32, 32, 32, 32, 32, 32, 32, 32, 108, 101, 116, 116, 101, 114, 45, 115, 112, 97, 99, 105, 110, 103, 58, 32, 50, 112, 120, 59, 10, 32, 32, 32, 32, 32, 32, 125, 10, 32, 32, 32, 32, 32, 32, 46, 108, 97, 115, 116, 110, 97, 109, 101, 32, 123, 10, 32, 32, 32, 32, 32, 32, 32, 32, 102, 111, 110, 116, 45, 102, 97, 109, 105, 108, 121, 58, 32, 39, 71, 101, 111, 114, 103, 105, 97, 39, 44, 32, 39, 84, 105, 109, 101, 115, 32, 78, 101, 119, 32, 82, 111, 109, 97, 110, 39, 44, 32, 115, 101, 114, 105, 102, 59, 10, 32, 32, 32, 32, 32, 32, 32, 32, 102, 111, 110, 116, 45, 115, 105, 122, 101, 58, 32, 50, 50, 112, 120, 59, 10, 32, 32, 32, 32, 32, 32, 32, 32, 102, 111, 110, 116, 45, 119, 101, 105, 103, 104, 116, 58, 32, 52, 48, 48, 59, 10, 32, 32, 32, 32, 32, 32, 32, 32, 108, 101, 116, 116, 101, 114, 45, 115, 112, 97, 99, 105, 110, 103, 58, 32, 49, 49, 112, 120, 59, 10, 32, 32, 32, 32, 32, 32, 125, 10, 32, 32, 32, 32, 60, 47, 115, 116, 121, 108, 101, 62, 10, 32, 32, 60, 47, 100, 101, 102, 115, 62, 10, 32, 32, 60, 33, 45, 45, 32, 70, 105, 114, 115, 116, 32, 110, 97, 109, 101, 32, 45, 45, 62, 10, 32, 32, 60, 33, 45, 45, 32, 67, 101, 110, 116, 114, 101, 32, 115, 101, 112, 97, 114, 97, 116, 111, 114, 32, 45, 32, 116, 119, 111, 32, 108, 105, 110, 101, 115, 32, 119, 105, 116, 104, 32, 103, 97, 112, 32, 102, 111, 114, 32, 99, 105, 114, 99, 108, 101, 32, 45, 45, 62, 10, 32, 32, 60, 33, 45, 45, 32, 76, 97, 115, 116, 32, 110, 97, 109, 101, 32, 45, 45, 62, 10, 32, 32, 60, 116, 101, 120, 116, 10, 32, 32, 32, 32, 32, 120, 61, 34, 49, 53, 53, 46, 49, 53, 51, 51, 56, 34, 10, 32, 32, 32, 32, 32, 121, 61, 34, 53, 48, 46, 51, 50, 53, 55, 55, 49, 34, 10, 32, 32, 32, 32, 32, 116, 101, 120, 116, 45, 97, 110, 99, 104, 111, 114, 61, 34, 109, 105, 100, 100, 108, 101, 34, 10, 32, 32, 32, 32, 32, 99, 108, 97, 115, 115, 61, 34, 102, 105, 114, 115, 116, 110, 97, 109, 101, 34, 10, 32, 32, 32, 32, 32, 102, 105, 108, 108, 61, 34, 35, 51, 51, 51, 51, 51, 51, 34, 10, 32, 32, 32, 32, 32, 105, 100, 61, 34, 116, 101, 120, 116, 49, 34, 10, 32, 32, 32, 32, 32, 115, 116, 121, 108, 101, 61, 34, 102, 111, 110, 116, 45, 115, 105, 122, 101, 58, 52, 50, 46, 54, 54, 54, 55, 112, 120, 59, 115, 116, 114, 111, 107, 101, 45, 119, 105, 100, 116, 104, 58, 48, 46, 57, 56, 48, 49, 49, 49, 59, 102, 105, 108, 108, 58, 35, 102, 97, 102, 97, 102, 97, 59, 102, 105, 108, 108, 45, 111, 112, 97, 99, 105, 116, 121, 58, 49, 34, 62, 60, 116, 115, 112, 97, 110, 10, 32, 32, 32, 32, 32, 32, 32, 115, 116, 121, 108, 101, 61, 34, 102, 111, 110, 116, 45, 115, 116, 121, 108, 101, 58, 110, 111, 114, 109, 97, 108, 59, 102, 111, 110, 116, 45, 118, 97, 114, 105, 97, 110, 116, 58, 110, 111, 114, 109, 97, 108, 59, 102, 111, 110, 116, 45, 119, 101, 105, 103, 104, 116, 58, 110, 111, 114, 109, 97, 108, 59, 102, 111, 110, 116, 45, 115, 116, 114, 101, 116, 99, 104, 58, 110, 111, 114, 109, 97, 108, 59, 102, 111, 110, 116, 45, 115, 105, 122, 101, 58, 52, 50, 46, 54, 54, 54, 55, 112, 120, 59, 102, 111, 110, 116, 45, 102, 97, 109, 105, 108, 121, 58, 39, 68, 97, 110, 99, 105, 110, 103, 32, 83, 99, 114, 105, 112, 116, 39, 59, 45, 105, 110, 107, 115, 99, 97, 112, 101, 45, 102, 111, 110, 116, 45, 115, 112, 101, 99, 105, 102, 105, 99, 97, 116, 105, 111, 110, 58, 39, 68, 97, 110, 99, 105, 110, 103, 32, 83, 99, 114, 105, 112, 116, 39, 59, 102, 105, 108, 108, 58, 35, 102, 97, 102, 97, 102, 97, 59, 102, 105, 108, 108, 45, 111, 112, 97, 99, 105, 116, 121, 58, 49, 34, 10, 32, 32, 32, 32, 32, 32, 32, 105, 100, 61, 34, 116, 115, 112, 97, 110, 49, 34, 62, 77, 105, 99, 107, 97, 195, 171, 108, 60, 47, 116, 115, 112, 97, 110, 62, 60, 47, 116, 101, 120, 116, 62, 10, 32, 32, 60, 108, 105, 110, 101, 10, 32, 32, 32, 32, 32, 120, 49, 61, 34, 49, 48, 54, 46, 57, 51, 57, 51, 54, 34, 10, 32, 32, 32, 32, 32, 121, 49, 61, 34, 54, 51, 46, 50, 49, 55, 55, 51, 49, 34, 10, 32, 32, 32, 32, 32, 120, 50, 61, 34, 49, 53, 50, 46, 57, 51, 57, 51, 54, 34, 10, 32, 32, 32, 32, 32, 121, 50, 61, 34, 54, 51, 46, 50, 49, 55, 55, 51, 49, 34, 10, 32, 32, 32, 32, 32, 115, 116, 114, 111, 107, 101, 61, 34, 35, 51, 51, 51, 51, 51, 51, 34, 10, 32, 32, 32, 32, 32, 115, 116, 114, 111, 107, 101, 45, 119, 105, 100, 116, 104, 61, 34, 48, 46, 55, 53, 34, 10, 32, 32, 32, 32, 32, 105, 100, 61, 34, 108, 105, 110, 101, 49, 34, 10, 32, 32, 32, 32, 32, 115, 116, 121, 108, 101, 61, 34, 115, 116, 114, 111, 107, 101, 58, 35, 102, 97, 102, 97, 102, 97, 59, 115, 116, 114, 111, 107, 101, 45, 111, 112, 97, 99, 105, 116, 121, 58, 49, 34, 32, 47, 62, 10, 32, 32, 60, 108, 105, 110, 101, 10, 32, 32, 32, 32, 32, 120, 49, 61, 34, 49, 54, 48, 46, 57, 51, 57, 51, 54, 34, 10, 32, 32, 32, 32, 32, 121, 49, 61, 34, 54, 51, 46, 50, 49, 55, 55, 51, 49, 34, 10, 32, 32, 32, 32, 32, 120, 50, 61, 34, 50, 48, 54, 46, 57, 51, 57, 51, 54, 34, 10, 32, 32, 32, 32, 32, 121, 50, 61, 34, 54, 51, 46, 50, 49, 55, 55, 51, 49, 34, 10, 32, 32, 32, 32, 32, 115, 116, 114, 111, 107, 101, 61, 34, 35, 51, 51, 51, 51, 51, 51, 34, 10, 32, 32, 32, 32, 32, 115, 116, 114, 111, 107, 101, 45, 119, 105, 100, 116, 104, 61, 34, 48, 46, 55, 53, 34, 10, 32, 32, 32, 32, 32, 105, 100, 61, 34, 108, 105, 110, 101, 50, 34, 10, 32, 32, 32, 32, 32, 115, 116, 121, 108, 101, 61, 34, 115, 116, 114, 111, 107, 101, 58, 35, 102, 97, 102, 97, 102, 97, 59, 115, 116, 114, 111, 107, 101, 45, 111, 112, 97, 99, 105, 116, 121, 58, 49, 34, 32, 47, 62, 10, 32, 32, 60, 99, 105, 114, 99, 108, 101, 10, 32, 32, 32, 32, 32, 99, 120, 61, 34, 49, 53, 54, 46, 57, 51, 57, 51, 54, 34, 10, 32, 32, 32, 32, 32, 99, 121, 61, 34, 54, 51, 46, 50, 49, 55, 55, 51, 49, 34, 10, 32, 32, 32, 32, 32, 114, 61, 34, 50, 46, 53, 34, 10, 32, 32, 32, 32, 32, 102, 105, 108, 108, 61, 34, 35, 51, 51, 51, 51, 51, 51, 34, 10, 32, 32, 32, 32, 32, 105, 100, 61, 34, 99, 105, 114, 99, 108, 101, 50, 34, 10, 32, 32, 32, 32, 32, 115, 116, 121, 108, 101, 61, 34, 102, 105, 108, 108, 58, 35, 102, 97, 102, 97, 102, 97, 59, 102, 105, 108, 108, 45, 111, 112, 97, 99, 105, 116, 121, 58, 49, 34, 32, 47, 62, 10, 32, 32, 60, 116, 101, 120, 116, 10, 32, 32, 32, 32, 32, 120, 61, 34, 49, 52, 57, 46, 50, 50, 55, 57, 55, 34, 10, 32, 32, 32, 32, 32, 121, 61, 34, 57, 56, 46, 55, 54, 56, 56, 52, 53, 34, 10, 32, 32, 32, 32, 32, 116, 101, 120, 116, 45, 97, 110, 99, 104, 111, 114, 61, 34, 109, 105, 100, 100, 108, 101, 34, 10, 32, 32, 32, 32, 32, 99, 108, 97, 115, 115, 61, 34, 108, 97, 115, 116, 110, 97, 109, 101, 34, 10, 32, 32, 32, 32, 32, 102, 105, 108, 108, 61, 34, 35, 51, 51, 51, 51, 51, 51, 34, 10, 32, 32, 32, 32, 32, 105, 100, 61, 34, 116, 101, 120, 116, 50, 34, 10, 32, 32, 32, 32, 32, 115, 116, 121, 108, 101, 61, 34, 102, 111, 110, 116, 45, 115, 105, 122, 101, 58, 52, 48, 46, 54, 51, 51, 53, 112, 120, 59, 115, 116, 114, 111, 107, 101, 45, 119, 105, 100, 116, 104, 58, 49, 46, 48, 54, 57, 51, 59, 102, 105, 108, 108, 58, 35, 102, 97, 102, 97, 102, 97, 59, 102, 105, 108, 108, 45, 111, 112, 97, 99, 105, 116, 121, 58, 49, 34, 62, 60, 116, 115, 112, 97, 110, 10, 32, 32, 32, 32, 32, 32, 32, 115, 116, 121, 108, 101, 61, 34, 102, 111, 110, 116, 45, 115, 116, 121, 108, 101, 58, 110, 111, 114, 109, 97, 108, 59, 102, 111, 110, 116, 45, 118, 97, 114, 105, 97, 110, 116, 58, 110, 111, 114, 109, 97, 108, 59, 102, 111, 110, 116, 45, 119, 101, 105, 103, 104, 116, 58, 110, 111, 114, 109, 97, 108, 59, 102, 111, 110, 116, 45, 115, 116, 114, 101, 116, 99, 104, 58, 110, 111, 114, 109, 97, 108, 59, 102, 111, 110, 116, 45, 102, 97, 109, 105, 108, 121, 58, 39, 65, 108, 101, 103, 114, 101, 121, 97, 32, 83, 67, 39, 59, 45, 105, 110, 107, 115, 99, 97, 112, 101, 45, 102, 111, 110, 116, 45, 115, 112, 101, 99, 105, 102, 105, 99, 97, 116, 105, 111, 110, 58, 39, 65, 108, 101, 103, 114, 101, 121, 97, 32, 83, 67, 39, 59, 102, 105, 108, 108, 58, 35, 102, 97, 102, 97, 102, 97, 59, 102, 105, 108, 108, 45, 111, 112, 97, 99, 105, 116, 121, 58, 49, 34, 10, 32, 32, 32, 32, 32, 32, 32, 105, 100, 61, 34, 116, 115, 112, 97, 110, 50, 34, 62, 67, 65, 78, 79, 85, 73, 76, 60, 47, 116, 115, 112, 97, 110, 62, 60, 47, 116, 101, 120, 116, 62, 10, 60, 47, 115, 118, 103, 62, 10,)),
  format: "svg",
  alt: "Mickaël Canouil logo",
  ..args,
)
// mcanouil - Typst authors
// The display of an author: the name, the degrees in small type, the
// affiliation numbers, an ORCID badge with alternative text, and the marks
// for the corresponding author, equal contribution and a deceased author.
// Marks that only repeat a legend line are artefacts.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Path data of the ORCID glyph and of its disc, in a 32 by 32 view box.
#let mc-orcid-disc = "M32 16c0 8.837-7.163 16-16 16-8.838 0-16-7.163-16-16C0 7.162 7.162 0 16 0c8.837 0 16 7.162 16 16Z"
#let mc-orcid-glyph = "M18.813 9.637h-5.45v13.9h5.474c4.555 0 7.35-3.378 7.35-6.95 0-1.635-.562-3.372-1.77-4.704-1.215-1.336-3.065-2.246-5.605-2.246ZM18.6 21.3h-2.813v-9.425H18.5c1.823 0 3.12.552 3.96 1.4.842.849 1.252 2.021 1.252 3.312 0 .784-.239 1.967-.993 2.948-.745.969-2.01 1.765-4.119 1.765ZM8.363 9.675v13.887h2.425V9.675H8.363ZM9.575 8.65c.84 0 1.513-.689 1.513-1.513 0-.823-.673-1.512-1.513-1.512-.838 0-1.512.674-1.512 1.513 0 .823.672 1.512 1.512 1.512Z"

// Answer an ORCID badge: an accent disc with a paper glyph, whose alternative
// text is "ORCID <id>".
#let orcid-badge(id) = {
  let colours = tokens()
  let svg = (
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 32 32\">",
    "<path fill=\"" + colours.accent.to-hex() + "\" d=\"" + mc-orcid-disc + "\"/>",
    "<path fill=\"" + colours.paper.to-hex() + "\" fill-rule=\"evenodd\" d=\"" + mc-orcid-glyph + "\"/>",
    "</svg>",
  ).join()
  box(
    height: 0.8em,
    baseline: 0.1em,
    image(bytes(svg), format: "svg", alt: mc-labels.at("mcanouil-author-orcid") + " " + id),
  )
}

// Answer the envelope mark of the corresponding author, drawn as an artefact.
#let envelope-mark() = {
  let colours = tokens()
  let line = 0.5pt + colours.ink
  pdf.artifact(box(
    width: 0.9em,
    height: 0.62em,
    baseline: 0.05em,
    stroke: line,
    radius: 0.5pt,
    place(top + left, polygon(stroke: line, (0em, 0em), (0.45em, 0.36em), (0.9em, 0em))),
  ))
}

// Answer the line of one author.
// - author: dictionary with name, degrees, affiliations, orcid, corresponding,
//   equal and deceased.
#let author-line(author) = {
  let colours = tokens()
  let parts = (
    text(weight: "bold", author.name),
    if author.degrees.len() > 0 { text(size: 0.8em, fill: colours.muted, author.degrees.join(", ")) },
    if author.affiliations.len() > 0 { super(author.affiliations.map(str).join(",")) },
    if author.corresponding { envelope-mark() },
    if author.orcid != "" { orcid-badge(author.orcid) },
    if author.equal { [\*] },
    if author.deceased { sym.dagger },
  )
  parts.filter(part => part != none).join(h(0.25em))
}

// Answer the numbered affiliation lines.
#let affiliation-lines(affiliations) = (
  affiliations
    .enumerate(start: 1)
    .map(entry => [#super(str(entry.at(0))) #entry.at(1)])
    .join(linebreak())
)

// Answer the legend lines of the marks that the authors use, one for each mark.
// - email: email of the corresponding author, or "".
#let author-legends(authors, email: "") = {
  let legends = ()
  if authors.any(author => author.corresponding) {
    let address = if email != "" { ": " + email }
    legends.push([#envelope-mark()#h(0.3em)#mc-labels.at("mcanouil-author-corresponding")#address])
  }
  if authors.any(author => author.equal) {
    legends.push([\* #mc-labels.at("mcanouil-author-equal")])
  }
  if authors.any(author => author.deceased) {
    legends.push([#sym.dagger #mc-labels.at("mcanouil-author-deceased")])
  }
  legends.join(linebreak())
}
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
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)

#let mc-fonts = (
  base: ("Source Serif 4", ),
  headings: ("Source Serif 4", ),
  monospace: ("Fira Code", ),
)

#let mc-authors = (authors: ((name: "Mickaël Canouil", degrees: ("Ph.D.",), affiliations: (1, 2,), orcid: "0000-0002-3396-4549", corresponding: true, equal: true, deceased: false), (name: "Ana Author", degrees: ("M.Sc.",), affiliations: (1,), orcid: "0000-0001-2345-6789", corresponding: false, equal: true, deceased: false), (name: "Ben Writer", degrees: ("M.D.", "Ph.D.",), affiliations: (2,), orcid: "", corresponding: false, equal: false, deceased: false), (name: "Cleo Reader", degrees: (), affiliations: (1,), orcid: "", corresponding: false, equal: false, deceased: false), (name: "Dan Plotter", degrees: (), affiliations: (2,), orcid: "", corresponding: false, equal: false, deceased: false), (name: "Eve Fitter", degrees: (), affiliations: (1,), orcid: "", corresponding: false, equal: false, deceased: false), (name: "Finn Checker", degrees: (), affiliations: (2,), orcid: "", corresponding: false, equal: false, deceased: false), (name: "Gus Elder", degrees: (), affiliations: (2,), orcid: "", corresponding: false, equal: false, deceased: true),), affiliations: ("Inserm U1283, Department of Genomics, Lille, France", "Imperial College London, School of Public Health, London, UK",), email: "contact@example.org")

#show: doc => article(
  title: [Survival analysis of the cohort],
  subtitle: [A 24-week follow-up],
  date: [2026-11-11],
  authors: mc-authors.authors,
  affiliations: mc-authors.affiliations,
  email: mc-authors.email,
  abstract: [This is the abstract of the study.],
  abstract-title: [Abstract],
  keywords: ([survival], [cohort], ),
  mode: "light",
  tokens: tokens(),
  fonts: mc-fonts,
  header: slots(left: [Survival analysis of the cohort], centre: [], right: [#chapter-title()]),
  footer: slots(left: [Mickaël Canouil, Ana Author, Ben Writer, Cleo Reader, Dan Plotter, Eve Fitter, Finn Checker, Gus Elder], centre: [], right: [#page-number()]),
  motif-name: mc-motif,
  doc,
)

// code-window: adaptive colour helpers (derive UI tones from page background)
#let _cw-page-bg() = {
  let f = page.fill
  if type(f) == color { f } else { luma(255) }
}

#let _cw-fg(bg) = {
  let comps = bg.components(alpha: false)
  let lum = if comps.len() == 1 {
    comps.at(0) / 100%
  } else {
    0.2126 * comps.at(0) / 100% + 0.7152 * comps.at(1) / 100% + 0.0722 * comps.at(2) / 100%
  }
  if lum < 0.5 { luma(255) } else { luma(0) }
}
// code-window: annotation state passed to Skylighting via Typst state
#let _cw-annotations = state("cw-annotations", none)

// Derive a contrasting annotation colour from a background fill.
// Light backgrounds get dark circles; dark backgrounds get light circles.
// Uses ITU-R BT.709 luminance coefficients, matching quarto-cli PR #14170.
#let code-window-annote-colour(bg) = {
  if type(bg) == color {
    let comps = bg.components(alpha: false)
    let lum = if comps.len() == 1 {
      comps.at(0) / 100%
    } else {
      0.2126 * comps.at(0) / 100% + 0.7152 * comps.at(1) / 100% + 0.0722 * comps.at(2) / 100%
    }
    if lum < 0.5 { luma(200) } else { luma(60) }
  } else {
    luma(60)
  }
}

#let code-window-circled-number(n, bg-colour: none) = {
  let c = if bg-colour != none { code-window-annote-colour(bg-colour) } else { luma(120) }
  box(baseline: 20%, circle(
    radius: 4.5pt,
    stroke: 0.5pt + c,
  )[#set text(size: 5.5pt, fill: c); #align(center + horizon, str(n))])
}

#let code-window-annotation-item(block-id, n, content) = {
  let lbl-prefix = "cw-" + str(block-id) + "-"
  context {
    let target = label(lbl-prefix + "line-" + str(n))
    let has-target = query(target).len() > 0
    [#block(above: 0.4em, below: 0.4em)[
      #if has-target {
        link(target)[#code-window-circled-number(n)]
      } else {
        code-window-circled-number(n)
      }
      #h(0.4em)
      #content
    ] #label(lbl-prefix + "item-" + str(n))]
  }
}

#let code-window-annotated-content(content, annotations: (:), bg-colour: none, block-id: 0) = {
  if annotations.len() > 0 {
    _cw-annotations.update((annotations: annotations, bg-colour: bg-colour, block-id: block-id))
    content
    _cw-annotations.update(none)
  } else {
    content
  }
}
#let code-window(
  content,
  filename: none,
  is-auto: false,
  style: "macos",
  annotations: (:),
  bg-colour: none,
  block-id: 0,
  lines-label: none,
) = {
  context {
  let page-bg = _cw-page-bg()
  let fg = _cw-fg(page-bg)
  let border-colour = color.mix((fg, 15%), (page-bg, 85%))
  let surface-fill = color.mix((fg, 5%), (page-bg, 95%))
  let muted-colour = color.mix((fg, 50%), (page-bg, 50%))
  let label-colour = color.mix((fg, 65%), (page-bg, 35%))

  let filename-label = if filename != none {
    text(
      size: if is-auto { 0.7em } else { 0.85em },
      weight: 500,
      fill: label-colour,
      if is-auto { upper(filename) } else { filename },
    )
  }

  let lines-chip = if lines-label != none {
    box(
      inset: (x: 0.4em, y: 0.05em),
      outset: (y: 0.15em),
      radius: 3pt,
      fill: color.mix((fg, 10%), (page-bg, 90%)),
      stroke: 0.5pt + border-colour,
      text(size: 0.7em, weight: 500, fill: label-colour, lines-label),
    )
  }

  let traffic-lights = box(
    inset: (right: 0.5em),
    stack(
      dir: ltr,
      spacing: 0.425em,
      circle(radius: 0.425em, fill: rgb("#ff5f56"), stroke: none),
      circle(radius: 0.425em, fill: rgb("#ffbd2e"), stroke: none),
      circle(radius: 0.425em, fill: rgb("#27c93f"), stroke: none),
    ),
  )

  let window-buttons = box(
    inset: (left: 0.5em),
    {
      set line(stroke: 1pt + muted-colour)
      stack(
        dir: ltr,
        spacing: 0.8em,
        // Minimise (horizontal line)
        box(width: 0.6em, height: 0.6em, align(horizon, line(length: 100%))),
        // Maximise (square)
        box(width: 0.6em, height: 0.6em, stroke: 1pt + muted-colour),
        // Close (x)
        box(width: 0.6em, height: 0.6em, {
          place(line(start: (0%, 0%), end: (100%, 100%)))
          place(line(start: (100%, 0%), end: (0%, 100%)))
        }),
      )
    },
  )

  let _label-with-chip = if lines-chip != none {
    stack(dir: ltr, spacing: 0.5em, filename-label, lines-chip)
  } else {
    filename-label
  }

  let title-bar = if style == "macos" {
    grid(
      columns: (auto, 1fr),
      align: (left + horizon, right + horizon),
      gutter: 0.5em,
      stroke: 0pt,
      traffic-lights,
      _label-with-chip,
    )
  } else if style == "windows" {
    grid(
      columns: (1fr, auto),
      align: (left + horizon, right + horizon),
      gutter: 0.5em,
      stroke: 0pt,
      _label-with-chip,
      window-buttons,
    )
  } else {
    // default: plain filename, left-aligned
    _label-with-chip
  }

  block(
    width: 100%,
    stroke: 1pt + border-colour,
    radius: 8pt,
    clip: true,
    {
      block(
        width: 100%,
        fill: surface-fill,
        inset: (x: 1em, y: 0.6em),
        below: 0pt,
        radius: 0pt,
        stroke: (bottom: 1pt + border-colour),
        sticky: true,
        title-bar,
      )
      // Strip code block chrome so content fills flush against the window body.
      // set block() provides defaults for Skylighting blocks (explicit fill preserved).
      // show raw overrides the document-level raw block styling (fill, radius).
      {
        set block(
          width: 100%,
          inset: 8pt,
          radius: 0pt,
          stroke: none,
          above: 0pt,
          below: 0pt,
        )
        show raw.where(block: true): set block(
          fill: none,
          width: 100%,
          radius: 0pt,
          stroke: none,
          above: 0pt,
          below: 0pt,
        )
        code-window-annotated-content(
          content,
          annotations: annotations,
          bg-colour: bg-colour,
          block-id: block-id,
        )
      }
    },
  )
  }
}
// skylighting-typst-fix override
#let Skylighting(
  fill: none,
  number: false,
  start: 1,
  sourcelines,
) = {
  let bgcolor = if fill != none { fill } else { rgb("#f1f3f5") }
  let has-gutter = start + sourcelines.len() > 999

  context {
    let _page-bg = _cw-page-bg()
    let _fg = _cw-fg(_page-bg)
    let _border-colour = color.mix((_fg, 15%), (_page-bg, 85%))
    let annot-data = _cw-annotations.get()
    let blocks = []
    let lnum = start - 1
    let seen-annotes = (:)

    for ln in sourcelines {
      lnum = lnum + 1
      if number {
        blocks = blocks + box(
          width: if has-gutter { 30pt } else { 24pt },
          text([ #lnum ]),
        )
      }

      if annot-data != none {
        let annot-num = annot-data.annotations.at(str(lnum), default: none)
        if annot-num != none {
          let lbl-prefix = "cw-" + str(annot-data.block-id) + "-"
          if str(annot-num) not in seen-annotes {
            seen-annotes.insert(str(annot-num), true)
            blocks = blocks + box(width: 100%)[
              #ln
              #h(1fr)
              #link(label(lbl-prefix + "item-" + str(annot-num)))[
                #code-window-circled-number(annot-num, bg-colour: annot-data.bg-colour)
              ]
              #label(lbl-prefix + "line-" + str(annot-num))
            ]
          } else {
            blocks = blocks + box(width: 100%)[
              #ln
              #h(1fr)
              #link(label(lbl-prefix + "item-" + str(annot-num)))[
                #code-window-circled-number(annot-num, bg-colour: annot-data.bg-colour)
              ]
            ]
          }
        } else {
          blocks = blocks + ln
        }
      } else {
        blocks = blocks + ln
      }
      blocks = blocks + EndLine()
    }

    block(
      fill: bgcolor,
      width: 100%,
      inset: 8pt,
      radius: 2pt,
      stroke: 0.5pt + _border-colour,
      blocks,
    )
  }
}
= Introduction
<introduction>
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis sagittis posuere ligula sit amet lacinia. Duis dignissim pellentesque magna, rhoncus congue sapien finibus mollis. Ut eu sem laoreet, vehicula ipsum in, convallis erat. Vestibulum magna sem, blandit pulvinar augue sit amet, auctor malesuada sapien. Nullam faucibus leo eget eros hendrerit, non laoreet ipsum lacinia. Curabitur cursus diam elit, non tempus ante volutpat a. Quisque hendrerit blandit purus non fringilla. Integer sit amet elit viverra ante dapibus semper. Vestibulum viverra rutrum enim, at luctus enim posuere eu. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus.

Nunc ac dignissim magna. Vestibulum vitae egestas elit. Proin feugiat leo quis ante condimentum, eu ornare mauris feugiat. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Mauris cursus laoreet ex, dignissim bibendum est posuere iaculis. Suspendisse et maximus elit. In fringilla gravida ornare. Aenean id lectus pulvinar, sagittis felis nec, rutrum risus. Nam vel neque eu arcu blandit fringilla et in quam. Aliquam luctus est sit amet vestibulum eleifend. Phasellus elementum sagittis molestie. Proin tempor lorem arcu, at condimentum purus volutpat eu. Fusce et pellentesque ligula. Pellentesque id tellus at erat luctus fringilla. Suspendisse potenti.
