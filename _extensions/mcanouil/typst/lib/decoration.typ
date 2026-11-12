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
