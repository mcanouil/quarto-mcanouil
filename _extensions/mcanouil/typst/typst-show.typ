#let mc-tokens = (
$for(mcanouil-tokens/pairs)$
  $it.key$: rgb("#$it.value$"),
$endfor$
)
#let mc-fonts = (
  base: "$mcanouil-fonts.base$",
  headings: "$mcanouil-fonts.headings$",
  monospace: "$mcanouil-fonts.monospace$",
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
