#import "style.typ": *
// The recovery loop: propose an edit to the CAD program, fit its parameters with irys, keep it only
// if the description (in nats) gets shorter. Bar lengths are schematic, not measured.
#let fig-recon() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let ar(a, b, col: c-label, w: 0.6pt) = line(a, b, stroke: w + col, mark: (end: ">", size: 0.13, fill: col))
  let panel(a, b, title, col: c-line-hi) = {
    rect(a, b, stroke: 0.6pt + col, fill: c-surface, radius: 0.08)
    lbl((a.at(0) + 0.14, b.at(1) - 0.2), title, anchor: "west", fill: if col == c-line-hi { c-label } else { col })
  }
  let code(pos, body, fill: c-text) = content(pos, anchor: "west", text(font: mono-m, size: s-xs, fill: fill, body))
  // inputs: three photographs, each with its tag, and the tag
  for (i, dy) in ((0, 0.0), (1, 0.95), (2, 1.9)) {
    let (x, y) = (0.0 + 0.12 * i, 3.55 + dy)
    rect((x, y), (x + 1.2, y + 0.8), stroke: 0.5pt + c-label, fill: c-bg)
    rect((x + 0.15, y + 0.12), (x + 0.38, y + 0.35), stroke: none, fill: c-text.transparentize(30%))
    rect((x + 0.55, y + 0.3), (x + 1.0, y + 0.6), stroke: 0.4pt + c-label)
  }
  lbl((0.7, 6.6), [PHOTOS])
  lbl((0.7, 3.25), [TAG: CAMERA, SCALE])
  // program
  panel((2.3, 3.6), (7.0, 6.5), [PROGRAM])
  code((2.45, 5.85), [base 62.5 50.7 16.2])
  code((2.45, 5.45), [hole 5.7 -5.4 3.3])
  code((2.45, 5.05), [slotx 18.0 9.1 4.2])
  code((2.45, 4.65), [pose x y yaw], fill: c-label)
  // sketch of the part: plate, hole, slot
  rect((5.35, 4.1), (6.8, 5.5), stroke: 0.5pt + c-text.transparentize(30%), radius: 0.12)
  circle((5.85, 5.0), radius: 0.17, stroke: 0.5pt + c-sel)
  rect((5.6, 4.35), (6.5, 4.6), stroke: 0.5pt + c-text.transparentize(30%), radius: 0.125)
  lbl((6.08, 3.85), [THE PART])
  // edits
  panel((8.0, 3.6), (11.9, 6.5), [EDIT])
  code((8.15, 5.85), [\+ feature])
  code((8.15, 5.45), [\− feature])
  code((8.15, 5.05), [hole ↔ counterbore])
  code((8.15, 4.65), [holes → pattern])
  // fit
  panel((8.0, 0.9), (11.9, 2.7), [FIT], col: c-irys)
  code((8.15, 1.95), [Levenberg–Marquardt on θ])
  code((8.15, 1.5), [J by irys edge sampling], fill: c-irys)
  // score: the description in nats, three candidates
  panel((2.3, 0.0), (7.0, 2.7), [SCORE  NATS])
  let sc = 0.58
  let bar(y, name, r, f, p, ok) = {
    lbl((3.75, y), name, anchor: "east")
    let x = 3.9
    rect((x, y - 0.1), (x + r * sc, y + 0.1), stroke: none, fill: c-line-hi)
    let x = x + r * sc
    rect((x, y - 0.1), (x + f * sc, y + 0.1), stroke: none, fill: c-label.transparentize(40%))
    let x = x + f * sc
    rect((x, y - 0.1), (x + p * sc, y + 0.1), stroke: none, fill: c-text.transparentize(15%))
    let x = x + p * sc
    if ok == true { line((x + 0.1, y), (x + 0.17, y - 0.08), (x + 0.32, y + 0.1), stroke: 0.8pt + c-ok) }
    if ok == false { line((x + 0.1, y - 0.09), (x + 0.28, y + 0.09), stroke: 0.8pt + c-fault); line((x + 0.1, y + 0.09), (x + 0.28, y - 0.09), stroke: 0.8pt + c-fault) }
  }
  bar(1.9, [NOW], 3.0, 0.3, 0.6, none)
  bar(1.5, [\+ SLOT], 1.4, 0.5, 0.9, true)
  bar(1.1, [\+ 1/PIXEL], 0.1, 1.0, 3.4, false)
  // legend
  let lg(x, col, name) = { rect((x, 0.38), (x + 0.2, 0.52), stroke: none, fill: col); lbl((x + 0.27, 0.45), name, anchor: "west") }
  lg(2.4, c-line-hi, [RESIDUAL])
  lg(3.95, c-label.transparentize(40%), [PARAMS])
  lg(5.35, c-text.transparentize(15%), [PROGRAM])
  // the loop
  ar((7.0, 5.05), (8.0, 5.05))
  lbl((7.5, 5.25), [PROPOSE], anchor: "south")
  ar((9.95, 3.6), (9.95, 2.7))
  lbl((10.05, 3.15), [EACH EDIT], anchor: "west")
  ar((8.0, 1.8), (7.0, 1.8))
  ar((4.65, 2.7), (4.65, 3.6), col: c-ok)
  lbl((4.75, 3.15), [KEEP IF SHORTER], anchor: "west", fill: c-ok)
  ar((0.9, 3.05), (2.3, 1.9))
  // the one exit
  ar((7.0, 0.35), (8.0, 0.35), col: c-sel)
  lbl((8.1, 0.47), [DIMENSIONS ± √(F⁻¹)], anchor: "west", fill: c-sel)
  lbl((8.1, 0.15), [WHEN NO EDIT IS SHORTER], anchor: "west")
})
