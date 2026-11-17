// mcanouil - Typst logo
// The logo of the document: the user brand logo, or else the logo of the
// preset, with its alternative text.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Answer the logo as an image. Arguments are those of image(), for example height.
#let mc-logo(..args) = image(
  bytes($mcanouil-logo.bytes$),
  format: $mcanouil-logo.format$,
  alt: $mcanouil-logo.alt$,
  ..args,
)
