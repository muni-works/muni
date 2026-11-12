#import "style.typ": *
// Why the replay is bit-exact: (a) an integer RNG both tiers compute identically, (b) a fixed
// combining tree instead of float atomics, (c) a BVH walk whose order depends on the ray alone.
#let fig-determinism() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let hair = 0.45pt + c-label
  let ar(a, b, col: c-label) = line(a, b, stroke: 0.5pt + col, mark: (end: ">", size: 0.1, fill: col))
  let txt(pos, body, fill: c-text, anchor: "center") = content(pos, anchor: anchor, text(font: mono-m, size: s-xs, fill: fill, body))
  let top = 4.6
  // ---- (a) RNG ----
  lbl((0, top), [(A) SPLITMIX64 IN LIMBS], anchor: "west", fill: c-text)
  lbl((0, top - 0.45), [64-BIT STATE =], anchor: "west")
  lbl((0, top - 0.75), [4 × 16-BIT LIMBS], anchor: "west")
  for k in range(4) {
    rect((0.2 + k * 0.85, 3.0), (0.95 + k * 0.85, 3.45), stroke: 0.6pt + c-sel, fill: c-surface)
    txt((0.575 + k * 0.85, 3.225), [16])
  }
  // two lanes
  let lane(y, name, sub) = {
    rect((0.1, y - 0.25), (1.75, y + 0.25), stroke: 0.5pt + c-line-hi, fill: c-surface)
    txt((0.925, y + 0.0), name)
    lbl((0.925, y - 0.42), sub)
  }
  ar((0.925, 3.0), (0.925, 2.35))
  ar((2.775, 3.0), (2.775, 2.35))
  lane(2.1, [GPU], [2 × u32 WORDS])
  rect((1.95, 1.85), (3.6, 2.35), stroke: 0.5pt + c-line-hi, fill: c-surface)
  txt((2.775, 2.1), [CPU f64 REF])
  lbl((2.775, 1.68), [u64])
  // identical outputs
  for (j, dx) in ((0, -0.45), (1, 0.0), (2, 0.45)) {
    txt((0.925 + dx, 0.95), [u#sub[#j]], fill: c-sel)
    txt((2.775 + dx, 0.95), [u#sub[#j]], fill: c-sel)
  }
  ar((0.925, 1.45), (0.925, 1.15)); ar((2.775, 1.45), (2.775, 1.15))
  txt((1.85, 0.95), [=])
  lbl((1.85, 0.45), [SAME STREAM, BIT FOR BIT])
  // ---- (b) fixed-order reduction ----
  let bx = 4.15
  lbl((bx, top), [(B) FIXED-ORDER SUM], anchor: "west", fill: c-text)
  lbl((bx, top - 0.45), [256 SPLITS ·], anchor: "west")
  lbl((bx, top - 0.75), [1 WORKGROUP / PARAM], anchor: "west")
  let lw = 0.43
  let lvl = (1.45, 2.05, 2.65, 3.25)
  let px(level, i) = bx + 0.2 + lw * (calc.pow(2, level) * (i + 0.5))
  for i in range(8) {
    circle((px(0, i), lvl.at(0)), radius: 0.06, fill: c-label, stroke: none)
    txt((px(0, i), lvl.at(0) - 0.25), [g#sub[#i]], fill: c-label)
  }
  for l in (1, 2, 3) {
    let n = calc.pow(2, 3 - l)
    for i in range(n) {
      let p = (px(l, i), lvl.at(l))
      line((px(l - 1, 2 * i), lvl.at(l - 1)), p, (px(l - 1, 2 * i + 1), lvl.at(l - 1)), stroke: 0.5pt + c-line-hi)
      circle(p, radius: 0.06, fill: if l == 3 { c-sel } else { c-text }, stroke: none)
    }
  }
  txt((px(3, 0) + 0.15, lvl.at(3) + 0.02), [δθ], fill: c-sel, anchor: "west")
  // the crossed-out alternative
  txt((px(3, 0), 0.6), [atomicAdd (ORDER VARIES)], fill: c-label.transparentize(40%))
  line((px(3, 0) - 1.6, 0.6), (px(3, 0) + 1.6, 0.6), stroke: 0.5pt + c-label.transparentize(20%))
  // ---- (c) ray-only BVH walk ----
  let cx = 8.2
  lbl((cx, top), [(C) RAY-ONLY BVH WALK], anchor: "west", fill: c-text)
  lbl((cx, top - 0.45), [NEAR CHILD FIRST BY SLAB], anchor: "west")
  lbl((cx, top - 0.75), [ENTRY · FIXED TIE-BREAK], anchor: "west")
  // root
  rect((cx + 0.35, 1.05), (cx + 3.5, 3.55), stroke: 0.5pt + c-line-hi)
  // children
  rect((cx + 0.55, 1.95), (cx + 1.95, 3.35), stroke: 0.5pt + c-line-hi, fill: c-surface)
  rect((cx + 1.75, 1.25), (cx + 3.3, 2.6), stroke: 0.5pt + c-line-hi, fill: c-surface)
  // triangles
  line((cx + 0.7, 2.15), (cx + 1.3, 2.05), (cx + 0.85, 2.55), close: true, stroke: 0.4pt + c-label)
  line((cx + 2.35, 1.5), (cx + 3.0, 1.7), (cx + 2.5, 2.35), close: true, stroke: 0.4pt + c-label)
  // the ray: origin left, through both children
  let (o, d) = ((cx + 0.0, 3.2), (cx + 3.7, 1.25))
  line(o, d, stroke: 0.7pt + c-info, mark: (end: ">", size: 0.1, fill: c-info))
  // visit order
  let num(p, n) = { circle(p, radius: 0.16, fill: c-bg, stroke: 0.5pt + c-sel); txt(p, [#n], fill: c-sel) }
  let ry(x) = 3.2 - (3.2 - 1.25) / 3.7 * x
  num((cx + 0.35, ry(0.35) + 0.38), 1)
  num((cx + 0.75, ry(0.55) + 0.12), 2)
  num((cx + 1.95, ry(1.75) + 0.12), 3)
  circle((cx + 2.6, ry(2.6)), radius: 0.06, fill: c-info, stroke: none)
  lbl((cx + 1.9, 0.6), [CLOSEST-HIT CULLING])
  lbl((cx + 1.9, 0.3), [ORDER = f(RAY) ALONE])
})
