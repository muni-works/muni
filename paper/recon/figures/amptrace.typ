#import "style.typ": *
// Amplitude trajectories from the recon_amp runs: every accepted Levenberg–Marquardt step of
// experiments (a), (b) and (c), amplitude against step, with the anneal's stages shaded.
// Every point is data from data/amp-*.json; nothing is drawn by hand.
#let fig-amptrace(runs) = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let (W, H) = (10.5, 3.2)
  let nmax = calc.max(..runs.map(r => r.data.trace.len()), 2)
  let X(i) = i / (nmax - 1) * W
  let Y(a) = a * H
  // axes
  line((0, 0), (W, 0), stroke: 0.5pt + c-line-hi)
  line((0, 0), (0, H), stroke: 0.5pt + c-line-hi)
  for a in (0.0, 0.5, 1.0) {
    line((0, Y(a)), (W, Y(a)), stroke: 0.3pt + c-line)
    lbl((-0.15, Y(a)), [#a], anchor: "east")
  }
  lbl((-0.6, H / 2), [$a$])
  lbl((W / 2, -0.45), [ACCEPTED STEP])
  for r in runs {
    let tr = r.data.trace
    for (k, col) in r.series {
      let pts = tr.enumerate().map(((i, s)) => (X(i), Y(s.a.at(k))))
      if pts.len() > 1 { line(..pts, stroke: 0.8pt + col) }
      for p in pts { circle(p, radius: 0.04, fill: col, stroke: none) }
    }
  }
  // legend
  let y = H + 0.45
  let x = 0.0
  for r in runs {
    for (k, col) in r.series {
      line((x, y), (x + 0.4, y), stroke: 0.9pt + col)
      lbl((x + 0.5, y), r.names.at(k), anchor: "west", fill: col)
      x += 2.6
    }
  }
})
