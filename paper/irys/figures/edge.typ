#import "style.typ": *
// Primary edge sampling: a silhouette edge E of a projected triangle moves under the pose phi;
// the pixels it sweeps change coverage, and only rays traced either side of E see that.
#let fig-edge() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let add(a, b) = (a.at(0) + b.at(0), a.at(1) + b.at(1))
  let sc(a, k) = (a.at(0) * k, a.at(1) * k)
  let dot(a, b) = a.at(0) * b.at(0) + a.at(1) * b.at(1)
  let px = 0.6
  let (x0, y0) = (0.0, 0.6)
  // triangle; E = A to B is the silhouette, its outward normal n points down-right
  let A = (0.35, 0.85)
  let B = (3.3, 3.45)
  let C = (0.3, 3.4)
  let L = calc.sqrt(calc.pow(B.at(0) - A.at(0), 2) + calc.pow(B.at(1) - A.at(1), 2))
  let u = ((B.at(0) - A.at(0)) / L, (B.at(1) - A.at(1)) / L)
  let n = (u.at(1), -u.at(0))
  let d = 0.42
  let s = add(A, sc(add(B, sc(A, -1)), 0.5))
  // pixels swept between E and its displaced copy: their coverage changes
  for i in range(6) { for j in range(5) {
    let c = (x0 + (i + 0.5) * px, y0 + (j + 0.5) * px)
    let t = dot(add(c, sc(A, -1)), n)
    let along = dot(add(c, sc(A, -1)), u)
    if t > 0 and t < d and along > 0 and along < L {
      rect((x0 + i * px, y0 + j * px), (x0 + (i + 1) * px, y0 + (j + 1) * px), stroke: none, fill: c-sel.transparentize(80%))
    }
  }}
  line(A, B, C, close: true, stroke: 0.5pt + c-info.transparentize(30%), fill: c-info.transparentize(88%))
  grid((x0, y0), (x0 + 6 * px, y0 + 5 * px), step: px, stroke: 0.4pt + c-line-hi)
  // displaced edge under phi + d phi
  line(add(A, sc(n, d)), add(B, sc(n, d)), stroke: (paint: c-sel.transparentize(45%), thickness: 0.6pt, dash: (1.5pt, 1.5pt)))
  line(A, B, stroke: 1.1pt + c-sel)
  line(s, add(s, sc(n, d)), stroke: 0.6pt + c-sel, mark: (end: ">", size: 0.12, fill: c-sel))
  circle(s, radius: 0.045, fill: c-text, stroke: none)
  lbl(add(s, (-0.14, 0.2)), text(fill: c-text)[s])
  lbl(add(add(s, sc(n, d)), (0.24, -0.04)), text(fill: c-sel)[v#sub[n]])
  lbl(add(B, (-0.4, 0.17)), text(fill: c-sel)[E])
  lbl(add(add(B, sc(n, d)), (0.06, 0.1)), [E′], anchor: "west", fill: c-sel.transparentize(30%))
  lbl((x0 + 1.8, y0 + 3.3), [6×5 PIXELS])
  lbl((x0 + 1.8, y0 - 0.3), [SWEPT PIXELS CHANGE COVERAGE], fill: c-sel.transparentize(20%))

  // inset: s magnified, epsilon = 1e-3 px drawn as 0.5
  let O = (5.6, 2.25)
  let R = 1.3
  let e = 0.55
  circle(s, radius: 0.16, stroke: 0.4pt + c-label)
  line(add(s, (0.12, 0.11)), add(O, (-0.92, 0.9)), stroke: 0.4pt + c-label.transparentize(40%))
  line(add(s, (0.12, -0.11)), add(O, (-0.92, -0.9)), stroke: 0.4pt + c-label.transparentize(40%))
  let P(a, b) = add(O, add(sc(u, a), sc(n, b)))
  // own triangle: a sliver thinner than epsilon; beyond it the coplanar neighbour of the same face
  let seg(b1, b2) = range(121).map(k => {
    let t = k / 120 * 2 * calc.pi
    let (ca, cb) = (R * calc.cos(t), R * calc.sin(t))
    let bb = calc.clamp(cb, b1, b2)
    let aa = calc.sqrt(calc.max(R * R - bb * bb, 0)) * (if ca < 0 { -1 } else { 1 })
    P(aa, bb)
  })
  let sl = 0.2
  line(..seg(-sl, 0), close: true, stroke: none, fill: c-sel.transparentize(72%))
  line(..seg(-R, -sl), close: true, stroke: none, fill: c-info.transparentize(86%))
  let ca = calc.sqrt(R * R - sl * sl)
  line(P(-ca, -sl), P(ca, -sl), stroke: 0.3pt + c-info.transparentize(40%))
  let cb = R
  line(P(-cb, 0), P(cb, 0), stroke: 1.1pt + c-sel)
  circle(O, radius: R, stroke: 0.5pt + c-label)
  let si = P(0, -e)
  let so = P(0, e)
  line(si, so, stroke: 0.4pt + c-label)
  circle(O, radius: 0.04, fill: c-text, stroke: none)
  circle(si, radius: 0.055, fill: c-info, stroke: none)
  circle(so, radius: 0.055, fill: c-info, stroke: none)
  lbl(add(si, (-0.1, 0.1)), [f(s − εn)], anchor: "east", fill: c-info)
  lbl(add(si, (-0.1, -0.12)), [INSIDE], anchor: "east")
  lbl(add(so, (0.0, -0.2)), [f(s + εn)], anchor: "north", fill: c-info)
  lbl(add(so, (0.0, -0.42)), [OUTSIDE], anchor: "north")
  lbl(add(O, (0, 1.55)), [INSET · ε = 10#super[−3] PX])
  lbl(add(O, (0, -1.55)), [OWN TRIANGLE: SLIVER < ε])
  lbl(P(0.25, -0.98), [COPLANAR NEIGHBOUR], size: 5.5pt)
  // the estimator
  content((5.8, -0.75), text(font: sans, size: 8.5pt, fill: c-text,
    $(partial I_p) / (partial phi) supset.eq integral_E (f(s - epsilon n) - f(s + epsilon n)) thin v_n thin dif ell$))
  let fx = 7.45
  note((fx, 3.9), [Moving #text(fill: c-sel)[E] to #text(fill: c-sel)[E′] changes which pixels are covered. The change is a jump, invisible to derivatives of shading at fixed rays; only rays either side of a sampled point on E measure it.], width: 3.6cm)
  note((fx, 1.55), [CAD tessellations are full of slivers thinner than ε. The inner ray counts as inside on the edge's own triangle or a coplanar neighbour of the same face.], width: 3.6cm)
})
