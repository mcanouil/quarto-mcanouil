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
  tokens: tokens(),
  fonts: mc-fonts,
  header: slots(left: [$mcanouil-header.left$], centre: [$mcanouil-header.centre$], right: [$mcanouil-header.right$]),
  footer: slots(left: [$mcanouil-footer.left$], centre: [$mcanouil-footer.centre$], right: [$mcanouil-footer.right$]),
  motif-name: mc-motif,
  doc,
)
