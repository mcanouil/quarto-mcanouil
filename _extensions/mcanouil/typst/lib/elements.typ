// mcanouil - Typst structured elements
// Quarto's structured elements in the style of the preset, all colours from
// the tokens: callouts, code, tables, highlights, rules, footnotes, term
// lists, theorems and proofs, task lists, keys and details. Quarto's own
// definitions come before the template, so a function here with the same
// name, such as callout or a highlighting token, takes the place of Quarto's.
// lua/typst-elements.lua writes the calls to the mc- functions. Glyphs,
// motifs and markers are tagged as artefacts.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Corner radius of the boxes of the preset, as --mc-radius in HTML.
#let mc-radius = (gold: 5pt, mono: 0pt, quarto: 6pt, terminal: 0pt).at(mc-preset)

// Corner radius of the small boxes in a line of text: inline code, keys and
// task boxes.
#let mc-small-radius = calc.min(mc-radius, 3pt)

// Highlighting: the colour of each token class from the tokens, as in the HTML
// style sheet, so that every token reads on the tint of the code blocks in
// every scheme.
#let mc-tok(name, s, ..style) = text(fill: mc-tokens.at(name), ..style, raw(s))
#let AlertTok(s) = mc-tok("important-text", s)
#let AnnotationTok(s) = mc-tok("muted", s)
#let AttributeTok(s) = mc-tok("note-text", s)
#let BaseNTok(s) = mc-tok("warning-text", s)
#let BuiltInTok(s) = mc-tok("link", s)
#let CharTok(s) = mc-tok("warning-text", s)
#let CommentTok(s) = mc-tok("muted", s)
#let CommentVarTok(s) = mc-tok("muted", s, style: "italic")
#let ConstantTok(s) = mc-tok("caution-text", s)
#let ControlFlowTok(s) = mc-tok("accent-text", s, weight: "bold")
#let DataTypeTok(s) = mc-tok("caution-text", s)
#let DecValTok(s) = mc-tok("caution-text", s)
#let DocumentationTok(s) = mc-tok("muted", s, style: "italic")
#let ErrorTok(s) = mc-tok("important-text", s)
#let ExtensionTok(s) = mc-tok("link", s)
#let FloatTok(s) = mc-tok("caution-text", s)
#let FunctionTok(s) = mc-tok("link", s)
#let ImportTok(s) = mc-tok("accent-text", s)
#let InformationTok(s) = mc-tok("muted", s)
#let KeywordTok(s) = mc-tok("accent-text", s, weight: "bold")
#let NormalTok(s) = mc-tok("ink", s)
#let OperatorTok(s) = mc-tok("note-text", s)
#let OtherTok(s) = mc-tok("note-text", s)
#let PreprocessorTok(s) = mc-tok("accent-text", s)
#let RegionMarkerTok(s) = mc-tok("ink", s)
#let SpecialCharTok(s) = mc-tok("warning-text", s)
#let SpecialStringTok(s) = mc-tok("warning-text", s)
#let StringTok(s) = mc-tok("warning-text", s)
#let VariableTok(s) = mc-tok("note-text", s)
#let VerbatimStringTok(s) = mc-tok("warning-text", s)
#let WarningTok(s) = mc-tok("muted", s, style: "italic")

// Inline code on the tint, in the ink colour.
// - body: the code.
#let mc-inline-code(body) = box(
  fill: mc-tokens.tint,
  inset: (x: 3pt, y: 0pt),
  outset: (y: 3pt),
  radius: mc-small-radius,
  text(fill: mc-tokens.ink, body),
)

// Callouts

// Glyph of the icon of each callout type, as mc-callout-glyphs in HTML. The
// check of tip is drawn, as some preset fonts have no check mark.
#let mc-callout-glyphs = (note: "i", tip: none, warning: "!", important: "!!", caution: "?")

// Answer the drawn check mark of the tip icon.
// - size: side of the icon.
// - paint: colour of the mark.
#let mc-callout-check(size, paint) = curve(
  stroke: (paint: paint, thickness: size * 0.12, cap: "round", join: "round"),
  curve.move((size * 0.27, size * 0.52)),
  curve.line((size * 0.43, size * 0.68)),
  curve.line((size * 0.74, size * 0.34)),
)

// Answer the icon of a callout type: a disc (gold) or a square (mono) in the
// type colour with the glyph on it in the paper colour, or a circle drawn in
// the label ink with the glyph in it (quarto, terminal). It is an artefact:
// the title names the type.
// - type: callout type.
// - colours: the tokens.
// - size: side of the icon.
// - cap: height of a capital letter of the label, as the label draws it.
#let mc-callout-icon(type, colours, size, cap) = {
  let filled = mc-preset in ("gold", "mono")
  let ink = colours.at(type + "-text")
  let paint = if filled { colours.paper } else { ink }
  let glyph = mc-callout-glyphs.at(type)
  let mark = if glyph == none {
    mc-callout-check(size, paint)
  } else {
    text(
      fill: paint,
      size: size * 0.6,
      weight: "black",
      tracking: -0.05em,
      top-edge: "cap-height",
      bottom-edge: "baseline",
      glyph,
    )
  }
  let shape = box(
    width: size,
    height: size,
    radius: if mc-preset == "mono" { 0pt } else { 50% },
    fill: if filled { colours.at(type) } else { none },
    stroke: if filled { none } else { 1pt + ink },
    place(center + horizon, mark),
  )
  // The glyph is placed, so the shape has no text baseline and its bottom
  // sits on the line: the shift puts its middle on the middle of the capital
  // letters of the label.
  box(baseline: (size - cap) / 2, pdf.artifact(shape))
}

// Answer the label of a callout: the icon, then the title in the style of
// the preset, in the label ink of the type.
// - type: callout type.
// - title: title of the callout.
// - icon: true to show the icon.
// - colours: the tokens.
#let mc-callout-label(type, title, icon, colours) = {
  let style = (
    gold: (size: 1em, icon: 1.15em),
    mono: (size: 0.8em, icon: 1.4em),
    quarto: (size: 0.76em, icon: 1.3em),
    terminal: (size: 0.76em, icon: 1.3em),
  ).at(mc-preset)
  set text(size: style.size, fill: colours.at(type + "-text"), weight: "bold")
  set par(first-line-indent: 0pt, hanging-indent: 0pt)
  let styled(it) = if mc-preset == "gold" {
    text(tracking: 0.04em, smallcaps(all: true, it))
  } else {
    text(tracking: if mc-preset == "mono" { 0.1em } else { 0.06em }, upper(it))
  }
  if icon {
    // The ink of "H" in the label style: small capitals in gold, capitals
    // elsewhere.
    context mc-callout-icon(type, colours, style.icon, measure(text(top-edge: "bounds", bottom-edge: "baseline", styled("H"))).height)
    h(0.5em)
  }
  styled(title)
}

// Answer a callout in the style of the preset.
// - spec: type, appearance, titled, title, body and icon (true to show it).
// - colours: the tokens.
#let mc-callout-box(spec, colours) = {
  let type = spec.type
  let edge = colours.at(type)
  let minimal = spec.appearance == "minimal"
  let label = if minimal and not spec.titled { none } else {
    mc-callout-label(type, spec.title, spec.icon and not minimal, colours)
  }
  let body = if spec.body != none {
    set text(fill: colours.ink)
    spec.body
  }
  if mc-preset in ("quarto", "terminal") {
    // atelier: an outline in the type colour, the label set into the top
    // border on the paper, so the border breaks behind it.
    // Terminal: the frame dashed, square, and its start side a solid bar one
    // character wide, drawn as the first column so it stays in the text column.
    let terminal = mc-preset == "terminal"
    let room = 1.15em
    let line-stroke = (paint: edge, thickness: 1.5pt, dash: if minimal or terminal { "dashed" } else { none })
    let frame = block(
      width: 100%,
      inset: (top: if label == none { 0.8em } else { room }, x: 1em, bottom: 0.8em),
      radius: if terminal { 0pt } else { mc-radius },
      stroke: if terminal { (top: line-stroke, right: line-stroke, bottom: line-stroke) } else { line-stroke },
      {
        if label != none {
          let tag = box(fill: colours.paper, inset: (x: 0.45em), label)
          context {
            let height = measure(tag).height
            place(top + left, dx: -0.65em, dy: -room - height / 2, tag)
          }
        }
        body
      },
    )
    // The label rises above the frame by half its height: the top padding
    // keeps it clear of the block above.
    pad(top: 0.45em, if terminal {
      grid(columns: (0.6em, 1fr), fill: (x, y) => if x == 0 { edge }, pdf.artifact[], frame)
    } else {
      frame
    })
  } else {
    let gold = mc-preset == "gold"
    let room = if gold { 2.5em } else { 1.5em }
    let inset = (left: if gold { 0.9em } else { 0.7em }, right: room, top: 0.75em, bottom: 0.8em)
    block(
      width: 100%,
      above: 1.2em,
      below: 1.2em,
      inset: inset,
      radius: if gold { mc-radius } else { 0pt },
      fill: if gold { color.mix((edge, 7%), (colours.paper, 93%)) } else { none },
      stroke: if gold { (left: 3pt + edge) } else { (top: 3pt + edge) },
      {
        motif(mc-motif, top + right, room, dx: inset.right, dy: -inset.top, paint: edge, strength: if gold { 0.6 } else { 0.9 })
        if label != none {
          block(above: 0pt, below: 0.6em, label)
        }
        body
      },
    )
  }
}

// Answer whether content is a callout marker that lua/typst-elements.lua
// writes as the first block of the body.
#let mc-is-callout-marker(it) = it.func() == metadata and type(it.value) == dictionary and "mc-callout" in it.value

// Answer the marker of a callout body and the body without it, with no
// leading space or paragraph break. The body is none when nothing is left.
// - body: the body as Quarto passes it.
#let mc-callout-split(body) = {
  let children = if body.has("children") { body.children } else { (body,) }
  let marker = children.find(mc-is-callout-marker)
  let rest = children.filter(child => not mc-is-callout-marker(child))
  let blank = ([ ].func(), parbreak)
  while rest.len() > 0 and rest.first().func() in blank {
    rest = rest.slice(1)
  }
  while rest.len() > 0 and rest.last().func() in blank {
    rest = rest.slice(0, -1)
  }
  (marker: if marker == none { none } else { marker.value }, body: if rest.len() == 0 { none } else { rest.join() })
}

// Quarto's callout call, in the style of the preset. Quarto passes no type,
// so the type, the appearance and whether the title is the callout's own
// come from the marker in the body; a body with no marker is a note. The
// colours that Quarto passes are not used. The specification of the callout
// goes in front of it as metadata, for the cross-reference show rule.
// - body, title, icon: as Quarto passes them; icon is none for no icon.
// - ..args: any other argument a later Quarto passes, such as the type and
//   the appearance asked for in issue 15414 of quarto-dev/quarto-cli. They are not
//   used yet, so the call keeps working when Quarto adds them.
// Upstream: quarto-dev/quarto-cli issue 15414, pull request 15415.
// Remove when: the minimum Quarto version passes kind and appearance; then
// read them from args in place of the marker.
#let callout(body: [], title: none, background_color: none, icon: none, icon_color: none, body_background_color: none, ..args) = {
  let parts = mc-callout-split(body)
  let marker = if parts.marker == none { (mc-callout: "note", appearance: "default", titled: true) } else { parts.marker }
  // Quarto turns a minimal callout into a simple one with no icon, as the
  // HTML classes callout-style-simple and no-icon do.
  let minimal = marker.appearance == "minimal" or (marker.appearance == "simple" and icon == none)
  let spec = (
    type: marker.at("mc-callout"),
    appearance: if minimal { "minimal" } else { marker.appearance },
    titled: marker.titled,
    title: if title == none { upper(marker.at("mc-callout").first()) + marker.at("mc-callout").slice(1) } else { title },
    body: parts.body,
    icon: icon != none,
  )
  metadata((mc-callout-spec: spec))
  mc-callout-box(spec, mc-tokens)
}

// Answer the specification of the callout in content, or none.
// - it: content.
#let mc-find-callout(it) = {
  if type(it) != content { return none }
  if it.func() == metadata and type(it.value) == dictionary and "mc-callout-spec" in it.value {
    return it.value.at("mc-callout-spec")
  }
  if it.has("children") {
    for child in it.children {
      let found = mc-find-callout(child)
      if found != none { return found }
    }
  }
  if it.has("body") { return mc-find-callout(it.body) }
  if it.has("child") { return mc-find-callout(it.child) }
  none
}

// Answer a cross-referenced callout: the callout with the supplement and the
// number before its title, as Quarto's own show rule does.
// - it: the figure of the callout.
#let mc-callout-figure(it) = {
  let spec = mc-find-callout(it.body)
  if spec == none { return it }
  let number = it.counter.display(it.numbering)
  let title = if spec.titled and spec.title != none { [#it.supplement #number: #spec.title] } else { [#it.supplement #number] }
  align(left, mc-callout-box(spec + (title: title, titled: true), mc-tokens))
}

// Task lists

// Answer the box of a task: a box in the muted colour, or a box in the
// accent colour with a check, drawn as an image whose alternative text gives
// the state.
// - done: true when the task is done.
#let mc-task(done) = {
  let colours = mc-tokens
  let radius = (gold: 2, mono: 0, quarto: 3, terminal: 0).at(mc-preset)
  let edge = if done { colours.accent } else { colours.muted }
  let fill = if done { colours.accent.to-hex() } else { "none" }
  let check = if done {
    "<path d='M4.3 8.4 6.9 11 11.7 5.4' fill='none' stroke='" + colours.paper.to-hex() + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'/>"
  } else { "" }
  let svg = (
    "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'>"
      + "<rect x='1' y='1' width='14' height='14' rx='" + str(radius) + "' fill='" + fill + "' stroke='" + edge.to-hex() + "' stroke-width='1.5'/>"
      + check
      + "</svg>"
  )
  let alt = mc-labels.at(if done { "mcanouil-task-done" } else { "mcanouil-task-open" })
  box(baseline: 0.1em, image(bytes(svg), format: "svg", height: 0.85em, alt: alt))
}

// A task list: no bullet, the box of each task at the start of the line.
// - body: the list.
#let mc-task-list(body) = {
  set list(marker: none, indent: 0pt, body-indent: 0pt)
  body
}

// Keys and details

// A key, as the HTML kbd element: on the tint, in a frame with a heavier
// bottom edge. The monospace font comes from mc-elements() by the label.
// - body: the key.
#let mc-kbd(body) = {
  let colours = mc-tokens
  let edge = color.mix((colours.line, 50%), (colours.muted, 50%))
  [#box(
    fill: colours.tint,
    stroke: (x: 1pt + edge, top: 1pt + edge, bottom: 2pt + edge),
    radius: mc-small-radius,
    inset: (x: 0.35em, y: 0pt),
    outset: (top: 0.25em, bottom: 0.3em),
    text(size: 0.78em, fill: colours.ink, body),
  )<mc-kbd>]
}

// A details element, open as on paper: the summary after a marker in the
// accent text colour, then the content, in a frame in the line colour.
// - summary: the summary.
// - body: the content.
#let mc-details(summary, body) = {
  let colours = mc-tokens
  let marker = pdf.artifact(box(
    baseline: -0.05em,
    polygon(fill: colours.at("accent-text"), stroke: none, (0pt, 0pt), (0.6em, 0pt), (0.3em, 0.5em)),
  ))
  block(
    width: 100%,
    above: 1em,
    below: 1em,
    inset: (x: 0.9em, y: 0.7em),
    radius: mc-radius,
    stroke: (paint: colours.line, thickness: 1pt, dash: if mc-preset == "terminal" { "dashed" } else { none }),
    {
      block(above: 0pt, below: 0.6em, text(fill: colours.ink, [#marker#h(0.45em)#summary]))
      body
    },
  )
}

// Theorems and proofs: the label of a theorem in the accent text colour, the
// label of a proof in the muted colour. Quarto renders both with theorion,
// as figures of the kind of the environment.
#let mc-theorem-kinds = ("theorem", "lemma", "corollary", "proposition", "conjecture", "definition", "example", "exercise", "algorithm")
#let mc-proof-kinds = ("proof", "remark", "solution")

// Answer content without its trailing spaces and paragraph breaks, also at the
// end of its last child, so that what follows it stays on its last line.
// - it: content.
#let mc-trim-end(it) = {
  if type(it) != content or not it.has("children") { return it }
  let blank = ([ ].func(), parbreak)
  let children = it.children
  while children.len() > 0 and children.last().func() in blank {
    children = children.slice(0, -1)
  }
  if children.len() == 0 { return [] }
  (..children.slice(0, -1), mc-trim-end(children.last())).join()
}

// Answer a proof with its end mark, a square in the muted colour at the end
// of its last line, as in HTML. The mark is an artefact.
// - it: the figure of the proof.
// - colours: the tokens.
#let mc-proof(it, colours) = {
  let mark = pdf.artifact(box(width: 0.6em, height: 0.6em, stroke: 0.75pt + colours.muted))
  align(start, block(width: 100%, breakable: true, mc-trim-end(it.body) + h(1fr) + mark))
}

// Style the structured elements of a document with the tokens of the preset.
// - meta: the document, see mcanouil-document().
// - body: the content of the document.
#let mc-elements(meta, body) = {
  let colours = meta.tokens
  let theme = mc-code-window-theme(mc-preset, colours)
  show raw.where(block: true): set block(
    fill: theme.fill,
    stroke: theme.stroke-thickness + theme.border,
    radius: theme.radius,
    inset: 8pt,
    width: 100%,
  )
  show <mc-kbd>: set text(font: meta.fonts.monospace)
  show figure: it => {
    if type(it.kind) != str {
      it
    } else if it.kind.starts-with("quarto-callout-") {
      mc-callout-figure(it)
    } else if it.kind in mc-theorem-kinds {
      show strong: set text(fill: colours.at("accent-text"))
      it
    } else if it.kind == "proof" {
      show emph: set text(fill: colours.muted)
      mc-proof(it, colours)
    } else if it.kind in mc-proof-kinds {
      show emph: set text(fill: colours.muted)
      it
    } else {
      it
    }
  }
  show figure.caption: set text(fill: colours.muted)
  set table(
    stroke: (x, y) => (top: if y == 0 { 0.75pt + colours.line }, bottom: 0.75pt + colours.line),
    inset: (x: 0.7em, y: 0.5em),
  )
  set table.hline(stroke: 1.25pt + color.mix((colours.ink, 55%), (colours.line, 45%)))
  show table.cell.where(y: 0): set text(weight: "bold")
  set highlight(fill: color.mix((colours.accent, 28%), (colours.paper, 72%)))
  show highlight: set text(fill: colours.ink)
  show divider: set line(stroke: 0.75pt + colours.line)
  set footnote.entry(separator: line(length: 30%, stroke: 0.75pt + colours.line))
  show footnote.entry: set text(fill: colours.ink)
  // The show rule is on the item, so the list keeps its tag structure.
  show terms.item: it => {
    block(above: 0.9em, below: 0.35em, sticky: true, text(weight: "bold", fill: colours.ink, it.term))
    block(above: 0.35em, below: 0.9em, inset: (left: 0.9em, y: 0.1em), stroke: (left: 2pt + colours.line), it.description)
  }
  body
}
