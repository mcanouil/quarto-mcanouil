#let mc-tokens = (
$for(mcanouil-tokens/pairs)$
  $it.key$: rgb("#$it.value$"),
$endfor$
)
#let mc-labels = (
$for(mcanouil-labels/pairs)$
  $it.key$: $it.value$,
$endfor$
)
#let mc-fonts = (
  base: ($for(mcanouil-fonts.base)$"$it$", $endfor$),
  headings: ($for(mcanouil-fonts.headings)$"$it$", $endfor$),
  monospace: ($for(mcanouil-fonts.monospace)$"$it$", $endfor$),
)

#show: doc => article(
$if(title)$
  title: [$title$],
$endif$
$if(subtitle)$
  subtitle: [$subtitle$],
$endif$
$if(lang)$
  lang: "$lang$",
$endif$
$if(region)$
  region: "$region$",
$endif$
  mode: "$mcanouil-mode$",
  tokens: mc-tokens,
  fonts: mc-fonts,
  doc,
)
