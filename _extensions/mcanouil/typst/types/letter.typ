// mcanouil - letter
// The letter document type: the sender, the address window of NF Z 11-001 or
// DIN 5008 form B, fold marks, place and date, references, subject, opening,
// body, closing, signature, cc, enclosures and postscript.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Side of the corner motif of page 1 of a letter.
#let mc-letter-motif-size = 36mm

// Answer the lines of the sender block: the name in bold, the address lines, the email and the phone.
// - sender: dictionary with name, address (array), email and phone, or none.
#let sender-lines(sender) = {
  if sender == none { return () }
  let lines = ()
  if "name" in sender { lines.push(strong(sender.name)) }
  lines += sender.at("address", default: ())
  for key in ("email", "phone") {
    if key in sender { lines.push(sender.at(key)) }
  }
  lines
}

// Answer the return line of DIN 5008: the name and the address of the sender on one line.
// - sender: dictionary, see sender-lines().
#let return-line(sender) = {
  if sender == none { return none }
  (sender.at("name", default: none), ..sender.at("address", default: ())).filter(it => it != none).join([ #sym.dot.c ])
}

// Answer the place and the date, for example "Lille, le 11 novembre 2026".
// - place: content or none.
// - date: content or none.
#let place-and-date(place, date) = {
  let prefix = mc-labels.at("mcanouil-letter-date-prefix")
  let dated = if date == none { none } else if prefix == "" { date } else { [#prefix #date] }
  (place, dated).filter(it => it != none).join([, ])
}

// Answer a label and its colon: French sets a no-break space before the colon.
// - label: text of the label.
#let with-colon(label) = context if text.lang == "fr" { label + sym.space.nobreak + ":" } else { label + ":" }

// Answer a label followed by its value, for the references of the letter.
// - key: label key.
// - value: content.
#let labelled(key, value) = [#with-colon(mc-labels.at(key)) #value]

// Answer the reference block of DIN 5008: each term in small muted type above its value.
// - standard: key of mc-letter-standards.
// - entries: array of (label, value) pairs.
#let reference-block(standard, entries) = {
  let info = mc-letter-standards.at(standard).info
  let colours = tokens()
  at-page(standard, info.x, info.y, width: info.width, {
    set par(spacing: 0.5em)
    for (label, value) in entries {
      block(above: 0.8em, below: 0pt, sticky: true, text(size: 8pt, fill: colours.muted, label))
      block(above: 0.2em, below: 0pt, value)
    }
  })
}

// Answer a letter.
// - meta: the document, see mcanouil-document(), with `letter`: standard, address, sender, place, reference,
//   your-reference, subject, opening, closing, cc, encl, ps and signature-image.
// - body: the content of the document.
#let mc-letter(meta, body) = {
  let fields = meta.letter
  let standard = fields.standard
  let geometry = mc-letter-standards.at(standard)
  let colours = tokens()
  let authors = meta.at("authors", default: ())
  let sender = fields.at("sender", default: none)
  if sender == none and authors.len() > 0 { sender = (name: authors.first().name) }
  let signer = if sender != none { sender.at("name", default: none) }
  let motif-name = meta.at("motif-name", default: none)
  let place-date = place-and-date(fields.at("place", default: none), meta.at("date", default: none))
  let reference = fields.at("reference", default: none)
  let your-reference = fields.at("your-reference", default: none)
  let subject = fields.at("subject", default: none)
  let din = standard == "din"

  set page(
    paper: "a4",
    margin: geometry.margin,
    fill: colours.paper,
    background: context {
      fold-marks(standard, folds: here().page() == 1)
      if motif-name != none and here().page() == 1 { motif(motif-name, bottom + right, mc-letter-motif-size) }
    },
    footer: context if here().page() > 1 {
      text(size: 8pt, fill: colours.muted, meta.footer)
    },
  )
  set par(spacing: 1em, justify: false)
  set text(size: 10.5pt)

  block(width: 100%, height: mc-letter-body-start - geometry.margin.top, breakable: false, {
    let lines = sender-lines(sender)
    if lines.len() > 0 {
      let x = if din { geometry.info.x } else { geometry.margin.left }
      at-page(standard, x, geometry.margin.top, width: 70mm, text(size: 9pt, lines.join(linebreak())))
    }
    address-window(standard, fields.at("address", default: ()), sender-line: if din { return-line(sender) })
    if din {
      let entries = ()
      if your-reference != none { entries.push((mc-labels.at("mcanouil-letter-your-reference"), your-reference)) }
      if reference != none { entries.push((mc-labels.at("mcanouil-letter-reference"), reference)) }
      if place-date != none { entries.push((mc-labels.at("mcanouil-letter-date"), place-date)) }
      reference-block(standard, entries)
    }
  })

  if not din {
    if place-date != none { align(right, place-date) }
    if your-reference != none or reference != none {
      let entries = ()
      if your-reference != none { entries.push(labelled("mcanouil-letter-your-reference", your-reference)) }
      if reference != none { entries.push(labelled("mcanouil-letter-reference", reference)) }
      entries.join([ #sym.dot.c ])
    }
  }
  if subject != none {
    block(above: 1.4em, below: 1.4em, strong(if din { subject } else { labelled("mcanouil-letter-subject", subject) }))
  }
  if "opening" in fields { block(below: 1em, fields.opening) }
  body
  if "closing" in fields { block(above: 1.2em, below: 0pt, sticky: false, fields.closing) }
  block(above: 0.6em, below: 0pt, breakable: false, {
    if "signature-image" in fields {
      image(
        fields.at("signature-image"),
        height: 16mm,
        alt: mc-labels.at("mcanouil-letter-signature"),
      )
    } else {
      v(16mm)
    }
    if signer != none { signer }
  })
  let trailer(key, items) = block(above: 1.4em, below: 0pt, breakable: false, {
    text(weight: "bold", with-colon(mc-labels.at(key)))
    for item in items {
      linebreak()
      item
    }
  })
  if "cc" in fields { trailer("mcanouil-letter-cc", fields.cc) }
  if "encl" in fields { trailer("mcanouil-letter-enclosures", fields.encl) }
  if "ps" in fields { block(above: 1.4em, below: 0pt, [#strong(mc-labels.at("mcanouil-letter-postscript") + " ") #fields.ps]) }
}
