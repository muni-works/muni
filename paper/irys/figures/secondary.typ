#import "style.typ": *
// Secondary edges: a moving occluder moves its shadow, and the shadow's edge is a jump in the
// pixel that sees the floor. Floor y = 0 (normal m up), sun direction l = (-1, 1.6)/|.|, so a point
// (x, y) of the occluder shadows the floor at x + y/1.6. X is the block's top-right corner.
#let fig-secondary() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let k = 1.0 / 1.6                       // run per unit drop of a sun ray
  let hair = 0.4pt + c-label
  let ray = 0.45pt + c-info.transparentize(35%)
  let ar(a, b, col, w: 0.6pt) = line(a, b, stroke: w + col, mark: (end: ">", size: 0.13, fill: col))
  let floorx(p) = p.at(0) + p.at(1) * k
  // block and its displacement v
  let (x0, x1, y0, y1) = (2.4, 3.6, 2.0, 2.6)
  let v = (0.5, 0.3)
  let X = (x1, y1)
  let X2 = (x1 + v.at(0), y1 + v.at(1))
  let S = (floorx(X), 0)
  let S2 = (floorx(X2), 0)
  let Sl = (floorx((x0, y0)), 0)
  // floor and shadow
  rect((Sl.at(0), -0.12), (S.at(0), 0), stroke: none, fill: c-surface)
  line((0.3, 0), (10.9, 0), stroke: 0.6pt + c-line-hi)
  rect((Sl.at(0), 0), (S.at(0), 0.035), stroke: none, fill: c-text.transparentize(80%))
  lbl((10.9, 0.2), [RECEIVER], anchor: "east")
  ar((0.55, 0), (0.55, 0.6), c-label, w: 0.45pt)
  lbl((0.7, 0.42), [m], anchor: "west")
  // parallel sun rays: one grazing X (it makes S), one grazing the opposite corner, two in the open
  for p in ((x0, y0), X) {
    let t = 1.15
    line((p.at(0) - t, p.at(1) + t * 1.6), (floorx(p), 0), stroke: ray)
  }
  line((1.9 - 2.2, 3.52), (1.9, 0), stroke: ray)
  // the displaced copy's grazing ray
  line((X2.at(0) - 0.55, X2.at(1) + 0.88), S2, stroke: (paint: c-info.transparentize(65%), thickness: 0.4pt, dash: "dashed"))
  // sun direction l (toward the sun)
  ar((1.6, 3.15), (1.6 - 0.5, 3.15 + 0.8), c-info)
  lbl((0.95, 3.82), [l], anchor: "east", fill: c-info)
  lbl((0.95, 3.5), [SUN], anchor: "east")
  // occluder and ghost
  rect((x0 + v.at(0), y0 + v.at(1)), (x1 + v.at(0), y1 + v.at(1)), stroke: (paint: c-line-hi, thickness: 0.5pt, dash: "dashed"))
  rect((x0, y0), (x1, y1), stroke: 0.7pt + c-line-hi, fill: c-surface)
  lbl(((x0 + x1) / 2, y0 - 0.22), [ARM LINK], anchor: "north")
  circle(X, radius: 0.055, fill: c-sel, stroke: none)
  lbl((X.at(0) - 0.12, X.at(1) + 0.16), [X], anchor: "south-east", fill: c-sel)
  ar(X, X2, c-text, w: 0.5pt)
  lbl((X2.at(0) + 0.12, X2.at(1) + 0.02), [v], anchor: "west", fill: c-text)
  // S, S' and dS on the floor
  circle(S, radius: 0.055, fill: c-sel, stroke: none)
  circle(S2, radius: 0.045, fill: none, stroke: 0.5pt + c-sel)
  lbl((S.at(0), -0.2), [S], anchor: "north", fill: c-sel)
  ar((S.at(0), -0.62), (S2.at(0), -0.62), c-sel)
  lbl((S.at(0) - 0.15, -0.62), [dS], anchor: "east", fill: c-sel)
  content((S2.at(0), -0.95), anchor: "north-east",
    text(font: sans, size: s-sm, fill: c-text)[$d S = v - l thin (m dot v) \/ (m dot l)$])
  lbl(((Sl.at(0) + S.at(0)) / 2, -0.22), [SHADOW], anchor: "north")
  // camera and the pixel that sees S
  let C = (10.1, 2.6)
  line(C, S, stroke: 0.45pt + c-text.transparentize(40%))
  line(C, (S2.at(0) + 0.0, 0), stroke: (paint: c-text.transparentize(80%), thickness: 0.35pt))
  merge-path(fill: c-surface, stroke: 0.6pt + c-line-hi, {
    line((C.at(0) - 0.05, C.at(1)), (C.at(0) + 0.5, C.at(1) + 0.28), (C.at(0) + 0.5, C.at(1) - 0.28), close: true)
  })
  lbl((C.at(0) + 0.25, C.at(1) + 0.45), [CAMERA], anchor: "south")
  note((7.0, 4.15), [The pixel's value jumps across S, so the shadow's motion is part of ∂I/∂φ, though the arm is not in the pixel.], width: 3.6cm)
  note((6.7, -0.45), [Edges seen from each path vertex, from an edge BVH per part; one-sample MIS over geometry, sun cone and mirror lobe.], width: 4.0cm)
})
