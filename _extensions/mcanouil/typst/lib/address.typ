// mcanouil - Typst address window
// The geometry of the two letter standards, and the address window, the fold
// marks and the punch mark that follow it. The letter and the invoice share it.
//
// NF Z 11-001 (France): A4, the window on the right at 110 mm from the left and
// 50 mm from the top, 80 by 35 mm; fold marks at one third (99 mm) and two thirds
// (198 mm) of the page height.
// DIN 5008 form B (Germany): A4, the window on the left at 20 mm from the left and
// 45 mm from the top, 85 by 45 mm; reference block at 125 mm from the left and
// 50 mm from the top, 75 mm wide; fold marks at 105 mm and 210 mm, punch mark at
// 148.5 mm.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Geometry of each standard, in distances from the top left corner of an A4 page.
// - margin: page margins of the letter.
// - window: the address window.
// - info: the reference block, or none.
// - folds: positions of the fold marks, from the top of the page.
// - punch: position of the punch mark, or none.
// - mark: length of a fold mark, from the left edge of the page.
// - return-line: height of the line of the sender above the recipient, inside the window, or none.
#let mc-letter-standards = (
  nf: (
    margin: (top: 20mm, bottom: 25mm, left: 20mm, right: 20mm),
    window: (x: 110mm, y: 50mm, width: 80mm, height: 35mm),
    info: none,
    folds: (99mm, 198mm),
    punch: none,
    mark: 5mm,
    return-line: none,
  ),
  din: (
    margin: (top: 20mm, bottom: 25mm, left: 25mm, right: 20mm),
    window: (x: 20mm, y: 45mm, width: 85mm, height: 45mm),
    info: (x: 125mm, y: 50mm, width: 75mm),
    folds: (105mm, 210mm),
    punch: 148.5mm,
    mark: 4mm,
    return-line: 12.7mm,
  ),
)

// Y position of the first line of the body on page 1, under the window and the reference block.
#let mc-letter-body-start = 100mm

// Answer a block of content placed at a distance from the top left corner of the page, for use inside
// a block that starts at the top left corner of the text area of the standard.
// - standard: key of mc-letter-standards.
// - x, y: distances from the top left corner of the page.
// - body: the content.
#let at-page(standard, x, y, width: auto, body) = {
  let margin = mc-letter-standards.at(standard).margin
  place(top + left, dx: x - margin.left, dy: y - margin.top, block(width: width, body))
}

// Answer the address window: the recipient where the window of the envelope shows it. In DIN 5008
// the line of the sender sits above the recipient, inside the window.
// - standard: key of mc-letter-standards.
// - recipient: array of content, one for each address line.
// - sender-line: content of the return line, or none.
#let address-window(standard, recipient, sender-line: none) = {
  let geometry = mc-letter-standards.at(standard)
  let window = geometry.window
  let colours = tokens()
  let skip = if geometry.return-line == none { 0pt } else { geometry.return-line }
  if sender-line != none and geometry.return-line != none {
    at-page(standard, window.x, window.y, width: window.width, text(size: 7pt, fill: colours.muted, sender-line))
  }
  at-page(standard, window.x, window.y + skip, width: window.width, recipient.join(linebreak()))
}

// Answer the fold marks and the punch mark of a standard as an artefact, for the background of a page.
// - standard: key of mc-letter-standards.
// - folds: draw the fold marks; the punch mark is drawn whatever this value.
#let fold-marks(standard, folds: true) = {
  let geometry = mc-letter-standards.at(standard)
  let colours = tokens()
  let stroke = 0.5pt + colours.muted
  pdf.artifact({
    if folds {
      for y in geometry.folds {
        place(top + left, dy: y, line(length: geometry.mark, stroke: stroke))
      }
    }
    if geometry.punch != none {
      place(top + left, dy: geometry.punch, line(length: 2 * geometry.mark, stroke: stroke))
    }
  })
}
