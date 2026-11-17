// mcanouil - Typst block quotes
// A block quote in the style of the preset. Pandoc writes a block quote as
// `quote(block: true)`, and Lua adds `attribution:` when the last paragraph
// of the quote starts with a dash. The text and the attribution stay tagged
// content; the edge, the rules, the icon and the label are artefacts.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Answer the attribution of a quote, set in the style that a preset gives.
// - it: the quote.
// - style: function from the attribution to content.
#let mc-quote-attribution(it, style) = if it.attribution != none { style(it.attribution) }

// Gold: a gilded edge on the left, italic text, the attribution in small
// capitals in the accent text colour.
#let mc-quote-gold(it, colours, label) = block(
  width: 100%,
  above: 1.2em,
  below: 1.2em,
  inset: (left: 14pt, y: 2pt),
  stroke: (left: 3pt + gradient.linear(
    colours.at("accent-low"),
    colours.at("accent-high"),
    colours.at("accent-low"),
    angle: 90deg,
  )),
  {
    set text(size: 1.08em)
    text(style: "italic", it.body)
    mc-quote-attribution(it, attribution => {
      v(0.5em)
      text(size: 0.86em, fill: colours.at("accent-text"), tracking: 0.05em, smallcaps(attribution))
    })
  },
)

// Mono: a thick rule in the accent colour above, a hairline below, heavy text,
// and the attribution after an inverted label.
#let mc-quote-mono(it, colours, label) = block(
  width: 100%,
  above: 1.2em,
  below: 1.2em,
  inset: (y: 8pt),
  stroke: (top: 3pt + colours.accent, bottom: 1pt + colours.line),
  {
    set text(size: 1.15em)
    set par(leading: 0.55em)
    text(weight: 800, it.body)
    mc-quote-attribution(it, attribution => {
      v(0.7em)
      set text(size: 0.68em, fill: colours.muted)
      pdf.artifact(box(
        fill: colours.accent,
        inset: (x: 5pt, y: 2pt),
        outset: (y: 1pt),
        text(fill: colours.paper, weight: "bold", tracking: 0.1em, upper(label)),
      ))
      h(0.6em)
      attribution
    })
  },
)

// Quarto: a card with rounded corners, a round quote icon in the chrome
// colour, and the attribution in a pill. Typst draws no shadow, so the card
// has a stroke in the line colour, and the fill is the card token.
#let mc-quote-quarto(it, colours, label) = block(
  width: 100%,
  above: 1.2em,
  below: 1.2em,
  inset: (left: 38pt, right: 14pt, y: 12pt),
  radius: 9pt,
  stroke: 0.5pt + colours.line,
  fill: colours.card,
  {
    place(top + left, dx: -28pt, dy: -3pt, pdf.artifact(circle(
      radius: 9pt,
      fill: colours.chrome,
      inset: 0pt,
      align(center + horizon, text(fill: colours.at("on-ground-title"), weight: "bold", size: 15pt, baseline: 2pt, "\u{201C}")),
    )))
    it.body
    mc-quote-attribution(it, attribution => {
      v(0.4em)
      box(
        fill: colours.tint,
        radius: 100pt,
        inset: (x: 8pt, y: 2pt),
        text(size: 0.92em, fill: colours.at("accent-text"), attribution),
      )
    })
  },
)

// Terminal: a dashed box in the line colour, a bracketed label on the top
// edge, and the attribution in the muted colour.
#let mc-quote-terminal(it, colours, label) = block(
  width: 100%,
  above: 1.9em,
  below: 1.2em,
  inset: (x: 12pt, top: 16pt, bottom: 8pt),
  stroke: (paint: colours.line, thickness: 1pt, dash: "dashed"),
  {
    place(top + left, dx: -2pt, dy: -21pt, pdf.artifact(box(
      fill: colours.paper,
      inset: (x: 6pt),
      text(size: 0.85em, fill: colours.at("accent-text"), "[" + upper(label) + "]"),
    )))
    it.body
    mc-quote-attribution(it, attribution => {
      v(0.4em)
      text(fill: colours.muted, attribution)
    })
  },
)

// The block quote style of each preset.
#let mc-quote-styles = (
  gold: mc-quote-gold,
  mono: mc-quote-mono,
  quarto: mc-quote-quarto,
  terminal: mc-quote-terminal,
)

// Style the block quotes of a document with the style of the preset.
// - meta: the document, see mcanouil-document().
// - body: the content of the document.
#let mc-quotes(meta, body) = {
  let style = mc-quote-styles.at(mc-preset)
  show quote.where(block: true): it => style(it, meta.tokens, mc-labels.at("mcanouil-quote"))
  body
}
