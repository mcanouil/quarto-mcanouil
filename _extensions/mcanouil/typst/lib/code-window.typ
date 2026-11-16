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
  let shared = (
    border: colours.line,
    surface: colours.tint,
    label: colours.muted,
    muted: colours.muted,
    traffic-light-size: 0.7em,
    traffic-light-gap: 0.35em,
  )
  let own = (
    // Gold: a gilded frame, as the gilded rules of the preset.
    gold: (
      border: gradient.linear(
        colours.at("accent-low"),
        colours.at("accent-high"),
        colours.at("accent-low"),
        space: rgb,
      ),
      radius: 5pt,
    ),
    // Mono: square, in a thick ink frame.
    mono: (border: colours.ink, stroke-thickness: 2pt, radius: 0pt),
    // Quarto: rounded, the title bar on the card.
    quarto: (surface: colours.card, radius: 9pt),
    // Terminal: square, in a dashed accent frame.
    terminal: (border: colours.accent, stroke-dash: "dashed", radius: 0pt),
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
