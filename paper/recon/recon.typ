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
  let mono-s(body, fill: c-label) = text(font: mono, size: 5.6pt, fill: fill, body)
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
    rect((0, 0), (width, height * 0.55), stroke: none,
      fill: gradient.linear(c-bg.transparentize(100%), c-bg.transparentize(15%), c-bg, angle: 90deg))
  })
}

// ---- title page -----------------------------------------------------------------
#if not web {page(margin: 0in, background: place(top, fig-cover(width: 21.59)))[
  #set par(leading: 0.5em)
  #v(1fr)
  #pad(x: 0.75in, bottom: 0.65in)[
    #grid(columns: (auto, 1fr, auto), column-gutter: 0.8em, align: horizon,
      caps(fill: c-text)[Municipal Robotics · Research],
      line(length: 100%, stroke: 0.5pt + c-line-hi),
      caps[November 2026 · Draft])
    #v(0.35in)
    #move(dx: -0.045 * s-display, text(font: sans-sb, size: s-display * 1.2, tracking: -0.025em)[Seeing Is\ Measuring])
    #v(0.5em)
    #line(length: 22%, stroke: 2pt + c-label)
    #v(0.7em)
    #text(size: s-lg, fill: c-label)[Editable CAD programs from photographs: a feature must pay for itself]
    #v(0.45in)
    #grid(columns: (1fr, auto), align: (left + bottom, right + bottom),
      caps[Cam Pedersen · Municipal Robotics],
      image("images/muni-logo.svg", width: 0.7in))
    #v(0.2in)
    #text(size: s-xs, fill: c-label)[Cover: a printed enclosure with a rounded shell, a recessed bezel, a speaker grille and two round ports. Today's grammar cannot write it down (@sec:real).]
  ]
]}

#let abstract-text = [
  A photograph of a part contains its design: which features it has, and their dimensions. We recover both as an editable CAD program, a plate and a list of holes, counterbores, slots, bosses and patterns, each with its dimensions, from three phone photographs beside a printed tag. A program is scored by its description length in nats (residual, parameter cost and program length in one unit), so an edit that adds a feature is kept only if the feature pays for itself. Inside each edit, the dimensions are fitted with a Jacobian from irys's edge-sampling estimator; the companion paper describes that renderer.

  On a held-out gate of #V("recon.g.parts") synthetic parts drawn from the grammar, the recovery reads every dimension to within 1 mm on #V("recon.g.p1") (Wilson 95% interval #ci("recon.g.p1_ci")%). The miss is almost all identification: when the features are right, #V("recon.g.given_topo")% of parts measure within 1 mm, with a median worst-dimension error of #F("recon.g.med_ok", 2) mm. The commonest error is a hole read as a counterbore or the reverse (#V("recon.g.hole_cb") parts). The Fisher error bars are optimistic; one scale, $sigma' = #V("recon.sig.c") sigma_F$, fitted on half the parts, covers #V("recon.sig.cov1")% of the other half's dimensions at $1 sigma'$.

  Greedy search makes identification a sequence of yes-or-no bets. We propose *feature amplitudes*, a continuous relaxation over which features a program has: each optional feature gets an amplitude $a in [0, 1]$, the image blends the renders without and with it, the derivative with respect to $a$ is exact, the description length becomes $a L$, and an anneal drives every amplitude to 0 or 1 before the ordinary program is emitted. #todo[one sentence with the results of experiments (a)–(c) and the amplitude finals on the gate.] We close with what the grammar must learn to describe a real printed enclosure.
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

A drawing of a part is a short program. "A 74 by 67 by 17 mm plate with three 3 mm holes on a 17 mm circle" is a dozen numbers and a few words, and from it anyone can make the part. A photograph of the same part is millions of pixels. Turning the photograph back into the program is two problems at once. One is *identification*: which features the part has. The other is *measurement*: their dimensions. Measurement is continuous and has gradients; identification is discrete and does not.

The companion paper @pedersen2026irys built the measuring half: irys, a differentiable spectral path tracer whose edge-sampled gradients reach the dimensions of a CAD model, and whose replay is bit-exact so a gradient that fails its test is a bug and not noise. This paper is the identifying half, and the bridge between them. We search over editable CAD programs, fit each candidate's dimensions through irys's estimator, and choose between candidates by *description length* @rissanen1978mdl @grunwald2007mdl: the number of nats it takes to say the photographs given the program, plus the program and its parameters. A feature is worth adding exactly when it shortens that total. It has to pay for itself.

On parts the grammar can describe, the measuring half is good and the identifying half is not. On a held-out gate of #V("recon.g.parts") synthetic parts, #V("recon.g.given_topo")% of parts whose features are identified correctly measure within 1 mm, but only #V("recon.g.topo")% are identified correctly. The commonest confusion is between a hole and a counterbore. That is not a surprise from a greedy search: each edit is a yes-or-no bet taken on the evidence of one fit, and a counterbore whose floor the photographs barely show and a hole of the counterbore's outer radius are nearly the same image. The decision deserves gradients too.

The second half of the paper gives it some. *Feature amplitudes* relax the choice of features to a continuous one. Each optional feature gets an amplitude $a in [0, 1]$; the model image is the render without the feature plus $a$ times the difference the feature makes; the description length charges $a L$; and an anneal drives each amplitude to an endpoint. The derivative with respect to an amplitude is exact and costs one extra render, with no edge sampling. Its expected strength is choosing among features someone has proposed, the hole-or-counterbore question in particular, since a counterbore of depth zero is a hole. Its expected weakness is discovery: an amplitude placed where there is no feature has nothing to pull it to one that exists.

Our contributions are:

- *Recovery by description length through a differentiable renderer.* A search over a CAD grammar whose every candidate is fitted by Levenberg–Marquardt with an edge-sampled Jacobian and scored in nats, with three photographs and a printed tag as the only input (@sec:method).
- *An honest gate.* A development set of #V("recon.parts") parts, a held-out gate of #V("recon.g.parts") in-grammar and #V("recon.o.parts") out-of-grammar parts with every default frozen, per-feature error, failure modes, and error bars calibrated against the gate's own errors (@sec:results).
- *Feature amplitudes*, a continuous relaxation over the discrete part of a CAD program with an exact amplitude gradient and a continuous description length, and the smallest experiments that test it (@sec:amp, @sec:amp-results).
- *A path to real objects*: what a printed enclosure needs from the grammar, and the printed-part experiment that will replace the synthetic photographs (@sec:real).

== Scope and limits

- *The photographs are synthetic.* They are rendered by irys's OpenPBR scene kernel with a phone camera model. No number in this paper comes from a real photograph yet (@sec:real).
- *The grammar is a plate.* One extruded block with a corner treatment and features cut into or standing on its top face. The out-of-grammar parts of @tab:gate test its edges, not a different family.
- *The search is the method's weakest part*, and the amplitude relaxation addresses only its choosing, not its proposing.
- *Compute.* A part costs minutes of CPU (@sec:results); nothing here runs on the GPU path of the companion paper except the final path-traced fit.

= Related work

*Inverse CAD and program synthesis.* Recovering an editable CAD description is usually posed as program synthesis. CSGNet parses shapes into CSG programs with a recurrent network @sharma2018csgnet; InverseCSG converts meshes to compact CSG trees with a solver-based synthesizer @du2018inversecsg; Szalinski rewrites flat CSG into programs with loops by equality saturation @nandi2020szalinski; DeepCAD generates sketch-and-extrude sequences @wu2021deepcad; ShapeAssembly writes part-assembly programs @jones2020shapeassembly; Point2CAD recovers BRep surfaces from point clouds @liu2024point2cad, and CAD-Recode writes CAD code from point clouds with a language model @rukhovich2024cadrecode. Ellis et al. infer graphics programs from images by proposing primitives and synthesizing a program over them @ellis2018graphics, and DreamCoder learns a library of program components alongside the search @ellis2021dreamcoder. These methods take meshes, point clouds or clean drawings, or learn a prior from a dataset. Ours starts from photographs, scores each candidate by rendering it, and reports error bars on every dimension.

*Measurement from images.* Close-range photogrammetry measures manufactured objects from calibrated images, usually by triangulating targets or features and adjusting cameras and points together @luhmann2019photogrammetry. We share its tools (a calibration target, bundle-adjustment-style least squares, Fisher-information error estimates) but fit a parametric model of the whole part to its pixels rather than to sparse points, so a hole's diameter is read from its outline and shading rather than from markers.

*Relaxing discrete structure.* Continuous relaxations of a discrete choice are common where the choice has no gradient. DARTS mixes candidate operations with softmax weights and anneals to one @liu2019darts; the Gumbel-softmax samples from a relaxed categorical @jang2017gumbel; DiffCSG differentiates CSG by rasterization so the boolean structure can be optimized @yuan2024diffcsg. The amplitude's length term $a L$ is an $ell_1$ penalty on a selection variable, the relaxation of a count that the lasso made familiar @tibshirani1996lasso. What is particular here is the image: a feature's effect on the render is local and nearly additive, so the blend factors per feature and its gradient is exact, and the description length gives the penalty its weight in the same unit as the residual, with no tuning knob.

*Differentiable rendering.* Edge sampling @li2018edge and path replay @vicini2021prb, and their implementation in irys, are described in the companion paper @pedersen2026irys; Mitsuba 3 @jakob2022mitsuba3 is the closest general system. CAD parameters upstream of the mesh are differentiated by the BRep kernel of @pedersen2026vcad.

= The recovery <sec:method>

== Programs and their description length

A program is a plate (width, depth, height and a corner treatment: sharp, a fillet or a chamfer) and an ordered list of features on its top face: through-holes, counterbores, through-slots along either axis, bosses, linear hole patterns and circular hole patterns, each with its centre and dimensions, plus the part's pose on the table, $(x, y, "yaw")$. The program is built by the vcad kernel and tessellated for rendering. A program is scored by its description length in nats,

$ "score"("program", theta) = underbrace(-log p("photos" | "render"("program", theta)), "residual") + underbrace(1/2 log det F(theta), "parameters") + underbrace(-log p("program"), "program") $

the residual under a robust (Huber) noise model, a Laplace parameter cost from the Fisher information $F = J^top Sigma^(-1) J$, and the program's own length under a uniform grammar prior: a few nats for each feature and its kind. Every term is in nats, so there is no weight to tune between fit and complexity. A feature that explains ten pixels of noise costs more in program and parameters than it saves in residual, and is refused.

The noise model matters to the score more than to the fit. The residual of a good fit is not white: what the appearance model cannot do (a window's reflection, interreflection, a tone curve) is smooth across many pixels, and counting those pixels as independent would overcount the nats such structure is worth, so features would be bought to explain shading. We scale the noise variance by the residual's integrated autocorrelation area, measured on the table away from the part, the number of pixels per independent one.

== Search

The search starts from the best box: one silhouette trades a plate's depth against its height, so a box is fitted per band of heights and each is lit and fitted on the image; the lowest robust cost wins. It then proposes edits: add a feature at a blob of the residual, remove a feature, turn a hole into a counterbore or a slot, merge holes into a pattern, change the corner treatment. Each edit is fitted (below) and scored, a beam of two is kept, and the best four distinct programs are refitted at full resolution, where the final choice is made. An edit is kept only if it shortens the description (@fig:recon). When no edit does, the search stops and reports the dimensions with their error bars.

#figure(fig-recon(),
  caption: [#lead[The recovery loop.] The recovery edits an editable CAD program, fits each edit's dimensions with irys's edge-sampling Jacobian, scores it in nats, and keeps it only if the description of the photographs gets shorter. A feature has to pay for itself. Bar lengths are schematic.],
) <fig:recon>

== Fitting the dimensions

Inside each edit, Levenberg–Marquardt fits the continuous parameters (dimensions and pose) over a short blur homotopy, with a silhouette-distance term at the coarse levels and a chromatic coverage term throughout: the part's colour against the backdrop's, projected onto the line between them, is an observed coverage that shading leaves alone. The Jacobian is irys's primary edge-sampling estimator applied to every vertex's velocity under each parameter, the same estimator the companion paper validates against central differences, plus the moving-shadow (secondary) term for the key light.

The renderer inside the search is not the path tracer. A search makes thousands of fits, so it uses a deterministic *photo model*: a G-buffer with closed-form OpenPBR shading, spherical-harmonic environment light, one fitted key light with soft shadows, and ambient occlusion from 16 fixed rays per point. It is noise-free and about six times cheaper per evaluation. After the search, the appearance is refitted under the path tracer and the final fit runs on the path-traced residual, with path replay for the radiance and per-vertex edge sampling for the geometry, so the reported program, score and dimensions are the path tracer's (@tab:dev, last column).

== A derivative the search was missing

With three photographs the main remaining error on the development set was a confusion between holes and counterbores. We traced one case: the correct program reached the full-resolution finalists and lost by 27 nats to a counterbore whose depth never moved from its starting value. A counterbore's step shows in a photograph mostly as ambient occlusion on its floor, and the photo model's occlusion was a fixed set of 16 rays per point: a step function of the geometry, with zero derivative almost everywhere. On a flat receiver those 16 directions are fixed in the world, so each is a directional light of weight $1 \/ 16$, and its derivative is the moving-shadow term the key light already had, with the receiver allowed to move too (a counterbore's floor moves with its depth). With that term the Jacobian's column for a counterbore's depth goes from cosine 0.88 against central differences to 0.97, every other column improves or holds, and the finite-difference columns the search had used for occluded parameters can go. The development set then reaches #V("recon.3a.p1") of #V("recon.parts") parts within 1 mm with no finite differences at all, in #V("recon.3a.s_part") s per part against #V("recon.3v.s_part") s.

== Camera and photographs

A printed tag36h11 tag beside the part fixes each camera's pose, its focal length (with the EXIF 35 mm-equivalent focal as a 2% prior) and the metric scale; its corners are refined on linear light, since on sRGB values the edge shifts toward the dark side. The part's pose is shared across the photographs; each photograph gets its own appearance. The test photographs are synthetic phone photographs: irys's OpenPBR scene kernel renders each part in PLA of one of six colours beside the tag sheet on grey paper, under a captured environment turned at random or a synthetic room with a window and a ceiling panel, plus a key light, at 2016×1512; then a camera model adds defocus, shot and read noise, a tone curve and JPEG compression, and writes an EXIF focal length.

= Feature amplitudes <sec:amp>

The search above is greedy over a discrete space. Every edit is a bet: fit the candidate, compare two numbers, keep one program. When two candidates explain the photographs almost equally well, which one wins depends on where each fit happened to start and stop, and the loser is never seen again. This section makes the choice continuous, so the fit that measures the features also chooses them.

== The relaxation

Let a program be a base $P_0$ (the plate, its pose and any features already settled) and $K$ optional features $f_1, dots, f_K$ with dimensions $theta_k$. Give each optional feature an amplitude $a_k in [0, 1]$ and render

$ I(a, theta) = I_0(theta_0) + sum_(k=1)^K a_k thin (I_k (theta_0, theta_k) - I_0 (theta_0)) $

where $I_0$ is the render of the base and $I_k$ the render of the base with feature $k$ added. At $a_k in {0, 1}$ the blend is exactly the render of an ordinary program whenever the features' effects on the image do not overlap, which for cuts on a plate is the usual case: two holes far apart change disjoint pixels, and the change one makes does not depend on whether the other is there. Between the endpoints the blend is not the render of any solid. It does not need to be; it is a path between two programs along which the score can be differentiated. The silhouette (coverage) channels blend the same way.

== Gradients

The derivative with respect to an amplitude is the difference the feature makes,

$ (partial I) / (partial a_k) = I_k - I_0, $

which is exact and costs nothing beyond the two renders the blend already needs: no edge sampling, no finite difference, no step size. The dimensions' columns are the blend of the ordinary Jacobians,

$ (partial I) / (partial theta_k) = a_k thin (partial I_k) / (partial theta_k), quad (partial I) / (partial theta_0) = (1 - sum_k a_k) (partial I_0) / (partial theta_0) + sum_k a_k thin (partial I_k) / (partial theta_0), $

each from irys's edge-sampling estimator in its own branch. A feature's own dimensions therefore see the image only in proportion to its amplitude, and at $a_k = 0$ their column vanishes; we freeze them below a small amplitude.

== A continuous description length

The score of @sec:method charges each feature its program length and its parameter cost. On the relaxation the charge becomes linear in the amplitude,

$ cal(S)(a, theta) = -log p("photos" | I(a, theta)) + sum_k a_k L_k + beta sum_k a_k (1 - a_k), $

where $L_k$ is the feature's description length (its kind and its parameters, in nats) and the last term is an anneal. At $beta = 0$ the problem is a smooth fit of amplitudes and dimensions together, in which a feature's amplitude grows exactly when the nats it saves in residual exceed the nats it costs, the same trade as the discrete score made continuous. As $beta$ grows, the concave penalty makes every interior amplitude more expensive than either endpoint, and the amplitudes are driven to 0 or 1. The program emitted at the end is the base plus every feature whose amplitude is 1, and it is then refitted and scored as an ordinary program, so the relaxation proposes and the exact score still decides.

== Alternatives on one face

The case the gate cares most about is two alternatives at one place: a hole, or a counterbore. Their effects overlap by construction, so the blend does not factor between them; we keep their amplitudes on the simplex $a_"hole" + a_"cbore" <= 1$, and the blend interpolates between the base, the hole and the counterbore. There is a second, more geometric relaxation hidden here. A counterbore whose depth is zero, or whose outer radius equals its inner one, is a hole. The counterbore's own dimensions already contain the hole as a face of their domain, and a fit that drives the depth to its bound has answered the question. The two relaxations are complementary: the amplitude asks whether the step is worth its nats; the depth asks where the step is.

== What it should and should not do

The relaxation is good at *choosing*. Given candidate features proposed by the search (or by a network), it fits them jointly with the base and each other, and lets the residual decide which survive, with gradients for the decision. It is not good at *discovery*. An amplitude for a hole placed where the part has none gets $partial I \/ partial a = I_k - I_0 eq.not 0$ but the wrong sign, so it correctly goes to 0; an amplitude for a hole placed a few radii from a real one also goes to 0, because the image term has no overlap to pull its position across. Its dimensions' gradient is the edge term of a feature whose edges are nowhere near the target's. So amplitudes need seeds: the residual blobs the greedy search already uses, or a learned proposer. Over-seeding is cheap in principle, since each seed that does not pay goes to 0, but each costs a render per evaluation.

#figure(fig-amp(),
  caption: [#lead[Feature amplitudes.] The model image blends the render of the program without a feature and with it. The amplitude's derivative is the difference of the two renders, exact and free of edge sampling; the feature's dimensions are fitted through the $a = 1$ branch with irys's edge-sampling estimator. Schematic.],
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
  caption: [#lead[The development set: dimensions from synthetic phone photographs], per part, worst dimension. With #V("recon.parts") parts the counts are coarse: the Wilson 95% interval on #V("recon.3a.p1")/#V("recon.parts") is #ci("recon.3a.p1_ci")%, against #ci("recon.1v.p1_ci")% for one photograph. "+ AO grad" differentiates the photo model's ambient occlusion instead of estimating those columns by finite differences; there the parts that pass at 0.5 mm have worst-dimension errors from #F("recon.3a.err_lo", 2) to #F("recon.3a.err_hi", 2) mm (median #F("recon.3a.err_med", 2)). The last column runs the final fit through irys's path tracer; it matches the photo model within one part at every threshold. Across all parts the pose on the tag plane is recovered to a median #F("recon.3v.pose_med", 2) mm and yaw within #F("recon.3v.yaw_max", 2)°, and the focal length within #F("recon.3v.focal_max", 1)%.],
) <tab:dev>

A single photograph cannot separate a plate's height from a boss's, or see the floor of a counterbore; three photographs mostly can. @fig:examples shows three of the parts with their photographs, the fit's overlay and the programs.

#figure(fig-recon-examples(),
  caption: [#lead[Three parts, three photographs each.] Left, the synthetic phone photographs the recovery sees, each beside the printed tag; right, the fit's overlay: the recovered part's outline on the crop, and the residual (red brighter, blue darker than the model). Part 3009 passes at 0.16 mm and 3012, with a four-hole circle and a counterbore, at 0.32 mm. Part 3016 fails: its first hole is read as a counterbore whose outer radius is the hole's, the confusion @sec:amp-results returns to. Programs in millimetres: a plate `base w d h`, then each feature with its centre and radii; FOUND omits the pose. `data/recon-examples.json`.],
) <fig:examples>

== The held-out gate

Development sets flatter. With every default frozen, we grew the gate to #V("recon.g.parts") grammar parts and #V("recon.o.parts") parts outside it, six kinds of four: holes closer to the edge than the generator allows, keyholes (two holes cut into each other), diagonal patterns, dense circles of small holes, every dimension off the 0.1 mm grid, and plates thicker than any in the grammar's range (@tab:gate).

#figure(
  table(
    columns: (1.5fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right, right),
    table.header([*Set*], [*≤ 0.5 mm*], [*≤ 1 mm*], [*topology*], [*≤ 1 mm \ given topology*]),
    [in grammar (#V("recon.g.parts"))], [#V("recon.g.p05")% #text(size: 0.85em)[(#ci("recon.g.p05_ci"))]], [*#V("recon.g.p1")%* #text(size: 0.85em)[(#ci("recon.g.p1_ci"))]], [#V("recon.g.topo")% #text(size: 0.85em)[(#ci("recon.g.topo_ci"))]], [#V("recon.g.given_topo")% #text(size: 0.85em)[(#ci("recon.g.given_topo_ci"))]],
    [out of grammar (#V("recon.o.parts"))], [#V("recon.o.p05")/#V("recon.o.parts")], [#V("recon.o.p1")/#V("recon.o.parts")], [#V("recon.o.topo")/#V("recon.o.parts")], [#V("recon.o.p1")/#V("recon.o.topo")],
  ),
  caption: [#lead[The held-out gate.] Three photographs, AO differentiated, no finite differences, every default frozen before the run. Wilson 95% intervals in parentheses. The first 20 grammar parts are the development set and reproduce its counts exactly; the #(V("recon.g.parts") - V("recon.parts")) new parts score #V("recon.g.new_p1") within 1 mm, so the development set was a favourable draw. Among parts with the right topology the worst dimension has a median error of #F("recon.g.med_ok", 2) mm (90th percentile #F("recon.g.p90_ok", 2)). Out of grammar, off-grid dimensions pass (#V("recon.o.unround_p1") of 4 within 1 mm); keyholes never do (#V("recon.o.overlap_p1") of 4). `data/measured.tsv`.],
) <tab:gate>

Within 1 mm falls from #V("recon.3a.p1") of #V("recon.parts") to #V("recon.g.p1") of #V("recon.g.parts"). The fall is almost entirely identification: given the right features, #V("recon.g.given_topo")% of parts measure within 1 mm. #V("recon.g.notag") parts fail before the search because the tag is not found in one of their photographs; they count as failures. The plate's height comes back #F("recon.g.h_bias", 2) mm low on average, a bias we have not traced.

#figure(
  table(
    columns: (2fr, 0.7fr, 2.4fr),
    align: (left, right, left),
    table.header([*Failure*], [*Parts*], [*What it looks like*]),
    [missed hole], [#V("recon.fm.missed_hole")], [a hole beside a larger feature, its residual merged into the other's],
    [counterbore read as hole], [#V("recon.fm.cb_to_hole")], [the step's floor is shading the model gets least right],
    [extra hole], [#V("recon.fm.extra_hole")], [a highlight or reflection explained as a cut],
    [hole read as counterbore], [#V("recon.fm.hole_to_cb")], [a counterbore at the hole's radius, its inner hole too small],
    [extra counterbore], [#V("recon.fm.extra_cb")], [as for extra holes, with the step buying shading],
    [sharp corner read as fillet], [#V("recon.fm.sharp_to_fillet")], [a small fillet pays for a soft silhouette],
    [extra boss], [#V("recon.fm.extra_boss")], [a highlight on the top face],
  ),
  caption: [#lead[How identification fails] on the 124-part gate, the commonest modes; a part can show several. Hole and counterbore confusions in either direction account for #V("recon.g.hole_cb") parts. irys `docs/recon-v1-gate100-report.md`.],
) <tab:failures>

Measurement, when identification is right, is uneven by feature. Hole radii are read to a median #F("recon.err.hole_r_med", 3) mm and the radii in circular patterns to #F("recon.err.circ_r_med", 3) mm, because a pattern's holes share one radius and pool their evidence. The worst dimension is a slot's length (median #F("recon.err.slot_len_med", 2) mm, 90th percentile #F("recon.err.slot_len_p90", 2), #V("recon.err.slot_len_n_over") of 29 above 0.5 mm): its ends are short arcs seen obliquely, and along the slot's axis nothing else constrains them. Counterbore depths are next (median #F("recon.err.cb_depth_med", 2) mm, 90th percentile #F("recon.err.cb_depth_p90", 2)).

== Error bars

The Fisher information gives each dimension a standard deviation. On this gate those are optimistic by a median factor of #V("recon.sig.opt") and do not rank the errors (Spearman $rho = #V("recon.sig.rho")$): the Fisher $sigma$ is the photographs' noise carried through the fit, and what dominates the error is the appearance model's bias, which pulls an edge the same way in every photograph. One scale fixes the coverage. Fitted on the even seeds, $sigma' = #V("recon.sig.c") sigma_F$ (bootstrap #F("recon.sig.c_ci", 1)–#F("recon.sig.c_ci", 1, i: 1)) covers #V("recon.sig.cov1")% of the odd seeds' dimensions at $1 sigma'$, and the errors' heavy tails put the 95% interval at $plus.minus #F("recon.sig.k95", 2) sigma'$, which covers #V("recon.sig.cov95")%. The recovery reports $sigma'$. That the scale is so large, and the same for every feature, says the bias is in the shading and not in any one parameter; a better appearance model should shrink it, and that is the test of one.

== Feature amplitudes: the smallest experiments <sec:amp-results>

We test the relaxation where it should be strongest, in three steps of increasing difficulty, before any gate. All three use the code of @sec:amp at irys `claude/recon-amplitudes`.

*(a) A feature that is there.* A 60×40×8 mm plate with one 4 mm-radius through-hole, rendered by the path tracer in four known views (the sim-to-sim setting of the recovery's first version). The fit starts with the right plate and an optional hole at amplitude 0.5, 2 mm off in each coordinate and 1 mm small. It passes if the amplitude goes to 1 and every dimension ends within 0.5 mm. It passes. The amplitude rises in the first four steps, while the hole's position and radius walk to the target through the $a$-weighted edge term, and ends at #V("amp.a.a") with every dimension within #F("amp.a.err", 3) mm, in #V("amp.a.steps") accepted steps and #V("amp.a.evals") renders (#V("amp.a.s") s on a shared machine). The amplitude stops just short of 1: the last 0.6% would cost more in residual than the anneal's $beta a (1 - a)$ saves at $beta lt.eq 1000$ nats, so the program is emitted by rounding, as designed.

*(b) A feature that is not.* The same start against a plate with no hole. It passes if the amplitude goes to 0. The emitted program is right (the plate alone, its dimensions within 0.01 mm), but by our own criterion the amplitude does not reach 0. It falls from 0.5 to #F("amp.b.a_max0", 2) in the first step and settles there at $beta lt.eq 10$: a faint grey disc, 3% of a hole, buys about ten nats of residual, because the model's noise and the target's differ (the target is rendered at 64 samples per pixel, the model at 16) and a free disc can fit a little of that difference. The anneal at $beta = 1000$ pushes it to #F("amp.b.a", 3), and rounding emits no hole. This is the relaxation's characteristic failure in miniature: between the endpoints a feature is not a feature but a free image component, and it will be used to explain whatever the model cannot. Extending the anneal to $beta = 10^4$ and $10^5$ nats fixes both runs: (b)'s amplitude reaches #F("amp.bl.a", 1) at $beta = 10^4$, giving up about #V("amp.bl.dnll") nats of residual, and (a)'s reaches #F("amp.al.a", 2) with every dimension within #F("amp.al.err", 3) mm. Both now pass by the strict criterion. The schedule needs to reach the scale of the ghost's residual gain, not the scale of the feature's length.

*(c) Hole or counterbore.* Gate part 3016, which the greedy search gets wrong (@fig:examples): its 3.8 mm hole is recovered as a counterbore whose outer radius is the hole's and whose inner hole is too small. We take the search's own program, replace that counterbore by two alternatives at amplitudes 0.5 and 0.5 on the simplex, a through-hole of the counterbore's outer radius and the counterbore as found, and let the relaxation choose, under the photo model, robust noise and appearance of the search's final fit. #todo[result of (c)]

*The gate with amplitude finals.* #todo[rerun the 100-part in-grammar gate with the search's final choice made by amplitudes (each finalist's optional features relaxed, seeded from the search's own proposals) against greedy description length, on mew; report ≤ 1 mm, topology and hole↔counterbore confusions with Wilson intervals, and add the rows `recon.amp.g.*` to `data/measured.tsv`.]

= Toward real objects <sec:real>

Everything above is read against a known standard: the photographs are rendered from the very programs we try to recover. The next standard is a printed part and a pair of calipers. The kit for that experiment exists (a 50 mm tag sheet, five gate parts exported for printing, shooting and caliper instructions) and the experiment has not been run. #todo[M2: print five gate parts, photograph each three times beside the tag with a phone, recover, and measure with calipers; the caliper table becomes this section's centre figure, and the "photographs are synthetic" limit comes out of the scope.]

The harder question is what real objects ask of the grammar. The cover shows one: a 3D-printed enclosure for a small screen. To write it down a program needs, in order of what the photograph shows,

- *a shell, not a plate.* A box whose edges each have their own radius (large on the top and front, small on the base), hollowed to a wall thickness. The plate grammar has one corner treatment for four vertical edges.
- *features on any face.* The bezel and the grille are on the front, not the top; the ports pierce the front too. Every feature needs a host face and a frame on it, and the search a proposal per visible face.
- *a recess as a first-class feature.* The screen sits in a rectangular pocket with its own corner radius and depth, which is a counterbore generalized to a rounded rectangle.
- *patterns as one feature.* The grille is about 150 small holes on a staggered grid. As a hundred and fifty holes it costs a hundred and fifty times the program length and can never pay for itself; as one pattern (pitch, stagger, extent, hole radius) it is a handful of nats, and its holes pool their evidence as the circular patterns' radii already do (@sec:results).
- *masks for what the model cannot render.* The screen is a black mirror reflecting the room, and the layer lines and seams of the print are texture the shading model does not have. Such regions should be down-weighted, as the tag already is, by a weight the recovery estimates (the residual's local dispersion, or the material's glossiness) rather than one drawn by hand.

Feature amplitudes fit this growth naturally. A larger grammar means more proposals per round and more near-ties between them (a recess or a through-cut, a grille of round holes or of hexagons), which is exactly where a greedy bet fails and a relaxation that fits the alternatives side by side should not. Discovery is the part they do not solve, and on a real object it is the larger part: the search must first propose a feature on the right face for an amplitude to choose it.

= Limitations

- *Synthetic photographs.* The only photographs in this paper are rendered (@sec:real).
- *One family of parts*, and the out-of-grammar parts are near misses within it. Keyholes, which no single feature describes, fail every time.
- *Identification is weak*, #V("recon.g.topo")% on the held-out gate, and the amplitude relaxation is tested so far only on the smallest problems (@sec:amp-results).
- *The error bars are calibrated, not derived*: a single empirical scale on the Fisher $sigma$, fitted on these synthetic parts, which may not transfer to real photographs.
- *Bias.* The plate's height comes back #F("recon.g.h_bias", 2) mm low on average for a reason we have not found.
- *Compute.* A part takes a median #V("recon.g.s_part_mew") s per process on a 24-core machine running six at once, about two minutes of wall time per part; the relaxation adds one render per optional feature to every evaluation.

= Reproducibility <sec:repro>

The recovery is the `irys-recon` crate of irys, open source under Apache-2.0. Each row of `data/measured.tsv` names the irys report and commit that produced it; the 124-part gate is irys commit `812dc62` (`docs/recon-v1-gate100-report.md` and its CSVs), regenerated by `scripts/recon_gate_stats.py`. The amplitude experiments are `examples/recon_amp.rs` on irys branch `claude/recon-amplitudes`, run on a 24-core Linux machine; they write their traces to `out/recon_amp/`, copied to `data/amp-*.json`.

= Conclusion

A recovery that measures well what it identifies has its next work in identifying. On #V("recon.g.parts") held-out synthetic parts, a description-length search through a differentiable renderer reads every dimension of #V("recon.g.p1")% of parts to within a millimetre, and #V("recon.g.given_topo")% of those whose features it gets right. The features it gets wrong are mostly near-ties, a hole or a counterbore, that a greedy search settles by a coin it does not know it is tossing. Feature amplitudes turn that coin into a gradient. #todo[closing sentence on what the amplitude experiments and the amplitude-final gate showed.] The next photographs are of real parts, and the next grammar is the one that can write down the enclosure on the cover.

#heading(outlined: true, numbering: none)[References]
#show bibliography: it => { show "?.": "?"; show "!.": "!"; it }
#bibliography("refs.bib", style: "nature", title: none)
