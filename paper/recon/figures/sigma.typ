#import "style.typ": *
// The note's two data figures.
// fig-sigma: each held-out part's largest calibrated error bar against its actual worst error
//   (data/sigma-vs-error.csv, from irys-assets/recon-v1-gate100/ig-merged.json @812dc62).
// fig-check: the four residual signals on the fresh parts, right answers against wrong ones
//   (data/check-fresh.csv, from irys claude/recon-amplitudes runs/fresh).

#let lg(v) = calc.log(v, base: 10)

#let fig-sigma() = {
  let rows = csv("../data/sigma-vs-error.csv").slice(1).map(r => (
    seed: int(r.at(0)), s: float(r.at(1)), e: float(r.at(2)), right: r.at(3) == "1", topo: r.at(4) == "1"))
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let (W, H, band) = (9.0, 5.0, 0.9)
    // x: sigma' 0.03 .. 30 mm; y: error 0.01 .. 10 mm, then a band for wrong features
    let x(v) = (lg(calc.clamp(v, 0.03, 30)) + 1.5) / 3 * W
    let y(v) = (lg(calc.clamp(v, 0.01, 10)) + 2) / 3 * H
    // tight region and pass line
    rect((0, 0), (x(1), H + band + 0.15), fill: c-sel.transparentize(90%), stroke: none)
    rect((0, 0), (W, H), stroke: 0.4pt + c-line-hi)
    rect((0, H + 0.15), (W, H + band + 0.15), stroke: 0.4pt + c-line-hi)
    for (v, t) in ((0.01, [0.01]), (0.1, [0.1]), (1, [1 mm]), (10, [10])) {
      line((0, y(v)), (W, y(v)), stroke: 0.3pt + c-line)
      lbl((-0.1, y(v)), t, anchor: "east")
    }
    for (v, t) in ((0.1, [0.1]), (1, [1 mm]), (10, [10])) {
      line((x(v), 0), (x(v), H), stroke: 0.3pt + c-line)
      lbl((x(v), -0.22), t, anchor: "north")
    }
    line((0, y(1)), (W, y(1)), stroke: (paint: c-text.transparentize(30%), thickness: 0.5pt, dash: "dashed"))
    line((x(0.03), y(0.03)), (x(10), y(10)), stroke: (paint: c-label, thickness: 0.4pt, dash: "dotted"))
    lbl((x(4), y(4) + 0.05), [ERROR = σ′], anchor: "south-east")
    lbl((W / 2, -0.62), [LARGEST CALIBRATED ERROR BAR σ′ OF THE PART], anchor: "north")
    lbl((-0.95, H / 2), std.rotate(-90deg, reflow: true)[ACTUAL WORST ERROR], anchor: "center")
    lbl((-0.1, H + 0.15 + band / 2), [WRONG\ FEATURES], anchor: "east")
    lbl((x(1) - 0.08, H + band + 0.3), [σ′ ≤ 1 MM: LOOKS TRUSTWORTHY], anchor: "south-east", fill: c-sel)
    for (i, r) in rows.enumerate() {
      let col = if r.right { c-ok } else { c-fault }
      let py = if r.topo { y(r.e) } else { H + 0.15 + band * (0.2 + 0.6 * calc.rem(i * 37, 11) / 10) }
      circle((x(r.s), py), radius: 0.075, fill: col.transparentize(15%), stroke: none)
    }
    // legend
    circle((0.25, -1.2), radius: 0.075, fill: c-ok, stroke: none)
    lbl((0.4, -1.2), [RIGHT (RIGHT FEATURES, WITHIN 1 MM)], anchor: "west", fill: c-ok)
    circle((6.6, -1.2), radius: 0.075, fill: c-fault, stroke: none)
    lbl((6.75, -1.2), [WRONG], anchor: "west", fill: c-fault)
  })
}

#let fig-check() = {
  let rows = csv("../data/check-fresh.csv").slice(1).map(r => (
    seed: int(r.at(0)), ex: float(r.at(1)), ol: float(r.at(2)), bl: float(r.at(3)),
    mg: if r.at(4) == "" { none } else { float(r.at(4)) }, right: r.at(5) == "1"))
  // name, value, axis transform to 0..1, ticks, fitted threshold (none: rule dropped)
  let sigs = (
    ([RESIDUAL EXCESS (PART ÷ TABLE)], r => r.ex, v => (lg(calc.clamp(v, 0.2, 20)) + 0.7) / 2, ((0.3, "0.3"), (1, "1"), (3, "3"), (10, "10")), 6.0),
    ([OUTLINE OFFSET, PX], r => r.ol, v => calc.clamp(v, 0, 2.5) / 2.5, ((0, "0"), (1, "1"), (2, "2")), 1.5),
    ([FINALIST MARGIN, NATS], r => r.mg, v => (lg(calc.clamp(v, 3, 3000)) - lg(3)) / 3, ((10, "10"), (100, "100"), (1000, "1000")), none),
  )
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let (W, lane, gap) = (8.4, 0.42, 0.75)
    let ox = 0.0
    for (k, (name, get, tf, ticks, thr)) in sigs.enumerate() {
      let top = -k * (2 * lane + gap + 0.35)
      lbl((ox, top + 0.18), name, anchor: "south-west", fill: c-text)
      for (j, (lab, want, col)) in (([RIGHT], true, c-ok), ([WRONG], false, c-fault)).enumerate() {
        let yc = top - lane * (j + 0.5)
        rect((ox, top - lane * j), (ox + W, top - lane * (j + 1)), stroke: 0.3pt + c-line, fill: none)
        lbl((ox - 0.1, yc), lab, anchor: "east", fill: col)
        for (i, r) in rows.filter(r => r.right == want).enumerate() {
          let v = get(r)
          if v != none {
            let jit = (calc.rem(r.seed * 7, 9) / 8 - 0.5) * lane * 0.7
            circle((ox + tf(v) * W, yc + jit), radius: 0.055, fill: col.transparentize(25%), stroke: none)
          }
        }
      }
      for (v, t) in ticks { lbl((ox + tf(v) * W, top - 2 * lane - 0.08), t, anchor: "north") }
      if thr != none {
        let tx = ox + tf(thr) * W
        line((tx, top + 0.05), (tx, top - 2 * lane - 0.02), stroke: (paint: c-sel, thickness: 0.8pt))
      } else {
        lbl((ox + W, top + 0.18), [DROPPED BY THE FIT], anchor: "south-east", fill: c-label)
      }
    }
    let yb = -3 * (2 * lane + gap + 0.35) + 0.1
    line((ox, yb), (ox + 0.4, yb), stroke: (paint: c-sel, thickness: 0.8pt))
    lbl((ox + 0.5, yb), [THRESHOLD FITTED ON EVEN SEEDS; RIGHT OF IT FLAGS THE PART], anchor: "west", fill: c-sel)
  })
}
