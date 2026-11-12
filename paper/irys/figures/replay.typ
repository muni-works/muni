#import "style.typ": *
// Path replay backpropagation: one path traced twice, the replay coinciding with the forward
// pass bit for bit, against a conventional AD tape that grows with depth.
#let fig-replay() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let hair = 0.45pt + c-label
  let xs = (0.5, 2.5, 4.5, 6.5, 8.5)
  let dy = (0.0, -0.45, 0.25, -0.4, 0.45)
  let names = ([CAM], [x#sub[1]], [x#sub[2]], [x#sub[3]], [SKY])
  let path(y0, col) = {
    for i in range(4) {
      line((xs.at(i), y0 + dy.at(i)), (xs.at(i + 1), y0 + dy.at(i + 1)), stroke: 0.7pt + col)
    }
    // camera, surfaces, sky
    let (cx, cy) = (xs.at(0), y0)
    line((cx - 0.28, cy + 0.16), (cx, cy), (cx - 0.28, cy - 0.16), close: true, stroke: 0.5pt + c-line-hi, fill: c-surface)
    for i in (1, 2, 3) {
      let (x, y) = (xs.at(i), y0 + dy.at(i))
      let s = if dy.at(i) < 0 { -1 } else { 1 }
      line((x - 0.35, y + s * 0.05), (x + 0.35, y + s * 0.05), stroke: 0.5pt + c-line-hi)
      circle((x, y), radius: 0.055, fill: col, stroke: none)
    }
    circle((xs.at(4), y0 + dy.at(4)), radius: 0.14, stroke: 0.5pt + c-text, fill: c-bg)
  }
  let yf = 5.6
  let yr = 3.7
  // forward
  lbl((0.0, yf + 0.9), [FORWARD], anchor: "west", fill: c-text)
  lbl((1.4, yf + 0.9), [COMPUTES L], anchor: "west")
  path(yf, c-sel)
  for i in range(5) {
    if dy.at(i) < 0 { lbl((xs.at(i) + 0.14, yf + dy.at(i) - 0.28), names.at(i), anchor: "west") } else { lbl((xs.at(i), yf + dy.at(i) + 0.32), names.at(i)) }
  }
  // replay
  lbl((0.0, yr - 1.05), [REPLAY], anchor: "west", fill: c-text)
  lbl((1.25, yr - 1.05), [SAME SEED · SAME PIPELINES], anchor: "west")
  path(yr, c-sel)
  for i in (1, 2, 3) {
    if dy.at(i) < 0 { lbl((xs.at(i) + 0.14, yr + dy.at(i) - 0.28), [f#sub[#i]], anchor: "west", fill: c-text) } else { lbl((xs.at(i) + 0.14, yr + dy.at(i) + 0.3), [f#sub[#i]], anchor: "west", fill: c-text) }
  }
  // bit-identical: "=" between the two passes at every vertex
  for i in range(5) {
    let x = xs.at(i)
    let (a, b) = (yr + dy.at(i) + 0.2, yf + dy.at(i) - 0.2)
    let m = (a + b) / 2
    line((x, a), (x, m - 0.16), stroke: (paint: c-line-hi, thickness: 0.4pt, dash: "dotted"))
    line((x, m + 0.16), (x, b), stroke: (paint: c-line-hi, thickness: 0.4pt, dash: "dotted"))
    content((x, m), text(font: mono-m, size: s-sm, fill: c-text)[=])
  }
  lbl((9.45, (yf + yr) / 2 - 0.1), [\= BIT-IDENTICAL], anchor: "west", fill: c-sel)
  // the adjoint, accumulated at each vertex of the replay
  content((xs.at(2), yr - 1.6), text(size: s-sm, fill: c-text)[$delta theta$ #text(font: mono-m)[+=] $delta L dot (L - L_j) dot partial_theta log f_j$])
  // per-lane state: constant
  let rx = 9.45
  line((rx - 0.2, 6.6), (rx - 0.2, 2.3), stroke: 0.4pt + c-line)
  lbl((rx, 6.5), [PER LANE], anchor: "west", fill: c-text)
  for k in range(7) { rect((rx + k * 0.3, 5.75), (rx + k * 0.3 + 0.24, 6.0), stroke: 0.4pt + c-sel, fill: c-surface) }
  lbl((rx, 5.45), [FIXED WORDS / PATH], anchor: "west")
  lbl((rx, 5.15), [NOTHING PER VERTEX], anchor: "west")
  lbl((rx, 3.75), [RECOMPUTES], anchor: "west")
  lbl((rx, 3.45), [INSTEAD OF STORING], anchor: "west")
  // conventional AD: a tape that grows with depth, dimmed and struck
  let yt = 0.45
  let ghost = c-line-hi
  lbl((0.0, yt + 1.2), [CONVENTIONAL AD], anchor: "west", fill: c-label.transparentize(35%))
  lbl((2.55, yt + 1.2), [TAPE PER VERTEX], anchor: "west", fill: c-label.transparentize(35%))
  for i in (1, 2, 3) {
    for k in range(i) {
      rect((xs.at(i) - 0.3, yt + k * 0.3), (xs.at(i) + 0.3, yt + k * 0.3 + 0.24), stroke: (paint: ghost, thickness: 0.4pt, dash: "dashed"))
    }
  }
  line((xs.at(1) - 0.6, yt - 0.1), (xs.at(3) + 0.6, yt + 1.0), stroke: 0.5pt + c-label.transparentize(30%))
  // memory against depth
  let (ox, oy, w, h) = (rx, 0.35, 2.3, 1.55)
  line((ox, oy + h), (ox, oy), (ox + w, oy), stroke: hair)
  lbl((ox - 0.12, oy + h), [MEM], anchor: "east")
  lbl((ox + w, oy - 0.22), [DEPTH], anchor: "north-east")
  line((ox + 0.1, oy + 0.2), (ox + w - 0.1, oy + h - 0.05), stroke: (paint: ghost, thickness: 0.5pt, dash: "dashed"))
  lbl((ox + w - 0.95, oy + h - 0.05), [TAPE], anchor: "east", fill: c-label.transparentize(35%))
  line((ox + 0.1, oy + 0.35), (ox + w - 0.1, oy + 0.35), stroke: 0.7pt + c-sel)
  lbl((ox + w - 0.1, oy + 0.55), [PRB], anchor: "east", fill: c-sel)
})
