// mcanouil - Typst code windows
// The theme of the embedded code-window, from the tokens of the preset, so a
// code window matches the HTML and Reveal.js windows: the traffic lights at
// 0.7 times the text, the file name in the muted colour, and the frame and
// title bar of the preset. code-window reads the state by its name.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Answer the code-window theme of a preset.
// - preset: name of the preset.
// - colours: the tokens of the render mode.
#let mc-code-window-theme(preset, colours) = {
  let title-bar = color.mix((colours.ink, 6%), (colours.tint, 94%))
  let shared = (
    border: colours.line,
    surface: colours.tint,
    // The code of every highlighted block, in a window or not, on the tint.
    fill: colours.tint,
    label: colours.muted,
    muted: colours.muted,
    traffic-light-size: 0.7em,
    traffic-light-gap: 0.35em,
  )
  let own = (
    // Gold: a line frame with a gilded top edge, as in HTML and Reveal.js.
    // Every side has a stroke, so the rounded corners keep their shape.
    gold: (
      stroke: (
        top: 1.5pt + gradient.linear(
          colours.at("accent-low"),
          colours.at("accent-high"),
          colours.at("accent-low"),
          space: rgb,
        ),
        rest: 0.75pt + colours.line,
      ),
      radius: 5pt,
    ),
    // Mono: square, a thick ink rule on top and no other edge, as in HTML and
    // Reveal.js.
    mono: (stroke: (top: 2pt + colours.ink, rest: none), radius: 0pt),
    // Quarto (atelier): rounded, the title bar a little stronger than the
    // tint of the body.
    quarto: (surface: title-bar, radius: 6pt),
    // Terminal (atelier): as quarto, square.
    terminal: (surface: title-bar, radius: 0pt),
  )
  shared + own.at(preset)
}

// Set the code-window theme of the preset for the code windows of a document.
// - meta: the document, see mcanouil-document().
// - body: the content of the document.
#let mc-code-windows(meta, body) = {
  state("code-window-theme").update(theme => theme + mc-code-window-theme(mc-preset, meta.tokens))
  body
}
