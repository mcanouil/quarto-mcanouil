// mcanouil - Typst tokens
// Colour tokens, scheme and motif of the preset, as Lua delivers them for the
// render mode. No colour value is written here; every colour comes from the
// preset data files through the `mcanouil-tokens` metadata.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

#let mc-tokens = (
$for(mcanouil-tokens/pairs)$
  $it.key$: rgb("#$it.value$"),
$endfor$
)
#let mc-mode = "$mcanouil-mode$"
#let mc-motif = "$mcanouil-motif$"
#let mc-preset = "$mcanouil-preset$"

// Answer the colour tokens of the render mode.
#let tokens() = mc-tokens
