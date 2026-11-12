// mcanouil - article
// The article document type: a single text column with a wide outer margin for
// margin notes, the title block and the abstract box on page 1 under the corner
// motif, numbered references, and the author contributions as a CRediT table
// at the end.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Side of the corner motif on page 1 of an article. It stays inside the outer
// margin, so the text column never meets it.
#let mc-article-motif-size = 52mm

// Marks of the degrees of contribution, and the mark of a role with no degree.
#let mc-credit-marks = (lead: "L", equal: "E", supporting: "S")
#let mc-credit-contributed = "•"

// Answer the initials of a name, for example "AA" for "Ana Author".
// - name: the name.
#let initials(name) = name.split(" ").filter(part => part != "").map(part => upper(part.first())).join()

// Answer the roles of the authors, each once, in order of first appearance.
// - authors: array of author dictionaries with a `roles` array.
#let credit-roles(authors) = authors.map(author => author.at("roles", default: ())).flatten().map(it => it.role).dedup()

// Answer the mark of an author for a role: L, E or S, a bullet for a role with
// no degree, or an empty cell.
// - author: author dictionary.
// - role: role name.
#let credit-mark(author, role) = {
  let found = author.at("roles", default: ()).filter(it => it.role == role)
  if found.len() == 0 { return [] }
  mc-credit-marks.at(found.first().degree, default: mc-credit-contributed)
}

// Answer the legend of the marks that the table uses.
// - authors: array of author dictionaries.
#let credit-legend(authors) = {
  let degrees = authors.map(author => author.at("roles", default: ())).flatten().map(it => it.degree)
  let entries = ()
  for (degree, mark) in mc-credit-marks {
    if degrees.contains(degree) { entries.push(mark + " " + mc-labels.at("mcanouil-credit-" + degree)) }
  }
  if degrees.any(degree => degree not in mc-credit-marks) {
    entries.push(mc-credit-contributed + " " + mc-labels.at("mcanouil-credit-contributed"))
  }
  entries.join([ #sym.dot.c ])
}

// Answer the CRediT table: the roles as rows, the authors as columns, the mark
// of each degree of contribution in the cells, and a legend line. The header
// cells are tagged. It answers nothing when no author has a role.
// - authors: array of author dictionaries, see author-line(), with `roles`.
#let credit-table(authors) = {
  let colours = tokens()
  let roles = credit-roles(authors)
  if roles.len() == 0 { return }
  let cell(content) = table.cell(align: center, content)
  block(breakable: false, width: 100%, above: 2em, fill: colours.tint, stroke: 0.5pt + colours.line, inset: 0.8em, {
    text(weight: "bold", mc-labels.at("mcanouil-credit-title"))
    v(0.4em)
    set text(size: 0.9em)
    table(
      columns: (1fr,) + authors.map(_ => auto),
      stroke: (x: none, y: 0.5pt + colours.line),
      inset: (x: 0.6em, y: 0.4em),
      table.header(
        table.cell(align: left, mc-labels.at("mcanouil-credit-role")),
        ..authors.map(author => cell(strong(initials(author.name)))),
      ),
      ..roles.map(role => (
        table.cell(align: left, upper(role.first()) + role.slice(role.first().len())),
        ..authors.map(author => cell(credit-mark(author, role))),
      )).flatten(),
    )
    v(0.2em)
    text(size: 0.85em, fill: colours.muted, credit-legend(authors))
  })
}

// Answer an article.
// - meta: the document, see mcanouil-document().
// - body: the content of the document.
#let mc-article(meta, body) = {
  let fonts = meta.fonts
  let motif-name = meta.at("motif-name", default: none)
  let corner = if motif-name != none { motif(motif-name, top + right, mc-article-motif-size) }
  let authors = meta.at("authors", default: ())
  set heading(numbering: "1.1")
  set footnote.entry(separator: none)
  show: chrome-page.with(meta.header, meta.footer, motif: corner, margin: none)
  title-block(
    title: meta.at("title", default: none),
    subtitle: meta.at("subtitle", default: none),
    kicker: meta.at("kicker", default: none),
    date: meta.at("date", default: none),
    authors: authors,
    affiliations: meta.at("affiliations", default: ()),
    email: meta.at("email", default: ""),
    abstract: meta.at("abstract", default: none),
    abstract-title: meta.at("abstract-title", default: none),
    keywords: meta.at("keywords", default: ()),
    font: fonts.headings,
  )
  body
  credit-table(authors)
}
