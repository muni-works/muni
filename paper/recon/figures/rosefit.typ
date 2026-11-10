#import "style.typ": *
// The rose-arm fit, every run of irys docs/phase2f-rose-loss.csv: (a) image loss per iteration
// for each configuration, the headline run in orange; (b) the headline run's three joint angles
// against the truth. Truth = rose/arm.rs TRUE_PHI.
#let fig-rosefit() = {
  let rows = csv("../data/rose-fit.csv").slice(1)
  let runs = ()
  for r in rows { if r.at(0) not in runs { runs.push(r.at(0)) } }
  let head = "context; 2f; 600 its"
  let names = (
    "context; 2f; 600 its": "ALL TERMS · 600 ITERS",
    "context; 2f; 300 its": "ALL TERMS · 300",
    "context; no secondary": "NO SECONDARY EDGES",
    "context; 2f + pyramid": "+ PYRAMID SCHEDULE",
    "control; 2f": "ARM ALONE (CONTROL)",
  )
  let truth = (-25.78, 16.04, -60.16)
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let (W, H) = (4.6, 3.8)
    // (a) worst joint error in degrees, log scale, every configuration
    let lx(i) = i / 600 * W
    let err(r) = calc.max(..range(3).map(j => calc.abs(float(r.at(3 + j)) * 180 / calc.pi - truth.at(j))))
    let ly(v) = (calc.log(calc.max(v, 0.03), base: 10) + 1.5) / 3.3 * H
    rect((0, 0), (W, H), stroke: 0.4pt + c-line-hi)
    for (e, t) in ((-1, [0.1°]), (0, [1°]), (1, [10°])) {
      let y = (e + 1.5) / 3.3 * H
      line((0, y), (W, y), stroke: 0.3pt + c-line)
      lbl((-0.1, y), t, anchor: "east")
    }
    for i in (0, 300, 600) { lbl((lx(i), -0.25), [#i], anchor: "north") }
    lbl((W / 2, -0.65), [ITERATION], anchor: "north")
    lbl((0, H + 0.25), [(A) WORST JOINT ERROR], anchor: "south-west", fill: c-text)
    let order = (head, "context; 2f; 300 its", "control; 2f", "context; no secondary", "context; 2f + pyramid")
    for (k, run) in order.enumerate() {
      let pts = rows.filter(r => r.at(0) == run).map(r => (lx(float(r.at(1))), calc.clamp(ly(err(r)), 0, H)))
      let hot = run == head
      let col = if hot { c-sel } else { (c-text, c-info, c-label, c-irys).at(calc.rem(k - 1, 4)).transparentize(30%) }
      line(..pts, stroke: (paint: col, thickness: if hot { 1pt } else { 0.5pt }))
      let (gx, gy) = (calc.rem(k, 2) * 5.6, -1.25 - calc.floor(k / 2) * 0.36)
      line((gx, gy), (gx + 0.35, gy), stroke: (paint: col, thickness: if hot { 1pt } else { 0.6pt }))
      lbl((gx + 0.45, gy), names.at(run), anchor: "west", fill: if hot { c-sel } else { c-label })
    }
    // (b) joint angles of the headline run
    let ox = W + 1.5
    let bx(i) = ox + i / 600 * (W - 1.2)
    let by(v) = (v + 70) / 90 * H
    rect((ox, 0), (ox + W - 1.6, H), stroke: 0.4pt + c-line-hi)
    for v in (-60, -40, -20, 0, 20) { lbl((ox - 0.1, by(v)), [#v°], anchor: "east") }
    for i in (0, 300, 600) { lbl((bx(i), -0.25), [#i], anchor: "north") }
    lbl((ox + (W - 1.2) / 2, -0.65), [ITERATION], anchor: "north")
    lbl((ox, H + 0.25), [(B) ALL-TERMS RUN], anchor: "south-west", fill: c-text)
    let hr = rows.filter(r => r.at(0) == head)
    for (j, (col, name)) in ((3, "PITCH"), (4, "ROLL"), (5, "ELBOW")).enumerate() {
      let y0 = by(truth.at(j))
      line((ox, y0), (ox + W - 1.6, y0), stroke: (paint: c-text.transparentize(40%), thickness: 0.4pt, dash: "dashed"))
      let pts = hr.map(r => (bx(float(r.at(1))), by(float(r.at(col)) * 180 / calc.pi)))
      line(..pts, stroke: 0.9pt + c-sel)
      lbl((ox + W - 1.0, y0), name, anchor: "west", fill: c-text)
    }
  })
}
