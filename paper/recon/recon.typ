// Research post: image-to-CAD recovery. Photographs in, an editable CAD program out, built on irys
// (paper/irys, the companion paper) and its edge-sampling estimator. Split out of the irys paper's
// former "Dimensions from photographs" section (2026-11-10); same treatment and preamble as irys.typ.
// One source, two outputs: `--features html --format html --input target=html` builds the web post.
// Every measured number is read from data/measured.tsv; each row names the irys report and commit
// that produced it. DRAFT: pending experiments are marked TODO in the text and in README.md.

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
#let brand-names = (("irys", "irys"), ("vcad", "vcad"), ("tang", "tang"), ("phyz", "phyz"))
// each product in its landing-page color (web/src/app/page.tsx), not its family
#let fam-color = (irys: rgb("#b48cff"), vcad: rgb("#ff2052"), tang: rgb("#ffd400"), phyz: rgb("#00f0ff"))
#let brand-re = regex("(?i)\\b(irys|vcad|tang|phyz)\\b")
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

#set document(title: "Seeing Is Measuring", author: "Cam Pedersen (Municipal Robotics)")

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
      pad(x: -hf-out(), grid(columns: (1fr, auto), caps[Seeing Is Measuring], caps[Municipal Robotics]))
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
#import "figures/recon.typ": fig-recon
#import "figures/amp.typ": fig-amp
#import "figures/rosefit.typ": fig-rosefit
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
  for r in csv("data/env.tsv", delimiter: "\t") { d.insert(r.at(0), r.at(1)) }
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
#let deg-err(k) = calc.abs(V("fit.phi_" + k) - V("fit.true_" + k))
#let max-deg-err = calc.max(deg-err("pitch"), deg-err("roll"), deg-err("elbow"))
#let theta-err = calc.max(
  calc.abs(V("fit.alpha") - 0.30), calc.abs(V("fit.f0_450") - 0.86),
  calc.abs(V("fit.f0_550") - 0.88), calc.abs(V("fit.f0_650") - 0.90))
// a Wilson interval stored as two fractions, printed as percentages
#let ci(key) = [#calc.round(100 * V(key))–#calc.round(100 * V(key, i: 1))]
// a pending result: never a number the data does not support
#let todo(body) = text(fill: c-warn)[[TODO: #body]]
#let mono-sm(body, fill: c-label) = text(font: mono-m, size: s-xs, fill: fill, tracking: 0.04em, body)

// Recovery examples: three of the gate's parts, each from its three photographs (the first shown
// large), the fit's overlay (model outline on the crop, and the residual), and the programs.
#let fig-recon-examples() = {
  let ex = json("data/recon-examples.json")
  let verdict(e) = if e.p05 { text(fill: c-ok)[PASS · WORST #calc.round(e.max, digits: 2) MM] } else if e.p1 { text(fill: c-ok)[PASS AT 1 MM · #calc.round(e.max, digits: 2) MM] } else if e.topo { text(fill: c-fault)[FAIL · #calc.round(e.max, digits: 2) MM] } else { text(fill: c-fault)[FAIL · WRONG FEATURES] }
  let mono-s(body, fill: c-text.transparentize(25%)) = text(font: mono, size: 6.4pt, fill: fill, body)
  align(left, grid(columns: (1fr,), row-gutter: 1.1em, ..ex.map(e => grid(
    columns: (1.05fr, 0.36fr, 1.9fr), column-gutter: 0.5em, row-gutter: 0.35em,
    image("images/recon/" + str(e.seed) + "-v0.jpg", width: 100%),
    stack(spacing: 0.3em, image("images/recon/" + str(e.seed) + "-v1.jpg", width: 100%), image("images/recon/" + str(e.seed) + "-v2.jpg", width: 100%)),
    image("images/recon/" + str(e.seed) + "-overlay.png", width: 100%),
    grid.cell(colspan: 3, stack(spacing: 0.35em,
      text(font: mono-m, size: s-xs, tracking: track)[PART #e.seed #h(0.6em) #verdict(e)],
      mono-s[TRUTH #h(0.5em) #e.truth],
      mono-s(fill: c-text)[FOUND #h(0.5em) #e.recovered.split("; pose").at(0)])),
  ))))
}

// The cover: the object the grammar cannot yet say. Cam's photo of a printed retro enclosure.
#let fig-cover(width: 21.59) = {
  let height = width * 1600 / 1200
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    content((0, 0), anchor: "south-west", image("images/enclosure.jpg", width: width * 1cm))
    rect((0, 0), (width, height * 0.62), stroke: none,
      fill: gradient.linear(c-bg.transparentize(100%), c-bg.transparentize(8%), c-bg, c-bg, angle: 90deg))
  })
}

// ---- title page -----------------------------------------------------------------
#if not web {page(margin: 0in, background: place(top, fig-cover(width: 21.59)))[
  #set par(leading: 0.5em)
  #v(1fr)
  #pad(left: 0.75in, right: 0.9in, bottom: 0.65in)[
    #grid(columns: (auto, 1fr, auto), column-gutter: 0.8em, align: horizon,
      caps(fill: c-text)[Municipal Robotics · Research],
      line(length: 100%, stroke: 0.5pt + c-line-hi),
      caps[November 2026 · Draft])
    #v(0.35in)
    #move(dx: -0.045 * s-display, text(font: sans-sb, size: s-display * 1.2, tracking: -0.025em)[Seeing Is\ Measuring])
    #v(0.5em)
    #line(length: 22%, stroke: 2pt + c-label)
    #v(0.7em)
    #text(size: s-lg, fill: c-label)[Editable CAD programs from photographs]
    #v(0.45in)
    #grid(columns: (1fr, auto), align: (left + bottom, right + bottom),
      caps[Cam Pedersen · Municipal Robotics],
      image("images/muni-logo.svg", width: 0.7in))
    #v(0.2in)
    #text(size: s-xs, fill: c-label)[Cover: a printed enclosure with a rounded shell, a recessed bezel, a speaker grille and two round ports. Today's grammar cannot write it down (@sec:real).]
  ]
]}

#let abstract-text = [
  A photograph of a part shows which features the part has and how large they are. We recover both as an editable CAD program, a plate and a list of holes, counterbores, slots, bosses and patterns, each with its dimensions, from three photographs beside a printed tag. Every photograph in this paper is synthetic, rendered with a phone camera model. We have not yet tested real photographs. We score a program by its description length in nats, which adds the residual, the parameter cost and the program length in one unit. The search keeps an edit that adds a feature only if the feature shortens the total, so a feature must pay for itself. Inside each edit, Levenberg–Marquardt fits the dimensions with a Jacobian from irys's edge-sampling estimator. The companion paper describes that renderer.

  On #V("recon.n.parts") held-out synthetic parts drawn from the grammar, the recovery reads every dimension to within 1 mm on #V("recon.n.p1") (#calc.round(100 * V("recon.n.p1") / V("recon.n.parts"))%, Wilson 95% interval #ci("recon.n.p1_ci")%). Most misses are wrong features: the recovery finds the right features on #V("recon.n.topo") parts, and #V("recon.n.p1") of those measure within 1 mm. A hole read as a counterbore, or the reverse, appears in #V("recon.n.hole_cb") of the #V("recon.n.topo_fail") parts with wrong features. The Fisher error bars are too small by a median factor of #V("recon.sig.opt") and do not rank the errors. One empirical scale restores coverage on average but is not a per-dimension error bar.

  A greedy search decides each feature with one yes-or-no comparison. We propose *feature amplitudes*, a continuous relaxation over which features a program has. Each optional feature gets an amplitude $a in [0, 1]$. The image blends the renders without and with the feature, the derivative with respect to $a$ is exact, and the description length charges $a L$. An anneal drives every amplitude to 0 or 1, and the fit then emits the ordinary program. We have tested it on three small problems only. It fits a hole from a start 2 mm off to within 0.03 mm. It removes a hole the target does not have, but only after we extended the anneal. On one part where the greedy search gave different answers in two runs, it chooses the hole over the counterbore. We have not yet run it on the held-out parts, so we do not know whether it improves identification. The last section lists what the grammar needs before it can describe a real printed enclosure.
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

To measure a part, you usually touch it with calipers, a coordinate-measuring machine or a gauge pin. A photograph touches nothing, yet it already contains the part's dimensions, mixed up with its pose, its finish, the light in the room and the lens. Inverse rendering separates them by finding the parameters whose rendering matches the photograph. For an engineered object those parameters are not free-form vertices or a neural field. They are the dimensions in a CAD model, the angles of a mechanism's joints and the finish of its surfaces. If a renderer can recover them, and say how well it knows each one, it is a measuring instrument.

An instrument has two obligations. It must be *exact*, so the same input gives the same reading. It must be *precise*, so its error is small and known. The companion paper @pedersen2026irys makes the renderer exact. Its replay is bit-identical to its forward pass, and its gradients match central differences down to the dimensions of a BRep. This paper measures precision, first on a model we already have (@sec:warmup), then on a model we must find.

A drawing of a part is a short program. "A 74 by 67 by 17 mm plate with three 3 mm holes on a 17 mm circle" is a dozen numbers and a few words, and anyone can make the part from it. A photograph of the same part is millions of pixels. Turning the photograph back into the program takes two steps. *Identification* finds which features the part has. *Measurement* finds their dimensions. Measurement is continuous and has gradients. Identification is discrete and has none.

irys supplies the gradients for measurement. vcad, our BRep CAD kernel @pedersen2026vcad, builds each program's solid. This paper adds identification. We search over editable CAD programs, fit each candidate's dimensions through irys's estimator, and choose between candidates by *description length* @rissanen1978mdl @grunwald2007mdl. The description length is the number of nats needed to encode the photographs given the program, plus the program and its parameters. The search adds a feature only when the feature shortens that total.

On parts the grammar can describe, measurement works and identification often fails. On #V("recon.n.parts") held-out synthetic parts, the recovery identifies the features correctly on #V("recon.n.topo") (#calc.round(100 * V("recon.n.topo") / V("recon.n.parts"))%), and #V("recon.n.p1") of those #V("recon.n.topo") measure within 1 mm. The largest single group of failures is a confusion between a hole and a counterbore. A greedy search decides each edit from one fit, and these two candidates render almost the same image. The photographs barely show a counterbore's floor, so a counterbore looks like a hole of its outer radius.

The second half of the paper gives that decision a gradient. *Feature amplitudes* relax the choice of features to a continuous one. Each optional feature gets an amplitude $a in [0, 1]$. The model image is the render without the feature plus $a$ times the difference the feature makes. The description length charges $a L$, and an anneal drives each amplitude to 0 or 1. The derivative with respect to an amplitude is exact and costs one extra render, with no edge sampling. We expect it to choose well among features that something else has proposed, the hole-or-counterbore choice in particular, since a counterbore of depth zero is a hole. We expect it to discover poorly. An amplitude placed away from every real feature gets no gradient toward one.

Our contributions are:

- *A warm-up with a known model.* Three joint angles and an anodised finish of a robot arm read from one render, to #fx(max-deg-err, 2)° and #fx(theta-err, 3) (@sec:warmup).
- *Recovery by description length through a differentiable renderer.* A search over a CAD grammar whose every candidate is fitted by Levenberg–Marquardt with an edge-sampled Jacobian and scored in nats, with three photographs and a printed tag as the only input (@sec:method).
- *A held-out test.* A development set of #V("recon.parts") parts, then #V("recon.n.parts") new in-grammar parts and #V("recon.o.parts") out-of-grammar parts run once with every setting frozen, with per-feature error, failure modes and a check of the error bars against the actual errors (@sec:results).
- *Feature amplitudes*, a continuous relaxation over the discrete part of a CAD program, with a continuous description length. We test it on three small problems and not yet on the held-out parts (@sec:amp, @sec:amp-results).

== Scope and limits

- *The photographs are synthetic.* irys's OpenPBR scene kernel renders them with a phone camera model. No number in this paper comes from a real photograph (@sec:real). The targets and the final path-traced fit share a renderer, so the results exclude every error a real camera, print and room would add. The search itself fits a cheaper photo model, which differs from the renderer that made the targets (@sec:method).
- *The grammar is a plate.* One extruded block with a corner treatment and features cut into or standing on its top face. The out-of-grammar parts of @tab:gate test its edges, not a different family.
- *The search is the method's weakest part.* The amplitude relaxation improves how it chooses between proposals and does not change what it proposes.
- *The arm fit is one run.* It converges from a start 23° off at the elbow. Under sky-only light the image loss along the elbow has a basin only about ±#V("basin.deg")° wide, and a fit without the sun stopped in a local minimum. We have not measured convergence over starts or seeds.
- *The search is not deterministic across machines.* One part gave a different program on a second run (@sec:amp-results). We have not measured this variance.
- *Compute.* A part takes about ten minutes of CPU time (@sec:results). Only the final path-traced fit uses the companion paper's GPU path.

= Related work

*Inverse CAD and program synthesis.* Recovering an editable CAD description is usually posed as program synthesis. CSGNet parses shapes into CSG programs with a recurrent network @sharma2018csgnet; InverseCSG converts meshes to compact CSG trees with a solver-based synthesizer @du2018inversecsg; Szalinski rewrites flat CSG into programs with loops by equality saturation @nandi2020szalinski; DeepCAD generates sketch-and-extrude sequences @wu2021deepcad; ShapeAssembly writes part-assembly programs @jones2020shapeassembly; Point2CAD recovers BRep surfaces from point clouds @liu2024point2cad, and CAD-Recode writes CAD code from point clouds with a language model @rukhovich2024cadrecode. Ellis et al. infer graphics programs from images by proposing primitives and synthesizing a program over them @ellis2018graphics, and DreamCoder learns a library of program components alongside the search @ellis2021dreamcoder. Learned systems train on construction sequences such as the Fusion 360 Gallery @willis2021fusion360, and Point2Cyl segments point clouds into extrusion cylinders @uy2022point2cyl. Tian et al. infer and execute 3D shape programs @tian2019shapeprograms, and Ellis et al. guide program search by executing partial programs @ellis2019repl. These methods take meshes, point clouds or clean drawings, or learn a prior from a dataset. Ours starts from photographs and scores each candidate by rendering it. We do not compare against any of them in this draft (@sec:limits).

*Analysis by synthesis.* Fitting a generative graphics model to an image is an old idea. Picture expresses it as a probabilistic program over scenes @kulkarni2015picture, and Cascaval et al. differentiate CAD programs so that edits to the shape move the parameters @cascaval2022bidirectional. Leclerc used description length to choose among image descriptions @leclerc1989mdl, and the Bayesian information criterion @schwarz1978bic is the usual simpler penalty that our Laplace term refines.

*Measurement from images.* Close-range photogrammetry measures manufactured objects from calibrated images, usually by triangulating targets or features and adjusting cameras and points together @luhmann2019photogrammetry. We share its tools (a calibration target, bundle-adjustment-style least squares, Fisher-information error estimates) but fit a parametric model of the whole part to its pixels rather than to sparse points, so a hole's diameter is read from its outline and shading rather than from markers.

*Relaxing discrete structure.* Continuous relaxations of a discrete choice are common where the choice has no gradient. DARTS mixes candidate operations with softmax weights and anneals to one @liu2019darts; the Gumbel-softmax samples from a relaxed categorical @jang2017gumbel; DiffCSG differentiates CSG by rasterization so the boolean structure can be optimized @yuan2024diffcsg. The amplitude's length term $a L$ is an $ell_1$ penalty on a selection variable @tibshirani1996lasso, and the anneal $beta a (1 - a)$ is the concave penalty that topology optimisation uses to push densities to 0 or 1 @bendsoe2003topology and that $L_0$ relaxations approximate @louizos2018l0. The blend is a linear interpolation of two images, so its derivative is elementary. None of these parts is new. What we add is their use to choose CAD features. Two things make that use convenient. A feature's effect on the render is local and nearly additive, so the blend factors per feature and its gradient is exact. The description length sets the penalty's weight in the same unit as the residual, so there is no weight to tune.

*Differentiable rendering.* Edge sampling @li2018edge and path replay @vicini2021prb, and their implementation in irys, are described in the companion paper @pedersen2026irys. Mitsuba 3 @jakob2022mitsuba3 is the closest general system. Reparameterisation @loubet2019reparam and warped-area sampling @bangaru2020warped handle the same visibility discontinuities without sampling edges. The vcad BRep kernel differentiates CAD parameters upstream of the mesh @pedersen2026vcad.

= A model you already have <sec:warmup>

We first recover the parameters of a model we already have. irys reads our humanoid's left arm, with its joints, from its CAD source. The unknowns are three joint angles and the finish of the anodised links, and the photograph is a path-traced render with fresh noise. Nothing in this problem is discrete, so it tests the continuous fit alone.

#figure(fig-rosefit(),
  caption: [#lead[Recovering three joint angles and a finish from a render.] The left arm of our humanoid robot, in context, 192×192, 8 samples per pixel, path depth 5 with next-event estimation. (a) The worst of the three joint errors for four configurations: all terms for 600 iterations, the arm alone in frame (the control), without secondary edges, and with a coarse-to-fine pyramid schedule. The last two diverge and leave the top of the plot within 50 iterations, so we keep secondary edges and drop the pyramid. (b) The all-terms run's joint angles against the truth (dashed). One run per configuration. `data/rose-fit.csv`, from irys `docs/phase2f-rose-loss.csv`.]) <fig:rose>

The target is the arm at shoulder pitch, shoulder roll and elbow (#V("fit.true_pitch"), #V("fit.true_roll"), #V("fit.true_elbow"))° with a bead-blasted clear-anodised finish $theta = (0.30, 0.86, 0.88, 0.90)$. From (#V("fit.init_pitch"), #V("fit.init_roll"), #V("fit.init_elbow"))° and a default finish, Adam on the image MSE for #V("fit.iters") iterations reaches (#V("fit.phi_pitch"), #V("fit.phi_roll"), #V("fit.phi_elbow"))°, an error of at most #fx(max-deg-err, 2)°, and $theta = (#V("fit.alpha"), #V("fit.f0_450"), #V("fit.f0_550"), #V("fit.f0_650"))$, within #fx(theta-err, 3) of the truth. The final MSE, #E("fit.mse"), equals that of the true parameters re-rendered with fresh noise (#E("fit.mse_truth")), so the fit has converged to the noise floor. An iteration costs #F("fit.ms_theta", 0) ms for the material gradient on the GPU, #F("fit.ms_edge", 0) ms for the primary edge term and #F("fit.ms_intsec", 0) ms for the interior and secondary terms on the CPU; the run takes #V("fit.seconds") s. The three terms sum to 345 ms per iteration, 207 s of the 244 s, and the rest is the forward render and bookkeeping. This is one run. We have not measured convergence over seeds or starting points. 

This run started 23° from the answer at the elbow and converged. That is not general. With the sun removed, the image loss along the elbow has a basin about ±#V("basin.deg")° wide, and a fit stopped in a local minimum at −20°. A continuous fit needs a start inside its basin, and the discrete search in the next section has to supply one.

= The recovery <sec:method>

== Programs and their description length

A program is a plate (width, depth, height and a corner treatment: sharp, a fillet or a chamfer) and an ordered list of features on its top face: through-holes, counterbores, through-slots along either axis, bosses, linear hole patterns and circular hole patterns, each with its centre and dimensions, plus the part's pose on the table, $(x, y, "yaw")$. The program is built by the vcad kernel and tessellated for rendering. We score a program by its description length in nats,

$ "score"("program", theta) = underbrace(-log p("photos" | "render"("program", theta)), "residual") + underbrace(1/2 log det F(theta), "parameters") + underbrace(-log p("program"), "program") $

the residual under a robust (Huber) noise model, a Laplace parameter cost from the Fisher information $F = J^top Sigma^(-1) J$, and the program's own length under a uniform grammar prior, a few nats for each feature and its kind. Every term is in nats, so the score has no weight between fit and complexity. The method still has settings: the Huber threshold, the noise scaling below, a beam of two, four finalists, and for amplitudes a freeze threshold and an anneal schedule. We fixed all of them on the development set, except the anneal schedule, which we extended after a failure (@sec:amp-results). The parameter term uses the Fisher information, which @sec:results shows is miscalibrated by a factor of about #V("recon.sig.c"), or $ln #V("recon.sig.c") approx 2.9$ nats per parameter. That is as large as a feature's program length, so the score's choices between programs with different parameter counts are biased by a comparable amount. We have not corrected for it. A feature that explains ten pixels of noise costs more in program and parameters than it saves in residual, so the search refuses it.

The noise model matters to the score more than to the fit. The residual of a good fit is not white. The appearance model cannot reproduce a window's reflection, interreflection or a tone curve, and those errors are smooth across many pixels. Counting those pixels as independent overcounts the nats, and the search then adds features to explain shading. We scale the noise variance by the residual's integrated autocorrelation area, which is the number of pixels per independent pixel, measured on the table away from the part.

== Search

The search starts from a box. One silhouette cannot separate a plate's depth from its height, so the search fits one box per band of heights, fits each one's lighting and dimensions on the image, and keeps the box with the lowest robust cost. It then proposes edits: add a feature at a blob of the residual, remove a feature, turn a hole into a counterbore or a slot, merge holes into a pattern, or change the corner treatment. The search fits and scores each edit and keeps a beam of two. It refits the best four distinct programs at full resolution and makes the final choice there. It keeps an edit only if the edit shortens the description (@fig:recon). When no edit does, the search stops and reports the dimensions with their error bars.

#figure(fig-recon(),
  caption: [#lead[The recovery loop.] The recovery edits an editable CAD program, fits each edit's dimensions with irys's edge-sampling Jacobian, scores it in nats, and keeps it only if the description of the photographs gets shorter. Bar lengths are schematic.],
) <fig:recon>

== Fitting the dimensions

Inside each edit, Levenberg–Marquardt fits the continuous parameters (dimensions and pose) over a short blur homotopy, with a silhouette-distance term at the coarse levels and a chromatic coverage term at every level. The coverage term projects each pixel's colour onto the line between the backdrop's colour and the part's, which gives an observed coverage that shading does not change. The Jacobian is irys's primary edge-sampling estimator applied to every vertex's velocity under each parameter, the same estimator the companion paper validates against central differences, plus the moving-shadow (secondary) term for the key light.

The renderer inside the search is not the path tracer. A search makes thousands of fits, so it uses a deterministic *photo model*, which is a G-buffer with closed-form OpenPBR shading, spherical-harmonic environment light, one fitted key light with soft shadows, and ambient occlusion from 16 fixed rays per point. It is noise-free and about six times cheaper per evaluation. After the search, we refit the appearance under the path tracer and run the final fit on the path-traced residual, with path replay for the radiance and per-vertex edge sampling for the geometry, so in that configuration the reported program, score and dimensions are the path tracer's. We ran it only on the development set (@tab:dev, last column). The held-out results use the photo model throughout.

== A derivative the search was missing

With three photographs the main remaining error on the development set was a confusion between holes and counterbores. We traced one case. The correct program reached the full-resolution finalists and lost by 27 nats to a counterbore whose depth never moved from its starting value. A counterbore's step shows in a photograph mostly as ambient occlusion on its floor. The photo model computed occlusion from a fixed set of 16 rays per point, which is a step function of the geometry with zero derivative almost everywhere. On a flat receiver those 16 directions are fixed in the world, so each is a directional light of weight $1 \/ 16$, and its derivative is the moving-shadow term the key light already had, with the receiver allowed to move too (a counterbore's floor moves with its depth). With that term the Jacobian's column for a counterbore's depth goes from cosine 0.88 against central differences to 0.97, every other column improves or holds, and the search no longer needs finite-difference columns for occluded parameters. The development set then reaches #V("recon.3a.p1") of #V("recon.parts") parts within 1 mm with no finite differences at all, in #V("recon.3a.s_part") s per part against #V("recon.3v.s_part") s.

== Camera and photographs

A printed AprilTag @olson2011apriltag (family tag36h11) beside the part fixes each camera's pose, its focal length (with the EXIF 35 mm-equivalent focal as a 2% prior) and the metric scale. We refine the tag's corners on linear light, because on sRGB values the edge shifts toward the dark side. The photographs share the part's pose, and each photograph gets its own appearance. The test photographs are synthetic. irys's OpenPBR scene kernel renders each part in PLA of one of six colours beside the tag sheet on grey paper, under a captured environment turned at random or a synthetic room with a window and a ceiling panel, plus a key light, at 2016×1512. A camera model then adds defocus, shot and read noise, a tone curve and JPEG compression, and writes an EXIF focal length.

= Feature amplitudes <sec:amp>

The search above is greedy over a discrete space. For every edit it fits the candidate, compares two scores and keeps one program. When two candidates explain the photographs almost equally well, the winner depends on where each fit started and stopped, and the search discards the loser. This section makes the choice continuous, so the fit that measures the features also chooses them.

== The relaxation

Let a program be a base $P_0$ (the plate, its pose and any features already settled) and $K$ optional features $f_1, dots, f_K$ with dimensions $theta_k$. Give each optional feature an amplitude $a_k in [0, 1]$ and render

$ I(a, theta) = I_0(theta_0) + sum_(k=1)^K a_k thin (I_k (theta_0, theta_k) - I_0 (theta_0)) $

where $I_0$ is the render of the base and $I_k$ the render of the base with feature $k$ added. At $a_k in {0, 1}$ the blend is exactly the render of an ordinary program whenever the features' effects on the image do not overlap, which is the usual case for cuts on a plate. Two holes far apart change disjoint pixels, and the change one makes does not depend on the other. Between the endpoints the blend is not the render of any solid. It only has to connect two programs with a path along which we can differentiate the score. The silhouette (coverage) channels blend the same way.

== Gradients

The derivative with respect to an amplitude is the difference the feature makes,

$ (partial I) / (partial a_k) = I_k - I_0, $

which is exact and needs only the two renders the blend already uses, with no edge sampling, finite difference or step size. The dimensions' columns are the blend of the ordinary Jacobians,

$ (partial I) / (partial theta_k) = a_k thin (partial I_k) / (partial theta_k), quad (partial I) / (partial theta_0) = (1 - sum_k a_k) (partial I_0) / (partial theta_0) + sum_k a_k thin (partial I_k) / (partial theta_0), $

each from irys's edge-sampling estimator in its own branch. The image therefore constrains a feature's dimensions only in proportion to its amplitude, and at $a_k = 0$ their column is zero. We freeze a feature's dimensions when its amplitude is below 0.02.

== A continuous description length

The score of @sec:method charges each feature its program length and its parameter cost. On the relaxation the charge becomes linear in the amplitude,

$ cal(S)(a, theta) = -log p("photos" | I(a, theta)) + sum_k a_k L_k + beta sum_k a_k (1 - a_k), $

where $L_k$ is the feature's description length (its kind and its parameters, in nats) and the last term is an anneal. At $beta = 0$ the problem is a smooth fit of amplitudes and dimensions together, in which a feature's amplitude grows when the nats it saves in residual exceed the nats it costs. This is the discrete score's comparison in continuous form. As $beta$ grows, the concave penalty makes every interior amplitude cost more than either endpoint and drives the amplitudes to 0 or 1. The fit emits the base plus every feature whose amplitude rounds to 1. The search then refits and scores that program as an ordinary program, so the exact score still makes the final decision.

== Alternatives on one face

The commonest failure in @sec:results is a choice between two alternatives at one place, a hole or a counterbore. Their effects overlap, so the blend does not factor between them. We keep their amplitudes on the simplex $a_"hole" + a_"cbore" <= 1$, and the blend interpolates between the base, the hole and the counterbore. The counterbore's own dimensions give a second relaxation. A counterbore whose depth is zero, or whose outer radius equals its inner radius, is a hole, so the hole lies on the boundary of the counterbore's parameter domain. A fit that drives the depth to its bound has chosen the hole. The amplitude decides whether the step is worth its nats, and the depth decides where the step is.

== What it should and should not do

The relaxation should be good at *choosing*. Given candidate features from the search or from a network, it fits them jointly with the base and with each other, and the residual's gradient decides which ones stay. It should be poor at *discovery*. An amplitude for a hole placed where the part has none makes the residual worse, so it goes to 0, which is correct. An amplitude for a hole placed a few radii from a real hole also goes to 0, because the two holes' edges do not overlap in the image and the edge term cannot move one onto the other. Amplitudes therefore need seeds, either the residual blobs the greedy search already uses or a learned proposer. A seed that does not pay goes to 0, but every seed costs one more render per evaluation.

#figure(fig-amp(),
  caption: [#lead[Feature amplitudes.] The model image blends the render of the program without a feature and with it. The amplitude's derivative is the difference of the two renders, which is exact and needs no edge sampling. irys's edge-sampling estimator fits the feature's dimensions through the $a = 1$ branch. Schematic.],
) <fig:amp>

The implementation is a new module of the recovery crate (`crates/irys-recon/src/amp.rs`). It renders $I_0$ and each $I_k$ with their Jacobians, assembles the blended residual and Jacobian with the robust weights of the ordinary fit, adds the length and anneal terms to the gradient (the anneal is concave and left out of the Gauss–Newton matrix), and runs damped Levenberg–Marquardt with the amplitudes clamped to $[0, 1]$ over a schedule $beta in {0, 10, 100, 1000}$ nats, extended to $10^4$ and $10^5$ in the runs reported last in @sec:amp-results.

= Results <sec:results>

== Development set

We developed the method on #V("recon.parts") parts drawn from the grammar, each recovered independently from one photograph or from three photographs taken from different directions (@tab:dev). Errors are the worst dimension of each part, after the plate's quarter-turn symmetry.

#figure(
  table(
    columns: (1.9fr, 0.8fr, 0.8fr, 1fr, 1.1fr),
    align: (left, right, right, right, right),
    table.header([*Recovered*], [*1 photo*], [*3 photos*], [*+ AO grad*], [*+ path-traced fit*]),
    [every dimension within 0.5 mm], [#V("recon.1v.p05")/#V("recon.parts")], [#V("recon.3v.p05")/#V("recon.parts")], [#V("recon.3a.p05")/#V("recon.parts")], [#V("recon.pt.p05")/#V("recon.parts")],
    [every dimension within 1 mm], [#V("recon.1v.p1")/#V("recon.parts")], [#V("recon.3v.p1")/#V("recon.parts")], [*#V("recon.3a.p1")/#V("recon.parts")*], [#V("recon.pt.p1")/#V("recon.parts")],
    [the right features (topology)], [#V("recon.1v.topo")/#V("recon.parts")], [#V("recon.3v.topo")/#V("recon.parts")], [#V("recon.3a.topo")/#V("recon.parts")], [#V("recon.pt.topo")/#V("recon.parts")],
  ),
  caption: [#lead[The development set: dimensions from synthetic photographs], per part, worst dimension. With #V("recon.parts") parts the counts are coarse. The Wilson 95% interval on #V("recon.3a.p1")/#V("recon.parts") is #ci("recon.3a.p1_ci")%, against #ci("recon.1v.p1_ci")% for one photograph. "+ AO grad" differentiates the photo model's ambient occlusion instead of estimating those columns by finite differences. In that column the parts that pass at 0.5 mm have worst-dimension errors from #F("recon.3a.err_lo", 2) to #F("recon.3a.err_hi", 2) mm (median #F("recon.3a.err_med", 2)). The last column runs the final fit through irys's path tracer. It gains one part at 0.5 mm and loses one at 1 mm, which at 20 parts is no measurable difference. Across all parts the pose on the tag plane is recovered to a median #F("recon.3v.pose_med", 2) mm and yaw within #F("recon.3v.yaw_max", 2)°, and the focal length within #F("recon.3v.focal_max", 1)%.],
) <tab:dev>

A single photograph cannot separate a plate's height from a boss's, and it does not show the floor of a counterbore. Three photographs usually resolve both. @fig:examples shows three of the parts with their photographs, the fit's overlay and the programs.

#figure(fig-recon-examples(),
  caption: [#lead[Three parts, three photographs each.] Left, the synthetic photographs the recovery sees, each beside the printed tag. Right, the fit's overlay, which draws the recovered part's outline on the crop and the residual (red brighter, blue darker than the model). Part 3009 passes at 0.16 mm and 3012, with a four-hole circle and a counterbore, at 0.32 mm. A circle of four holes repeats every 90°, so 3012's recovered phase of 120.8° is the true 30.8°. Part 3016 fails. The recovery reads its first hole as a counterbore whose outer radius is the hole's, and @sec:amp-results returns to this part. Programs are in millimetres, a plate `base w d h` and then each feature with its centre and radii. FOUND omits the pose. `data/recon-examples.json`.],
) <fig:examples>

== Held-out parts

A development set overstates a method's accuracy, because the method was tuned on it. With every setting frozen, we ran the recovery once on #V("recon.n.parts") new grammar parts and on #V("recon.o.parts") parts outside the grammar. @tab:gate reports the new parts alone, and also all #V("recon.g.parts") grammar parts including the #V("recon.parts") development parts. An out-of-grammar part's truth is still a program in our language, one the generator never draws, so "topology" means the same feature list as that program. The held-out runs use the photo model, with no final path-traced fit. The outside parts are six kinds of four: holes closer to the edge than the generator allows, keyholes (two holes cut into each other), diagonal patterns, dense circles of small holes, every dimension off the 0.1 mm grid, and plates thicker than any in the grammar's range (@tab:gate).

#figure(
  table(
    columns: (1.5fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right, right),
    table.header([*Set*], [*≤ 0.5 mm*], [*≤ 1 mm*], [*topology*], [*≤ 1 mm \ given topology*]),
    [*new in-grammar parts (#V("recon.n.parts"))*], [#V("recon.n.p05")/#V("recon.n.parts") #text(size: 0.85em)[(#ci("recon.n.p05_ci"))]], [*#V("recon.n.p1")/#V("recon.n.parts")* #text(size: 0.85em)[(#ci("recon.n.p1_ci"))]], [#V("recon.n.topo")/#V("recon.n.parts") #text(size: 0.85em)[(#ci("recon.n.topo_ci"))]], [#V("recon.n.p1")/#V("recon.n.topo") #text(size: 0.85em)[(#ci("recon.n.given_ci"))]],
    [with the 20 development parts (#V("recon.g.parts"))], [#V("recon.g.p05")% #text(size: 0.85em)[(#ci("recon.g.p05_ci"))]], [#V("recon.g.p1")% #text(size: 0.85em)[(#ci("recon.g.p1_ci"))]], [#V("recon.g.topo")% #text(size: 0.85em)[(#ci("recon.g.topo_ci"))]], [#V("recon.g.given_topo")% #text(size: 0.85em)[(#ci("recon.g.given_topo_ci"))]],
    [out of grammar (#V("recon.o.parts"))], [#V("recon.o.p05")/#V("recon.o.parts")], [#V("recon.o.p1")/#V("recon.o.parts")], [#V("recon.o.topo")/#V("recon.o.parts")], [#V("recon.o.p1")/#V("recon.o.topo")],
  ),
  caption: [#lead[Held-out results.] Three photographs, ambient occlusion differentiated, no finite differences, every setting frozen before the run. Wilson 95% intervals, in percent, in parentheses. The first row is the held-out result. The second adds the 20 development parts, which score 15 of 20 and so were a favourable draw. Among the new parts with the right topology the worst dimension has a median error of #F("recon.n.med_ok", 2) mm (90th percentile #F("recon.n.p90_ok", 2)). The last column conditions on the parts the search got right, so it describes the fit and not the method. Out of grammar, off-grid dimensions pass (#V("recon.o.unround_p1") of 4 within 1 mm) and keyholes never do (#V("recon.o.overlap_p1") of 4). `data/measured.tsv`.],
) <tab:gate>

Within 1 mm falls from #V("recon.3a.p1") of #V("recon.parts") on the development set to #V("recon.n.p1") of #V("recon.n.parts") on the new parts. Wrong features account for most of the fall: #V("recon.n.topo_fail") of the #V("recon.n.parts") new parts have wrong features, and #(V("recon.n.topo") - V("recon.n.p1")) more have the right features and a dimension off by more than 1 mm. #V("recon.g.notag") of the new parts fail before the search because the detector finds no tag in one of their photographs, on clean synthetic images, and they count as failures. The plate's height comes back #F("recon.g.h_bias", 2) mm low on average, in 91% of parts, a bias we have not traced. A 1 mm threshold on plates of about 60 mm with 2 to 5 mm holes is loose for metrology, and we report no trivial baseline such as the grammar's mean part.

#figure(
  table(
    columns: (2fr, 0.7fr, 2.4fr),
    align: (left, right, left),
    table.header([*Failure*], [*Parts*], [*Our reading (untested)*]),
    [missed hole], [#V("recon.fm.missed_hole")], [a hole beside a larger feature, its residual merged into the other's],
    [counterbore read as hole], [#V("recon.fm.cb_to_hole")], [the step's floor is shading the model gets least right],
    [extra hole], [#V("recon.fm.extra_hole")], [a highlight or reflection explained as a cut],
    [hole read as counterbore], [#V("recon.fm.hole_to_cb")], [a counterbore at the hole's radius, its inner hole too small],
    [extra counterbore], [#V("recon.fm.extra_cb")], [as for extra holes, with the step buying shading],
    [sharp corner read as fillet], [#V("recon.fm.sharp_to_fillet")], [a small fillet pays for a soft silhouette],
    [extra boss], [#V("recon.fm.extra_boss")], [a highlight on the top face],
  ),
  caption: [#lead[How identification fails.] The commonest modes among the #V("recon.all.topo_fail") parts with wrong features, counted over all #V("recon.all.parts") parts (the new parts, the development parts and the out-of-grammar parts). A part can show several. A hole and counterbore confusion in either direction appears in #V("recon.all.hole_cb") of the #V("recon.all.topo_fail"), and in #V("recon.n.hole_cb") of the #V("recon.n.topo_fail") wrong among the #V("recon.n.parts") new in-grammar parts. The last column is our interpretation and has not been tested.],
) <tab:failures>

When the features are right, accuracy varies by feature. The recovery reads hole radii to a median #F("recon.err.hole_r_med", 3) mm and the radii in circular patterns to #F("recon.err.circ_r_med", 3) mm, because a pattern's holes share one radius and pool their evidence. The worst dimension is a slot's length (median #F("recon.err.slot_len_med", 2) mm, 90th percentile #F("recon.err.slot_len_p90", 2), #V("recon.err.slot_len_n_over") of 29 above 0.5 mm). A slot's ends are short arcs seen obliquely, and nothing else constrains them along the slot's axis. Counterbore depths are next (median #F("recon.err.cb_depth_med", 2) mm, 90th percentile #F("recon.err.cb_depth_p90", 2)).

== Error bars

The Fisher information gives each dimension a standard deviation. On these parts those are optimistic by a median factor of #V("recon.sig.opt") and do not rank the errors (Spearman $rho = #V("recon.sig.rho")$). The Fisher $sigma$ propagates the photographs' noise through the fit. The appearance model's bias dominates the error, and it moves an edge the same way in every photograph. One scale corrects the average coverage. Fitted on the even seeds of all 124 parts, $sigma' = #V("recon.sig.c") sigma_F$ (bootstrap #F("recon.sig.c_ci", 1)–#F("recon.sig.c_ci", 1, i: 1)) covers #V("recon.sig.cov1")% of the odd seeds' dimensions at $1 sigma'$, and the errors' heavy tails put the 95% interval at $plus.minus #F("recon.sig.k95", 2) sigma'$, which covers #V("recon.sig.cov95")%. That split includes the development parts. On the #V("recon.n.parts") new in-grammar parts alone the same procedure gives a scale of #F("recon.nsig.c", 1), #V("recon.nsig.cov1")% coverage at $1 sigma'$ and a 95% interval of $plus.minus #F("recon.nsig.k95", 2) sigma'$ (#V("recon.nsig.cov95")% coverage), with $rho = #V("recon.nsig.rho")$. The scale is therefore known only to within about 14 to 18.

This is a weak result, and it limits the instrument claim. A scale fitted to give 68% coverage gives about 68% coverage on parts from the same distribution by construction. Because $sigma_F$ does not rank the errors, $sigma'$ does not tell a well-measured dimension from a poorly measured one. It is an average error with a unit, not an error bar. We suspect the cause is bias from the appearance model, since a fit to a target rendered by the photo model itself recovers the plate height to 0.04 mm, but we have not tested that on these parts.

== Feature amplitudes: the smallest experiments <sec:amp-results>

We test the relaxation on three small problems of increasing difficulty. Each is a single run, so none of them gives a rate.

*(a) A feature that is there.* A 60×40×8 mm plate with one 4 mm-radius through-hole, rendered by the path tracer in four known views (the sim-to-sim setting of the recovery's first version). The fit starts with the right plate and an optional hole at amplitude 0.5, 2 mm off in each coordinate and 1 mm small. It passes if the amplitude goes to 1 and every dimension ends within 0.5 mm. It passes. The amplitude rises in the first four steps while the $a$-weighted edge term moves the hole's position and radius to the target. The amplitude ends at #V("amp.a.a") with every dimension within #F("amp.a.err", 3) mm, in #V("amp.a.steps") accepted steps and #V("amp.a.evals") renders (#V("amp.a.s") s on a shared machine). The amplitude stops 0.6% short of 1, because at $beta lt.eq 1000$ nats the last 0.6% costs more in residual than the anneal's $beta a (1 - a)$ saves. Rounding emits the program.

*(b) A feature that is not.* The same start against a plate with no hole. It passes if the amplitude goes to 0. The emitted program is right (the plate alone, its dimensions within 0.01 mm), but the amplitude does not reach 0, so the run fails our criterion. It falls from 0.5 to #F("amp.b.a_max0", 2) in the first step and stays there at $beta lt.eq 10$. A hole at 3% amplitude is a faint grey disc, and the disc lowers the residual by about ten nats. The model's noise differs from the target's (the target is rendered at 64 samples per pixel, the model at 16), and the disc fits part of that difference. The anneal at $beta = 1000$ lowers the amplitude to #F("amp.b.a", 3), and rounding emits no hole. The same failure can occur at any scale. Between the endpoints the blend adds a free image component, and the fit uses it to explain whatever the model cannot. We then extended the anneal to $beta = 10^4$ and $10^5$ nats. This changes the schedule after seeing a failure, on the same two problems, so it is a fix and not a test. With it, (b)'s amplitude reaches #F("amp.bl.a", 1) at $beta = 10^4$, giving up about #V("amp.bl.dnll") nats of residual, and (a)'s reaches #F("amp.al.a", 2) with every dimension within #F("amp.al.err", 3) mm. Both runs then meet the criteria. The anneal must reach the size of the residual that a partial feature can absorb, which here is larger than the feature's description length.

*(c) Hole or counterbore.* Part 3016 of the development set, which the greedy search got wrong in the run of @fig:examples: its 3.8 mm hole is recovered as a counterbore whose outer radius is the hole's and whose inner hole is too small. We take the search's own program, replace that counterbore by two alternatives at amplitudes 0.5 and 0.5 on the simplex, a through-hole of the counterbore's outer radius and the counterbore as found, and let the relaxation choose, using the photo model, robust noise model and appearance of the search's final fit. The relaxation chooses the hole. Its amplitude goes to #F("amp.c.a_hole", 0) and the counterbore's to #F("amp.c.a_cb", 0), with the hole's radius at #F("amp.c.r", 2) mm against the true 3.80 and its centre within #F("amp.c.pos_err", 2) mm, in #V("amp.c.s") s and #V("amp.c.evals") renders. The emitted program has the right topology. One caveat limits what this shows. On this run the greedy search found the hole itself (#V("amp.c.v1_s") s), although the earlier run on another machine had read a counterbore. We therefore built the alternative from the earlier run's wrong reading, a counterbore of the hole's outer radius with that run's inner radius and depth. So the greedy answer differs between two runs on the same photographs, and we have not measured how often. The relaxation is meant to remove that instability, but this experiment does not show that it does. It shows one hand-built choice on one development part.

*Not yet run.* The experiment that would test the relaxation is the held-out set with the search's final choice made by amplitudes, against the greedy choice, on fresh parts and several seeds. We have not run it, and until we do the relaxation is a proposal. #todo[amplitude finals against greedy on fresh held-out parts, several seeds each.]

= Toward real objects (not yet done) <sec:real>

Every result above compares the recovery with a known program, because we rendered the photographs from the programs we try to recover. The next reference is a printed part measured with calipers. The kit for that experiment exists (a 50 mm tag sheet, five test parts exported for printing, and shooting and caliper instructions), and we have not run it. #todo[print at least 20 parts, photograph each three times with a phone, recover, and compare with calipers.]

Real objects also need a larger grammar. The cover shows a 3D-printed enclosure for a small screen. To describe it, a program needs:

- *A shell.* A box whose edges each have their own radius (large on the top and front, small on the base), hollowed to a wall thickness. The plate grammar has one corner treatment for four vertical edges.
- *Features on any face.* The bezel, the grille and the ports are on the front, not the top. Every feature needs a host face and a frame on that face, and the search needs proposals for every visible face.
- *A recess feature.* The screen sits in a rectangular pocket with its own corner radius and depth, which is a counterbore generalized to a rounded rectangle.
- *Patterns as one feature.* The grille is about 150 small holes on a staggered grid. Written as 150 holes it costs 150 times the program length of one hole, more than it saves in residual. Written as one pattern (pitch, stagger, extent, hole radius) it costs a few nats, and its holes share one radius, as the circular patterns' holes already do (@sec:results).
- *Masks for what the model cannot render.* The screen is a black mirror that reflects the room, and the shading model has no texture for the print's layer lines and seams. The recovery should down-weight such regions, as it already does for the tag, with a weight it estimates from the residual's local dispersion or the material's glossiness.

A larger grammar produces more proposals per round and more near-ties between them, such as a recess or a through-cut, or a grille of round holes or of hexagons. A greedy search fails on near-ties, and a relaxation that fits the alternatives together should not. Amplitudes do not help discovery, which is the larger problem on a real object. The search must first propose a feature on the right face before an amplitude can choose it.

= Limitations <sec:limits>

- *Synthetic photographs.* The only photographs in this paper are rendered, by the renderer the method is built on (@sec:real).
- *No baselines.* We compare against no other method: not a BIC-scored search, a silhouette-only fit, multi-view stereo followed by primitive fitting, or a learned image-to-CAD model. We also do not ablate the noise scaling, the beam width or the program prior beyond the columns of @tab:dev.
- *One family of parts.* The out-of-grammar parts are small departures from it. Keyholes, which no single feature describes, fail every time.
- *Identification is weak.* The features are right on #V("recon.n.topo") of the #V("recon.n.parts") held-out parts, and we have tested the amplitude relaxation only on three small problems (@sec:amp-results).
- *The error bars are not yet error bars.* The Fisher $sigma$ does not rank the errors, and one empirical scale fixes only the average coverage (@sec:results). The same Fisher term biases the score.
- *Bias.* The plate's height comes back #F("recon.g.h_bias", 2) mm low on average for a reason we have not found.
- *Compute.* On the development set a part took a mean of #V("recon.3a.s_part") s on a 16-core laptop with the machine to itself. The 100 in-grammar parts took a median of #V("recon.g.s_part_med") s of process time each, most of them on a 24-core machine running six processes of four threads at once, which is about two minutes of wall time per part there. The relaxation adds one render per optional feature to every evaluation.

= Reproducibility <sec:repro>

The recovery is the `irys-recon` crate of irys, open source under Apache-2.0. Each row of `data/measured.tsv` names the irys report and commit that produced it. The 124-part run is irys commit `812dc62` (`docs/recon-v1-gate100-report.md` and its CSVs), regenerated by `scripts/recon_gate_stats.py`. The amplitude experiments are `examples/recon_amp.rs` on irys branch `claude/recon-amplitudes`, run once each on a 24-core Linux machine. They write their traces to `out/recon_amp/`, which we copied to `data/amp-*.json`.

= Conclusion

The recovery measures well when it identifies the features, so identification is the next problem. On #V("recon.n.parts") held-out synthetic parts, a description-length search through a differentiable renderer reads every dimension of #V("recon.n.p1") parts to within a millimetre. It finds the right features on #V("recon.n.topo"), and #V("recon.n.p1") of those measure within a millimetre. The largest group of wrong features is a hole confused with a counterbore (#V("recon.n.hole_cb") of #V("recon.n.topo_fail") failures), and on one such part the greedy search gave different answers in two runs. Feature amplitudes give that choice a gradient. On three small problems the relaxation fits a feature it is given, removes a feature the target lacks once the anneal reaches $10^4$ nats, and chooses the hole in one hand-built comparison. These are single runs. The paper still needs the amplitude run on fresh held-out parts, baselines, error bars that rank the errors, and photographs of real parts.

#heading(outlined: true, numbering: none)[References]
#show bibliography: it => { show "?.": "?"; show "!.": "!"; it }
#bibliography("refs.bib", style: "nature", title: none)
