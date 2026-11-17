// mcanouil - Typst authors
// The display of an author: the name, the degrees in small type, the
// affiliation numbers, an ORCID badge with alternative text, and the marks
// for the corresponding author, equal contribution and a deceased author.
// Marks that only repeat a legend line are artefacts.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Path data of the ORCID glyph and of its disc, in a 32 by 32 view box.
#let mc-orcid-disc = "M32 16c0 8.837-7.163 16-16 16-8.838 0-16-7.163-16-16C0 7.162 7.162 0 16 0c8.837 0 16 7.162 16 16Z"
#let mc-orcid-glyph = "M18.813 9.637h-5.45v13.9h5.474c4.555 0 7.35-3.378 7.35-6.95 0-1.635-.562-3.372-1.77-4.704-1.215-1.336-3.065-2.246-5.605-2.246ZM18.6 21.3h-2.813v-9.425H18.5c1.823 0 3.12.552 3.96 1.4.842.849 1.252 2.021 1.252 3.312 0 .784-.239 1.967-.993 2.948-.745.969-2.01 1.765-4.119 1.765ZM8.363 9.675v13.887h2.425V9.675H8.363ZM9.575 8.65c.84 0 1.513-.689 1.513-1.513 0-.823-.673-1.512-1.513-1.512-.838 0-1.512.674-1.512 1.513 0 .823.672 1.512 1.512 1.512Z"

// Answer an ORCID badge: an accent disc with a paper glyph, whose alternative
// text is "ORCID <id>".
#let orcid-badge(id) = {
  let colours = tokens()
  let svg = (
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 32 32\">",
    "<path fill=\"" + colours.accent.to-hex() + "\" d=\"" + mc-orcid-disc + "\"/>",
    "<path fill=\"" + colours.paper.to-hex() + "\" fill-rule=\"evenodd\" d=\"" + mc-orcid-glyph + "\"/>",
    "</svg>",
  ).join()
  box(
    height: 0.8em,
    baseline: 0.1em,
    image(bytes(svg), format: "svg", alt: mc-labels.at("mcanouil-author-orcid") + " " + id),
  )
}

// Answer the envelope mark of the corresponding author, drawn as an artefact.
#let envelope-mark() = {
  let colours = tokens()
  let line = 0.5pt + colours.ink
  pdf.artifact(box(
    width: 0.9em,
    height: 0.62em,
    baseline: 0.05em,
    stroke: line,
    radius: 0.5pt,
    place(top + left, polygon(stroke: line, (0em, 0em), (0.45em, 0.36em), (0.9em, 0em))),
  ))
}

// Answer the line of one author.
// - author: dictionary with name, degrees, affiliations, orcid, corresponding,
//   equal and deceased.
#let author-line(author) = {
  let colours = tokens()
  let parts = (
    text(weight: "bold", author.name),
    if author.degrees.len() > 0 { text(size: 0.8em, fill: colours.muted, author.degrees.join(", ")) },
    if author.affiliations.len() > 0 { super(author.affiliations.map(str).join(",")) },
    if author.corresponding { envelope-mark() },
    if author.orcid != "" { orcid-badge(author.orcid) },
    if author.equal { [\*] },
    if author.deceased { sym.dagger },
  )
  parts.filter(part => part != none).join(h(0.25em))
}

// Answer the numbered affiliation lines.
#let affiliation-lines(affiliations) = (
  affiliations
    .enumerate(start: 1)
    .map(entry => [#super(str(entry.at(0))) #entry.at(1)])
    .join(linebreak())
)

// Answer the legend lines of the marks that the authors use, one for each mark.
// - email: email of the corresponding author, or "".
#let author-legends(authors, email: "") = {
  let legends = ()
  if authors.any(author => author.corresponding) {
    let address = if email != "" { ": " + email }
    legends.push([#envelope-mark()#h(0.3em)#mc-labels.at("mcanouil-author-corresponding")#address])
  }
  if authors.any(author => author.equal) {
    legends.push([\* #mc-labels.at("mcanouil-author-equal")])
  }
  if authors.any(author => author.deceased) {
    legends.push([#sym.dagger #mc-labels.at("mcanouil-author-deceased")])
  }
  legends.join(linebreak())
}
