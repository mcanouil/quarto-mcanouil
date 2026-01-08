// MIT License
//
// Copyright (c) 2026 Mickaël Canouil
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// Quarto metadata mapping to Typst template
// Maps YAML frontmatter to mcanouil-article function parameters
// Author: Mickaël Canouil
// License: MIT

#show: mcanouil-article.with(
// Document Metadata
$if(title)$
  title: [$title$],
$endif$
$if(subtitle)$
  subtitle: [$subtitle$],
$endif$
$if(by-author)$
  authors: (
$for(by-author)$
    (
      name: (
        literal: $if(it.name.literal)$[$it.name.literal$]$else$none$endif$,
        given: $if(it.name.given)$[$it.name.given$]$else$none$endif$,
        family: $if(it.name.family)$[$it.name.family$]$else$none$endif$,
      ),
      email: $if(it.email)$"$it.email$"$else$none$endif$,
      orcid: $if(it.orcid)$"$it.orcid$"$else$none$endif$,
      url: $if(it.url)$"$it.url$"$else$none$endif$,
      attributes: $if(it.attributes)$(
        corresponding: $if(it.attributes.corresponding)$$it.attributes.corresponding$$else$false$endif$,
      )$else$none$endif$,
      affiliations: $if(it.affiliations)$(
$for(it.affiliations)$
        (
          name: $if(it.name)$[$it.name$]$else$none$endif$,
          department: $if(it.department)$[$it.department$]$else$none$endif$,
          city: $if(it.city)$[$it.city$]$else$none$endif$,
          country: $if(it.country)$[$it.country$]$else$none$endif$,
        ),
$endfor$
      )$else$()$endif$,
    ),
$endfor$
  ),
$else$
  authors: (),
$endif$
$if(date)$
  date: [$date$],
$endif$
$if(abstract)$
  abstract: [$abstract$],
$endif$
$if(keywords)$
  keywords: ($for(keywords)$"$keywords$",$endfor$),
$endif$
// Colour Configuration
$if(brand-mode)$
  brand-mode: "$brand-mode$",
$else$
  brand-mode: "light",
$endif$
$if(colour.background)$
  colour-background: $colour.background$,
$elseif(colour-background)$
  colour-background: $colour-background$,
$endif$
$if(colour.foreground)$
  colour-foreground: $colour.foreground$,
$elseif(colour-foreground)$
  colour-foreground: $colour-foreground$,
$endif$
$if(colour.muted)$
  colour-muted: $colour.muted$,
$elseif(colour-muted)$
  colour-muted: $colour-muted$,
$endif$
// Decorative Elements
$if(show-corner-brackets)$
  show-corner-brackets: $show-corner-brackets$,
$endif$
$if(show-margin-decoration)$
  show-margin-decoration: $show-margin-decoration$,
$endif$
$if(show-title-page-background)$
  show-title-page-background: $show-title-page-background$,
$endif$
$if(show-heading-underlines)$
  show-heading-underlines: $show-heading-underlines$,
$endif$
// Logo Configuration
$if(logo.enabled)$
  show-logo: $logo.enabled$,
$elseif(show-logo)$
  show-logo: $show-logo$,
$endif$
$if(logo.path)$
  logo: "$logo.path$",
$elseif(logo)$
  logo: "$logo$",
$endif$
$if(logo.width)$
  logo-width: $logo.width$,
$elseif(logo-width)$
  logo-width: $logo-width$,
$endif$
$if(logo.inset)$
  logo-inset: $logo.inset$,
$elseif(logo-inset)$
  logo-inset: $logo-inset$,
$endif$
$if(logo.alt)$
  logo-alt: "$logo.alt$",
$elseif(logo-alt)$
  logo-alt: "$logo-alt$",
$endif$
$if(orcid-icon)$
  orcid-icon: "$orcid-icon$",
$endif$
// Title Page
$if(title-page)$
  title-page: $title-page$,
$endif$
// Header and Footer
$if(header-footer-style)$
  header-footer-style: "$header-footer-style$",
$endif$
$if(institute)$
  institute: [$institute$],
$endif$
$if(copyright)$
  copyright: [$copyright.statement$],
$endif$
$if(license)$
  license: [$license.text$],
$endif$
// Watermark
$if(watermark.text)$
  watermark-text: "$watermark.text$",
$elseif(watermark-text)$
  watermark-text: "$watermark-text$",
$endif$
$if(watermark.image)$
  watermark-image: "$watermark.image$",
$elseif(watermark-image)$
  watermark-image: "$watermark-image$",
$endif$
$if(watermark.opacity)$
  watermark-opacity: $watermark.opacity$,
$elseif(watermark-opacity)$
  watermark-opacity: $watermark-opacity$,
$endif$
$if(watermark.angle)$
  watermark-angle: $watermark.angle$,
$elseif(watermark-angle)$
  watermark-angle: $watermark-angle$,
$endif$
$if(watermark.size)$
  watermark-size: $watermark.size$,
$elseif(watermark-size)$
  watermark-size: $watermark-size$,
$endif$
$if(watermark.colour)$
  watermark-colour: $watermark.colour$,
$elseif(watermark-colour)$
  watermark-colour: $watermark-colour$,
$endif$
// Typography
$if(mainfont)$
  font-body: "$mainfont$",
$endif$
$if(sansfont)$
  font-headings: "$sansfont$",
$endif$
$if(fontsize)$
  font-size: $fontsize$,
$endif$
$if(heading.weight)$
  heading-weight: "$heading.weight$",
$elseif(heading-weight)$
  heading-weight: "$heading-weight$",
$endif$
$if(heading.style)$
  heading-style: "$heading.style$",
$elseif(heading-style)$
  heading-style: "$heading-style$",
$endif$
$if(heading.colour)$
  heading-colour: $heading.colour$,
$elseif(heading-colour)$
  heading-colour: $heading-colour$,
$endif$
$if(heading.line-height)$
  heading-line-height: $heading.line-height$,
$elseif(heading-line-height)$
  heading-line-height: $heading-line-height$,
$endif$
$if(title-size)$
  title-size: $title-size$,
$endif$
$if(subtitle-size)$
  subtitle-size: $subtitle-size$,
$endif$
$if(labels.abstract)$
  abstract-title: "$labels.abstract$",
$endif$
$if(labels.keywords)$
  keywords-title: "$labels.keywords$",
$endif$
// Page Layout
$if(papersize)$
  paper: "$papersize$",
$endif$
$if(margin)$
  margin: (
    top: $margin.top$,
    bottom: $margin.bottom$,
    left: $margin.left$,
    right: $margin.right$,
  ),
$endif$
$if(columns)$
  cols: $columns$,
$endif$
$if(column-gutter)$
  column-gutter: $column-gutter$,
$endif$
$if(lang)$
  lang: "$lang$",
$endif$
$if(region)$
  region: "$region$",
$endif$
// Document Structure
$if(section-numbering)$
  section-numbering: "$section-numbering$",
$endif$
  section-pagebreak: $section-pagebreak$,
$if(section-page)$
  section-page: $section-page$,
$endif$
$if(toc-depth)$
  toc-depth: $toc-depth$,
$endif$
$if(toc)$
  has-outlines: true,
$elseif(list-of)$
  has-outlines: true,
$endif$
$if(page-break-inside)$
  page-break-inside: $if(page-break-inside.table)$(
    table: $page-break-inside.table$,
    callout: $page-break-inside.callout$,
    code: $page-break-inside.code$,
    quote: $page-break-inside.quote$,
    terms: $page-break-inside.terms$,
  )$else$$page-break-inside$$endif$,
$endif$
// Table Styling
$if(table.stroke)$
  table-stroke: $table.stroke$,
$elseif(table-stroke)$
  table-stroke: $table-stroke$,
$endif$
$if(table.inset)$
  table-inset: $table.inset$,
$elseif(table-inset)$
  table-inset: $table-inset$,
$endif$
$if(table.fill)$
  table-fill: $if(table.fill/pairs)$(
$for(table.fill/pairs)$
    $it.key$: $it.value$,
$endfor$
  )$else$"$table.fill$"$endif$,
$elseif(table-fill)$
  table-fill: "$table-fill$",
$endif$
// Quote Styling
$if(quote.width)$
  quote-width: $quote.width$,
$elseif(quote-width)$
  quote-width: $quote-width$,
$endif$
$if(quote.align)$
  quote-align: $quote.align$,
$elseif(quote-align)$
  quote-align: $quote-align$,
$endif$
// Figure and Link Styling
$if(figure-placement)$
  figure-placement: $figure-placement$,
$endif$
$if(link.underline)$
  link-underline: $link.underline$,
$elseif(link-underline)$
  link-underline: $link-underline$,
$endif$
$if(link.underline-opacity)$
  link-underline-opacity: $link.underline-opacity$,
$elseif(link-underline-opacity)$
  link-underline-opacity: $link-underline-opacity$,
$endif$
$if(link.colour)$
  link-colour: $link.colour$,
$elseif(link-colour)$
  link-colour: $link-colour$,
$endif$
)

// Define brand mode with default fallback to "light"
#let effective-brand-mode = "$if(brand-mode)$$brand-mode$$else$light$endif$"

// Override Quarto's brand-color to respect template brand-mode
// This ensures callouts and other Quarto-generated elements use the correct colours
#let brand-colour-override = (
  background: mcanouil-colours(mode: effective-brand-mode).background,
  foreground: mcanouil-colours(mode: effective-brand-mode).foreground,
)

// Wrapper functions for typst-markdown filter
// These inject colours from template brand-mode

// Wrapper for .highlight divs
#let mcanouil-highlight(content, ..args) = {
  _highlight(content, mcanouil-colours(mode: effective-brand-mode), ..args)
}

// Image border wrapper - uses template brand-mode colours
#let mcanouil-image-border(content) = {
  image-border(content, mcanouil-colours(mode: effective-brand-mode))
}

// Wrapper for .value-box divs
#let mcanouil-value-box(content, ..args) = {
  render-value-box(colours: mcanouil-colours(mode: effective-brand-mode), ..args)
}

// Wrapper for .panel divs
#let mcanouil-panel(content, ..args) = {
  render-panel(content, colours: mcanouil-colours(mode: effective-brand-mode), ..args)
}

// Wrapper for .badge spans
#let mcanouil-badge(content, ..args) = {
  render-badge(content, colours: mcanouil-colours(mode: effective-brand-mode), ..args)
}

// Wrapper for .divider divs
#let mcanouil-divider(content, ..args) = {
  render-divider(colours: mcanouil-colours(mode: effective-brand-mode), ..args)
}

// Wrapper for .progress divs
#let mcanouil-progress(content, ..args) = {
  render-progress(colours: mcanouil-colours(mode: effective-brand-mode), ..args)
}

// Wrapper for .executive-summary divs
#let mcanouil-executive-summary(content, ..args) = {
  render-executive-summary(content, colours: mcanouil-colours(mode: effective-brand-mode), ..args)
}

// Wrapper for timeline rendering
#let mcanouil-timeline(events, ..args) = {
  render-timeline(events, mcanouil-colours(mode: effective-brand-mode), ..args)
}

// Wrapper for horizontal timeline rendering
// Horizontal timelines are not breakable to maintain visual integrity
#let mcanouil-horizontal-timeline(events, ..args) = {
  block(
    breakable: false,
    render-horizontal-timeline(events, mcanouil-colours(mode: effective-brand-mode), ..args)
  )
}

// Wrapper for card grid rendering
#let mcanouil-card-grid(cards, ..args) = {
  render-card-grid(cards, mcanouil-colours(mode: effective-brand-mode), ..args)
}

// Outlines section (TOC, List of X) on own page(s) when any are enabled
// These sections are rendered in single column mode
$if(toc)$
// Add break before TOC only if there's content before it (title block)
// Uses conditional-break to automatically select colbreak or pagebreak
$if(title)$
#conditional-break()
$endif$

// Native table of contents
// The heading's numbering property is set directly by the Lua filter,
// so the outline automatically displays correct numbering including prefixes
#context {
  // Only render TOC if there are headings to display
  let headings = query(heading).filter(it => it.outlined and it.level <= $toc-depth$)
  if headings.len() > 0 {
    heading(title-case([$toc-title$]), outlined: false, bookmarked: true, numbering: none)
    v(1em)
    // Style level 1 outline entries with extra spacing and bold (scoped to TOC only)
    {
      show outline.entry.where(level: 1): it => {
        v(0.5em, weak: true)
        strong(it)
      }
      outline(
        title: none,
        depth: $toc-depth$,
        indent: 1em,
      )
    }
    conditional-break()
  }
}
$endif$
$if(list-of)$
// Build configuration from Pandoc template variables
// Note: render-list-of-sections handles its own pagebreaks (before each section and after all sections)
#render-list-of-sections((
$for(list-of/pairs)$
  // Only add non-empty keys
  $if(it.key)$$it.key$: "$it.value$",$endif$
$endfor$
))
$endif$

// Apply columns to main content (after title block and outlines)
// This ensures outlines render in single column
$if(columns)$
// Update state to indicate if columns are active (true if > 1)
#columns-active-state.update($columns$ > 1)
// Set page columns (even for columns: 1, which is equivalent to single column)
#set page(columns: $columns$$if(column-gutter)$, column-gutter: $column-gutter$$endif$)
$endif$
