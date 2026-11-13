// mcanouil - invoice
// The invoice document type: the sender, the address window shared with the letter, the dates, an items
// table with tagged header cells and tabular figures, the totals, the payment box and the terms.
// The amounts are whole numbers of the smallest currency unit, so that the printed totals carry no
// floating point error.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Side of the corner motif of page 1 of an invoice.
#let mc-invoice-motif-size = 28mm

// Decimals of the smallest unit of the currencies that do not have two; the others have two.
#let mc-currency-digits = (JPY: 0, KRW: 0, VND: 0)

// Symbols of the currencies that have one; the others print their code.
#let mc-currency-symbols = (EUR: "€", USD: "\u{24}", GBP: "£", JPY: "¥", CHF: "CHF")

// Thousands separator and decimal mark of the languages of the labels; other languages use the English style.
#let mc-number-styles = (
  en: (group: ",", point: ".", after: false),
  fr: (group: "\u{202f}", point: ",", after: true),
  de: (group: ".", point: ",", after: true),
)

// Decimals kept for a quantity and for a unit price.
#let mc-invoice-quantity-digits = 4

// Answer the whole number that a decimal text stands for, multiplied by ten to the power of `digits`.
// - value: text such as "33.33", "1200" or "5,5"; a comma counts as the decimal mark.
// - digits: decimals to keep; a text with more decimals stops the render.
// - what: name of the field, for the error message.
#let parse-decimal(value, digits, what) = {
  let text = str(value).replace("\\", "").trim().replace(",", ".")
  let negative = text.starts-with("-")
  if negative or text.starts-with("+") { text = text.slice(1) }
  if text.match(regex("^(\d+\.?\d*|\.\d+)\z")) == none {
    panic("invoice: " + what + " \"" + str(value) + "\" is not a number; write it as 1200 or 33.33.")
  }
  let parts = text.split(".")
  let fraction = parts.at(1, default: "")
  if fraction.len() > digits {
    panic("invoice: " + what + " \"" + str(value) + "\" has more than " + str(digits) + " decimals.")
  }
  let whole = int(parts.first() + fraction + "0" * (digits - fraction.len()))
  if negative { -whole } else { whole }
}

// Answer the quotient of two whole numbers, rounded half away from zero.
// - number: whole number.
// - divisor: positive whole number.
#let divide-rounded(number, divisor) = if number < 0 {
  -divide-rounded(-number, divisor)
} else {
  calc.quo(2 * number + divisor, 2 * divisor)
}

// Answer a power of ten as a whole number.
// - exponent: whole number of zero or more.
#let ten-to(exponent) = calc.pow(10, exponent)

// Answer the text of an amount in the smallest currency unit, with the grouping and the decimal mark of a language.
// - minor: whole number of the smallest unit.
// - digits: decimals of the currency.
// - style: entry of mc-number-styles.
#let format-minor(minor, digits, style) = {
  let digits-text = str(calc.abs(minor))
  digits-text = "0" * calc.max(0, digits + 1 - digits-text.len()) + digits-text
  let whole = digits-text.slice(0, digits-text.len() - digits)
  let fraction = digits-text.slice(digits-text.len() - digits)
  let groups = ()
  while whole.len() > 3 {
    groups.insert(0, whole.slice(whole.len() - 3))
    whole = whole.slice(0, whole.len() - 3)
  }
  groups.insert(0, whole)
  let sign = if minor < 0 { "−" } else { "" }
  sign + groups.join(style.group) + if digits > 0 { style.point + fraction } else { "" }
}

// Answer a money formatter for a currency and a language.
// - currency: ISO 4217 code.
// - lang: language code of the document.
#let money-formatter(currency, lang) = {
  let digits = mc-currency-digits.at(currency, default: 2)
  let style = mc-number-styles.at(lang, default: mc-number-styles.en)
  let symbol = mc-currency-symbols.at(currency, default: currency)
  minor => {
    let amount = format-minor(minor, digits, style)
    if style.after { amount + sym.space.nobreak + symbol } else if symbol == currency {
      symbol + sym.space.nobreak + amount
    } else { symbol + amount }
  }
}

// Answer a VAT rate as text, for example "20 %" or "5,5 %".
// - rate: hundredths of a percent as a whole number.
// - style: entry of mc-number-styles.
#let format-rate(rate, style) = {
  let text = format-minor(rate, 2, style)
  let trimmed = text.trim("0", at: end).trim(style.point, at: end)
  trimmed + sym.space.nobreak + "%"
}

// Answer a text where `{name}` stands for a value of a dictionary.
// - template: text with placeholders.
// - values: dictionary of content.
#let fill-template(template, values) = {
  let out = []
  let cursor = 0
  for found in template.matches(regex("\{([a-z]+)\}")) {
    out += template.slice(cursor, found.start)
    out += values.at(found.captures.first(), default: found.text)
    cursor = found.end
  }
  out + template.slice(cursor)
}

// Answer a date text as "YYYY-MM-DD" with the date itself.
// - value: text such as "2026-11-01".
// - what: name of the field, for the error message.
#let parse-date(value, what) = {
  let found = str(value).replace("\\", "").trim().match(regex("^(\d{4})-(\d{2})-(\d{2})\z"))
  if found == none {
    panic("invoice: " + what + " \"" + str(value) + "\" is not a date; write it as 2026-11-01.")
  }
  let (year, month, day) = found.captures.map(int)
  datetime(year: year, month: month, day: day)
}

// Answer the lines of an item for the table and the totals, in the smallest currency unit.
// - item: dictionary with description, details, quantity, unit-price and vat.
// - digits: decimals of the currency.
// - index: position of the item, for the error messages.
#let invoice-line(item, digits, index) = {
  let name = "item " + str(index + 1)
  let quantity = parse-decimal(item.at("quantity", default: "1"), mc-invoice-quantity-digits, name + " quantity")
  let price = parse-decimal(item.at("unit-price", default: "0"), mc-invoice-quantity-digits, name + " unit-price")
  let rate = parse-decimal(item.at("vat", default: "0"), 2, name + " vat")
  (
    description: item.description,
    details: item.at("details", default: none),
    quantity: quantity,
    price: price,
    rate: rate,
    net: divide-rounded(quantity * price, ten-to(2 * mc-invoice-quantity-digits - digits)),
  )
}

// Answer the totals of lines: the subtotal, the net amount and the VAT of each rate, and the total.
// - lines: array of invoice-line().
// - exempted: no VAT at all.
#let invoice-totals(lines, exempted) = {
  let subtotal = lines.map(line => line.net).sum(default: 0)
  if exempted { return (subtotal: subtotal, rates: (), total: subtotal) }
  let rates = lines.map(line => line.rate).dedup()
  let by-rate = rates.map(rate => {
    let net = lines.filter(line => line.rate == rate).map(line => line.net).sum()
    (rate: rate, net: net, vat: divide-rounded(net * rate, 10000))
  })
  (subtotal: subtotal, rates: by-rate, total: subtotal + by-rate.map(entry => entry.vat).sum(default: 0))
}

// Answer the sender block: the name, the address and the email.
// - sender: dictionary with name, address and email.
#let sender-block(sender) = {
  text(size: 12pt, weight: "bold", sender.name)
  for line in sender.at("address", default: ()) {
    linebreak()
    line
  }
  if "email" in sender {
    linebreak()
    let address = sender.email.replace("\\", "")
    link("mailto:" + address, address)
  }
}

// Answer the recipient lines of the address window: the name in bold, then the address.
// - recipient: dictionary with name and address.
#let recipient-lines(recipient) = (strong(recipient.name), ..recipient.at("address", default: ()))

// Answer an invoice.
// - meta: the document, see mcanouil-document(), with `invoice`: standard, sender, recipient, number, issued, due,
//   reference, fee, penalty, currency, items and bank.
// - body: the content of the document, printed as notes under the items.
#let mc-invoice(meta, body) = {
  let fields = meta.invoice
  let standard = fields.standard
  let geometry = mc-letter-standards.at(standard)
  let colours = tokens()
  let din = standard == "din"
  let sender = fields.sender
  let recipient = fields.recipient
  let exemption = sender.at("exempted", default: none)
  let exempted = exemption != none and exemption != [false] and exemption != [none]
  let currency = fields.at("currency", default: "EUR")
  let digits = mc-currency-digits.at(currency, default: 2)
  let style = mc-number-styles.at(meta.lang, default: mc-number-styles.en)
  let money = money-formatter(currency, meta.lang)
  let issued = parse-date(fields.issued, "issued")
  let due = parse-date(fields.due, "due")
  if due < issued {
    panic("invoice: due " + fields.due + " is before issued " + fields.issued + "; set a due date on or after the issue date.")
  }
  let show-date(date) = date.display("[year]-[month]-[day]")
  let lines = fields.items.enumerate().map(((index, item)) => invoice-line(item, digits, index))
  let totals = invoice-totals(lines, exempted)
  let motif-name = meta.at("motif-name", default: none)
  let subtitle = meta.at("title", default: none)

  set page(
    paper: "a4",
    margin: geometry.margin,
    fill: colours.paper,
    background: context {
      fold-marks(standard, folds: here().page() == 1)
      if motif-name != none and here().page() == 1 { motif(motif-name, bottom + right, mc-invoice-motif-size) }
    },
    footer: context if here().page() > 1 {
      text(size: 8pt, fill: colours.muted, meta.footer)
    },
  )
  set par(spacing: 1em, justify: false)
  set text(size: 10.5pt)
  show heading: it => block(
    above: 1.6em,
    below: 0.6em,
    sticky: true,
    text(font: meta.fonts.headings, size: if it.level == 1 { 22pt } else { 11pt }, weight: "bold", it.body),
  )

  block(width: 100%, height: mc-letter-body-start - geometry.margin.top, breakable: false, {
    let (sender-x, title-x) = if din { (geometry.info.x, geometry.margin.left) } else { (geometry.margin.left, geometry.window.x) }
    at-page(standard, sender-x, geometry.margin.top, width: 70mm, text(size: 9pt, sender-block(sender)))
    at-page(standard, title-x, geometry.margin.top, width: 75mm, {
      heading(level: 1, outlined: false, mc-labels.at("mcanouil-invoice-title"))
      if subtitle != none { text(fill: colours.muted, subtitle) }
    })
    address-window(standard, recipient-lines(recipient), sender-line: if din { return-line(sender) })
    let entries = (
      (mc-labels.at("mcanouil-invoice-number"), fields.number),
      (mc-labels.at("mcanouil-invoice-issued"), show-date(issued)),
      (mc-labels.at("mcanouil-invoice-due"), show-date(due)),
    )
    if din {
      reference-block(standard, entries)
    } else {
      reference-block(standard, entries, x: geometry.margin.left, y: 62mm, width: 75mm)
    }
  })

  let numeric(content) = text(number-width: "tabular", content)
  let headers = (
    (mc-labels.at("mcanouil-invoice-description"), left),
    (mc-labels.at("mcanouil-invoice-quantity"), right),
    (mc-labels.at("mcanouil-invoice-unit-price"), right),
    ..if exempted { () } else { ((mc-labels.at("mcanouil-invoice-vat"), right),) },
    (mc-labels.at("mcanouil-invoice-amount"), right),
  )
  let columns = headers.len()
  let quantity-text(quantity) = {
    let whole-part = calc.quo(quantity, ten-to(mc-invoice-quantity-digits))
    let fraction = calc.rem(quantity, ten-to(mc-invoice-quantity-digits))
    if fraction == 0 { str(whole-part) } else {
      format-minor(quantity, mc-invoice-quantity-digits, style).trim("0", at: end)
    }
  }
  let price-text(price) = money(divide-rounded(price, ten-to(mc-invoice-quantity-digits - digits)))
  let total-row(label, value, strong-row: false) = {
    let weight = if strong-row { "bold" } else { "regular" }
    let fill = if strong-row { colours.tint } else { none }
    (
      table.cell(colspan: columns - 1, align: right, fill: fill, text(weight: weight, label)),
      table.cell(align: right, fill: fill, numeric(text(weight: weight, value))),
    )
  }
  let footer-rows = ()
  if not exempted {
    footer-rows += total-row(mc-labels.at("mcanouil-invoice-subtotal"), money(totals.subtotal))
    for entry in totals.rates {
      footer-rows += total-row(
        [#mc-labels.at("mcanouil-invoice-vat") #format-rate(entry.rate, style)],
        money(entry.vat),
      )
    }
  }
  footer-rows += total-row(mc-labels.at("mcanouil-invoice-total"), money(totals.total), strong-row: true)

  set table(
    columns: (1fr, auto, auto, ..if exempted { () } else { (auto,) }, auto),
    inset: (x: 6pt, y: 7pt),
    stroke: (x, y) => if y == 0 {
      (bottom: 0.8pt + colours.ink)
    } else if y <= lines.len() {
      (bottom: 0.5pt + colours.line)
    },
    align: (x, y) => if x == 0 { left } else { right },
  )
  table(
    table.header(..headers.map(((label, alignment)) => table.cell(align: alignment, text(weight: "bold", label)))),
    ..lines
      .map(line => (
        [#strong(line.description)#if line.details != none [ \ #text(fill: colours.muted, line.details)]],
        numeric(quantity-text(line.quantity)),
        numeric(price-text(line.price)),
        ..if exempted { () } else { (numeric(format-rate(line.rate, style)),) },
        numeric(money(line.net)),
      ))
      .flatten(),
    table.footer(repeat: false, ..footer-rows),
  )
  if exempted {
    align(right, text(fill: colours.muted, emph(mc-labels.at("mcanouil-invoice-exempted"))))
    if exemption != [true] { align(right, text(fill: colours.muted, emph(exemption))) }
  }

  body

  if "bank" in fields {
    let bank = fields.bank
    block(width: 100%, breakable: false, above: 2em, below: 0pt, fill: colours.tint, stroke: 0.5pt + colours.line, inset: 10pt, {
      heading(level: 2, mc-labels.at("mcanouil-invoice-payment"))
      grid(
        columns: (auto, 1fr),
        column-gutter: 1em,
        row-gutter: 0.5em,
        align: top,
        // BIC and IBAN stay untranslated: they are international terms.
        mc-labels.at("mcanouil-invoice-bank"), [BIC #bank.bic \ IBAN #bank.iban],
        mc-labels.at("mcanouil-invoice-reference"), strong(fields.reference),
      )
      v(0.4em)
      text(size: 9pt, fill: colours.muted, mc-labels.at("mcanouil-invoice-reference-note"))
    })
  }

  if "fee" in fields and "penalty" in fields {
    let penalty = fields.penalty
    let penalty-text = if str(penalty).match(regex("^[\d.,]+\z")) != none {
      money(parse-decimal(penalty, digits, "penalty"))
    } else { penalty }
    heading(level: 2, mc-labels.at("mcanouil-invoice-terms"))
    text(size: 9pt, fill: colours.muted, fill-template(mc-labels.at("mcanouil-invoice-terms-text"), (
      sender: sender.name,
      date: show-date(issued),
      days: str((due - issued).days()),
      fee: format-minor(parse-decimal(fields.fee, 4, "fee"), 4, style).trim("0", at: end).trim(style.point, at: end),
      penalty: penalty-text,
    )))
  }
  let identifiers = ()
  if "registration" in sender {
    identifiers.push([#mc-labels.at("mcanouil-invoice-registration") #sender.registration])
  }
  if "vat" in sender { identifiers.push([#mc-labels.at("mcanouil-invoice-vat-number") #sender.vat]) }
  if identifiers.len() > 0 {
    v(1em)
    text(size: 8pt, fill: colours.muted, identifiers.join([ #sym.dot.c ]))
  }
}
