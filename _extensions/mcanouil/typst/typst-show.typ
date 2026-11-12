#let mc-fonts = (
  base: ($for(mcanouil-fonts.base)$"$it$", $endfor$),
  headings: ($for(mcanouil-fonts.headings)$"$it$", $endfor$),
  monospace: ($for(mcanouil-fonts.monospace)$"$it$", $endfor$),
)

$if(mcanouil-authors)$
#let mc-authors = $mcanouil-authors$
$endif$

#show: doc => mcanouil-document(
  "$mcanouil-type$",
  "$mcanouil-layout$",
  $if(mcanouil-kind)$"$mcanouil-kind$"$else$none$endif$,
  (
$if(title)$
    title: [$title$],
$endif$
$if(subtitle)$
    subtitle: [$subtitle$],
$endif$
$if(date)$
    date: [#[]$date$],
$endif$
$if(mcanouil-authors)$
    authors: mc-authors.authors,
    affiliations: mc-authors.affiliations,
    email: mc-authors.email,
$endif$
$if(abstract)$
    abstract: [$abstract$],
    abstract-title: [$labels.abstract$],
$endif$
$if(version)$
    version: [$version$],
$endif$
$if(license.text)$
    licence: [$license.text$],
$elseif(license)$
    licence: [$license$],
$endif$
$if(copyright.holder)$
    copyright: [© $if(copyright.year)$$copyright.year$ $endif$$copyright.holder$],
$elseif(copyright)$
    copyright: [$copyright$],
$endif$
$if(toc-depth)$
    toc-depth: $toc-depth$,
$endif$
$if(keywords)$
    keywords: ($for(keywords)$[$it$], $endfor$),
$endif$
$if(mcanouil-letter-standard)$
    letter: (
      standard: "$mcanouil-letter-standard$",
      address: ($for(address)$[$it$], $endfor$),
$if(sender)$
      sender: (
$if(sender.name)$
        name: [$sender.name$],
$endif$
        address: ($for(sender.address)$[$it$], $endfor$),
$if(sender.email)$
        email: [$sender.email$],
$endif$
$if(sender.phone)$
        phone: [$sender.phone$],
$endif$
      ),
$endif$
$if(place)$
      place: [$place$],
$endif$
$if(reference)$
      reference: [$reference$],
$endif$
$if(your-reference)$
      your-reference: [$your-reference$],
$endif$
$if(subject)$
      subject: [$subject$],
$endif$
$if(opening)$
      opening: [$opening$],
$endif$
$if(closing)$
      closing: [$closing$],
$endif$
$if(cc)$
      cc: ($for(cc)$[$it$], $endfor$),
$endif$
$if(encl)$
      encl: ($for(encl)$[$it$], $endfor$),
$endif$
$if(ps)$
      ps: [$ps$],
$endif$
$if(signature-image)$
      signature-image: "$signature-image$",
$endif$
    ),
$endif$
    lang: "$if(lang)$$lang$$else$en$endif$",
    region: "$if(region)$$region$$else$US$endif$",
    mode: "$mcanouil-mode$",
    tokens: tokens(),
    fonts: mc-fonts,
    header: slots(left: [$mcanouil-header.left$], centre: [$mcanouil-header.centre$], right: [$mcanouil-header.right$]),
    footer: slots(left: [$mcanouil-footer.left$], centre: [$mcanouil-footer.centre$], right: [$mcanouil-footer.right$]),
    motif-name: mc-motif,
$if(mcanouil-memo-fields)$
    memo-fields: ($for(mcanouil-memo-fields)$(key: "$it.key$", value: [$it.value$]), $endfor$),
$endif$
  ),
  doc,
)
