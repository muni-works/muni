#import "style.typ": *
// Attached frames. (a) basis(n) builds the tangent from the normal and flips its sign when n
// crosses a plane, so omega, drawn from fixed random numbers in that frame, jumps. (b) The frame
// carried rigidly by the instance, R(phi) R(phi0)^T basis(n(phi0)), turns with it and omega moves
// continuously. Same image in expectation; only (b) is differentiable at fixed random numbers.
#let fig-frames() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let pol(a, r) = (r * calc.cos(a), r * calc.sin(a))
  let add(a, b) = (a.at(0) + b.at(0), a.at(1) + b.at(1))
  let angs = (60deg, 78deg, 102deg, 120deg)   // the normal's direction at phi0..phi3
  let xs = (1.9, 4.2, 6.5, 8.8)
  let ar(p, q, col, w) = line(p, q, stroke: w + col, mark: (end: ">", size: 0.11, fill: col))
  let panel(y, attached) = {
    // the plane basis(n) flips on, between phi1 and phi2
    for k in range(4) {
      let o = (xs.at(k), y)
      let a = angs.at(k)
      let op = 20% * (3 - k)     // older steps are ghosted
      let flip = not attached and k >= 2
      let ta = if flip { a + 90deg } else { a - 90deg }
      let t = pol(ta, 0.75)
      let w = add(pol(ta, 0.75 * calc.cos(55deg)), pol(a, 0.75 * calc.sin(55deg)))
      let tcol = if attached { c-irys } else if flip { c-sel } else { c-text }
      // the surface under the vertex, turning with the instance
      line(add(o, pol(a - 90deg, 0.55)), add(o, pol(a + 90deg, 0.55)), stroke: 0.7pt + c-line-hi)
      ar(o, add(o, pol(a, 0.85)), c-label.transparentize(op), 0.6pt)
      ar(o, add(o, t), tcol.transparentize(op), 0.8pt)
      ar(o, add(o, w), c-info.transparentize(op), 0.6pt)
      circle(o, radius: 0.035, fill: c-text, stroke: none)
      if k == 0 {
        lbl(add(o, pol(a, 1.0)), [n])
        lbl(add(add(o, t), (0.12, -0.12)), text(fill: tcol)[t])
        lbl(add(add(o, w), (0.18, 0.05)), text(fill: c-info)[ω])
      }
      lbl((xs.at(k), y - 0.95), [φ#sub[#k]])
    }
    line((xs.at(0) - 0.4, y - 0.75), (xs.at(3) + 0.4, y - 0.75), stroke: 0.4pt + c-line-hi, mark: (end: ">", size: 0.1, fill: c-line-hi))
  }
  // (a)
  let ya = 3.75
  lbl((0.0, ya + 0.95), text(fill: c-text)[(a) basis(n)], anchor: "west")
  panel(ya, false)
  let xm = (xs.at(1) + xs.at(2)) / 2
  line((xm, ya - 0.6), (xm, ya + 0.95), stroke: (paint: c-sel.transparentize(30%), thickness: 0.5pt, dash: (2pt, 2pt)))
  lbl((xm, ya + 1.1), [n CROSSES THE PLANE: t FLIPS], fill: c-sel)
  note((10.0, ya + 0.5), [ω jumps at fixed random numbers. No edge term sees it.], width: 1.9cm)
  // (b)
  let yb = 1.0
  lbl((0.0, yb + 0.95), text(fill: c-text)[(b) attached], anchor: "west")
  panel(yb, true)
  lbl((xm, yb + 1.1), [R(φ) R(φ#sub[0])#super[T] basis(n(φ#sub[0]))], fill: c-irys)
  note((10.0, yb + 0.5), [t turns with the instance; ω moves continuously.], width: 1.9cm)
})
