// Research post: exact parameter gradients through vcad's BRep kernel (the "differentiable seam").
// Written as the arXiv preprint that accompanies the vcad 2 launch.
// Same typography as paper/ribt; the style block below is copied from ribt.typ.
// One source, two outputs: `--features html --format html --input target=html` builds the web
// post; without the input it builds the PDF. See web/scripts/build-posts.mjs.
// Every measured value below is read from data/measured.tsv, which repro/repro.sh regenerates
// from a fresh vcad clone at the pinned commit (data/raw/env.tsv). Exceptions, stated in the text:
// figures quoted from the earlier revision d10f279, and the irys rebuild-probe thresholds.

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
  lbl((X(3) + w / 2 + 0.3, y), [∂J/∂x], fill: c-text)
  lbl((X(3) + w / 2 + 0.3, y - 0.35), [divergence theorem])
  // the adjoint, backwards
  let yb = -1.55
  line((X(3) + w / 2, yb), (X(0) + w / 2, yb), mark: (end: "stealth", fill: c-info), stroke: (paint: c-info, thickness: 0.6pt, dash: "dashed"))
  lbl(((X(0) + X(3) + w) / 2, yb - 0.3), [transposed pass: one pass of ∂J/∂x gives every dJ/dθ], fill: c-info)
  // topology wall
  lbl((X(1) + w / 2, h + 0.35), [a topology change returns an error], fill: c-fault)
})

// L-BFGS vs projected GD on the five-parameter rounded, drilled box (log J per iterate)
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
  lbl((X(8), Y(5) - 0.35), [design whose inertia is the target], anchor: "north", fill: c-ok)
  if pts.len() > 1 {
    line(..pts.map(p => (X(p.at(0)), Y(p.at(1)))), stroke: 0.4pt + c-line-hi)
  }
  let lb = ()
  let j = 0
  while ("fly::path::" + str(j)) in measured { lb.push((V("fly::path::" + str(j), i: 0), V("fly::path::" + str(j), i: 1))); j += 1 }
  if lb.len() > 1 {
    line(..lb.map(p => (X(p.at(0)), Y(p.at(1)))), stroke: 1.1pt + c-sel)
    for p in lb { circle((X(p.at(0)), Y(p.at(1))), radius: 0.06, fill: c-sel, stroke: none) }
    lbl((X(lb.last().at(0)) - 0.15, Y(lb.last().at(1)) + 0.45), [L-BFGS], anchor: "east", fill: c-sel)
    lbl((X(6.0), Y(3.2)), [projected gradient descent, faint], fill: c-label)
  }
  if pts.len() > 1 {
    circle((X(pts.first().at(0)), Y(pts.first().at(1))), radius: 0.08, fill: c-label, stroke: none)
    circle((X(pts.last().at(0)), Y(pts.last().at(1))), radius: 0.09, fill: c-sel, stroke: none)
    lbl((X(pts.first().at(0)) + 0.15, Y(pts.first().at(1)) - 0.25), [θ₀], anchor: "west")
  }
})

// the planned graph: geometry → dynamics → objective, with a thermal branch
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
  let nu = 24
  let nv = 12
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
    ([contact rollout · r], V("m11_contact_gradient::contact_chain_matches_end_to_end_fd@L167::rel"), none),
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
  lbl((X(1e-6), Y(0) + 0.55), [tolerance $10^(-6)$], fill: c-warn)
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
  lbl((x0 + 0.25, -1.0), [dV/dθ vs same-plan FD], anchor: "west")
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
  lbl((ox + 0.2, 1.85), [larger radius raises the axis: +1×10⁻³ m per mm], anchor: "west")
  lbl((ox + 0.2, 1.6), [adjoint ∂J/∂x → seam pullback], anchor: "west")
  arrow((ox + 0.0, 0.75), (ox, 0.45), col: c-info, w: 1.2pt)
  lbl((ox + 0.2, 0.7), [mass channel], anchor: "west", fill: c-info, font: mono-sb, size: s-sm)
  lbl((ox + 0.2, 0.42), [heavier, sinks into the spring: negative], anchor: "west")
  lbl((ox + 0.2, 0.17), [adjoint ∂J/∂p · seam dp/dθ], anchor: "west")
  lbl((ox, -0.9), [dJ/dθ = #sci(V("m11_contact_gradient::contact_chain_matches_end_to_end_fd@L167::grad"), digits: 3) m/mm · vs FD #E("m11_contact_gradient::contact_chain_matches_end_to_end_fd@L167::rel")], anchor: "west", fill: c-text)
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

// ---- figures for the validation experiments ------------------------------------------
// log10 helper and a generic log-log plot frame
// Typst writes negative integers with a Unicode minus; data keys use ASCII
#let ks(e) = if e < 0 { "-" + str(-e) } else { str(e) }
#let lg(x) = calc.log(calc.max(calc.abs(x), 1e-300), base: 10)
#let lmap(W, H, x0, x1, y0, y1) = (
  v => W * (lg(v) - x0) / (x1 - x0),
  v => H * (calc.max(y0, calc.min(y1, lg(v))) - y0) / (y1 - y0),
)
#let loglog-frame(W, H, x0, x1, y0, y1, xlabel, ylabel, xticks: (), yticks: ()) = {
  import cetz.draw: *
  let (X, Y) = lmap(W, H, x0, x1, y0, y1)
  for e in yticks {
    line((0, Y(calc.pow(10.0, e))), (W, Y(calc.pow(10.0, e))), stroke: 0.3pt + c-line)
    lbl((-0.12, Y(calc.pow(10.0, e))), [$10^(#str(e))$], anchor: "east")
  }
  for e in xticks { lbl((X(calc.pow(10.0, e)), -0.3), [$10^(#str(e))$]) }
  line((0, 0), (W, 0), stroke: 0.6pt + c-line-hi)
  lbl((W / 2, -0.72), xlabel)
  lbl((0, H + 0.3), ylabel, anchor: "west")
}
#let series-line(pts, col, w: 0.9pt, dash: none, dots: true) = {
  import cetz.draw: *
  if pts.len() > 1 { line(..pts, stroke: (paint: col, thickness: w, dash: dash)) }
  if dots { for p in pts { circle(p, radius: 0.05, fill: col, stroke: none) } }
}

// FD error against step size: a converged FD falls onto the seam; a wrong row would stay on a plateau
#let fig-sweep() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let W = 6.4
  let (X, Y) = lmap(W, 3.8, -8.3, -0.7, -12, -1)
  loglog-frame(W, 3.8, -8.3, -0.7, -12, -1, [finite-difference step h (mm)], [|FD − seam| / |seam|], xticks: (-8, -6, -4, -2), yticks: (-12, -9, -6, -3))
  let rel(a, b) = calc.abs(a - b) / calc.abs(b)
  let legend(k, col, label, dash: none) = {
    let y = 3.6 - k * 0.4
    line((W + 0.3, y), (W + 0.75, y), stroke: (paint: col, thickness: 1pt, dash: dash))
    lbl((W + 0.85, y), label, anchor: "west", fill: col)
  }
  let fresh(k, name, col, label) = {
    let s = V("rebuild::" + name + "::seam")
    let pts = range(-6, 0).filter(e => ("rebuild::" + name + "::fd::" + ks(e)) in measured).map(e => (X(calc.pow(10.0, e)), Y(rel(V("rebuild::" + name + "::fd::" + ks(e)), s))))
    series-line(pts, col)
    legend(k, col, label)
  }
  fresh(0, "torus_r", c-text, [torus · r, rebuild FD])
  fresh(1, "hole_r", c-label, [box − cylinder · r, rebuild FD])
  fresh(2, "fillet_r", c-vcad, [filleted cube · r, rebuild FD])
  let s3 = V("sweep::seam::3")
  let plan = range(-8, -3).filter(e => ("sweep::plan::3::" + ks(e)) in measured).map(e => (X(calc.pow(10.0, e)), Y(rel(V("sweep::plan::3::" + ks(e)), s3))))
  series-line(plan, c-warn, w: 1.2pt)
  legend(3, c-warn, [five-parameter box · fillet r, same-plan FD])
  let fr = range(-4, 0).map(e => (X(calc.pow(10.0, e)), Y(rel(V("sweep::fresh::3::" + ks(e)), s3))))
  series-line(fr, c-warn, dash: "dashed", dots: false)
  legend(4, c-warn, [five-parameter box · fillet r, rebuild FD], dash: "dashed")
})

// parameter error against wall-clock time for the same problem and line search, different oracles
#let fig-baselines() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let (X, Y) = lmap(8.0, 3.8, -1.3, 3.2, -8, 1)
  loglog-frame(8.0, 3.8, -1.3, 3.2, -8, 1, [wall-clock time (s)], [max |θ − θ\*| (mm)], xticks: (-1, 0, 1, 2, 3), yticks: (-8, -6, -4, -2, 0))
  let runs = (("lm_seam", c-vcad, [Levenberg–Marquardt · seam Jacobian], 1.4pt), ("lbfgs_seam", c-text, [L-BFGS · seam gradient], 1.1pt), ("lbfgs_fd4", c-label, [L-BFGS · rebuild FD, $h = 10^(-4)$], 0.8pt), ("lbfgs_fd6", c-line-hi, [L-BFGS · rebuild FD, $h = 10^(-6)$], 0.8pt), ("lbfgs_fd2", c-info, [L-BFGS · rebuild FD, $h = 10^(-2)$], 0.8pt))
  for (k, (name, col, label, w)) in runs.enumerate() {
    let pts = ()
    let i = 1
    while ("base::" + name + "::" + str(i)) in measured {
      let key = "base::" + name + "::" + str(i)
      pts.push((X(calc.max(V(key, i: 0) / 1000, 0.05)), Y(V(key, i: 2))))
      i += 1
    }
    if pts.len() > 1 { line(..pts, stroke: w + col) }
    lbl((8.2, 3.6 - k * 0.38), label, anchor: "west", fill: col)
    line((7.75, 3.6 - k * 0.38), (8.1, 3.6 - k * 0.38), stroke: w + col)
  }
})

// the fillet's gap to the continuum derivative against blend resolution
#let fig-gap() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let (X, Y) = lmap(6.0, 3.2, 0.8, 2.5, -4, 0)
  loglog-frame(6.0, 3.2, 0.8, 2.5, -4, 0, [circle segments N (a quarter-blend gets N / 4)], [relative gap to continuum dV/dr], xticks: (), yticks: (-4, -3, -2, -1, 0))
  for n in (8, 16, 32, 64, 128, 256) { lbl((X(n), -0.3), [#n]) }
  let c = V("gap::continuum")
  let pts = (8, 16, 32, 64, 128, 256).map(n => (X(n), Y((V("gap::" + str(n) + "::dv") - c) / c)))
  // N^-2 guide through the N = 64 point
  let g64 = (V("gap::64::dv") - c) / c
  line((X(8), Y(g64 * 64.0 * 64.0 / 64.0)), (X(256), Y(g64 * 64.0 * 64.0 / (256.0 * 256.0))), stroke: (paint: c-label, thickness: 0.5pt, dash: "dashed"))
  lbl((X(200), Y(g64 * 64.0 * 64.0 / (200.0 * 200.0)) + 0.3), [$N^(-2)$], fill: c-label)
  series-line(pts, c-vcad, w: 1.1pt)
  lbl((X(16) + 0.2, Y((V("gap::16::dv") - c) / c) + 0.15), [16, the resolution used above], anchor: "west", fill: c-vcad)
})

// a large torus for the title page
#let fig-torus-hero() = cetz.canvas(length: 2.2cm, { torus-panel(0, "R", [], []) })

// ---- title page -----------------------------------------------------------------
#if not web {page(margin: (x: 0.75in, top: 0.7in, bottom: 0.65in))[
  #set par(leading: 0.5em)
  #grid(columns: (auto, 1fr, auto), column-gutter: 0.8em, align: horizon,
    caps(fill: c-text)[Municipal Robotics · Research],
    line(length: 100%, stroke: 0.5pt + c-line-hi),
    caps[November 2026])
  #v(1.6em)
  #image("images/muni-logo.svg", width: 0.95in)
  #v(0.5in)
  #align(center, fig-torus-hero())
  #v(0.1in)
  #grid(columns: (1fr, auto), align: (left, right),
    caps[torus R = 8, r = 3 · design velocity of the major radius on its own mesh],
    caps(fill: c-sel)[red: outward · pale: inward])
  #v(1fr)
  #move(dx: -0.045 * s-display, text(font: sans-sb, size: s-display, tracking: -0.02em)[Exact Gradients\ Through a BRep Kernel])
  #v(0.5em)
  #line(length: 22%, stroke: 2pt + c-label)
  #v(0.7em)
  #text(size: s-lg, fill: c-label)[Differentiating CAD parameters through tessellation, fillets, mass properties and contact]
  #v(0.5in)
  #caps[Cam Pedersen · Municipal Robotics]
]}

// time and iterations for an optimizer run to first reach a parameter error below tol
#let ttt(name, tol) = {
  let i = 0
  let hit = none
  while ("base::" + name + "::" + str(i)) in measured {
    let k = "base::" + name + "::" + str(i)
    if V(k, i: 2) < tol { hit = (i, V(k, i: 0) / 1000); break }
    i += 1
  }
  hit
}
#let ttt-cell(name, tol) = { let h = ttt(name, tol); if h == none [not reached] else [#h.at(0) it · #fx(h.at(1), 1) s] }
#let relc(a, b) = sci(calc.abs(a - b) / calc.abs(b))

#let abstract-text = [
  Gradient-based design needs the derivative of an objective with respect to the parameters a designer edits, such as a hole radius or a fillet radius. In a boundary-representation (BRep) kernel those parameters pass through Boolean operations, filleting and tessellation, which make discrete choices. We freeze the tessellation's topology at the current parameters and differentiate its node positions: surface nodes by evaluating the kernel's analytic surfaces on dual numbers, vertices and trim nodes by implicit differentiation of the surface equations, with tangency rows for fillet blends. The result is exact for the frozen mesh, extends to directional second derivatives and to a transposed (reverse) pass, and feeds mass properties and a rigid-body adjoint with penalty contact. A change of topology is reported as an error.

  We validate against finite differences of the frozen plan and of fresh rebuilds that share no tessellation with the seam, and state where the method falls short: the derivative of the frozen mesh differs from the continuum by the polygonization error (#fx(100 * calc.abs((V("gap::16::dv") - V("gap::continuum")) / V("gap::continuum")), 1)% for a fillet at 16 segments per circle, #fx(100 * calc.abs((V("gap::128::dv") - V("gap::continuum")) / V("gap::continuum")), 2)% at 128), a plan stays valid for parameter steps of at least #sci(V("radius::0::h")) mm, and the same-plan checks found two errors in the seam on filleted, drilled parts, which we describe and have fixed.
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

A mechanical designer works in parameters: the depth of a pocket, the radius of a bore, the radius of a fillet. An optimizer that serves that designer needs $d J \/ d theta$, the derivative of an objective $J$ (a mass, an inertia, the outcome of a simulation) with respect to those parameters. Between $theta$ and anything measurable sit Boolean operations, fillet construction and tessellation, each of which makes discrete decisions: which faces survive a Boolean, in which order they are sewn, how many segments approximate a circle. Commercial kernels do not generally expose parameter derivatives to the user, so designers typically fall back on finite differences of full rebuilds, at two rebuilds per parameter.

This is not a new problem, and our approach is not new in outline. Engineering Sketch Pad computes *tessellation sensitivities* on a parametric BRep: the motion of every grid point with respect to every design parameter, on a tessellation whose topology is kept consistent between the base and perturbed models, with sensitivities found on Nodes, then Edges, then Faces @dannenhoffer2015sensitivity @dannenhoffer2017adjoint. Those sensitivities are analytic for most construction operations and fall back to finite differences for others, filleting among them @dannenhoffer2015sensitivity. Banović et al. differentiate the Open CASCADE kernel itself by operator overloading @banovic2018occt @mykhaskiv2017nurbs; algorithmic differentiation of that kind reaches every operation the kernel performs, fillets included, and can be nested for second derivatives, at the cost of differentiating the kernel's combinatorial code and taping its execution.

We describe the same idea, which we call the *seam*, in vcad, our open-source Rust BRep kernel, and extend it in four directions. None is new to differentiation in general; what is new is having them in a frozen-tessellation method that leaves the kernel undifferentiated:

- *Analytic fillet sensitivities without AD or FD.* Where Engineering Sketch Pad falls back to finite differences for fillets, a fillet radius moves every blend's radius and axis at once, and its blends meet their support faces tangentially, which makes the implicit system at their corner vertices rank-deficient. We add tangency rows that complete it (@sec:implicit), so one fillet parameter, moving 20 surfaces, is differentiated without finite differences.
- *Second order on the frozen plan.* Directional second derivatives of mass properties, with the node accelerations of cones and tori (@sec:qoi).
- *A transposed pass.* Node velocities are linear in per-surface seed values; transposing those maps gives the derivative for every parameter from one pass (@sec:reverse).
- *Rigid-body dynamics.* Mass-property and contact cotangents from a discrete trajectory adjoint pulled back through the seam (@sec:physics).

We validate the derivatives against central finite differences of the frozen plan and, wherever a rebuild keeps its topology, of rebuilds tessellated from scratch, which share nothing with the seam's code (@sec:results); the exceptions are listed there. We describe the two cases where the checks found errors in the seam. A script regenerates every measured value in this paper from a fresh clone (@sec:repro).

== Scope and limits <sec:limits>

- *The derivative is that of the frozen mesh.* The seam differentiates the mesh the kernel produces at $theta_0$, with segment counts and triangulation held fixed. It differs from the continuum shape derivative by the polygonization error, which falls as $N^(-2)$ in the number of segments: for a filleted cube at 16 segments per full circle (four per quarter-blend) the fillet-radius derivative is #fx(100 * calc.abs((V("gap::16::dv") - V("gap::continuum")) / V("gap::continuum")), 1)% larger in magnitude than the continuum one, and #fx(100 * calc.abs((V("gap::128::dv") - V("gap::continuum")) / V("gap::continuum")), 2)% at 128 (@fig:gap).
- *A plan is valid only near where it was captured.* Re-evaluating a plan matches every node to its capture-time position within $10^(-3)$ mm. On the five-parameter box of @sec:box, every parameter can move by at least #sci(V("radius::0::h")) mm, the largest step of our logarithmic grid that kept correspondence; the next grid point, $10^(-3)$ mm, lost it. The optimizer therefore captures a fresh plan at every iterate.
- *Segment counts can change between iterates.* vcad's Boolean rims are sag-adaptive: their arc count depends on the radius. Sweeping the box's hole radius from 1.6 to 2.4 mm changes the node count #V("sag::changes") times, and each change moves the volume by up to #sci(V("sag::max_jump_rel")) of its value. Across iterates $J$ is therefore piecewise smooth with small jumps. The optimizer does not reject a step because its node count differs from the last iterate's, because each iterate's gradient is taken on its own plan; the jumps show up as noise in the line search.
- *No derivatives across topology changes.* When a perturbation would change the topology (a blind hole breaking through, a fillet consuming a face), the seam detects it with a topology signature and per-node correspondence checks and returns an error, and the optimizer shrinks the step (@fig:wall).
- *Seedings synthesized from the build function are not exact.* They are central differences of surface fields, accurate to $O(h^2)$, and they cost two rebuilds per parameter (@sec:synth).
- *Contact is phyz's differentiable penalty model*, a per-vertex spring–damper against a ground plane without friction, not a GJK/EPA collision pipeline @gilbert1988gjk. The trajectory adjoint supports single-degree-of-freedom joints, open-loop control and objectives on the final state only.
- *Everything runs on CPU in double precision.*

#figure(fig-wall(),
  caption: [#lead[What the gradient is a gradient of.] Within one topology class the frozen plan's volume is smooth in the parameter and the seam returns its derivative (red tangent). When a blind hole breaks through, the plan's topology signature changes and the seam returns an error; an optimizer treats that as a failed step and shrinks it. Schematic.],
) <fig:wall>

= Background and related work

*Parametric CAD sensitivities.* Structural shape optimization has long used design velocities, the sensitivity of boundary points to design variables @haftka1986shape @sokolowski1992shape. For CAD models these come from three routes. Finite differences of rebuilds with point correspondence are the most general and the most expensive; Robinson et al. and Agarwal et al. compute parametric design velocities this way for use with adjoint solvers @robinson2012adjoint @agarwal2018designvelocity. Differentiating the kernel by operator overloading gives exact derivatives of the kernel's operations: Banović et al. and Mykhaskiv et al. differentiate Open CASCADE and couple it to a discrete adjoint CFD solver @banovic2018occt @mykhaskiv2017nurbs, and Xu et al. differentiate a NURBS-based design chain @xu2014adjoint. Engineering Sketch Pad differentiates its own constructive solid geometry process analytically where it can and uses finite differences elsewhere, and maps the result onto a consistent tessellation @dannenhoffer2015sensitivity @dannenhoffer2017adjoint. Our seam is closest to Engineering Sketch Pad: we leave the kernel's combinatorial code undifferentiated and differentiate the map from parameters to a tessellation of fixed topology. Within that frozen-tessellation approach we add analytic fillet sensitivities, second derivatives, a transposed pass, and the coupling to rigid-body dynamics with contact; operator-overloading AD of a kernel can supply fillet and second derivatives too, by differentiating the kernel's own code. Isogeometric analysis avoids the tessellation by computing on the CAD basis @hughes2005iga.

*Differentiable CAD programs.* Cascaval et al. write CAD programs in an automatically differentiable language for bidirectional editing, and do not optimize across changes of topology @cascaval2022bidirectional. Michel and Boubekeur compute parameter updates for direct manipulation of procedural shapes @michel2021dag. Schulz et al. precompute a design space of CAD parameters for interactive optimization @schulz2017designspace.

*Differentiable rendering and other representations.* Differentiable rasterizers @kato2018nmr @liu2019softras and path tracers @li2018edge compute derivatives of images with respect to the vertices of a mesh of fixed connectivity, as ours is. Worchel and Alexa extract a mesh from parametric curves and surfaces for a differentiable mesh renderer and report that naive differentiable tessellation is fragile @worchel2023parametric. Signed distance fields, learned @park2019deepsdf or analytic, are differentiable almost everywhere and can be rendered differentiably @vicini2022sdf, and program synthesis recovers CSG trees from shapes @sharma2018csgnet @du2018inversecsg. These representations give up the BRep's exact faces, trims and fillets.

*Differentiable physics and co-design.* Differentiable simulators include rigid-body formulations with contact @belbute2018diffphys @geilinger2020add @werling2021nimble and differentiable programming systems @hu2020difftaichi. Robot co-design work optimizes morphology and control jointly @ha2017joint @xu2021codesign, usually over parametric primitives rather than CAD models. Placing a solver or a simulation inside a differentiable program as one step with a known adjoint is standard @blondel2022implicit; our rollout coupling is such a step written by hand.

= The differentiable seam <sec:seam>

#figure(fig-seam(),
  caption: [#lead[Where the chain is cut.] The BRep build is never differentiated. At the current parameters a frozen plan records the tessellation; node velocities $d x \/ d theta$ come from the kernel's analytic surfaces. Downstream quantities differentiate as smooth functions of node positions, and the transposed pass runs the same maps backwards.],
) <fig:seam>

== Frozen plans

vcad represents solids as BReps whose faces carry analytic surfaces (plane, cylinder, cone, sphere, torus, bilinear patch, B-spline), with Boolean operations, filleting and a tessellator. Two properties of the kernel shaped the design. First, its Boolean and fillet code is order-nondeterministic: two builds of the same model can enumerate isomorphic topology in different orders, flip a blend cylinder's axis or rotate its reference direction, so traversal order cannot carry node identity from one build to another. Second, the stock mesh stores 32-bit positions, at which a central difference with $h = 10^(-6)$ is meaningless, so the seam emits its own 64-bit mesh.

Capturing a plan tessellates once at $theta_0$ and classifies every node:

- *Vertex nodes* coincide with a topology vertex. Their velocity comes from implicit differentiation (@sec:implicit).
- *Surface nodes* are interior to a face, stored as fixed surface coordinates $(u, v)$. Their position is $S(u, v; phi(theta))$ for the surface's fields $phi$ (offset, radius, axis, half-angle).
- *Trim nodes* lie on the intersection of two faces with non-parallel normals but are not topology vertices, for example a ring on a cylinder's cap. Their position is the Newton solution of ${g_a (x) = 0, g_b (x) = 0, t dot (x - x_0) = 0}$, with $t$ the intersection tangent, so a trim node follows the moving trim whichever surface carries $theta$.

A plan carries a topology signature (a sorted multiset of per-face descriptors, invariant to isomorphic reordering) and each node's capture-time position. Re-evaluating at a nearby $theta$ resolves vertices and faces geometrically, by nearest match after transporting the stored $(u, v)$ through the rebuilt surface's frame. If any node lands more than $10^(-3)$ mm from where it should, evaluation fails with a lost-correspondence error; if the signature changes, it fails with a topology error.

#figure(fig-recipes(),
  caption: [#lead[Node recipes on a Boolean result.] Left: the top cap of a plate minus a cylinder, θ = hole radius. Rim vertices are topology vertices; their velocity comes from the implicit rows and is radial. Plane-interior samples lie on a surface that does not move and have zero velocity. Right: the rows at one rim vertex. The cap plane and the hole wall give two independent rows; the tangent direction is unconstrained and stays frozen, so the rim keeps its angular parameter.],
) <fig:recipes>

== Surface nodes

Every analytic surface in vcad is generic over a scalar type, so it can be evaluated on dual numbers $a + b epsilon$ with $epsilon^2 = 0$ @griewank2008. A parameter is connected to the surfaces it moves by a *seeding*: a map from surface index to field velocities (translate by $bold(v)$, grow the radius at rate $dot(r)$, open the cone at rate $dot(alpha)$). Seeds on one surface add, which is what a fillet needs: when the fillet radius grows, each blend cylinder's radius grows at rate 1 while its axis retreats from the edge, and each corner sphere does the same in three coordinates. For a surface node, the dual part of $S(u, v; phi + dot(phi) epsilon)$ is $d x \/ d theta$.

== Vertices and trims <sec:implicit>

A topology vertex lies on every surface incident to it. Each incident surface has an implicit form $g(x; phi) = 0$: for a plane $n dot (x - o)$, a cylinder $norm(x_perp)^2 - r^2$, a sphere $norm(x - c)^2 - r^2$, and for a cone with apex $a$, axis $d$ and half-angle $alpha$,
$ g = norm(x_perp)^2 - tan^2 alpha ((x - a) dot d)^2 . $
Differentiating $g(x(theta); phi(theta)) = 0$ gives one linear row per surface,
$ nabla g dot dot(x) = - (partial g) / (partial theta) . $
We solve the rows by Gram–Schmidt, carrying the right-hand side. Independent rows fix components of $dot(x)$, dependent rows must agree within tolerance (otherwise the solve fails), and directions no row constrains stay at zero, so a node on a circular rim keeps its angular parameter. Three planes at a box corner give a full $3 times 3$ solve; a plane and a cylinder at a hole rim give a rank-2 solve with a frozen tangent.

Two refinements were needed. Boolean sewing does not always pair the half-edges around a rim, so topological adjacency under-constrains some vertices, and the seam also collects rows by geometric incidence. And a fillet blend touches its support face tangentially, so the blend's row is parallel to the plane's and the system is rank-deficient exactly where the corner vertex slides along the face. The vertex must stay on the tangent curve; for a cylinder of axis $a$ tangent to a plane of normal $n$ we add the row $q dot dot(x) = q dot dot(bold(v))_"translate"$ with $q = a times n$. A sphere tangent to a plane has no axis; there the two rows use any two unit vectors $q_1, q_2$ orthogonal to $n$, which pins the tangent point's slide in both directions to the sphere's translation. With these rows the corner vertex of a filleted cube at $(r, r, L)$ moves at $(1, 1, 0)$ per unit radius, as the closed form requires.

#figure(fig-fillet(),
  caption: [#lead[A fillet radius is a composite seed.] A section through the blend on the edge at $(L, L)$. Growing the radius by δ grows the blend cylinder's radius at rate 1 while its axis retreats at $(-1, -1)$; the two motions compose so that the tangent lines slide along the support faces at unit rate. (On the opposite edge, at the origin, every sign flips, which is the $(1, 1, 0)$ of the text.) On the filleted cube one parameter moves 20 surfaces.],
) <fig:fillet>

= Quantities of interest <sec:qoi>

== Mass properties

Volume, mass, centroid and inertia tensor follow from signed-tetrahedron integrals over the closed mesh @mirtich1996mass. The integrals are written once over a generic scalar, so evaluating them at dual-number node positions gives every quantity and its derivative along $theta$ in one pass. A downstream functional enters through the contraction
$ (d J) / (d theta) = sum_i (partial J) / (partial x_i) dot (d x_i) / (d theta) , $
with $partial V \/ partial x_i$ known in closed form from the divergence theorem.

== Second order

For one direction in parameter space,
$ (d^2 V) / (d theta^2) = sum_(i j) (partial^2 V) / (partial x_i partial x_j) dot(x)_i dot(x)_j + sum_i (partial V) / (partial x_i) dot.double(x)_i . $
Evaluating the volume integral on nested duals $((x, dot(x)), (dot(x), dot.double(x)))$ carries both terms; the work is in the node accelerations $dot.double(x)$. A surface node on a plane, cylinder or sphere is linear in its fields, so its acceleration is the first-order lift fed the field accelerations. Cone and torus points are not linear in their fields ($tan alpha$, the two torus radii), so their surface nodes are lifted on nested duals. Vertex and trim nodes solve the implicit system differentiated twice,
$ nabla g dot dot.double(x) = - ( (partial^2 g) / (partial theta^2) + 2 dot(x)^top nabla_x (partial g) / (partial theta) + dot(x)^top nabla^2 g space dot(x) ) , $
with the same row gradients as the first-order solve; cones and tori contribute closed-form curvature terms because their $nabla^2 g$ is not constant. For least-squares objectives $J = sum_q r_q^2$ we also form the Gauss–Newton Hessian $2 J_r^top J_r$, which drops the residual-curvature term and is exact at zero residual.

#figure(fig-torus(),
  caption: [#lead[The torus's two design velocities] on its own mesh, front half. Growing the minor radius moves every node along the tube normal. Growing the major radius moves every node away from the axis, so the wall moves outward on the outer equator and inward on the inner one, so the outward and inward motions largely cancel and $d V \/ d R$ is the smaller derivative (continuum $2 pi^2 r^2$ against $4 pi^2 R r$, a ratio $r \/ 2 R$). Values are the seam's, on the 24-segment mesh, about 2% below these continuum forms by the polygonization gap of @sec:gap of a torus with $R = 8$, $r = 3$ mm.],
) <fig:torus>

= The transposed pass and optimization <sec:reverse>

A seeding $sigma_k$ assigns to each surface $s$ a vector of seed values: a translation in $RR^3$ and one rate per scalar field of that surface's kind. Each node's velocity is linear in the seed values of the surfaces that determine it: $dot(x)_i = sum_s A_(i s) sigma_k (s)$, where $A_(i s)$ is the Jacobian of node $i$'s recipe with respect to surface $s$'s fields at the frozen plan. The transposed pass contracts the transposes with $partial J \/ partial x$:
$ c_s = sum_i A_(i s)^top (partial J) / (partial x_i), quad (d J) / (d theta_k) = sum_s chevron.l c_s, sigma_k (s) chevron.r . $
One pass computes every per-surface cotangent $c_s$; each parameter then costs a few dot products. No tape is recorded. The transposed vertex solve runs the same Gram–Schmidt elimination, carrying each coefficient as a linear functional of the rows, and each row's dependence on its seeds is read off by calling the forward row constructor with unit seeds. Forward and transposed passes therefore share the rows: their agreement checks the linear algebra, not the rows.

The optimizer is L-BFGS with memory 8 @liu1989lbfgs, box projection and an Armijo line search on the projected step. Each iterate rebuilds the part and captures a fresh plan. A trial step that fails with a topology or correspondence error counts as a failed step. A curvature pair is dropped when $s dot y <= 10^(-12) norm(s) norm(y)$ or when its line search had to shrink past such an error, and a direction that is not a descent direction clears the memory.

= Seeding synthesis and documents <sec:synth>

Writing a seeding by hand is error-prone on real parts. Synthesis derives it from the build function: it rebuilds at $theta plus.minus h$ ($h = 10^(-4)$ in the units of the parameter in every result below), matches each base surface to its counterparts by frame-invariant geometric identity (a plane by its normal up to sign and its offset, a cylinder by its axis line and radius, a sphere by center and radius), and reads field velocities off central differences of the matched fields. Surface fields have no combinatorial structure, so the difference is accurate to $O(h^2)$, but the seeding, and every gradient computed with it, carries that error. It also costs two rebuilds per parameter: on the five-parameter box, synthesizing all five seedings takes #F("cost::synthesize_all", 0) ms, slightly more than a finite-difference gradient of the whole objective (#F("cost::fd_gradient", 0) ms). Synthesis pays off only when a seeding is reused across many evaluations at one $theta$; deriving seedings symbolically from the feature tree would remove both costs and is not implemented.

A named parameter of a `.vcad` document is differentiated the same way: the parameter is bound, the document is evaluated to one BRep per part, the seeding is synthesized, and each solid part returns $d(V, m, c, I) \/ d theta$. Evaluations at $theta plus.minus h$ must produce the same number of parts, or the call fails.

= Gradients through rigid-body rollouts <sec:physics>

In a rollout of an articulated rigid-body system without contact, the geometry of body $b$ enters the dynamics only through its ten mass-property scalars $p_b = (m, c, I)$. With contact, it also enters through the positions of the vertices that touch. The chain rule is
$ (d J) / (d theta) = sum_b (partial J) / (partial p_b) dot (d p_b) / (d theta) + sum_b sum_s chevron.l c_s^((b)), sigma_k (s) chevron.r , quad c_s^((b)) = sum_i A_(i s)^top (partial J) / (partial x_i^((b))) . $
$partial J \/ partial p_b$ comes from a discrete adjoint over semi-implicit Euler in the phyz simulator, written over Featherstone's articulated-body algorithm @featherstone2008; its within-step Jacobian columns are evaluated on dual numbers, one lane per column. $d p_b \/ d theta$ is the seam's mass-property derivative. For contact, phyz applies a penalty force $f_z = max(0, k delta - c v_z)$ at every vertex of the body's frozen-plan mesh that lies below the ground, its adjoint returns $partial J \/ partial x$ on those vertices, and the transposed pass turns that into $d J \/ d theta$. A rollout the adjoint cannot express (state feedback, multi-DOF joints) falls back to central differences on the ten scalars, which needs about twenty re-simulations per body and no CAD rebuild.

= Results <sec:results>

All results come from vcad's test suite at commit #raw(env.at("vcad_rev").slice(0, 10)) and from the experiments in `repro/` (@sec:repro), run in the release profile on one thread of a #env.at("cpu") (#env.at("rustc")). Each test asserts a tolerance, $10^(-6)$ for most first-order checks; the values below are what the tests measured. We use two finite-difference references. *Same-plan FD* rebuilds the part at $theta plus.minus h$ and re-evaluates the frozen plan captured at $theta_0$; it checks the seam's derivative of its own plan evaluator. *Rebuild FD* tessellates each rebuild from scratch and shares no code with the seam beyond the kernel itself; it is the independent check, but it is noisy at small $h$, where node placements differ between rebuilds, and it carries truncation error at large $h$. Relative errors are $|a - b| \/ |b|$, with $b$ the seam's value (or the closed form, where one is named). Rebuild FD is not possible for the irys benchmark (@sec:irys), and the cone's second derivative is checked against its closed form only.

== Validation against finite differences

The models are: an extruded $4 times 3$ mm rectangle, depth $d = 2$ mm; a $10 times 8 times 5$ mm box minus a through-hole of radius $r = 2.5$ mm (32 circle segments requested; the Boolean's sag-adaptive rim refines the hole to 112); a cylinder of radius 5 mm and height 8 mm (24 segments); a 10 mm cube with every edge filleted at $r = 1.5$ mm (16 segments per full circle, #V("gap::16::nodes") nodes); a cone frustum with base radius 5, top radius 3 and height 8 mm (apex at 20 mm, 24 segments), parameterized by half-angle and by height; and a torus with $R = 8$, $r = 3$ mm (24 segments).

#figure(
  table(
    columns: (1.4fr, 0.7fr, 0.95fr, 0.8fr, 0.8fr, 0.85fr),
    align: (left, left, right, right, right, right),
    table.header([*Model*], [*θ*], [*dV/dθ (seam)*], [*same-plan FD*], [*node-wise*], [*rebuild FD, $h = 10^(-2)$*]),
    [Extrusion], [depth], [#F(K-m0 + "@L80::dv", 3)], [#E(K-m0 + "@L80::rel_fd")], [#E(K-m0 + "::cmp.max_rel_err")], [#relc(V("rebuild::extrude::fd::-2"), V("rebuild::extrude::seam"))],
    [Box − cylinder], [hole r], [#F(K-m2 + "@L119::dv", 3)], [#E(K-m2 + "@L119::rel_fd")], [#E("m2_boolean_hole::m2_rim_nodes_implicit_diff_matches_fd::cmp.max_rel_err")], [#relc(V("rebuild::hole_r::fd::-3"), V("rebuild::hole_r::seam"))#super[a]],
    [Cylinder], [height], [#F(K-m3b + "@L118::dv", 3)], [#E(K-m3b + "@L118::rel_fd")], [#E(K-m3b + "::cmp.max_rel_err")], [#relc(V("rebuild::cyl_h::fd::-2"), V("rebuild::cyl_h::seam"))],
    [Filleted cube], [fillet r], [#F(K-m4 + "@L195::dv", 3)], [#E(K-m4 + "@L132::rel_fd")], [#E(K-m4 + "::cmp.max_rel_err")], [#relc(V("rebuild::fillet_r::fd::-2"), V("rebuild::fillet_r::seam"))],
    [Filleted cube], [edge a], [#F(K-m5 + "@L311::dv_da_rev", 3)], [#E(K-m5 + "@L311::rel_a")], [–], [#relc(V("rebuild::fillet_a::fd::-2"), V("rebuild::fillet_a::seam"))],
    [Cone frustum], [half-angle], [#F(K-m7a + "@L163::dv", 2)], [#E(K-m7a + "@L163::rel_fd")], [#E(K-m7a + "::cmp.max_rel_err")], [#relc(V("rebuild::cone_a::fd::-5"), V("rebuild::cone_a::seam"))#super[b]],
    [Cone frustum], [height], [#F(K-m7h + "@L208::dv", 3)], [#E(K-m7h + "@L208::rel_fd")], [#E(K-m7h + "::cmp.max_rel_err")], [#relc(V("rebuild::cone_h::fd::-4"), V("rebuild::cone_h::seam"))#super[b]],
    [Torus], [minor r], [#F("m7_cone_torus::torus_gate@L269::torus minor r::dv", 2)], [#E("m7_cone_torus::torus_gate@L269::torus minor r::rel_fd")], [#E("m7_cone_torus::torus_gate::torus minor r::cmp.max_rel_err")], [#relc(V("rebuild::torus_r::fd::-2"), V("rebuild::torus_r::seam"))],
    [Torus], [major R], [#F("m7_cone_torus::torus_gate@L269::torus major R::dv", 2)], [#E("m7_cone_torus::torus_gate@L269::torus major R::rel_fd")], [#E("m7_cone_torus::torus_gate::torus major R::cmp.max_rel_err")], [#relc(V("rebuild::torus_R::fd::-2"), V("rebuild::torus_R::seam"))],
  ),
  caption: [#lead[First-order volume gradients.] Same-plan FD uses $h = 10^(-6)$. Node-wise is the worst relative error of $d x_i \/ d theta$ over all mesh nodes against same-plan FD. Rebuild FD compares against the seam with a synthesized seeding, so that column mixes the seeding's $O(h^2)$ synthesis error with the FD's own error; #super[a] $h = 10^(-3)$, because the hole's sag-adaptive rim changes its segment count between $r plus.minus 10^(-2)$; #super[b] $h = 10^(-5)$ and $10^(-4)$, below the cone's truncation error. @fig:sweep shows every step size. `data/measured.tsv`.],
) <tab:fd>

Every model passes both checks, and the rebuild FD, which is independent of the seam, confirms the same-plan results to the accuracy its noise and truncation allow. Where a discrete closed form exists the seam meets it to rounding: the hole's mesh cross-section is the inscribed 112-gon, so $d V \/ d r = -N sin(2 pi \/ N) r t$, met to #E(K-m2 + "@L111::rel_closed"); the cone's half-angle derivative meets the prismatoid volume $V = (h k \/ 3)(R_b^2 + R_t^2 + R_b R_t)$ with $k = N sin(2 pi \/ N) \/ 2$ to #E(K-m7a + "@L156::rel_closed"); the cylinder-height derivative meets the N-gon cap area to #E(K-m3b + "@L112::rel_closed"); and the extrusion's $d V \/ d d$ is exactly the cross-section area. The mass-property derivatives behave the same way: $d I_(z z) \/ d d$ of the extrusion meets its closed form to #E("m3_mass_properties::extrude_inertia_derivative_matches_closed_form_and_fd@L63::rel"), and the cylinder's inertia derivative with respect to radius meets same-plan FD to #E(K-m3m + "@L129::rel").

#figure(fig-ladder(),
  caption: [#lead[Every first-order check on one axis.] Filled: the seam's $d V \/ d theta$ against same-plan FD, except two rows: the contact rollout's $d J \/ d theta$ is against rebuild-and-resimulate FD, and the filleted cube's edge $a$ is the transposed pass against the forward reference. Open: the worst node-wise $d x \/ d theta$. All are below the $10^(-6)$ tolerance; the cone-height node-wise error (#E(K-m7h + "::cmp.max_rel_err")) and the contact rollout (#E("m11_contact_gradient::contact_chain_matches_end_to_end_fd@L167::rel")) are less than an order below it, the first because the cap-rim nodes ride a sloped ruling and their FD difference is small, the second because its reference re-simulates a penalty contact. `data/measured.tsv`.],
) <fig:ladder>

#figure(fig-sweep(),
  caption: [#lead[Finite-difference error against step size.] Solid lines: rebuild FD for three models of @tab:fd. Each falls until the rebuilds' node placements stop agreeing (left) or truncation takes over (right), and at its best step it meets the seam. Yellow: same-plan FD of the fillet-radius component of the five-parameter box's objective, which has no rebuild noise and falls to roundoff; the dashed yellow line is rebuild FD for the same component. In an earlier kernel revision the yellow line stayed flat at about $10^(-4)$ across these steps, which is how a seam error was found (@sec:box). `data/measured.tsv`.],
) <fig:sweep>

== The polygonization gap <sec:gap>

The seam's derivative is that of the mesh, so it differs from the continuum derivative by the polygonization error. For the hole that error is the factor $sin x \/ x$ with $x = 2 pi \/ N$, #E(K-m2 + "@L129::gap") at 112 segments. For the filleted cube it is larger, and larger in magnitude than the continuum value, because an inscribed polygon removes more material than the circular blend and removes it faster as $r$ grows. At 16 segments per full circle (four per quarter-blend) the seam's $d V \/ d r = #F("gap::16::dv", 3)$ against the continuum #F("gap::continuum", 3), a gap of #fx(100 * calc.abs((V("gap::16::dv") - V("gap::continuum")) / V("gap::continuum")), 1)%; the gap falls as $N^(-2)$ (@fig:gap). Mass properties at four segments per quarter-blend are a coarse model of a filleted part, and the remedy is resolution, not a different derivative.

#figure(fig-gap(),
  caption: [#lead[The fillet's polygonization gap.] Relative difference between the seam's $d V \/ d r$ on the filleted cube and the continuum derivative of $V(r) = a^3 + 6 a^2 r + 3 pi a r^2 + 4 pi r^3 \/ 3$, $a = L - 2 r$, against the circle segment count. The dashed line is $N^(-2)$. At 128 segments the gap is #fx(100 * calc.abs((V("gap::128::dv") - V("gap::continuum")) / V("gap::continuum")), 2)%. `data/measured.tsv`.],
) <fig:gap>

== Transposed pass, synthesis and second order

#figure(
  table(
    columns: (2.2fr, 1fr, 1fr),
    align: (left, right, right),
    table.header([*Check*], [*Seam value*], [*Rel. difference*]),
    [Transposed vs forward, hole dV/dr], [#F("m5_reverse_mode::agree::hole dV/dr::rev", 4)], [#relc(V("m5_reverse_mode::agree::hole dV/dr::rev"), V("m5_reverse_mode::agree::hole dV/dr::fwd"))],
    [Transposed vs forward, fillet dV/dr], [#F("m5_reverse_mode::agree::rounded cube dV/dr::rev", 4)], [#relc(V("m5_reverse_mode::agree::rounded cube dV/dr::rev"), V("m5_reverse_mode::agree::rounded cube dV/dr::fwd"))],
    [Synthesized vs hand seeding, fillet dV/dr], [#F(K-m6 + "::dv_dr_syn", 4)], [#E(K-m6 + "::rel_dv_dr_syn_vs_dv_dr_hand")],
    [Synthesized vs hand seeding, edge dV/da], [#F(K-m6 + "::dv_da_syn", 3)], [#E(K-m6 + "::rel_dv_da_syn_vs_dv_da_hand")],
    [Synthesized, torus vs same-plan FD], [#F("m6_synthesized_seeding::cone_and_torus_parameters_synthesized::dv", 2)], [#E("m6_synthesized_seeding::cone_and_torus_parameters_synthesized::rel_dv_vs_fd")],
    [d²V/dr², hole vs closed form], [#F(K-m10 + "m10_hole_second_derivative_matches_closed_form_and_fd@L140::ddv", 3)], [#E(K-m10 + "m10_hole_second_derivative_matches_closed_form_and_fd@L132::rel_closed")],
    [d²V/dα², cone vs closed form], [#F(K-m10 + "m10_cone_half_angle_second_derivative_matches_closed_form@L370::ddv", 1)], [#E(K-m10 + "m10_cone_half_angle_second_derivative_matches_closed_form@L355::rel")],
    [d²V/dr², torus minor vs rebuild FD of dV/dr, $h = 10^(-1)$], [#F(K-m10 + "m10_torus_minor_radius_second_derivative@L444::ddv", 3)], [#relc(V("second::torus::-1"), V(K-m10 + "m10_torus_minor_radius_second_derivative@L444::ddv"))],
    [d²V/dθ², torus with r = θ² vs chain rule], [#F(K-m10 + "m10_torus_nonlinear_field_chain_rule@L505::ddv_dthth", 1)], [#E(K-m10 + "m10_torus_nonlinear_field_chain_rule@L505::rel2")],
    [d²V/dr², filleted cube vs rebuild FD of dV/dr, $h = 10^(-1)$], [#F(K-m10 + "m10_rounded_cube_second_derivative_matches_fd@L284::ddv", 3)], [#relc(V("second::fillet::-1"), V(K-m10 + "m10_rounded_cube_second_derivative_matches_fd@L284::ddv"))],
    [Gauss–Newton vs full Hessian (Frobenius)], [–], [#E(K-m10 + "m10_gauss_newton_hessian_matches_full_hessian_near_optimum@L839::rel_frob")],
  ),
  caption: [#lead[Transposed pass, synthesized seedings and second derivatives.] The transposed and forward passes share their rows, so their agreement checks the linear algebra only. Synthesized seedings carry the $O(h^2)$ error of the field differences. Second derivatives are checked against central differences of the seam's own first derivative on fresh rebuilds, at the step where that difference has converged. The Gauss–Newton comparison is on the five-parameter box near its optimum. `data/measured.tsv`.],
) <tab:rev>

For the torus the rebuild difference of $d V \/ d r$ is dominated by rebuild noise at small $h$ and converges onto the seam's second derivative as $h$ grows (from #relc(V("second::torus::-4"), V(K-m10 + "m10_torus_minor_radius_second_derivative@L444::ddv")) at $h = 10^(-4)$ to #relc(V("second::torus::-1"), V(K-m10 + "m10_torus_minor_radius_second_derivative@L444::ddv")) at $10^(-1)$); the #E(K-m10 + "m10_torus_minor_radius_second_derivative@L444::rel") in vcad's own test is its smaller step. The filleted cube behaves the same way: the difference reaches #F("second::fillet::-1", 4) at $h = 10^(-1)$ against the seam's #F(K-m10 + "m10_rounded_cube_second_derivative_matches_fd@L284::ddv", 4), and a five-point stencil on one frozen plan agrees with the seam to #E(K-m10 + "m10_rounded_cube_second_derivative_matches_same_plan_stencil@L876::rel"). An earlier revision of the kernel failed this check by $10^(-3)$ at every step (@sec:box).

== Five parameters of a filleted, drilled box <sec:box>

The part is a box of dimensions $(s_x, s_y, s_z)$ with every edge filleted at radius $r$ and a centered through-hole of radius $r_h$: 6 planes, 12 blend cylinders, 8 corner spheres and the hole wall, #V("cost::nodes") mesh nodes at $theta^*$ (16 segments per circle). The objective is the squared relative miss of five quantities (volume, the three centroid coordinates and $I_(z z)$) against their values at $theta^* = (10, 12, 8, 1.8, 2.2)$ mm, starting from $theta_0 = (8, 14, 6, 1.2, 1.6)$ mm. The five-by-five Jacobian of the quantities has determinant #F("m9::jac::det", 0) and smallest pivot #F("m9::jac::min_pivot", 2), so the parameters are locally identifiable.

*Two errors the finite differences caught.* At $theta_0$, same-plan FD at $h = 10^(-6)$ agrees with the seam's gradient to #relc(V("sweep::plan::0::-6"), V("sweep::seam::0")) for $s_x$, #relc(V("sweep::plan::2::-6"), V("sweep::seam::2")) for $s_z$, #relc(V("sweep::plan::3::-6"), V("sweep::seam::3")) for the fillet radius and #relc(V("sweep::plan::4::-6"), V("sweep::seam::4")) for the hole radius, and rebuild FD of the fillet-radius component reaches #relc(V("sweep::fresh::3::-2"), V("sweep::seam::3")) at $h = 10^(-2)$ (@fig:sweep). This was not so in the kernel revision we first measured (`d10f279`). In that run, which `repro.sh` does not regenerate and whose figures we quote, the fillet-radius component sat $1.4 times 10^(-4)$ from same-plan FD and the $s_x$ component $2.4 times 10^(-5)$, at every step from $10^(-8)$ to $10^(-6)$, and the filleted cube's second derivative missed by $10^(-3)$. An error that does not move with the step is not finite-difference noise, and both had causes in the seam. A Boolean rounds the centers of a corner sphere and its blend cylinder through single precision, so the two surfaces cross at about $3 times 10^(-4)$ rad instead of meeting tangentially; the tessellator classified their shared arc as a trim between two surfaces and tracked it with an ill-conditioned Newton solve. Such near-tangent pairs now take the sphere's surface rule, which removed the fillet-radius and second-derivative errors. Separately, a vertex on the hole's rim has only plane and cylinder rows, which left its slide along the rim at zero while the kernel moves it with the hole; volume cannot see that, moments can. Those directions now ride with the vertex's curved surface. Both fixes are in the pinned commit, each with a regression test.

#figure(
  table(
    columns: (2fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right),
    table.header([*Method (same driver)*], [*to $10^(-3)$ mm*], [*to $10^(-6)$ mm*], [*final error*]),
    [Levenberg–Marquardt, seam Jacobian], [#ttt-cell("lm_seam", 1e-3)], [#ttt-cell("lm_seam", 1e-6)], [#E("base::lm_seam::err")],
    [L-BFGS, seam gradient], [#ttt-cell("lbfgs_seam", 1e-3)], [#ttt-cell("lbfgs_seam", 1e-6)], [#E("base::lbfgs_seam::err")],
    [L-BFGS, rebuild FD, $h = 10^(-4)$], [#ttt-cell("lbfgs_fd4", 1e-3)], [#ttt-cell("lbfgs_fd4", 1e-6)], [#E("base::lbfgs_fd4::err")],
    [L-BFGS, rebuild FD, $h = 10^(-6)$], [#ttt-cell("lbfgs_fd6", 1e-3)], [#ttt-cell("lbfgs_fd6", 1e-6)], [#E("base::lbfgs_fd6::err")],
    [L-BFGS, rebuild FD, $h = 10^(-2)$], [#ttt-cell("lbfgs_fd2", 1e-3)], [#ttt-cell("lbfgs_fd2", 1e-6)], [#E("base::lbfgs_fd2::err")],
  ),
  caption: [#lead[Recovering θ\* on the five-parameter box.] Iterations and wall-clock time until $max |theta - theta^*|$ first falls below the tolerance. All L-BFGS runs share one driver (memory 8, Armijo line search on rebuilt-from-scratch objective values, 200 iterations); only the gradient differs. Levenberg–Marquardt uses the seam's exact $5 times 5$ Jacobian of the residuals. `data/measured.tsv`.],
) <tab:opt>

#figure(fig-baselines(),
  caption: [#lead[Parameter error against wall-clock time] for the runs of @tab:opt. Every curve rebuilds the part at each objective evaluation; the gradient source is the only difference. `data/measured.tsv`.],
) <fig:baselines>

What exact derivatives buy here is not only that L-BFGS converges: with rebuild FD at a well-chosen step ($h = 10^(-4)$) it reaches $10^(-3)$ in a similar number of iterations and stalls at #E("base::lbfgs_fd4::err") mm in this run (rebuild FD is not repeatable to $10^(-6)$, because rebuilds do not place nodes identically, so where it stalls varies from run to run). They buy cost and robustness. A seam gradient (rebuild, capture, one pass and one transposed pass) takes #F("cost::seam_gradient", 0) ms on this part against #F("cost::fd_gradient", 0) ms for a rebuild-FD gradient, a factor of #fx(V("cost::fd_gradient") / V("cost::seam_gradient"), 0) at five parameters that grows with the parameter count; and FD at a too-small ($10^(-6)$) or too-large ($10^(-2)$) step ends #E("base::lbfgs_fd6::err") and #E("base::lbfgs_fd2::err") mm from $theta^*$. Because the residuals are square and vanish at $theta^*$, Gauss–Newton with the exact Jacobian is the natural method, and Levenberg–Marquardt reaches $10^(-6)$ in #ttt("lm_seam", 1e-6).at(0) iterations and #fx(ttt("lm_seam", 1e-6).at(1), 2) s. Its first iterates converge quadratically, as an exact Jacobian at zero residual should; below about $10^(-8)$ mm the error shrinks only by a constant factor per iterate, because there each rebuild's objective is no longer smooth at the scale of the step (the sag-adaptive jumps of @sec:limits and single-precision rounding in the Boolean) and the damping does not fully relax.

The rebuild dominates each iterate: #F("cost::build", 0) ms against #F("cost::capture", 1) ms for the capture, #F("cost::seam", 2) ms for one forward pass, #F("cost::dual_qoi", 2) ms for the dual mass properties of that pass, and #F("cost::pullback", 2) ms for the transposed pass. The transposed pass costs about #fx(V("cost::pullback") / V("cost::seam"), 1) forward passes on this part, so it pays from two parameters up. (On the filleted cube without the hole, @fig:cost, it costs about three, because that part has fewer vertex rows to transpose relative to its surface nodes.)

== A fillet radius and a flywheel

Projected gradient descent on the fillet radius of the 10 mm cube alone recovers the radius whose volume matches a target, $r^* = 2.2$ mm from $r_0 = 1$ mm, landing at #F("m4_fillet_radius::optimize::r", 6) mm in #V("m4_fillet_radius::optimize::iters") accepted iterates.

#figure(fig-flywheel(),
  caption: [#lead[A flywheel design brief.] A disc (radius 40 mm, thickness 10 mm) with a center bore and four lightening holes on a 25 mm bolt circle; θ = (bore radius, hole radius). Objective: mass over a reference mass plus $100 dot$ the squared relative miss of a target spin inertia, the inertia of the design at (8, 5) mm. The bounds keep the holes inside the disc and clear of each other. L-BFGS (bold) stops after #V("base::fly_lbfgs::iters") iterations with the inertia within #fx(100 * V("fly::inertia_miss"), 1)% of the target and #fx(100 * (1 - V("fly::mass_ratio_final")), 1)% less mass than the (8, 5) design, the bore on its upper bound (the bound that keeps it clear of the lightening holes); projected gradient descent (faint) takes #context { let n = 0; while ("m3_flywheel::iter::" + str(n + 1)) in measured { n += 1 }; [#n] } steps along a zig-zag to a similar design. `data/measured.tsv`.],
) <fig:flywheel>

Each flywheel iterate takes seconds because the build does: five Booleans at 24 segments take #fx(V("cost::fly::build") / 1000, 1) s, against #F("cost::fly::capture", 0) ms to capture its #V("cost::fly::nodes")-node plan.

== A named document parameter

A `.vcad` document whose cylinder radius is bound to the named parameter `r` differentiates with no hand seeding: $d V \/ d r =$ #F(K-doc + "ir::dv", 3) against the N-gon closed form #F(K-doc + "parametric_document_cylinder_gradient@L119::dv_exact", 3) (#E(K-doc + "parametric_document_cylinder_gradient@L119::rel")), and $d I_(z z) \/ d r$ agrees with FD of document rebuilds to #E(K-doc + "parametric_document_cylinder_gradient@L140::rel_izz"). A document written in vcad's loon language and one whose parameter is declared with `defparam` reach the same closed form to #E(K-doc + "loon_authored_document_gradient@L251::rel") and #E(K-doc + "defparam_makes_the_gradient_reachable_without_hand_binding@L281::rel"). These gradients use synthesized seedings and carry their $O(h^2)$ error.

== Shape through dynamics and contact

#figure(
  table(
    columns: (2.1fr, 1fr, 1fr),
    align: (left, right, right),
    table.header([*Rollout*], [*dJ/dθ*], [*vs rebuild-and-resimulate FD*]),
    [Flywheel spin-up, $J = omega(T)$, FD on p], [#F("m8_rollout_gradient::flywheel_spinup_gradient_matches_end_to_end_fd@L203::grad", 4)], [#E("m8_rollout_gradient::flywheel_spinup_gradient_matches_end_to_end_fd@L203::rel")],
    [Gravity pendulum, $J = q(T)$, FD on p], [#F("m8_rollout_gradient::gravity_pendulum_gradient_matches_end_to_end_fd@L240::grad", 5)], [#E("m8_rollout_gradient::gravity_pendulum_gradient_matches_end_to_end_fd@L240::rel")],
    [Flywheel, adjoint], [#F("m11_adjoint_rollout::adjoint_matches_end_to_end_fd@L249::g", 4)], [#E("m11_adjoint_rollout::adjoint_matches_end_to_end_fd@L249::rel")],
    [Pendulum on a body-x revolute, adjoint], [#F("m11_adjoint_rollout::adjoint_matches_end_to_end_fd@L259::g", 5)], [#E("m11_adjoint_rollout::adjoint_matches_end_to_end_fd@L259::rel")],
    [Cylinder resting on its side, contact], [#sci(V("m11_contact_gradient::contact_chain_matches_end_to_end_fd@L167::grad"), digits: 3)], [#E("m11_contact_gradient::contact_chain_matches_end_to_end_fd@L167::rel")],
    [Filleted box resting on a blend, contact], [#sci(V("cbox::grad"), digits: 3)], [#relc(V("cbox::fd::-2"), V("cbox::grad"))],
  ),
  caption: [#lead[Gradients of rollouts with respect to a CAD radius]: J in rad/s, rad and m; θ in mm. The first five rows use a cylinder (radius 10 mm, height 8 mm, density 2700 kg/m³) on one joint, θ its radius; the last uses a 20 mm cube filleted at $r = 2$ mm, θ the fillet radius. The reference rebuilds the CAD, re-tessellates, recomputes mass properties and re-simulates, at $h = 10^(-3)$ mm (cylinder) and $10^(-2)$ mm (filleted box). Contact: $k = 100$ N/m and $c = 0.5$ N·s/m per vertex. The adjoint's pendulum mounts the same cylinder on a revolute about the body x axis instead of rotating its inertia, so its value differs from the first pendulum's. `data/measured.tsv`.],
) <tab:physics>

The cylinder rows are a check of the chain on a body whose mass properties have closed forms. The last row exercises the seam through dynamics: a 20 mm cube with every edge filleted at 2 mm rests on one blended edge, held by a vertical prismatic joint, and $J$ is its settled height. The fillet radius moves 20 surfaces. Growing it raises the lowest point of the blend by $sqrt(2) - 1$ per unit radius, so the surface channel alone would give $d J \/ d theta = #sci(V("cbox::surface_only"), digits: 3)$ m per mm; the gradient, #sci(V("cbox::grad"), digits: 3), adds the mass channel and the change in penetration depth of the blend vertices in contact (the set of vertices in contact is held fixed; a change of that set is a discontinuity no gradient sees), and matches a rebuild-and-resimulate FD to #relc(V("cbox::fd::-2"), V("cbox::grad")).

#figure(fig-contact(),
  caption: [#lead[Shape through contact.] The cylinder of @tab:physics rests on its side on phyz's per-vertex penalty springs; $J$ is its settled height. Growing the radius raises the body through the surface channel and sinks it through the mass channel. `data/measured.tsv`.],
) <fig:contact>

== Pixels to CAD parameters <sec:irys>

The transposed pass accepts any cotangent on the plan's nodes, including one from a renderer. With the irys differentiable path tracer @irys we pulled an image gradient back to a CAD dimension on a real part: the left shoulder-pitch output plate of the Rose robot arm, a 3 mm rounded plate with a 49 mm bearing bore and twelve 4.4 mm bolt holes. θ is the bore diameter; the plan has #V("irys::nodes") nodes at 32 circle segments and a synthesized seeding. irys renders the plan's mesh as it is against an empty background at 160 × 128 pixels, so the whole derivative comes from visibility edges, and its edge sampler returns $partial cal(L) \/ partial x$ on every node for a fixed smooth image loss ($#V("irys::samples")$ samples, #V("irys::seeds") seeds).

#figure(
  table(
    columns: (2.2fr, 1fr, 1fr),
    align: (left, right, right),
    table.header([*Path to dL/dθ*], [*Value*], [*vs transposed pass*]),
    [Transposed pass], [#F("irys::pullback", 5)], [–],
    [Forward pass, $sum partial cal(L) \/ partial x dot dot(x)$], [#F("irys::forward", 5)], [#E("irys::forward_rel")],
    [Same-plan FD node velocities, $h = 10^(-5)$ mm], [#F("irys::fdvel", 5)], [#E("irys::fdvel_rel")],
    [Render FD with nodes moved along FD velocities, $h = #V("irys::render_h")$ mm], [#F("irys::render", 4)], [#E("irys::render_rel")],
  ),
  caption: [#lead[The rose-arm benchmark] at irys `5e09686`, rose `832192f` and vcad #raw(env.at("vcad_rev").slice(0, 7)), regenerated by `repro/irys.sh`. The transposed pass's Monte Carlo standard error over the seeds is ±#V("irys::pullback_se"), which covers the seam's paths but not the render FD: at $h = 0.02$, $0.05$ and $0.1$ mm the render FD gives #F("irys::render_sweep::0.02", 3), #F("irys::render_sweep::0.05", 3) and #F("irys::render_sweep::0.1", 3), a spread of #fx(100 * (V("irys::render_sweep::0.05") - V("irys::render_sweep::0.1")) / V("irys::pullback"), 1)% with no trend in $h$, so its error is its own quadrature noise. The transposed pass lies inside that spread; the render check is good to about 1%, the seam checks above it to $10^(-5)$ and better.],
) <tab:irys>

A rebuild FD is not possible here. A rebuild at $theta plus.minus h$ loses correspondence for $h >= 2 times 10^(-3)$ mm and changes topology at 0.05 mm, where the bore rim's sag-adaptive arc count drops by two vertices, while at $h = 5 times 10^(-4)$ mm the render FD is dominated by quadrature noise. The last row therefore moves the plan's nodes along their same-plan FD velocities instead of rebuilding, which checks the renderer's derivative but not the seam's; the seam's part of the chain is checked by the third row.

== Cost

#figure(fig-cost(),
  caption: [#lead[Per-call cost on the filleted cube] at three blend resolutions, median. Capturing a plan, one forward pass and one transposed pass are all linear in the number of mesh nodes. `data/measured.tsv`.],
) <fig:cost>

= Discussion <sec:discussion>

*Why freeze the tessellation.* Differentiating the kernel's code has to give some answer at every branch: which face a Boolean keeps, how a fillet orders its blends, how many segments a circle gets. Those answers are piecewise constant in $theta$, and in vcad they are also order-nondeterministic. Freezing the plan makes the discrete state explicit and checkable. The cost is the limits of @sec:limits: a plan is valid for steps of #sci(V("radius::0::h")) mm on the five-parameter box, segment counts change between iterates, and the derivative is that of the mesh. For optimization this has been enough on every part we tried, because each iterate captures a new plan and the jumps between plans are of order $10^(-6)$ of the objective; for an objective that depends on fine surface detail, the polygonization gap would dominate before the jumps do.

*What the finite differences show.* On every plane, cylinder, cone and torus model, same-plan FD, rebuild FD and the seam agree. On filleted solids rebuild FD is noisy at small steps, because rebuilds place nodes differently, and has to be read at a step of $10^(-3)$ to $10^(-2)$ mm (@fig:sweep). At those steps it confirms the seam on the filleted cube and the filleted, drilled box. Same-plan FD is the sharper test, since it has no rebuild noise, and it is the one that exposed the two seam errors of @sec:box: each showed as an error that stayed fixed while the step moved over two decades.

*Toward an operator graph.* The rollout coupling of @sec:physics composes three steps by hand: the seam (parameters to node positions, with its transposed pass), mass properties (node positions to ten scalars per body) and the phyz adjoint (scalars and contact vertices to $J$). Each is a step with a forward map and an exact vector–Jacobian product, which is the shape of an operator node in a differentiable program @blondel2022implicit. We are building that graph on the tang tensor compiler @tang, where linear solves and simulations become nodes with their own adjoints; none of that is evaluated here.

*Remaining gaps.* Cone-tangent-to-plane tangency rows are not implemented; fillets with asymmetric corners or three blends at a vertex fall back to an older pipeline that is not differentiated; the contact model is frictionless; and the method is demonstrated only on vcad. Nothing in it depends on vcad beyond analytic surfaces that evaluate on dual numbers and a tessellator that can classify its nodes.

= Reproducibility <sec:repro>

`repro/repro.sh` clones vcad at #raw(env.at("vcad_rev")) (its lockfile pins phyz, loon and tang) and applies `report.patch`, which adds `eprintln!` lines after statements in vcad's tests that already compute a measured quantity, so each test still asserts its own tolerance and prints the value it checks. It then copies in `paper_experiments.rs` and `paper_contact_fillet.rs`, the experiments added for this paper (rebuild FD, step sweeps, resolution study, optimizer baselines, costs, plan radius, segment-count jumps, second-order sweeps, the flywheel L-BFGS run and the filleted-box contact rollout), runs everything, runs `irys.sh` for the rose-arm benchmark, and writes `data/measured.tsv`. This document reads every measured value, table cell and plotted point from that file, with two exceptions stated where they occur: the figures quoted from the earlier kernel revision `d10f279` (@sec:box), and the correspondence and topology thresholds of the irys rebuild probe, which come from a separate probe run (@sec:irys). Model construction counts (segments requested, the 112-gon rim) are inputs, not measurements. The run took place on #env.at("date") on #env.at("host").

= Conclusion

Freezing a BRep's tessellation and differentiating its node positions gives derivatives of CAD parameters, fillet radii included, that are exact for the mesh, extend to second order and a transposed pass, and carry through to mass properties and rigid-body dynamics with contact. The approach follows Engineering Sketch Pad's tessellation sensitivities; within that approach our additions are analytic fillet sensitivities, second derivatives, the transposed pass and the dynamics coupling. Its limits are those of the frozen mesh, a polygonization gap that falls as $N^(-2)$ and plans valid for small steps. Checking against finite differences of one frozen plan found two errors in the seam, both since fixed. vcad, the experiments and the data are open source.

#heading(outlined: true, numbering: none)[References]
#show bibliography: it => { show "?.": "?"; show "!.": "!"; it }
#bibliography("refs.bib", style: "nature", title: none)
