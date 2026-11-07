// Research post: exact parameter gradients through vcad's BRep kernel (the "differentiable seam").
// Written as the arXiv preprint that accompanies the vcad 2 launch.
// Same treatment as paper/ribt (muon "Pilot Light", dark); the style block below is copied from ribt.typ.
// One source, two outputs: `--features html --format html --input target=html` builds the web
// post; without the input it builds the PDF. See web/scripts/build-posts.mjs.
// Every measured number below is read from data/measured.tsv, which repro/repro.sh regenerates
// from a fresh vcad clone at the pinned commit (data/raw/env.tsv). Nothing is typed in by hand
// except closed forms and the design-note citations marked "vcad docs".

#let web = sys.inputs.at("target", default: "pdf") == "html"
// inside a drawn figure the equation is already part of an SVG (figures set alt "in-frame"), so leave it alone there
#show math.equation: it => if web and it.alt != "in-frame" { html.elem("span", attrs: (class: "math"), html.frame(it)) } else { it }
#show math.equation: set text(font: "New Computer Modern Math", fallback: true)
#show math.equation: it => { show regex("[A-Za-z0-9]"): set text(font: "IBM Plex Sans"); it }

// ---- color roles (as vision.typ, ribt.typ) ---
#let c-bg      = rgb("#0b0907")
#let c-surface = rgb("#15110d")
#let c-line    = rgb("#2a2119")
#let c-line-hi = rgb("#4a3a2a")
#let c-text    = rgb("#e8e1d2")
#let c-label   = rgb("#a08d70")
#let c-sel     = rgb("#ff5f00")
#let c-ok      = rgb("#39ff14")
#let c-warn    = rgb("#ffd400")
#let c-fault   = rgb("#ff2052")
#let c-info    = rgb("#00f0ff")

// product names in their landing-page color
#let brand-names = (("vcad", "vcad"), ("tang", "tang"), ("loon", "loon"), ("phyz", "phyz"))
// each product in its landing-page color (web/src/app/page.tsx), not its family
#let fam-color = (vcad: rgb("#ff2052"), tang: rgb("#ffd400"), loon: c-label, phyz: rgb("#00f0ff"))
#let brand-re = regex("(?i)\\b(vcad|tang|loon|phyz)\\b")
#metadata(brand-names) <brand-names>
#let brand-family(name) = brand-names.find(n => n.at(0) == lower(name)).at(1)
#show brand-re: it => if web { it } else { text(fill: fam-color.at(brand-family(it.text)), it) }

// ---- type -------------------------------------------------------------------
#let sans    = ("IBM Plex Sans",)
#let sans-m  = ("IBM Plex Sans Medm", "IBM Plex Sans")
#let sans-sb = ("IBM Plex Sans SmBld", "IBM Plex Sans")
#let mono    = ("IBM Plex Mono", "IBM Plex Sans")
#let mono-m  = ("IBM Plex Mono Medm", "IBM Plex Sans Medm")
#let mono-sb = ("IBM Plex Mono SmBld", "IBM Plex Sans SmBld")
#let track = 0.12em
#let s-xs = 6.5pt
#let s-sm = 7.5pt
#let body-size = 9pt
#let s-md = 10.5pt
#let s-lg = 13pt
#let s-display = 40pt
#let nb = sym.space.nobreak.narrow

#let caps(body, size: s-xs, fill: c-label, font: mono-m) = text(font: font, size: size, tracking: track, fill: fill, upper(body))
#let lead(body) = text(font: sans-m, fill: c-text, body)
#let aside(title, body) = if web { html.elem("aside", attrs: (class: "aside"), { html.elem("div", attrs: (class: "aside-title"), title); body }) } else {
  pad(left: 0.35in, right: 0.35in, block(width: 100%, inset: (left: 12pt, y: 2pt), stroke: (left: 0.6pt + c-line-hi), above: 2.2em, below: 2.2em, breakable: false, {
    set text(size: s-sm, fill: c-label)
    set par(spacing: 1.1em, leading: 0.68em)
    show strong: set text(fill: c-text)
    block(below: 0.9em, text(font: mono-m, size: s-xs, fill: c-sel, tracking: track, upper([Aside · ] + title)))
    body
  }))
}

#set document(title: "Exact Gradients Through a BRep Kernel", author: "Cam Pedersen (Municipal Robotics)")

#let hf-out() = { let m = page.margin; let l = if type(m) == dictionary { m.at("left", default: m.at("x", default: 0.75in)) } else { 0.75in }; calc.max(0in, l - 0.7in) }

#set page(
  paper: "us-letter",
  fill: c-bg,
  margin: (x: 1.85in, top: 1.1in, bottom: 1.05in),
  header-ascent: 0.45in,
  footer-descent: 0.45in,
  numbering: "1",
  header: context {
    if counter(page).get().first() > 1 {
      pad(x: -hf-out(), grid(columns: (1fr, auto), caps[Exact Gradients Through a BRep Kernel], caps[Municipal Robotics]))
    }
  },
  footer: context {
    if counter(page).get().first() > 1 {
      pad(x: -hf-out(), grid(columns: (1fr, auto, 1fr),
        caps[November 2026],
        text(font: mono-m, size: s-xs, fill: c-label, number-width: "tabular")[#{ let n = counter(page).get().first(); if n < 10 { "0" + str(n) } else { str(n) } } / #counter(page).final().first()],
        align(right, caps[Research])))
    }
  },
)

#set text(font: sans, weight: 400, size: body-size, fill: c-text, fallback: false, lang: "en", region: "us", hyphenate: false, costs: (runt: 1000%, widow: 200%, orphan: 200%))
#set par(justify: false, leading: 0.84em, spacing: 1.4em, linebreaks: "optimized")
#let web-num(pattern) = if web { (..n) => html.elem("span", attrs: (class: "sec-num"), numbering(pattern, ..n)) } else { pattern }
#set heading(numbering: web-num("1.1"))
#show strong: set text(font: sans-sb)
#show link: set text(fill: c-text)
// URL links get a quiet underline in the PDF; on the web the stylesheet styles them
#show link: it => if web or type(it.dest) != str { it } else { underline(stroke: 0.5pt + c-label, offset: 2pt, it) }
#show heading: set text(font: sans, weight: 400, fill: c-text, hyphenate: false)
#let numlabel(it) = text(font: mono-m, size: s-xs, fill: c-label, tracking: track, counter(heading).display(it.numbering))
#show heading.where(level: 1): it => if web { it } else { block(above: 2.2em, below: 1.1em, sticky: true, width: 100%, {
  if it.numbering != none { place(left, dx: -1.15in, dy: 0.32em, box(width: 1.0in, align(right, numlabel(it)))) }
  text(font: sans-sb, size: s-lg, tracking: -0.01em, it.body)
}) }
#show heading.where(level: 2): it => if web { it } else { block(above: 1.65em, below: 0.55em, sticky: true, {
  if it.numbering == none { return text(font: sans-m, size: s-md, it.body) }
  place(left, dx: -1.15in, dy: 0.22em, box(width: 1.0in, align(right, numlabel(it))))
  text(font: sans-m, size: s-md, it.body)
}) }
#show raw: set text(font: mono, size: 1em)
#set list(marker: box(baseline: -0.07em, rect(width: 0.36em, height: 0.36em, fill: c-label, stroke: none)), indent: 0em, body-indent: 0.85em, spacing: 1.15em)

#set table(stroke: (x, y) => (
    top: if y == 0 { 0.6pt + c-line-hi } else if y == 1 { 0.6pt + c-line-hi } else { 0.35pt + c-line },
    bottom: 0.6pt + c-line-hi,
  ), inset: (x: 6pt, y: 4.6pt))
#show table: set text(font: sans, size: s-sm, number-width: "tabular", hyphenate: false)
#show table: set par(leading: 0.62em, justify: false)
#show table.cell.where(x: 0): it => if it.y == 0 { it } else { set text(font: sans-m, fill: c-text); it }
#show table.cell.where(y: 0): it => {
  set text(font: mono-m, size: s-xs, fill: c-label, tracking: track)
  show strong: s => upper(s.body)
  it
}
#set figure(placement: none, gap: 1.1em)
#show figure: set block(above: 1.9em, below: 1.9em)
#show figure.where(kind: table): set figure.caption(position: top)
#show figure.caption: it => {
  set par(leading: 0.64em, justify: false)
  set align(left)
  block(width: 100%, text(font: sans, size: s-sm, fill: c-label, hyphenate: false)[
    #caps(if it.kind == table [Table] else [Fig] + nb + it.counter.display(), font: mono-sb, fill: c-text)#if web [ ] else [#h(0.7em)]#it.body
  ])
}
#show cite: set text(fill: c-label)

// ---- figures ----------------------------------------------------------------
#import "@preview/cetz:0.4.2"
// Web figures: drawn bodies become inline SVG via html.frame (as vision.typ); tables stay <table>s.
#show figure: it => if web and it.kind != table {
  let lab = if it.has("label") { str(it.label) } else { "" }
  let body = html.frame(block(width: 4.8in, fill: c-bg, inset: 6pt, { set math.equation(alt: "in-frame"); it.body }))
  let cap = if it.caption != none { html.elem("figcaption", [#html.elem("span", attrs: (class: "fig-label"))[Fig #context it.counter.display(it.numbering)] #it.caption.body]) }
  html.elem("figure", attrs: if lab == "" { (class: "narrow") } else { (id: lab, class: "narrow") }, { body; cap })
} else { it }
#let lbl(pos, body, anchor: "center", fill: c-label, size: s-xs, font: mono-m) = cetz.draw.content(pos, anchor: anchor, text(font: font, size: size, fill: fill, tracking: 0.04em, body))

// ---- measured values ----------------------------------------------------------
#let measured = {
  let d = (:)
  // rows have a variable number of fields, so split by hand
  for line in read("data/measured.tsv").split("\n").filter(l => l != "") {
    let r = line.split("\t")
    d.insert(r.at(0), r.slice(1))
  }
  d
}
#let env = {
  let d = (:)
  for r in csv("data/raw/env.tsv", delimiter: "\t") { d.insert(r.at(0), r.at(1)) }
  d
}
// a measured value by key; a missing key is a build error, never a silent blank
#let V(key, i: 0) = {
  assert(key in measured, message: "measured.tsv has no key " + key)
  float(measured.at(key).at(i).replace("+", ""))
}
// relative error in scientific notation, 2 significant digits; exact zero prints as 0
#let sci(x, digits: 1) = {
  if x == 0 { return [0] }
  let e = calc.floor(calc.log(calc.abs(x), base: 10))
  let m = calc.round(x / calc.pow(10.0, e), digits: digits)
  if m == 10 or m == -10 { m = m / 10; e += 1 }
  [$#str(m) times 10^(#str(e))$]
}
#let fx(x, d) = str(calc.round(x, digits: d))
#let E(key, i: 0) = sci(V(key, i: i))
#let F(key, d, i: 0) = fx(V(key, i: i), d)

// key prefixes
#let K-m0 = "m0_extrude_volume::m0_extrude_volume_derivative_matches_analytic_and_fd"
#let K-m2 = "m2_boolean_hole::m2_through_hole_dv_dr_matches_closed_form_and_fd"
#let K-m3b = "m3_boundary_trim::boundary_nodes_track_a_moving_plane_trim"
#let K-m3m = "m3_mass_properties::cylinder_radius_inertia_derivatives_match_fd"
#let K-m4 = "m4_fillet_radius::m4_fillet_radius_derivative_matches_fd_and_continuum"
#let K-m5 = "m5_reverse_mode::m5_one_pullback_prices_every_fillet_cube_parameter"
#let K-m6 = "m6_synthesized_seeding::rounded_cube_both_parameters_synthesized"
#let K-m7a = "m7_cone_torus::cone_half_angle_derivative"
#let K-m7h = "m7_cone_torus::cone_height_derivative"
#let K-m10 = "m10_second_order::"
#let K-doc = "document_gradient::"

// ---- figures ------------------------------------------------------------------
#let mono-sm(body, fill: c-label) = text(font: mono-m, size: s-xs, fill: fill, tracking: 0.04em, body)

// the seam: where the chain is cut
#let fig-seam() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let boxes = (
    ([θ], [parameters], false),
    ([BRep], [build(θ)], false),
    ([frozen mesh], [plan at θ₀], true),
    ([QoI], [mass props, J], false),
  )
  let w = 2.35
  let gap = 0.55
  let h = 1.15
  let X(i) = i * (w + gap)
  for (i, (name, sub, hot)) in boxes.enumerate() {
    let x = X(i)
    rect((x, 0), (x + w, h), fill: if hot { c-sel.transparentize(82%) } else { c-surface }, stroke: 0.6pt + if hot { c-sel } else { c-line-hi })
    lbl((x + w / 2, h - 0.35), name, fill: if hot { c-sel } else { c-text }, size: s-sm, font: mono-sb)
    lbl((x + w / 2, h - 0.8), sub)
    if i < 3 {
      line((x + w + 0.05, h / 2), (x + w + gap - 0.05, h / 2), mark: (end: "stealth", fill: c-label), stroke: 0.6pt + c-label)
    }
  }
  // what is differentiated and how
  let y = -0.45
  lbl(((X(1) + X(2) + w) / 2, y), [lift-bridge duals · implicit vertex rows], fill: c-text)
  lbl(((X(1) + X(2) + w) / 2, y - 0.35), [dx/dθ, exact; combinatorics never differentiated])
  lbl((X(3) + w / 2, y), [∂J/∂x], fill: c-text)
  lbl((X(3) + w / 2, y - 0.35), [divergence theorem])
  // the adjoint, backwards
  let yb = -1.55
  line((X(3) + w / 2, yb), (X(0) + w / 2, yb), mark: (end: "stealth", fill: c-info), stroke: (paint: c-info, thickness: 0.6pt, dash: "dashed"))
  lbl(((X(0) + X(3) + w) / 2, yb - 0.3), [reverse mode: one pullback of ∂J/∂x prices every θ], fill: c-info)
  // topology wall
  lbl((X(1) + w / 2, h + 0.35), [topology change ⇒ error, not a gradient], fill: c-fault)
})

// L-BFGS vs projected GD on the five-parameter rounded, drilled box (log J per iterate)
#let fig-lbfgs(width: 11.0, height: 5.0, legend: true) = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let series(prefix) = {
    let out = ()
    let n = 0
    while prefix + str(n) in measured { out.push(V(prefix + str(n))); n += 1 }
    out
  }
  let lb = series("m9::lbfgs::J::")
  let gd = series("m9::gd::J::")
  let lo = -17.0
  let hi = 1.0
  let nmax = gd.len() - 1
  let X(i) = width * i / nmax
  let Y(j) = height * (calc.max(lo, calc.log(calc.max(j, 1e-300), base: 10)) - lo) / (hi - lo)
  for e in range(int(lo), int(hi) + 1, step: 4) {
    line((0, Y(calc.pow(10.0, e))), (width, Y(calc.pow(10.0, e))), stroke: 0.3pt + c-line)
    lbl((-0.15, Y(calc.pow(10.0, e))), [$10^(#str(e))$], anchor: "east")
  }
  for i in (0, 50, 100, 150, 200) {
    lbl((X(i), -0.3), [#i])
  }
  line((0, 0), (width, 0), stroke: 0.6pt + c-line-hi)
  lbl((width / 2, -0.75), [accepted iterate])
  line(..gd.enumerate().map(((i, j)) => (X(i), Y(j))), stroke: 0.7pt + c-label)
  line(..lb.enumerate().map(((i, j)) => (X(i), Y(j))), stroke: 1.1pt + c-sel)
  if legend {
    lbl((X(lb.len() - 1) + 0.15, Y(lb.last())), [L-BFGS · #(lb.len() - 1) iterates], anchor: "west", fill: c-sel)
    lbl((width, Y(gd.last()) + 0.3), [projected GD · not converged at #nmax], anchor: "east", fill: c-text)
  }
})

// the flywheel's descent path in (bore, hole) radius
#let fig-flywheel() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let pts = ()
  let n = 0
  while ("m3_flywheel::iter::" + str(n)) in measured {
    let k = "m3_flywheel::iter::" + str(n)
    pts.push((V(k, i: 0), V(k, i: 1), V(k, i: 2)))
    n += 1
  }
  let (x0, x1, y0, y1) = (2.0, 12.0, 2.0, 8.0)
  let w = 8.0
  let h = w * (y1 - y0) / (x1 - x0)
  let X(x) = w * (x - x0) / (x1 - x0)
  let Y(y) = h * (y - y0) / (y1 - y0)
  rect((0, 0), (w, h), stroke: 0.6pt + c-line-hi)
  for x in (2, 4, 6, 8, 10, 12) { lbl((X(x), -0.3), [#x]) }
  for y in (2, 4, 6, 8) { lbl((-0.25, Y(y)), [#y], anchor: "east") }
  lbl((w / 2, -0.75), [bore radius (mm)])
  lbl((-0.7, h / 2), [hole radius (mm)], anchor: "east")
  circle((X(8), Y(5)), radius: 0.12, stroke: 0.7pt + c-ok, fill: none)
  lbl((X(8) + 0.2, Y(5) - 0.3), [θ\* that set the target], anchor: "west", fill: c-ok)
  if pts.len() > 1 {
    line(..pts.map(p => (X(p.at(0)), Y(p.at(1)))), stroke: 0.8pt + c-sel)
    circle((X(pts.first().at(0)), Y(pts.first().at(1))), radius: 0.08, fill: c-label, stroke: none)
    circle((X(pts.last().at(0)), Y(pts.last().at(1))), radius: 0.09, fill: c-sel, stroke: none)
    lbl((X(pts.first().at(0)) + 0.15, Y(pts.first().at(1)) - 0.25), [θ₀], anchor: "west")
  }
})

// the planned graph: geometry → dynamics → objective, with a thermal branch
#let fig-showpiece() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let node(pos, name, sub, col, dashed: false) = {
    let (x, y) = pos
    rect((x - 1.1, y - 0.42), (x + 1.1, y + 0.42), fill: c-surface, stroke: (paint: col, thickness: 0.6pt, dash: if dashed { "dashed" } else { none }))
    lbl((x, y + 0.12), name, fill: col, size: s-sm, font: mono-sb)
    lbl((x, y - 0.2), sub)
  }
  let arr(a, b, col, dashed: false) = line(a, b, mark: (end: "stealth", fill: col), stroke: (paint: col, thickness: 0.6pt, dash: if dashed { "dashed" } else { none }))
  let y1 = 2.0
  let y2 = 0.0
  node((0, 1.0), [θ], [.vcad params], c-text)
  node((2.7, y1), [SeamEval], [frozen plan], c-sel)
  node((5.4, y1), [MassProps], [10 per body], c-sel)
  node((8.1, y1), [Rollout], [phyz, contact], c-sel)
  node((10.8, y1), [jump height], [J], c-sel)
  node((2.7, y2), [Assemble], [thermal], c-label, dashed: true)
  node((5.4, y2), [LinearSolve], [adjoint: $A^top$], c-label, dashed: true)
  node((8.1, y2), [peak temp], [≤ limit], c-label, dashed: true)
  arr((1.1, 1.2), (1.6, y1 - 0.1), c-sel)
  arr((3.8, y1), (4.3, y1), c-sel)
  arr((6.5, y1), (7.0, y1), c-sel)
  arr((9.2, y1), (9.7, y1), c-sel)
  bezier((2.7, y1 + 0.42), (8.1, y1 + 0.42), (4.5, y1 + 1.3), (6.3, y1 + 1.3), stroke: 0.6pt + c-sel, mark: (end: "stealth", fill: c-sel))
  lbl((5.4, y1 + 1.25), [contact skin: penalty forces on the seam mesh], fill: c-sel)
  arr((1.1, 0.8), (1.6, y2 + 0.1), c-label, dashed: true)
  arr((3.8, y2), (4.3, y2), c-label, dashed: true)
  arr((6.5, y2), (7.0, y2), c-label, dashed: true)
  line((10.8, -0.9), (0, -0.9), mark: (end: "stealth", fill: c-info), stroke: (paint: c-info, thickness: 0.6pt, dash: "dashed"))
  lbl((5.4, -1.2), [one reverse pass: ∂J/∂θ → L-BFGS], fill: c-info)
  lbl((9.5, y2 + 0.15), [orange: exists, hand-composed], anchor: "west", fill: c-sel)
  lbl((9.5, y2 - 0.2), [dashed: planned], anchor: "west")
})

// ---- illustrations ----------------------------------------------------------------
#let c-vcad = rgb("#ff2052")
#let c-ice = rgb("#ffd9c7")
#let arrow(a, b, col: c-vcad, w: 0.7pt, dash: none) = cetz.draw.line(a, b, stroke: (paint: col, thickness: w, dash: dash), mark: (end: "stealth", fill: col, scale: 0.6))
#let pdot(p, col: c-label, r: 0.05) = cetz.draw.circle(p, radius: r, fill: col, stroke: none)

// 1. the three node recipes on a plate with a hole, and the implicit rows at one rim vertex
#let fig-recipes() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  // left: top view of the plate
  let s = 2.3
  let hr = 1.05
  let n = 24
  rect((-s, -s), (s, s), stroke: 0.6pt + c-line-hi, fill: c-surface)
  // a fan of triangles from the plate corners to the rim, the stock planar triangulation in miniature
  for i in range(n) {
    let a = 2 * calc.pi * i / n
    let p = (hr * calc.cos(a), hr * calc.sin(a))
    let corner = (if calc.cos(a) > 0 { s } else { -s }, if calc.sin(a) > 0 { s } else { -s })
    line(p, corner, stroke: 0.3pt + c-line)
  }
  let rim = range(n + 1).map(i => { let a = 2 * calc.pi * i / n; (hr * calc.cos(a), hr * calc.sin(a)) })
  line(..rim, stroke: 0.8pt + c-label, fill: c-bg)
  // plane-interior samples: SurfaceUv on a plane that does not move: zero velocity
  for (x, y) in ((-1.7, 1.7), (1.7, -1.7), (1.7, 1.7), (-1.7, -1.7), (0, 1.8), (1.8, 0), (0, -1.8), (-1.8, 0)) { pdot((x, y), col: c-label, r: 0.045) }
  // rim vertices: TopoVertex, velocity radial (dx/dr)
  for i in range(n) {
    let a = 2 * calc.pi * i / n
    let p = (hr * calc.cos(a), hr * calc.sin(a))
    arrow(p, ((hr + 0.42) * calc.cos(a), (hr + 0.42) * calc.sin(a)), w: 0.6pt)
    pdot(p, col: c-vcad, r: 0.055)
  }
  lbl((0, -s - 0.35), [plate − cylinder(r), top cap], fill: c-text)
  lbl((0, -s - 0.68), [θ = r · needles are dx/dr])
  // legend
  let lx = -s
  let ly = s + 0.9
  pdot((lx, ly), col: c-vcad, r: 0.06)
  lbl((lx + 0.15, ly), [TopoVertex: implicit rows], anchor: "west", fill: c-text)
  pdot((lx, ly - 0.35), col: c-label, r: 0.05)
  lbl((lx + 0.15, ly - 0.35), [SurfaceUv: S(u, v; φ(θ)) on duals], anchor: "west")
  // right: the rows at one rim vertex, in the plane through the axis (the hole's axis is off to the left)
  let ox = 6.3
  let oy = 0.2
  let v = (ox, oy)
  line((ox - 2.3, oy), (ox, oy), stroke: 0.8pt + c-label)
  line((ox, oy), (ox, oy - 2.3), stroke: 0.8pt + c-label)
  lbl((ox - 2.25, oy + 0.2), [cap plane], anchor: "west")
  lbl((ox - 0.12, oy - 2.1), [hole wall], anchor: "east")
  line((ox + 0.6, oy), (ox + 0.6, oy - 2.3), stroke: (paint: c-vcad, thickness: 0.6pt, dash: "dashed"))
  lbl((ox + 0.72, oy - 2.1), [wall at r + δ], anchor: "west", fill: c-vcad)
  // row gradients
  arrow(v, (ox, oy + 1.25), col: c-text, w: 0.6pt)
  lbl((ox + 0.14, oy + 1.15), [$nabla g_"plane" dot dot(x) = 0$], anchor: "west", fill: c-text)
  arrow(v, (ox + 1.45, oy), col: c-text, w: 0.6pt)
  lbl((ox + 1.5, oy - 0.3), [$nabla g_"cyl" dot dot(x) = 2r$], anchor: "west", fill: c-text)
  circle(v, radius: 0.16, stroke: 0.5pt + c-label)
  pdot(v, col: c-label, r: 0.03)
  lbl((ox - 0.3, oy + 0.75), [t (into page): frozen], anchor: "east")
  // solution
  arrow(v, (ox + 0.6, oy), w: 1.3pt)
  pdot(v, col: c-vcad, r: 0.07)
  lbl((ox + 0.6, oy + 0.32), [$dot(x) = hat(r)$], fill: c-vcad, size: s-sm)
  lbl((ox + 0.3, oy - 2.75), [two rows + a frozen tangent: exactly radial], fill: c-text)
})

// 2. a fillet radius moves its blend two ways at once, and the tangent line slides along the face
#let fig-fillet() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let L = 3.2
  let r = 1.3
  let d = 0.45
  let quarter(rr, col, w, dash: none) = {
    let c = (L - rr, L - rr)
    let pts = range(17).map(k => { let a = calc.pi / 2 * k / 16; (c.at(0) + rr * calc.cos(a), c.at(1) + rr * calc.sin(a)) })
    line(..pts, stroke: (paint: col, thickness: w, dash: dash))
    line((0, L), (L - rr, L), stroke: (paint: col, thickness: w, dash: dash))
    line((L, 0), (L, L - rr), stroke: (paint: col, thickness: w, dash: dash))
  }
  // the material, and the edge before filleting
  line((0, 0), (0, L), (L - r, L), ..range(17).map(k => { let a = calc.pi / 2 * (16 - k) / 16; (L - r + r * calc.cos(a), L - r + r * calc.sin(a)) }), (L, 0), close: true, fill: c-surface, stroke: none)
  line((L - 0.6, L), (L, L), (L, L - 0.6), stroke: (paint: c-line-hi, thickness: 0.5pt, dash: "dotted"))
  lbl((L + 0.1, L - 0.25), [sharp edge], anchor: "west")
  quarter(r, c-label, 0.9pt)
  quarter(r + d, c-vcad, 0.7pt, dash: "dashed")
  // blend axis (center) and its retreat
  let c0 = (L - r, L - r)
  let c1 = (L - r - d, L - r - d)
  pdot(c0, col: c-text, r: 0.05)
  arrow(c0, c1, w: 0.9pt)
  lbl((c1.at(0) - 0.1, c1.at(1) - 0.05), [axis retreats (−1, −1)], anchor: "north-east", fill: c-vcad)
  // radius growth along the bisector
  let m0 = (c0.at(0) + r * 0.7071, c0.at(1) + r * 0.7071)
  line(c0, m0, stroke: (paint: c-text, thickness: 0.5pt, dash: "dotted"))
  lbl(((c0.at(0) + m0.at(0)) / 2 + 0.12, (c0.at(1) + m0.at(1)) / 2 - 0.12), [r, rate +1], anchor: "north-west", fill: c-text)
  // the tangent point on the top face slides by exactly (−1, 0)
  let t0 = (L - r, L)
  let t1 = (L - r - d, L)
  arrow(t0, t1, w: 1.1pt)
  pdot(t0, col: c-vcad, r: 0.06)
  lbl(((t0.at(0) + t1.at(0)) / 2, L + 0.32), [tangent line slides (−1, 0)], fill: c-vcad)
  let s0 = (L, L - r)
  let s1 = (L, L - r - d)
  arrow(s0, s1, w: 1.1pt)
  pdot(s0, col: c-vcad, r: 0.06)
  lbl((L + 0.15, (s0.at(1) + s1.at(1)) / 2), [(0, −1)], anchor: "west", fill: c-vcad)
  lbl((L / 2, -0.4), [section through one blend · solid: r · dashed: r + δ], fill: c-text)
  // right: the census of one parameter on the cube
  let ox = 5.6
  let rows = (([6], [planes], [inset, translate]), ([12], [blend cylinders], [radius + axis retreat]), ([8], [corner spheres], [radius + center retreat]))
  lbl((ox, L + 0.1), [one θ = fillet r moves], anchor: "west", fill: c-text, font: mono-sb, size: s-sm)
  for (k, (nn, what, how)) in rows.enumerate() {
    let y = L - 0.55 - k * 0.72
    lbl((ox, y), nn, anchor: "west", fill: c-vcad, font: mono-sb, size: s-md)
    lbl((ox + 0.8, y + 0.1), what, anchor: "west", fill: c-text)
    lbl((ox + 0.8, y - 0.2), how, anchor: "west")
  }
  lbl((ox, L - 2.85), [20 moving surfaces · 836 nodes], anchor: "west", fill: c-text)
  lbl((ox, L - 3.15), [dV/dr vs FD: #E(K-m4 + "@L132::rel_fd")], anchor: "west", fill: c-vcad)
})

// 3. the torus's two design velocities, on its own mesh
#let torus-panel(ox, which, title, sub) = {
  import cetz.draw: *
  let R0 = 1.75
  let r0 = 0.62
  let pitch = 0.95
  let cp = calc.cos(pitch)
  let sp = calc.sin(pitch)
  let P(x, y, z) = (ox + x, -y * sp * 0.0 + y * cp * 0.0 + (y * sp + z * cp) * 1.0)
  // simple oblique: screen x = x, screen y = y·sin(p)·0.45 + z
  let S(x, y, z) = (ox + x, y * 0.42 + z)
  let front(u, v) = calc.sin(u) * calc.cos(v) * 0.42 - calc.sin(v) * 0 < 0.4
  let nu = 36
  let nv = 16
  for i in range(nu) {
    let u = 2 * calc.pi * i / nu
    let pts = range(nv + 1).map(j => { let v = 2 * calc.pi * j / nv; let c = R0 + r0 * calc.cos(v); S(c * calc.cos(u), c * calc.sin(u), r0 * calc.sin(v)) })
    line(..pts, stroke: 0.3pt + (if calc.sin(u) < 0 { c-label } else { c-line-hi }))
  }
  for j in range(nv) {
    let v = 2 * calc.pi * j / nv
    let pts = range(nu + 1).map(i => { let u = 2 * calc.pi * i / nu; let c = R0 + r0 * calc.cos(v); S(c * calc.cos(u), c * calc.sin(u), r0 * calc.sin(v)) })
    line(..pts, stroke: 0.3pt + c-line-hi)
  }
  // needles on the near half (sin u < 0 faces the viewer in this oblique)
  for i in range(0, nu, step: 2) {
    let u = 2 * calc.pi * i / nu
    if calc.sin(u) > 0.15 { continue }
    for j in range(0, nv, step: 2) {
      let v = 2 * calc.pi * j / nv
      let n = (calc.cos(v) * calc.cos(u), calc.cos(v) * calc.sin(u), calc.sin(v))
      let d = if which == "r" { n } else { (calc.cos(u), calc.sin(u), 0) }
      let outward = d.at(0) * n.at(0) + d.at(1) * n.at(1) + d.at(2) * n.at(2)
      let c = R0 + r0 * calc.cos(v)
      let p = (c * calc.cos(u), c * calc.sin(u), r0 * calc.sin(v))
      let k = 0.38
      line(S(..p), S(p.at(0) + k * d.at(0), p.at(1) + k * d.at(1), p.at(2) + k * d.at(2)), stroke: 0.7pt + (if outward > 0.05 { c-vcad } else if outward < -0.05 { c-ice } else { c-label }))
    }
  }
  lbl((ox, -1.75), title, fill: c-text, font: mono-sb, size: s-sm)
  lbl((ox, -2.05), sub)
}
#let fig-torus() = cetz.canvas(length: 1cm, {
  torus-panel(0, "r", [dx/dr: the tube normal], [dV/dr #F("m7_cone_torus::torus_gate@L269::torus minor r::dv", 3) · vs FD #E("m7_cone_torus::torus_gate@L269::torus minor r::rel_fd")])
  torus-panel(5.4, "R", [dx/dR: away from the axis], [dV/dR #F("m7_cone_torus::torus_gate@L269::torus major R::dv", 3) · vs FD #E("m7_cone_torus::torus_gate@L269::torus major R::rel_fd")])
  import cetz.draw: *
  pdot((-1.7, 1.55), col: c-vcad, r: 0.06)
  lbl((-1.55, 1.55), [wall moves outward], anchor: "west")
  pdot((1.6, 1.55), col: c-ice, r: 0.06)
  lbl((1.75, 1.55), [inward: the inner equator gives up volume as R grows], anchor: "west")
})

// 4. where the frozen plan's derivative exists, and where the seam refuses
#let fig-wall() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let W = 6.4
  let H = 3.0
  let t = 4.2 // plate thickness, in plot x units
  let X(d) = d / 5.6 * W
  // V(d): falls linearly while the hole is blind, flat once it breaks through
  let Y(d) = if d < t { H - 0.42 * d } else { H - 0.42 * t }
  line((0, 0), (W, 0), stroke: 0.6pt + c-line-hi)
  line((0, 0), (0, H + 0.4), stroke: 0.6pt + c-line-hi)
  lbl((W, -0.3), [hole depth d], anchor: "east")
  lbl((-0.15, H + 0.4), [V], anchor: "east")
  // the valid neighbourhood of a plan captured at d0
  let d0 = 2.0
  rect((X(d0 - 0.9), 0.02), (X(d0 + 0.9), H + 0.3), fill: c-ok.transparentize(93%), stroke: none)
  lbl((X(d0), H + 0.48), [one topology class: exact dV/dd], fill: c-ok)
  line(..range(0, 57).map(k => { let d = k / 10; (X(d), Y(d)) }), stroke: 1pt + c-label)
  // the tangent the seam returns
  let sl = -0.42 * W / 5.6
  line((X(d0 - 1.2), Y(d0) - sl * X(1.2) / X(1) * 0 + 0.42 * 1.2), (X(d0 + 1.2), Y(d0) - 0.42 * 1.2), stroke: 0.9pt + c-vcad)
  pdot((X(d0), Y(d0)), col: c-vcad, r: 0.07)
  lbl((X(d0) + 0.15, Y(d0) + 0.25), [θ₀], anchor: "west", fill: c-vcad)
  // the wall
  line((X(t), 0), (X(t), H + 0.3), stroke: (paint: c-fault, thickness: 0.7pt, dash: "dashed"))
  lbl((X(t) + 0.1, H - 0.2), [breaks through], anchor: "west", fill: c-fault)
  lbl((X(t) + 0.1, H - 0.5), [TopologyChanged], anchor: "west", fill: c-fault, font: mono-sb)
  lbl((X(t) + 0.1, H - 0.8), [an error, not a gradient], anchor: "west")
  // section sketches: blind and through
  let sk(ox, through) = {
    rect((ox, -1.55), (ox + 1.3, -0.95), fill: c-surface, stroke: 0.5pt + c-line-hi)
    rect((ox + 0.5, if through { -1.55 } else { -1.3 }), (ox + 0.8, -0.95), fill: c-bg, stroke: 0.5pt + c-label)
  }
  sk(X(d0) - 0.65, false)
  lbl((X(d0), -1.8), [blind])
  sk(X(5.0) - 0.65, true)
  lbl((X(5.0), -1.8), [through])
})

// 5. every finite-difference gate on one log axis
#let fig-ladder() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let rows = (
    ([extrusion · depth], V(K-m0 + "@L80::rel_fd"), V(K-m0 + "::cmp.max_rel_err")),
    ([box − cylinder · r], V(K-m2 + "@L119::rel_fd"), V("m2_boolean_hole::m2_rim_nodes_implicit_diff_matches_fd::cmp.max_rel_err")),
    ([cylinder · height], V(K-m3b + "@L118::rel_fd"), V(K-m3b + "::cmp.max_rel_err")),
    ([filleted cube · r], V(K-m4 + "@L132::rel_fd"), V(K-m4 + "::cmp.max_rel_err")),
    ([filleted cube · a], V(K-m5 + "@L311::rel_a"), none),
    ([cone · half-angle], V(K-m7a + "@L163::rel_fd"), V(K-m7a + "::cmp.max_rel_err")),
    ([cone · height], V(K-m7h + "@L208::rel_fd"), V(K-m7h + "::cmp.max_rel_err")),
    ([torus · r], V("m7_cone_torus::torus_gate@L269::torus minor r::rel_fd"), V("m7_cone_torus::torus_gate::torus minor r::cmp.max_rel_err")),
    ([torus · R], V("m7_cone_torus::torus_gate@L269::torus major R::rel_fd"), V("m7_cone_torus::torus_gate::torus major R::cmp.max_rel_err")),
    ([contact rollout · r], V("m11_contact_gradient::contact_chain_matches_end_to_end_fd@L166::rel"), none),
  )
  let x0 = 3.1
  let W = 6.6
  let lo = -13.0
  let hi = -5.0
  let X(v) = x0 + W * (calc.log(calc.max(v, 1e-13), base: 10) - lo) / (hi - lo)
  let n = rows.len()
  let Y(k) = (n - 1 - k) * 0.42
  for e in range(int(lo), int(hi) + 1) {
    line((X(calc.pow(10.0, e)), -0.25), (X(calc.pow(10.0, e)), Y(0) + 0.25), stroke: 0.3pt + c-line)
    if calc.rem(calc.abs(e), 2) == 1 or e == -6 { lbl((X(calc.pow(10.0, e)), -0.5), [$10^(#str(e))$]) }
  }
  // the gate
  line((X(1e-6), -0.25), (X(1e-6), Y(0) + 0.35), stroke: (paint: c-warn, thickness: 0.7pt, dash: "dashed"))
  lbl((X(1e-6), Y(0) + 0.55), [gate $10^(-6)$], fill: c-warn)
  for (k, (name, fdv, nodev)) in rows.enumerate() {
    let y = Y(k)
    lbl((x0 - 0.15, y), name, anchor: "east", fill: c-text, size: s-xs)
    line((x0, y), (X(fdv), y), stroke: 0.3pt + c-line-hi)
    if nodev != none {
      circle((X(nodev), y), radius: 0.07, stroke: 0.7pt + c-label, fill: c-bg)
    }
    circle((X(fdv), y), radius: 0.075, fill: c-vcad, stroke: none)
  }
  circle((x0 + 0.1, -1.0), radius: 0.075, fill: c-vcad, stroke: none)
  lbl((x0 + 0.25, -1.0), [dV/dθ vs FD of a full rebuild], anchor: "west")
  circle((x0 + 0.1, -1.35), radius: 0.07, stroke: 0.7pt + c-label, fill: c-bg)
  lbl((x0 + 0.25, -1.35), [worst node, dx/dθ], anchor: "west")
})

// 6. the contact co-design case: two channels with opposite signs
#let fig-contact() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let r = 1.15
  let c = (0, r - 0.12)
  // ground and penalty springs at the bottom vertices
  for x in range(-6, 7) { line((x * 0.4, -0.02), (x * 0.4 - 0.18, -0.24), stroke: 0.4pt + c-line-hi) }
  let n = 28
  let poly = range(n + 1).map(i => { let a = 2 * calc.pi * i / n; (c.at(0) + r * calc.cos(a), c.at(1) + r * calc.sin(a)) })
  line(..poly, stroke: 0.8pt + c-label, fill: c-surface)
  for i in range(n) {
    let a = 2 * calc.pi * i / n
    let p = (c.at(0) + r * calc.cos(a), c.at(1) + r * calc.sin(a))
    if p.at(1) < 0 {
      // a vertex below the ground: a penalty force pushes it up, proportional to its depth
      arrow(p, (p.at(0), p.at(1) + 0.25 - 3 * p.at(1)), col: c-info, w: 0.7pt)
      pdot(p, col: c-info, r: 0.04)
    }
  }
  line((-2.6, 0), (2.6, 0), stroke: 0.8pt + c-label)
  // the grown section
  let poly2 = range(n + 1).map(i => { let a = 2 * calc.pi * i / n; (c.at(0) + (r + 0.28) * calc.cos(a), c.at(1) + 0.28 + (r + 0.28) * calc.sin(a)) })
  line(..poly2, stroke: (paint: c-vcad, thickness: 0.6pt, dash: "dashed"))
  pdot(c, col: c-text, r: 0.04)
  lbl((0, c.at(1) + r + 0.55), [J = settled height of the axis], fill: c-text)
  lbl((0, -0.5), [phyz penalty f = max(0, kδ − c v), per vertex], fill: c-info)
  // the two channels
  let ox = 3.3
  arrow((ox, 0.9), (ox, 2.3), w: 1.2pt)
  lbl((ox + 0.2, 2.15), [surface channel], anchor: "west", fill: c-vcad, font: mono-sb, size: s-sm)
  lbl((ox + 0.2, 1.85), [contact line drops dθ: +1e-3 m per mm], anchor: "west")
  lbl((ox + 0.2, 1.6), [adjoint ∂J/∂x → seam pullback], anchor: "west")
  arrow((ox + 0.0, 0.75), (ox, 0.45), col: c-info, w: 1.2pt)
  lbl((ox + 0.2, 0.7), [mass channel], anchor: "west", fill: c-info, font: mono-sb, size: s-sm)
  lbl((ox + 0.2, 0.42), [heavier, sinks into the spring: negative], anchor: "west")
  lbl((ox + 0.2, 0.17), [adjoint ∂J/∂p · seam dp/dθ], anchor: "west")
  lbl((ox, -0.9), [dJ/dθ = #sci(V("m11_contact_gradient::contact_chain_matches_end_to_end_fd@L166::grad"), digits: 3) m/mm · vs FD #E("m11_contact_gradient::contact_chain_matches_end_to_end_fd@L166::rel")], anchor: "west", fill: c-text)
})

// 7. capture, seam and pullback cost against node count
#let fig-cost() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let segs = ("16", "64", "128")
  let pts = segs.map(s => (V("m10::timing::" + s, i: 0), V("m10::timing::" + s, i: 1), V("m10::timing::" + s, i: 2), V("m10::timing::" + s, i: 3)))
  let W = 7.0
  let H = 3.0
  let nmax = 7000.0
  let tmax = 5.0
  let X(n) = W * n / nmax
  let Y(t) = H * t / tmax
  for t in (0, 1, 2, 3, 4, 5) {
    line((0, Y(t)), (W, Y(t)), stroke: 0.3pt + c-line)
    lbl((-0.15, Y(t)), [#t], anchor: "east")
  }
  for n in (0, 2000, 4000, 6000) { lbl((X(n), -0.3), [#n]) }
  lbl((W / 2, -0.7), [mesh nodes (filleted cube at 16, 64, 128 segments)])
  lbl((-0.6, H + 0.3), [ms, median], anchor: "west")
  let series = ((1, [capture], c-label), (3, [pullback (all parameters)], c-vcad), (2, [seam pass (one parameter)], c-text))
  for (k, name, col) in series {
    line(..pts.map(p => (X(p.at(0)), Y(p.at(k)))), stroke: 1pt + col)
    for p in pts { circle((X(p.at(0)), Y(p.at(k))), radius: 0.06, fill: col, stroke: none) }
    let last = pts.last()
    lbl((X(last.at(0)) + 0.15, Y(last.at(k))), name, anchor: "west", fill: col)
  }
})

// ---- title page -----------------------------------------------------------------
#if not web {page(margin: (x: 0.75in, top: 0.7in, bottom: 0.65in))[
  #set par(leading: 0.5em)
  #grid(columns: (auto, 1fr, auto), column-gutter: 0.8em, align: horizon,
    caps(fill: c-text)[Municipal Robotics · Research],
    line(length: 100%, stroke: 0.5pt + c-line-hi),
    caps[November 2026 · Draft])
  #v(1.6em)
  #image("images/muni-logo.svg", width: 0.95in)
  #v(0.5in)
  #align(center, fig-lbfgs(width: 16.5, height: 8.5, legend: false))
  #v(0.1in)
  #grid(columns: (1fr, auto), align: (left, right),
    caps[Five CAD parameters of a filleted, drilled box · objective per iterate],
    caps(fill: c-sel)[L-BFGS on exact BRep gradients])
  #v(1fr)
  #move(dx: -0.045 * s-display, text(font: sans-sb, size: s-display, tracking: -0.02em)[Exact Gradients\ Through a BRep Kernel])
  #v(0.5em)
  #line(length: 22%, stroke: 2pt + c-label)
  #v(0.7em)
  #text(size: s-lg, fill: c-label)[Differentiating CAD parameters through tessellation, fillets, mass properties and contact]
  #v(0.5in)
  #caps[Cam Pedersen · Municipal Robotics]
]}

#let abstract-text = [
  Gradient-based design needs the derivative of a downstream quantity with respect to the parameters a designer actually edits: a hole radius, a fillet radius, an extrude depth. In a boundary-representation (BRep) CAD kernel those parameters pass through Boolean operations, filleting and tessellation, all of which make discrete choices, so the kernel is not differentiable as written. We describe the differentiable seam in vcad, an open-source Rust BRep kernel: rather than differentiating the kernel's combinatorics, we freeze the tessellation's topology at the current parameter value and differentiate the positions of its nodes exactly, by evaluating the kernel's analytic surfaces on dual numbers and by implicit differentiation of the surface equations at vertices and trim curves. The seam detects changes of topology and reports them as errors instead of returning wrong gradients.

  The seam covers planes, cylinders, spheres, cones and tori, including composite motions such as a fillet radius that moves twenty surfaces at once; exact first and directional second derivatives of volume, mass, centroid and inertia; a reverse-mode transpose that prices every parameter from one pass; seeding synthesized from the build function; L-BFGS; gradients of a named parameter of a `.vcad` document; and, through an exact trajectory adjoint in the phyz simulator, gradients of rigid-body rollouts including penalty contact against the CAD surface. Every derivative is validated against finite differences of a full rebuild. Fillet-radius volume gradients agree to #E(K-m4 + "@L132::rel_fd"), reverse mode prices both parameters of a filleted cube from one pass and matches forward mode to rounding, and a contact rollout's shape gradient to #E("m11_contact_gradient::contact_chain_matches_end_to_end_fd@L166::rel"). L-BFGS recovers all five parameters of a filleted, drilled box in #V("m9::lbfgs::iters") iterations where projected gradient descent does not converge in #V("m9::gd::iters"). The gradients are those of the frozen tessellation: they are exact for the mesh the kernel produces and differ from the continuum shape derivative by the polygonization error, and they say nothing across a change of topology. We present the seam as one operator with its own adjoint, the geometry node in a planned architecture in which vcad's physics is written once as math and the tang compiler derives kernels and gradients for every device; today the seam, mass properties and the rollout adjoint are composed by hand, and that composition is the graph the architecture will make general.
]
#if web {
  html.elem("section", attrs: (class: "abstract", id: "abstract"), {
    html.elem("h2", attrs: (class: "abstract-title"), [Abstract])
    abstract-text
  })
} else {page(margin: (x: 0.75in, top: 1.1in, bottom: 1.05in))[
  #block(width: 4.9in)[
    #heading(outlined: false, numbering: none)[Abstract]
    #set text(size: 10pt)
    #set par(leading: 0.8em, spacing: 1.25em)
    #abstract-text
  ]
]}

= Introduction

A mechanical designer works in parameters: the depth of a pocket, the radius of a bore, the radius of a fillet. An optimizer that should help that designer needs $d J \/ d theta$, the derivative of an objective $J$ (a mass, an inertia, a simulated trajectory) with respect to those same parameters. Production CAD kernels do not provide it. Between $theta$ and anything measurable sit Boolean operations, fillet construction and tessellation, each of which makes discrete decisions: which faces survive a Boolean, in which order they are sewn, how many segments approximate a circle, where a triangulation inserts a vertex. Practitioners fall back on finite differences of full rebuilds, which cost one rebuild per parameter and, as we show, are noisy on filleted parts, because two rebuilds can enumerate the same topology in different orders.

Most differentiable-geometry work avoids the problem by changing the representation: signed distance fields, constructive solid geometry over smooth primitives, or meshes optimized directly. These are well suited to learning and to rendering, but the designer's model is a BRep with fillets, and its parameters are the ones in the feature tree.

We take the opposite approach and differentiate the production kernel without changing it. The idea, which we call the *seam*, is to cut the chain at the tessellated mesh. At the current parameter $theta_0$ we record a *frozen plan*: the tessellation's connectivity and, for every mesh node, a recipe that says how that node is determined by the BRep (a topology vertex, a point at fixed surface coordinates, or a point on the intersection of two surfaces). Within the neighbourhood where the topology does not change, node positions are smooth functions of $theta$, and we compute their derivatives $d x_i \/ d theta$ exactly. Everything downstream (mass properties, objectives, a physics adjoint) is an ordinary smooth function of node positions.

Our contributions are:

- *A frozen-tessellation seam for a production BRep kernel* (vcad), with exact node sensitivities from dual-number evaluation of the kernel's analytic surfaces and implicit differentiation of surface equations at vertices and trims, covering planes, cylinders, spheres, cones and tori, and composite motions such as a fillet radius (@sec:seam).
- *Exact derivatives of mass properties*, first order and directional second order including node accelerations on cones and tori, and a Gauss–Newton Hessian for least-squares objectives (@sec:qoi).
- *A reverse mode* obtained by transposing the seam's per-node linear maps, so one pass prices every parameter, and an L-BFGS optimizer over it that treats topology changes as failed steps (@sec:reverse).
- *Seeding synthesized from the build function*, which removes the last hand-written step, and gradients of named parameters of `.vcad` documents (@sec:synth).
- *Gradients through rigid-body rollouts*, exact for contact-free rollouts and for a penalty-contact model whose contact cotangent on the CAD surface is pulled back through the seam (@sec:physics).

Every derivative is validated against central finite differences of a full CAD rebuild (@sec:results), and a script regenerates every number in this paper from a fresh clone (@sec:repro).

The seam also fits an operator-graph design. It takes CAD parameters and returns a mesh together with a vector–Jacobian product, which is the contract of an opaque operator node in a differentiable program. @sec:operator places it in the architecture we are building for vcad and phyz on the tang compiler, where engineering physics is written once as tensor comprehensions and gradients through solves and rollouts come from operator nodes with known adjoints. The results in this paper are for the seam and its hand-wired consumers as they exist today; the architecture is stated as the plan they plug into, not as a result.

== Scope and limits

We state the limits first, because they define what the gradients mean.

- *Gradients of the frozen tessellation.* The seam differentiates the mesh the kernel actually produces at $theta_0$, with its segment counts and triangulation held fixed. It is exact for that mesh. It differs from the continuum shape derivative by the polygonization error: for a 112-segment hole the gap is #E(K-m2 + "@L129::gap"), and for 16-segment fillet blends #fx(100 * V(K-m4 + "@L195::gap"), 1)% (@tab:fd). Refining the mesh closes this gap; the seam does not.
- *No derivatives across topology changes.* When a perturbation would change the topology (a blind hole breaking through, a fillet consuming a face), the derivative of the frozen mesh does not exist in any useful sense. The seam detects this with a topology signature and per-node correspondence checks and returns an error. The optimizer treats such a step as failed and shrinks it.
- *The contact adjoint covers phyz's differentiable penalty model*, a per-vertex spring–damper against a ground plane with no friction. It does not differentiate the GJK/EPA collision pipeline used by vcad's production physics world @gilbert1988gjk.
- *Round-off agreement is on CPU in f64.* Every gate in this paper runs on CPU in double precision. No GPU result is claimed.
- *The trajectory adjoint supports single-degree-of-freedom joints* (revolute, prismatic, fixed), open-loop control and objectives on the final state only.

#figure(fig-wall(),
  caption: [#lead[What the gradient is a gradient of.] Within one topology class the frozen plan's volume is smooth in the parameter and the seam returns its exact derivative (red tangent). When a blind hole breaks through, the plan's topology signature changes and the seam returns `TopologyChanged`; an optimizer treats that as a failed step and shrinks it. Schematic.],
) <fig:wall>

= Background and related work

*Differentiable rendering and mesh optimization.* Differentiable rasterizers @kato2018nmr @liu2019softras and path tracers @li2018edge compute derivatives of images with respect to mesh vertices. They operate on a mesh whose connectivity is held fixed, as ours is; the difference is where the vertex positions come from. Worchel and Alexa extract a mesh from parametric curves and surfaces and pass it to a differentiable mesh renderer @worchel2023parametric; they report that naive differentiable tessellation is fragile, which our correspondence machinery addresses for BRep solids.

*Implicit and CSG representations.* Signed distance fields, learned @park2019deepsdf or analytic, are differentiable almost everywhere and can be rendered differentiably @vicini2022sdf. Program-synthesis approaches recover CSG trees from shapes @sharma2018csgnet @du2018inversecsg. Commercial implicit-modeling optimizers work in the same representation (TODO: find a citable reference for a production implicit-modeling optimizer). These representations trade the BRep's exact faces, trims and fillets for differentiability; we keep the BRep.

*Differentiable CAD programs.* Cascaval et al. write CAD programs in an automatically differentiable language for bidirectional editing; they do not optimize across changes of topology @cascaval2022bidirectional. Michel and Boubekeur compute parameter updates for direct manipulation of procedural shapes @michel2021dag. Schulz et al. precompute a design space of CAD parameters for interactive optimization @schulz2017designspace. The closest work in engineering is the algorithmic differentiation of the Open CASCADE kernel with ADOL-C by Banović et al., coupled to an adjoint CFD solver @banovic2018occt. They differentiate the kernel's operations by operator overloading; we leave the kernel's combinatorial code undifferentiated and differentiate only the geometric map from parameters to the frozen mesh, which is why a nondeterministic Boolean or fillet is not a problem for us.

*CAD-parameterized shape optimization.* Structural shape optimization has long used design velocities, the sensitivity of boundary points to design variables @haftka1986shape @sokolowski1992shape. Agarwal et al. compute parametric design velocities for CAD models for use with adjoint solvers @agarwal2018designvelocity, and isogeometric analysis removes the mesh by computing on the CAD basis @hughes2005iga. Our node velocities $d x_i \/ d theta$ are design velocities; what we add is computing them exactly inside a general-purpose BRep kernel, including fillets, and carrying them to mass properties and rigid-body dynamics.

*Differentiable physics and co-design.* Differentiable simulators include rigid-body formulations with contact @belbute2018diffphys @geilinger2020add @werling2021nimble and differentiable programming systems @hu2020difftaichi. Robot co-design work optimizes morphology and control jointly @ha2017joint @xu2021codesign, usually over parametric primitives rather than CAD models. Our physics consumer is a discrete adjoint over Featherstone's articulated-body algorithm @featherstone2008; the contribution here is the interface, which prices CAD parameters through two channels, the ten mass-property scalars per body and the contact cotangent on the CAD surface.

*Differentiable array compilers.* The architecture in @sec:operator builds on tang, our tensor compiler, whose single compute primitive is the comprehension $"out"[i] = plus.o.big_k "body"(x["view"(i, k)])$ with a traced scalar body, a monoid combine and affine, guarded or gather views; tang derives gradients of comprehension programs and generates code for CUDA, Metal, WGSL, OpenCL, GLSL and C, checked against an f64 reference interpreter (TODO: cite the tang paper once it has an arXiv identifier). Operator nodes with user-supplied adjoints, such as a linear solve differentiated by the implicit function theorem, are the standard way to place solvers inside such programs (TODO: cite implicit-differentiation libraries, e.g. JAX custom VJPs, after verifying a reference).

= The differentiable seam <sec:seam>

#figure(fig-seam(),
  caption: [#lead[Where the chain is cut.] The BRep build is never differentiated. At the current parameters a frozen plan records the tessellation; node sensitivities $d x \/ d theta$ come from the kernel's analytic surfaces. Downstream quantities differentiate as smooth functions of node positions, and reverse mode runs the same maps transposed.],
) <fig:seam>

== Frozen plans

vcad's kernel represents solids as BReps whose faces carry analytic surfaces (plane, cylinder, cone, sphere, torus, bilinear patch, B-spline), Boolean operations, filleting and a tessellator. Two properties of the kernel, both found by running it, shaped the design. First, the Boolean pipeline and the fillet kernel are order-nondeterministic: two builds of the same model can enumerate isomorphic topology in different orders, flip a blend cylinder's axis or rotate its reference direction. Traversal order therefore cannot carry node identity from one build to another. Second, the stock mesh stores 32-bit positions, at which a central difference with $h = 10^(-6)$ is meaningless, so the seam emits its own 64-bit mesh.

`capture_plan` tessellates once at $theta_0$ and classifies every node:

- *TopoVertex*: the node coincides with a topology vertex. Its velocity comes from implicit differentiation (@sec:implicit).
- *SurfaceUv*: the node is interior to a face, stored as fixed surface coordinates $(u, v)$. Its position is $S(u, v; phi(theta))$ for the surface's fields $phi$ (offset, radius, axis, half-angle).
- *Boundary*: the node lies on the intersection of two faces with independent normals but is not a topology vertex, for example a ring on a cylinder's cap. Its position is the Newton solution of ${g_a(x) = 0, g_b(x) = 0, t dot (x - x_0) = 0}$, with $t$ the intersection tangent, so the node follows the moving trim whichever surface carries $theta$.

A plan carries a topology signature (a sorted multiset of per-face descriptors, which is invariant to isomorphic reordering) and each node's capture-time position. Re-evaluating at a nearby $theta$ resolves vertices and faces geometrically, by nearest match after transporting the stored $(u, v)$ through the rebuilt surface's frame, and fails with `CorrespondenceLost` when any node lands more than $10^(-3)$ mm from where it should. A changed signature fails with `TopologyChanged`. Both are errors, never a mesh.

#figure(fig-recipes(),
  caption: [#lead[Node recipes on a Boolean result.] Left: the top cap of a plate minus a cylinder, θ = hole radius. Rim vertices are topology vertices; their velocity comes from the implicit rows and is exactly radial. Plane-interior samples sit on a surface that does not move and have zero velocity. Right: the rows at one rim vertex. The cap plane and the hole wall give two independent rows; the tangent direction is unconstrained and stays frozen, so the rim keeps its angular parameter.],
) <fig:recipes>

== Surface nodes: the lift bridge

Every analytic surface in the kernel is generic over a scalar type, so it can be evaluated on dual numbers $a + b epsilon$ with $epsilon^2 = 0$ @griewank2008. A parameter is connected to the surfaces it moves by a *seeding*: a map from surface index to field velocities (translate by $bold(v)$, grow the radius at rate $dot(r)$, open the cone at rate $dot(alpha)$, and so on). Seeds compose additively, which matters for fillets: when the fillet radius grows, each blend cylinder's radius grows at rate 1 while its axis retreats from the edge, and each corner sphere does the same in three coordinates. For a SurfaceUv node, the dual part of $S(u, v; phi + dot(phi) epsilon)$ is exactly $d x \/ d theta$.

== Vertices and trims: implicit differentiation <sec:implicit>

A topology vertex lies on every surface incident to it. Each incident surface has an implicit form $g(x; phi) = 0$: for a plane $n dot (x - o)$, a cylinder $norm(x_perp)^2 - r^2$, a sphere $norm(x - c)^2 - r^2$, and for a cone with apex $a$, axis $d$ and half-angle $alpha$,
$ g = norm(x_perp)^2 - tan^2 alpha (( x - a) dot d)^2 . $
Differentiating $g(x(theta); phi(theta)) = 0$ gives one linear row per surface,
$ nabla g dot dot(x) = - (partial g) / (partial theta) . $
We solve the rows by Gram–Schmidt, carrying the right-hand side. Independent rows fix components of $dot(x)$, dependent rows must agree within tolerance (otherwise the solve fails), and directions no row constrains stay at zero. The last rule is the frozen-branch convention: a node on a circular rim keeps its angular parameter. Three planes at a box corner give a full $3 times 3$ solve; a plane and a cylinder at a hole rim give a rank-2 solve with a frozen tangent.

The rows needed two refinements. Boolean sewing does not always pair the half-edges around a rim, so topological adjacency under-constrains some vertices, and the seam also collects rows by geometric incidence. And a fillet blend touches its support face *tangentially*, so the blend's row is parallel to the plane's and the system is rank-deficient exactly where the corner vertex slides along the face. The missing information is that the vertex must stay on the tangent curve; for a cylinder of axis $a$ tangent to a plane of normal $n$ we add the row $q dot dot(x) = q dot dot(bold(v))_"translate"$ with $q = a times n$, and two such rows for a sphere. With these rows the corner of a filleted cube slides at exactly $(1, 1, 0)$ per unit radius.

#figure(fig-fillet(),
  caption: [#lead[A fillet radius is a composite seed.] Growing the radius by δ grows each blend cylinder's radius at rate 1 while its axis retreats at $(-1, -1)$ in the section plane; the two motions compose so that the tangent lines slide along the support faces at exactly unit rate. On the all-edges-filleted cube one parameter moves 20 surfaces this way.],
) <fig:fillet>

= Quantities of interest <sec:qoi>

== Mass properties

Volume, mass, centroid and inertia tensor follow from signed-tetrahedron integrals over the closed mesh @mirtich1996mass. The integrals are written once over a generic scalar, so evaluating them at dual-number node positions gives every quantity and its derivative along $theta$ in one pass. A physics functional plugs in through the contraction
$ (d J) / (d theta) = sum_i (partial J) / (partial x_i) dot (d x_i) / (d theta) , $
with $partial V \/ partial x_i$ known in closed form from the divergence theorem.

== Second order

For one direction in parameter space,
$ (d^2 V) / (d theta^2) = sum_(i j) (partial^2 V) / (partial x_i partial x_j) dot(x)_i dot(x)_j + sum_i (partial V) / (partial x_i) dot.double(x)_i . $
Evaluating the volume integral on nested duals $((x, dot(x)), (dot(x), dot.double(x)))$ carries both terms. The work is in the node accelerations $dot.double(x)$. A surface node on a plane, cylinder or sphere is linear in its fields, so its acceleration is the first-order lift fed the field accelerations. Cone and torus points are not linear in their fields ($tan alpha$, the two torus radii), so surface nodes are lifted on nested duals. Vertex and trim nodes solve the implicit system differentiated twice,
$ nabla g dot dot.double(x) = - ( (partial^2 g) / (partial theta^2) + 2 dot(x)^top nabla_x (partial g) / (partial theta) + dot(x)^top nabla^2 g space dot(x) ) , $
with the same row gradients as the first-order solve; the cone and torus contribute closed-form curvature terms because their $nabla^2 g$ is not constant. For least-squares objectives $J = sum_q r_q^2$ we also provide the Gauss–Newton Hessian $2 J_r^top J_r$, which drops the residual-curvature term and is therefore exact at zero residual.

#figure(fig-torus(),
  caption: [#lead[The torus's two design velocities] on its own mesh, front half. Growing the minor radius moves every node along the tube normal. Growing the major radius moves every node away from the axis, so the wall moves outward on the outer equator and inward on the inner one, which is why $d V \/ d R = 2 pi^2 r^2$ is smaller than $d V \/ d r = 4 pi^2 R r$ here. Values are the seam's, on the 24-segment mesh of `make_torus(8, 3)`.],
) <fig:torus>

= Reverse mode and optimization <sec:reverse>

Node velocities are linear in the seed values. For each node there is a fixed linear map from the per-surface seed slots (a translation in $RR^3$ and one slot per scalar field) to $dot(x)_i$. Reverse mode is the transpose of these maps contracted with $partial J \/ partial x$:
$ (partial J) / (partial s) = sum_i A_(i s)^top (partial J) / (partial x_i), quad (d J) / (d theta_k) = sum_s chevron.l (partial J) / (partial s), "seed"_k (s) chevron.r . $
One `evaluate_with_pullback` computes the per-surface cotangents; each parameter then costs a few dot products. No tape or graph is recorded. The transposed vertex solve runs the same Gram–Schmidt elimination carrying each coefficient as a linear functional of the rows, and each row's dependence on its seeds is read off by calling the forward row constructor with unit seeds, so forward and reverse mode cannot disagree about a row.

The optimizer is L-BFGS with memory 8 @liu1989lbfgs, box projection and an Armijo line search on the projected step. The objective is smooth only within a topology class, so three rules keep bad curvature out of the memory: pairs with $s dot y <= 10^(-12) norm(s) norm(y)$ are dropped; a pair is dropped when the line search that produced it had to shrink past a `TopologyChanged` or `CorrespondenceLost` error, since its $y$ mixes two branches; and a direction that is not a descent direction clears the memory and falls back to projected steepest descent. Each iterate rebuilds the part and captures a fresh plan.

= Seeding synthesis and documents <sec:synth>

Writing a seeding by hand ("this radius moves these twenty surfaces, each at radius rate 1 with a center retreat of $(plus.minus 1, plus.minus 1, 0)$") is error-prone on real parts. `synthesize_seeding` derives it from the build function. It rebuilds at $theta plus.minus h$, matches each base surface to its counterparts by frame-invariant geometric identity (a plane by its normal up to sign and its offset; a cylinder by its axis line and radius; a sphere by center and radius), and reads the field velocities off central differences of the matched fields. Surface fields, unlike mesh nodes, have no combinatorial structure, so this difference is accurate to $O(h^2)$. Only observable components are kept: in-plane drift of a plane's origin and axial drift of a cylinder's center are gauge and are projected out, while a cone's apex slide is observable because it changes the radius at every height. Everything downstream of the seeding remains exact.

`document_parameter_gradient` applies this to a `.vcad` document: a named parameter is bound, the document is evaluated to one BRep per part, the seeding is synthesized, and each solid part returns $d(V, m, c, I) \/ d theta$. Evaluations at $theta plus.minus h$ are checked to produce the same number of parts, so a parameter value that adds or removes a part errors instead of returning a gradient.

= Gradients through rigid-body rollouts <sec:physics>

In a rollout of an articulated rigid-body system without contact, the geometry of body $b$ enters the dynamics only through its ten mass-property scalars $p_b = (m, c, I)$. The chain rule is exact:
$ (d J) / (d theta) = sum_b (partial J) / (partial p_b) dot (d p_b) / (d theta) + sum_b "pullback"_b ((partial J) / (partial x)) . $
The first factor of the first term, $partial J \/ partial p_b$, comes from a discrete adjoint over semi-implicit Euler in phyz @featherstone2008. Its within-step Jacobian columns are themselves exact: the articulated-body algorithm, forward kinematics and contact law are generic over the scalar type and are evaluated on dual numbers, one lane per column. The second factor, $d p_b \/ d theta$, is the seam's mass-property derivative. The second term is the contact channel: phyz's differentiable rollout applies a penalty force $f_z = max(0, k delta - c v_z)$ at every vertex of the body's frozen-plan mesh below the ground, and its adjoint returns $partial J \/ partial x$ on those vertices, which the seam's reverse mode turns into $d J \/ d theta$ (@sec:reverse). Vertices reach the dynamics only through each body's six-component contact wrench, so the adjoint prices the wrench cotangent once per body and contracts it against each vertex's local wrench Jacobian rather than carrying $3N$ dual lanes. A rollout that the structured specification cannot express (state feedback, multi-DOF joints) falls back to central differences on the ten scalars, which needs about twenty re-simulations per body and no CAD rebuild.

= The seam as an operator node <sec:operator>

Viewed from outside, everything in @sec:seam to @sec:physics is a small set of operators, each with a forward map and an exact vector–Jacobian product:

- *SeamEval*: $theta |-> x$, node positions of the frozen plan; VJP by the transposed seam (@sec:reverse). It fails, rather than returning a value, outside its topology class.
- *MassProps*: $x |-> p$, the ten mass-property scalars per body; VJP from the divergence-theorem gradients.
- *Rollout*: $(p, x) |-> J$, a phyz trajectory with penalty contact on the seam mesh; VJP from the discrete adjoint, returning both $partial J \/ partial p$ and the contact cotangent $partial J \/ partial x$.

In vcad today these three are composed by hand: `adjoint_gradient_core` in `vcad-kernel-physics` runs a nominal seam pass per body, computes mass properties, runs one phyz adjoint pass and contracts the two channels. That function is a three-node operator graph written out manually, and every rollout result in @tab:physics comes from it.

The architecture we are building makes that graph general. Engineering physics in vcad (thermal and electromagnetic time steps, finite-element assembly, sparse matrix–vector products) has the shape of tang comprehensions: affine views and a map for a stencil step, a gather view with a scatter-add monoid for assembly. What a comprehension IR cannot express is "solve this system" or "run this simulation" as a single step with a known gradient, so the one new construct is an opaque operator node that runs native code forward and takes a user-supplied adjoint backward: `LinearSolve` (adjoint: one more solve with $A^top$), `NonlinearSolve`, a checkpointed `TimeLoop`, phyz's `Rollout` and the `SeamEval` of this paper. ABA and contact stay native Rust inside `Rollout`; they are sequential recursions that already have a correct adjoint and gain nothing from being traced.

#figure(fig-showpiece(),
  caption: [#lead[The planned showpiece], not a result of this paper. CAD parameters of a leg (wall thickness, fillet radius, foot pad) pass through SeamEval, MassProps and a phyz contact rollout to jump height, with a motor housing's steady-state temperature as a coupled constraint through assembly and a linear solve. One reverse pass gives $partial J \/ partial theta$ for L-BFGS. The orange path exists today, composed by hand (@tab:physics); the thermal branch and the general graph are planned.],
) <fig:showpiece>

The plan is staged so that each step has a numeric gate: one tang version across vcad, phyz and tang; a sparse conjugate-gradient solver written in the IR and `LinearSolve` proved on steady thermal against vcad's hand adjoint to $10^(-12)$; thermal and FEA assembly as comprehensions on GPU; `Rollout` and `SeamEval` as nodes, matching today's hand-wired numbers to round-off before the hand wiring is deleted; coupled thermal stress through one graph; and Revolve-style checkpointing for long rollouts and transients. None of these gates has passed at the time of writing, and no result in @sec:results depends on them.

= Results <sec:results>

All results come from vcad's gate tests at commit #raw(env.at("vcad_rev").slice(0, 10)), run in the release profile on a single thread (#env.at("cpu"), #env.at("rustc")). Each test asserts its bound; the values below are what the tests measured (@sec:repro). "FD" is a central difference with $h = 10^(-6)$ in the parameter unless stated: the part is rebuilt at $theta plus.minus h$ and re-evaluated under the same frozen plan, so FD and the seam differentiate the same discrete object. Relative errors are taken against the larger of the two magnitudes.

== Validation against finite differences

#let fdrow(name, theta, dv, dvfd, rel, nodes) = (name, theta, dv, dvfd, rel, nodes)
#figure(
  table(
    columns: (1.55fr, 0.75fr, 0.95fr, 0.85fr, 0.85fr),
    align: (left, left, right, right, right),
    table.header([*Model*], [*θ*], [*dV/dθ (seam)*], [*vs FD*], [*node-wise*]),
    [Extrusion], [depth], [#F(K-m0 + "@L80::dv", 3)], [#E(K-m0 + "@L80::rel_fd")], [#E(K-m0 + "::cmp.max_rel_err")],
    [Box − cylinder], [hole r], [#F(K-m2 + "@L119::dv", 3)], [#E(K-m2 + "@L119::rel_fd")], [#E("m2_boolean_hole::m2_rim_nodes_implicit_diff_matches_fd::cmp.max_rel_err")],
    [Cylinder], [height], [#F(K-m3b + "@L118::dv", 3)], [#E(K-m3b + "@L118::rel_fd")], [#E(K-m3b + "::cmp.max_rel_err")],
    [Filleted cube], [fillet r], [#F(K-m4 + "@L195::dv", 3)], [#E(K-m4 + "@L132::rel_fd")], [#E(K-m4 + "::cmp.max_rel_err")],
    [Filleted cube], [edge a], [#F(K-m5 + "@L311::dv_da_rev", 3)], [#E(K-m5 + "@L311::rel_a")], [–],
    [Cone frustum], [half-angle], [#F(K-m7a + "@L163::dv", 2)], [#E(K-m7a + "@L163::rel_fd")], [#E(K-m7a + "::cmp.max_rel_err")],
    [Cone frustum], [height], [#F(K-m7h + "@L208::dv", 3)], [#E(K-m7h + "@L208::rel_fd")], [#E(K-m7h + "::cmp.max_rel_err")],
    [Torus], [minor r], [#F("m7_cone_torus::torus_gate@L269::torus minor r::dv_fd", 2)], [#E("m7_cone_torus::torus_gate@L269::torus minor r::rel_fd")], [#E("m7_cone_torus::torus_gate::torus minor r::cmp.max_rel_err")],
    [Torus], [major R], [#F("m7_cone_torus::torus_gate@L269::torus major R::dv_fd", 2)], [#E("m7_cone_torus::torus_gate@L269::torus major R::rel_fd")], [#E("m7_cone_torus::torus_gate::torus major R::cmp.max_rel_err")],
  ),
  caption: [#lead[First-order volume gradients against finite differences of a full rebuild.] Node-wise is the worst relative error of $d x_i \/ d theta$ over all mesh nodes. Torus rows list the FD value; the seam agrees to the error shown. Every row passes vcad's $10^(-6)$ gate. The filleted cube moves 20 surfaces with one parameter. `data/measured.tsv`.],
) <tab:fd>

Where a discrete closed form exists the seam meets it to rounding. The hole's mesh cross-section is the inscribed 112-gon, so $d V \/ d r = -N sin(2 pi \/ N) r t$; the seam matches it to #E(K-m2 + "@L111::rel_closed"). The cone's half-angle derivative matches the prismatoid formula to #E(K-m7a + "@L156::rel_closed"), the cylinder-height derivative the N-gon cap area to #E(K-m3b + "@L112::rel_closed"), and the extrusion's $d V \/ d d$ the cross-section area exactly (#E(K-m0 + "@L72::rel_analytic")). The continuum shape derivatives differ by the polygonization error and no more: #E(K-m2 + "@L129::gap") for the hole (bounded by $x^2 \/ 6$ with $x = 2 pi \/ N$), and #fx(100 * V(K-m4 + "@L195::gap"), 1)% for the fillet's Minkowski-sum derivative at 16 segments per quarter-blend.

The mass-property derivatives behave the same way: $d I_(z z) \/ d d$ of the extrusion meets its closed form to #E("m3_mass_properties::extrude_inertia_derivative_matches_closed_form_and_fd@L63::rel") and FD to #E("m3_mass_properties::extrude_inertia_derivative_matches_closed_form_and_fd@L80::rel"); the cylinder's inertia derivative with respect to radius meets FD to #E(K-m3m + "@L129::rel").

#figure(fig-ladder(),
  caption: [#lead[Every first-order gate on one axis.] Filled: the seam's $d V \/ d theta$ (or $d J \/ d theta$ for the contact rollout) against a central difference of a full rebuild. Open: the worst node-wise $d x \/ d theta$. All sit two or more orders below vcad's $10^(-6)$ gate. `data/measured.tsv`.],
) <fig:ladder>

== Reverse mode, synthesis and second order

#figure(
  table(
    columns: (2.1fr, 1fr, 1fr),
    align: (left, right, right),
    table.header([*Check*], [*Value*], [*Rel. error*]),
    [Reverse vs forward, hole dV/dr], [#F("m5_reverse_mode::agree::hole dV/dr::rev", 4)], [#sci(calc.abs(V("m5_reverse_mode::agree::hole dV/dr::rev") - V("m5_reverse_mode::agree::hole dV/dr::fwd")) / calc.abs(V("m5_reverse_mode::agree::hole dV/dr::fwd")))],
    [Reverse vs forward, fillet dV/dr], [#F("m5_reverse_mode::agree::rounded cube dV/dr::rev", 4)], [#sci(calc.abs(V("m5_reverse_mode::agree::rounded cube dV/dr::rev") - V("m5_reverse_mode::agree::rounded cube dV/dr::fwd")) / calc.abs(V("m5_reverse_mode::agree::rounded cube dV/dr::fwd")))],
    [Synthesized vs hand seeding, fillet dV/dr], [#F(K-m6 + "::dv_dr_syn", 4)], [#E(K-m6 + "::rel_dv_dr_syn_vs_dv_dr_hand")],
    [Synthesized vs hand seeding, edge dV/da], [#F(K-m6 + "::dv_da_syn", 3)], [#E(K-m6 + "::rel_dv_da_syn_vs_dv_da_hand")],
    [Synthesized, cone/torus composite vs FD], [#F("m6_synthesized_seeding::cone_and_torus_parameters_synthesized::dv", 2)], [#E("m6_synthesized_seeding::cone_and_torus_parameters_synthesized::rel_dv_vs_fd")],
    [Reverse on synthesized seeding vs forward], [#F(K-m6 + "::dv_dr_rev", 4)], [#E(K-m6 + "::rel_dv_dr_rev_vs_dv_dr_syn")],
    [d²V/dr², hole vs closed form], [#F(K-m10 + "m10_hole_second_derivative_matches_closed_form_and_fd@L140::ddv", 3)], [#E(K-m10 + "m10_hole_second_derivative_matches_closed_form_and_fd@L132::rel_closed")],
    [d²V/dα², cone vs closed form], [#F(K-m10 + "m10_cone_half_angle_second_derivative_matches_closed_form@L370::ddv", 1)], [#E(K-m10 + "m10_cone_half_angle_second_derivative_matches_closed_form@L355::rel")],
    [d²V/dα², cone vs FD of dV/dα], [], [#E(K-m10 + "m10_cone_half_angle_second_derivative_matches_closed_form@L370::rel_fd")],
    [d²V/dr², torus minor vs FD of dV/dr], [#F(K-m10 + "m10_torus_minor_radius_second_derivative@L444::fd", 2)], [#E(K-m10 + "m10_torus_minor_radius_second_derivative@L444::rel")],
    [d²V/dθ², torus with r = θ² (chain rule)], [#F(K-m10 + "m10_torus_nonlinear_field_chain_rule@L505::ddv_dthth", 1)], [#E(K-m10 + "m10_torus_nonlinear_field_chain_rule@L505::rel2")],
    [d²V/dr², filleted cube vs FD (h = 10⁻³)], [#F(K-m10 + "m10_rounded_cube_second_derivative_matches_fd@L284::fd", 2)], [#E(K-m10 + "m10_rounded_cube_second_derivative_matches_fd@L284::rel")],
    [Gauss–Newton vs full Hessian (Frobenius)], [], [#E(K-m10 + "m10_gauss_newton_hessian_matches_full_hessian_near_optimum@L839::rel_frob")],
  ),
  caption: [#lead[Reverse mode, synthesized seedings and second derivatives.] Reverse and forward mode use the same rows in a different order and agree to rounding. Synthesized seedings carry the $O(h^2)$ error of the field differences. The filleted cube's second derivative is checked with a wider FD step because re-capturing a filleted solid at $r plus.minus h$ adds about $10^(-4)$ of correspondence jitter (@sec:discussion). The Gauss–Newton comparison is on the five-parameter box near its optimum, where the dropped residual term vanishes. `data/measured.tsv`.],
) <tab:rev>

The cone gate is the first in which node accelerations are nonzero: opening the half-angle moves every rim vertex along a curved path, and the nested-dual lift and the cone's curvature rows reproduce the closed form to rounding.

== L-BFGS on a five-parameter part

The test part is a box of dimensions $(s_x, s_y, s_z)$ with all edges filleted at radius $r$ and a centered through-hole of radius $r_h$: 6 planes, 12 blend cylinders, 8 corner spheres and a hole wall, 916 mesh nodes. The objective is the squared relative miss of five quantities (volume, the three centroid coordinates and $I_(z z)$) against their values at $theta^* = (10, 12, 8, 1.8, 2.2)$ mm, starting from $theta_0 = (8, 14, 6, 1.2, 1.6)$ mm. The five-by-five Jacobian of the quantities has determinant #F("m9::jac::det", 0) and smallest pivot #F("m9::jac::min_pivot", 2), so all five parameters are locally identifiable.

#figure(fig-lbfgs(),
  caption: [#lead[L-BFGS against projected gradient descent], same gradients (reverse mode), same line search. L-BFGS stops on the gradient tolerance after #V("m9::lbfgs::iters") iterations (#V("m9::lbfgs::evals") objective evaluations) with $norm(theta - theta^*)_infinity =$ #E("m9::lbfgs::err_inf"). Gradient descent reaches its #V("m9::gd::iters")-iteration limit (#V("m9::gd::evals") evaluations) at $norm(theta - theta^*)_infinity =$ #E("m9::gd::err_inf"): steepest descent zig-zags between the dimension and radius directions, whose scales differ. `data/measured.tsv`.],
) <fig:lbfgs>

Reverse and forward gradients agree per component to at most #sci(calc.max(..range(5).map(k => V("m9::fwd_vs_rev::" + str(k), i: 2)))). Per iterate, the shared rebuild and capture take #F("m9::ms::build_capture", 1) ms; differentiation takes #F("m9::ms::forward", 2) ms in forward mode (five seam passes) and #F("m9::ms::reverse", 2) ms in reverse mode (one seam pass, one pullback, five dot products). The rebuild dominates at this size; the differentiation cost is the part that grows with the number of parameters, linearly in forward mode and by one dot product per parameter in reverse mode.

A finite-difference check of the same gradient shows why finite differences are a poor substitute on filleted parts. For the hole radius and $s_z$ FD agrees to #E("m9::fd::4", i: 2) and #E("m9::fd::2", i: 2), but for $s_x$ and the fillet radius the agreement is only #E("m9::fd::0", i: 2) and #E("m9::fd::3", i: 2). The error is in FD, not in the seam. Rebuilding a filleted solid under a plan captured elsewhere carries the fillet kernel's frame and correspondence noise, while reverse and forward mode, two independent implementations, agree to rounding.

== A fillet radius and a flywheel by gradient descent

Projected gradient descent on the fillet radius alone recovers the radius whose rounded cube hits a target volume, $r^* = 2.2$ mm from $r_0 = 1$ mm, landing at #F("m4_fillet_radius::optimize::r", 6) mm in #V("m4_fillet_radius::optimize::iters") accepted iterates.

#figure(fig-flywheel(),
  caption: [#lead[A flywheel design brief.] A disc (radius 40 mm, thickness 10 mm) with a center bore and four lightening holes on a 25 mm bolt circle; θ = (bore radius, hole radius). Objective: mass over a reference mass plus $100 dot$ the squared relative miss of a target spin inertia, the inertia of θ\* = (8, 5). Projected gradient descent, each iterate rebuilding the part through five Booleans and capturing a fresh plan. The bounds keep the holes inside the disc and clear of each other, so the topology does not change. Descent is monotone over #context { let n = 0; while ("m3_flywheel::iter::" + str(n + 1)) in measured { n += 1 }; [#n accepted iterates, ending at θ = (#F("m3_flywheel::iter::" + str(n), 2, i: 0), #F("m3_flywheel::iter::" + str(n), 2, i: 1)) mm] } with the bore on its upper bound: θ\* only sets the target inertia, and a larger bore reaches it with less mass. The zig-zag in hole radius is steepest descent on an anisotropic objective; the analytic gradient matched FD at θ₀ to #E("m3_flywheel_optimize::flywheel_hits_target_inertia_with_less_mass@L151::rel"). `data/measured.tsv`.],
) <fig:flywheel>

== A named parameter of a document

A `.vcad` document whose cylinder radius is bound to the named parameter `r` differentiates end to end with no hand seeding: $d V \/ d r =$ #F(K-doc + "ir::dv", 3) against the N-gon closed form #F(K-doc + "parametric_document_cylinder_gradient@L119::dv_exact", 3) (#E(K-doc + "parametric_document_cylinder_gradient@L119::rel")), and $d I_(z z) \/ d r$ agrees with a document-rebuild FD to #E(K-doc + "parametric_document_cylinder_gradient@L140::rel_izz"). A document authored in vcad's loon language and one whose parameter is declared with `defparam` reach the same closed form to #E(K-doc + "loon_authored_document_gradient@L251::rel") and #E(K-doc + "defparam_makes_the_gradient_reachable_without_hand_binding@L281::rel").

== Shape through dynamics and contact

#figure(
  table(
    columns: (1.9fr, 1fr, 1fr),
    align: (left, right, right),
    table.header([*Rollout (θ = cylinder radius)*], [*dJ/dθ*], [*vs end-to-end FD*]),
    [Flywheel spin-up, $J = omega(T)$, FD on p], [#F("m8_rollout_gradient::flywheel_spinup_gradient_matches_end_to_end_fd@L203::grad", 4)], [#E("m8_rollout_gradient::flywheel_spinup_gradient_matches_end_to_end_fd@L203::rel")],
    [Gravity pendulum, $J = q(T)$, FD on p], [#F("m8_rollout_gradient::gravity_pendulum_gradient_matches_end_to_end_fd@L240::grad", 5)], [#E("m8_rollout_gradient::gravity_pendulum_gradient_matches_end_to_end_fd@L240::rel")],
    [Flywheel, adjoint], [#F("m11_adjoint_rollout::adjoint_matches_end_to_end_fd@L248::g", 4)], [#E("m11_adjoint_rollout::adjoint_matches_end_to_end_fd@L248::rel")],
    [Pendulum on body-x revolute, adjoint], [#F("m11_adjoint_rollout::adjoint_matches_end_to_end_fd@L258::g", 5)], [#E("m11_adjoint_rollout::adjoint_matches_end_to_end_fd@L258::rel")],
    [Cylinder resting on its side, contact adjoint], [#sci(V("m11_contact_gradient::contact_chain_matches_end_to_end_fd@L166::grad"), digits: 3)], [#E("m11_contact_gradient::contact_chain_matches_end_to_end_fd@L166::rel")],
  ),
  caption: [#lead[Gradients of rollouts with respect to a CAD radius]: J in rad/s, rad and m; θ in mm. The reference rebuilds the CAD at $theta plus.minus h$, re-tessellates, recomputes mass properties and re-simulates, with contact where the rollout has it. The adjoint's pendulum is the same cylinder re-expressed for the adjoint's specification (revolute about the body x axis instead of a rotated inertia), so its value differs from the first pendulum's. The adjoint agrees with the finite-difference path on $p$ to #E("m11_adjoint_rollout::adjoint_matches_fd_path@L198::rel") (flywheel) and #E("m11_adjoint_rollout::adjoint_matches_fd_path@L219::rel") (pendulum). `data/measured.tsv`.],
) <tab:physics>

The contact case is the shape-through-contact co-design problem in its smallest form. A CAD cylinder lies on its side on a vertical prismatic joint and settles onto the ground; $J$ is its settled height. Growing the radius moves the contact line down the body by exactly $d theta$, which alone would give $d J \/ d theta = 10^(-3)$ m per mm (the surface channel), and adds mass that sinks the body further into the penalty spring (the mass channel, negative). The two channels have opposite signs. The gradient, #sci(V("m11_contact_gradient::contact_chain_matches_end_to_end_fd@L166::grad"), digits: 3), is #fx(100 * (1 - V("m11_contact_gradient::contact_chain_matches_end_to_end_fd@L166::grad") / 1e-3), 1)% below the surface channel alone, and matches a rebuild-and-resimulate FD to #E("m11_contact_gradient::contact_chain_matches_end_to_end_fd@L166::rel") with no finite difference anywhere in the analytic chain. The test also asserts that doubling the density lowers the gradient, so the mass channel contributes to the result.

#figure(fig-contact(),
  caption: [#lead[Shape through contact.] A CAD cylinder (θ = radius) rests on its side on phyz's per-vertex penalty springs; $J$ is its settled height. Growing the radius raises the body through the surface channel and sinks it through the mass channel. Both factors are exact, so the chain has no finite difference in it. `data/measured.tsv`.],
) <fig:contact>

== Pixels to CAD parameters: a shared benchmark with irys <sec:irys>

The seam's reverse mode accepts any cotangent on the frozen plan's nodes, including one from a renderer. With the irys differentiable path tracer (TODO: cite the irys paper once it has an arXiv identifier) we ran a shared benchmark on a real robot part: the left shoulder-pitch output plate of the rose arm, a 3 mm rounded plate with a 49 mm bearing bore and twelve 4.4 mm bolt holes. θ is the bore diameter. The frozen plan has 4942 nodes and 9932 triangles at 32 circle segments, with a synthesized seeding. irys renders the plan's mesh as it is, without re-tessellating, against an empty background at 160 × 128, so the whole derivative comes from visibility edges; its edge sampler returns $partial cal(L) \/ partial x$ on every plan node for a fixed smooth image loss.

#figure(
  table(
    columns: (2fr, 1fr, 1fr),
    align: (left, right, right),
    table.header([*Path to dL/dθ*], [*Value*], [*vs pullback*]),
    [Seam pullback (reverse mode)], [+40.16864], [–],
    [Seam forward mode, $sum partial cal(L) \/ partial x dot dot(x)$], [+40.16864], [$1.1 times 10^(-15)$],
    [vcad FD node velocities ($h = 10^(-5)$ mm)], [+40.17028], [$4.3 times 10^(-5)$],
    [End-to-end render FD ($h = 0.1$ mm)], [+40.0144], [$3.9 times 10^(-3)$],
  ),
  caption: [#lead[Shared rose-arm benchmark], measured by the irys session at irys `103e3da` and vcad `d10f279` rose `832192f`; not regenerated by `repro.sh`. The pullback's Monte Carlo standard error over 8 edge-sampling seeds is ±0.0226. The render FD itself moves by about 0.5% between $h = 0.02$ and $0.1$ mm, so the pullback agrees with it within the FD's own error.],
) <tab:irys>

The benchmark also shows why an end-to-end finite difference through a real part is a poor reference. A true rebuild at $theta plus.minus h$ fails with `CorrespondenceLost` for $h >= 2 times 10^(-3)$ mm and with `TopologyChanged` at $0.05$ mm, because the bore rim's arc count is sag-adaptive and drops from 4942 to 4940 vertices; at $h = 5 times 10^(-4)$ mm the render FD is dominated by quadrature noise. The end-to-end check therefore moves the plan's nodes along their FD velocities rather than rebuilding. The seam has no such step-size window: its pullback is exact for the frozen mesh, and the renderer's sampling error is the only noise left.

== Cost

#figure(fig-cost(),
  caption: [#lead[Per-call cost on the filleted cube] at three blend resolutions, release build, median. Capture, one forward seam pass and one pullback are all linear in the number of mesh nodes; the pullback prices every parameter at once. `data/measured.tsv`.],
) <fig:cost>

= Discussion <sec:discussion>

*Why freeze the tessellation.* The alternative, differentiating the kernel's code, has to give some answer at every branch: which face a Boolean keeps, how a fillet orders its blends, how many segments a circle gets. Those answers are piecewise constant in $theta$, so their derivatives are zero almost everywhere and undefined at the switches, and they are entangled with the nondeterminism we observed in the Boolean and fillet code. Freezing the plan turns the discrete state into an object the seam can check. Inside the plan's topology class the derivative is exact, and outside it the seam returns an error.

*What the gradient is a gradient of.* The seam's derivative is that of the mesh vcad produces, which is the object a mesh-based simulation consumes. For mass properties at practical resolutions the gap to the continuum is small (@tab:fd); for objectives that depend on fine surface detail it may not be, and the remedy is resolution.

*Finite differences are not a reliable reference on filleted solids.* On every plane, cylinder, cone and torus gate, FD and the seam agree to $10^(-8)$ or better. On filleted solids FD at $h = 10^(-6)$ degrades to $10^(-4)$–$10^(-5)$ for some parameters (@fig:lbfgs) because a rebuild at $theta plus.minus h$ carries correspondence jitter of that order; we validated those cases by agreement between independent forward and reverse implementations and by FD with a wider step.

*From a seam to a graph.* The natural next result is the showpiece of @fig:showpiece: the rollout path of @tab:physics with the thermal branch added, through operator nodes rather than hand composition, and validated by the same rebuild-and-resimulate differences. Because the seam returns an error outside its topology class instead of a wrong value, a graph that contains it never receives a wrong gradient from it.

*Remaining gaps.* Cone-tangent-to-plane tangency rows are not implemented, because no gate model has produced one. Fillets whose corners are asymmetric or meet three blends fall back to the kernel's older pipeline. The contact model is frictionless; friction's kink at sticking would need smoothing. Running costs in the rollout objective, multi-DOF joints and state-feedback control are mechanical extensions of the adjoint recursion that nothing has needed yet.

= Reproducibility <sec:repro>

`paper/vcad/repro/repro.sh` clones vcad at commit #raw(env.at("vcad_rev")) (its lockfile pins phyz, loon and tang), applies `report.patch`, runs the gate tests listed above with `--nocapture`, and writes `data/measured.tsv`. The patch is generated by `instrument.py` and only adds `eprintln!` lines after statements that already compute a measured quantity, so each gate still asserts its own bound and the printed value is the one it checks. This document reads every measured number, table cell and plotted point from that file; rebuilding the PDF after a run updates them. The run used for this draft took place on #env.at("date") on #env.at("host").

= Conclusion

Exact parameter gradients through a production BRep kernel are attainable without making the kernel differentiable. Cutting the chain at a frozen tessellation, and differentiating only the geometric map from parameters to mesh nodes, yields derivatives that are exact for the mesh, cover the parameters designers edit (including fillet radii), compose with reverse mode, second order and L-BFGS, and carry through to rigid-body dynamics and contact. They do not cross a change of topology. The kernel reports that case as an error. In the architecture we are building, the seam is the geometry operator in a graph where vcad's physics is written once as math and tang derives the kernels and gradients for every device. vcad, including the seam, is open source.

#heading(outlined: true, numbering: none)[References]
#show bibliography: it => { show "?.": "?"; show "!.": "!"; it }
#bibliography("refs.bib", style: "nature", title: none)
