// mcanouil - Typst labels
// The labels of the document language, as Lua delivers them through the
// `mcanouil-labels` metadata. The label text lives only in the language files.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

#let mc-labels = (
$for(mcanouil-labels/pairs)$
  $it.key$: $it.value$,
$endfor$
)
