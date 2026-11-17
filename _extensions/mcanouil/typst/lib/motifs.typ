// mcanouil - Typst corner motifs
// The corner motif of each preset, drawn for the top right corner of a 100 by
// 100 view box. The same shapes are in html/motifs/<name>.svg; the
// motif-geometry-match check compares the two from mc-motif-lines().
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Shapes of each motif. `points` holds the polygon corners as x, y pairs, the
// x, y, width and height of a rectangle, or the centre x, y and the radius of a
// circle. `opacity` is the opacity on a dark surface; a light surface uses 85% of it.
#let mc-motif-geometry = (
  facets: (
    (kind: "polygon", points: (100, 0, 38, 0, 100, 62), opacity: 0.18),
    (kind: "polygon", points: (100, 0, 62, 0, 100, 40), opacity: 0.3),
    (kind: "polygon", points: (100, 0, 80, 0, 100, 46), opacity: 0.22),
    (kind: "polygon", points: (100, 0, 52, 0, 86, 20), opacity: 0.26),
    (kind: "polygon", points: (100, 0, 88, 0, 100, 18), opacity: 0.55),
  ),
  steps: range(4)
    .map(i => range(4 - i).map(j => (
      kind: "rect",
      points: (88 - 13 * i, 13 * j, 12, 12),
      opacity: calc.round(calc.max(0.75 - 0.16 * (i + j), 0.08), digits: 2),
    )))
    .flatten(),
  ribbon: ((0, 12, 0.55), (16, 22, 0.35), (26, 29, 0.25)).map(((a, b, o)) => (
    kind: "polygon",
    points: (40 + a, 0, 40 + b, 0, 100, 60 - b, 100, 60 - a),
    opacity: o,
  )),
  dots: range(10)
    .map(i => range(10).map(j => (i: i, j: j, o: 0.75 - calc.sqrt(i * i + j * j) * 0.085)))
    .flatten()
    .filter(it => it.o > 0.04)
    .map(it => (kind: "circle", points: (96 - it.i * 7, 4 + it.j * 7, 1.3), opacity: calc.round(it.o, digits: 2))),
)

// Answer every shape of every motif as one line of text:
// "<motif> <kind> <numbers> <opacity>".
#let mc-motif-lines() = (
  mc-motif-geometry
    .pairs()
    .map(((name, shapes)) => shapes.map(shape => (name, shape.kind, ..shape.points.map(str), str(shape.opacity)).join(" ")))
    .flatten()
)

// Answer a corner motif, tagged as an artefact and placed in its page corner
// so that it bleeds to both edges. Place it in the page background.
// - name: motif name, a key of mc-motif-geometry.
// - corner: page corner, for example top + right; the drawing is mirrored for the others.
// - size: side of the square motif.
// - dark: true on a dark surface; auto follows the render mode.
// - dx, dy: offset from the corner.
#let motif(name, corner, size, dark: auto, dx: 0pt, dy: 0pt) = {
  assert(name in mc-motif-geometry, message: "mcanouil: unknown motif \"" + name + "\"; use one of " + mc-motif-geometry.keys().join(", ") + ".")
  let colours = tokens()
  let on-dark = if dark == auto { mc-mode == "dark" } else { dark }
  let strength = if on-dark { 1 } else { 0.85 }
  let unit = size / 100
  let shade(colour, opacity) = colour.transparentize(100% - opacity * strength * 100%)
  let draw(shape) = {
    let p = shape.points
    let o = shape.opacity
    if shape.kind == "polygon" {
      let fill = gradient.linear(
        (shade(colours.at("accent-high"), o), 0%),
        (shade(colours.accent, o), 55%),
        (shade(colours.at("accent-low"), o), 100%),
        angle: 45deg,
      )
      place(top + left, polygon(fill: fill, stroke: none, ..p.chunks(2).map(((x, y)) => (x * unit, y * unit))))
    } else if shape.kind == "rect" {
      let colour = if on-dark { colours.at("accent-high") } else { colours.accent }
      place(top + left, dx: p.at(0) * unit, dy: p.at(1) * unit, rect(
        width: p.at(2) * unit,
        height: p.at(3) * unit,
        stroke: none,
        fill: shade(colour, o),
      ))
    } else {
      place(top + left, dx: (p.at(0) - p.at(2)) * unit, dy: (p.at(1) - p.at(2)) * unit, circle(
        radius: p.at(2) * unit,
        stroke: none,
        fill: shade(colours.at("accent-high"), o),
      ))
    }
  }
  let drawing = box(width: size, height: size, mc-motif-geometry.at(name).map(draw).join())
  let flipped = scale(
    x: if corner.x == left { -100% } else { 100% },
    y: if corner.y == bottom { -100% } else { 100% },
    drawing,
  )
  pdf.artifact(place(corner, dx: dx, dy: dy, flipped))
}
