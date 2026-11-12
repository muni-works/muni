// Research post: image-to-CAD recovery. Photographs in, an editable CAD program out, built on irys
// (paper/irys, the companion paper) and its edge-sampling estimator. Split out of the irys paper's
// former "Dimensions from photographs" section (2026-11-10); same treatment and preamble as irys.typ.
// One source, two outputs: `--features html --format html --input target=html` builds the web post.
// Every measured number is read from data/measured.tsv; each row names the irys report and commit
// that produced it.

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
#import "figures/sigma.typ": fig-sigma, fig-check
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

// Part 3000: one photograph, the wrong answer's overlay, and the two programs.
#let fig-part3000() = {
  let mono-s(body, fill: c-text.transparentize(25%)) = text(font: mono, size: 6.4pt, fill: fill, body)
  align(left, grid(columns: (1fr, 1.6fr), column-gutter: 0.5em, row-gutter: 0.5em,
    image("images/recon/3000-v0.jpg", width: 100%),
    image("images/recon/3000-overlay.png", width: 100%),
    grid.cell(colspan: 2, stack(spacing: 0.35em,
      text(font: mono-m, size: s-xs, tracking: track)[PART 3000 #h(0.6em) #text(fill: c-fault)[WRONG · EVERY σ ≤ 0.11 MM · RESIDUAL EXCESS 0.75]],
      mono-s[TRUTH #h(0.5em) base 69.000 56.200 7.200 chamfer 7.200; hole 30.100 6.800 2.600; boss 16.400 4.500 6.900 5.500],
      mono-s(fill: c-text)[FOUND #h(0.5em) base 66.848 55.691 8.281 chamfer 7.117; boss 15.049 3.156 6.131 5.693])),
  ))
}

// The agreement check on three fresh parts: the two base photographs and the third, then the
// truth and both recoveries.
#let fig-agree-examples() = {
  let ex = json("data/agree-examples.json")
  let mono-s(body, fill: c-text.transparentize(25%)) = text(font: mono, size: 6.2pt, fill: fill, body)
  let one(t) = t.split("\n").join("; ")
  let verdict(e) = {
    let flag = if e.agree { text(fill: c-ok)[TRUSTED] } else { text(fill: c-warn)[FLAGGED: FEATURES CHANGED] }
    let truth = if e.two_ok { text(fill: c-ok)[2-PHOTO ANSWER RIGHT] } else { text(fill: c-fault)[2-PHOTO ANSWER WRONG] }
    [#flag #h(0.6em) #truth]
  }
  align(left, grid(columns: (1fr,), row-gutter: 1.0em, ..ex.map(e => grid(
    columns: (1fr, 1fr, 1fr), column-gutter: 0.35em, row-gutter: 0.35em,
    image("images/recon/" + str(e.seed) + "-b0.jpg", width: 100%),
    image("images/recon/" + str(e.seed) + "-b3.jpg", width: 100%),
    image("images/recon/" + str(e.seed) + "-b5.jpg", width: 100%),
    grid.cell(colspan: 3, stack(spacing: 0.32em,
      text(font: mono-m, size: s-xs, tracking: track)[PART #e.seed #h(0.6em) #verdict(e)],
      mono-s[TRUTH #h(0.5em) #one(e.truth)],
      mono-s(fill: c-text)[2 PHOTOS #h(0.5em) #one(e.two)],
      mono-s(fill: c-text)[3 PHOTOS #h(0.5em) #one(e.three)])),
  ))))
}

// The cover: the web cover's last frame (web/src/components/blog/covers/Deciding.tsx). Test part
// 3007 in the view of one of its photographs, each undecided hole drawn as the alternative its fit
// chose, with the amplitudes, residual insets and the program written out. Frames and numbers are
// images/cover/, written by web/scripts/recon-cover-data.py; nothing is drawn by hand.
#let cover = json("images/cover/cover.json")
#let fig-cover(width: 21.59, height: 17.5) = {
  let (w, h) = cover.size
  let k = height / h                       // cm per frame pixel
  let ox = width * 0.56 - 1500 * k          // keep the features right of centre
  let P(x, y) = (dx: ox * 1cm + x * k * 1cm, dy: y * k * 1cm)
  let px(n) = n * k * 1cm
  let mono-px(n, body, fill: c-text) = text(font: mono, size: px(n) * 0.95, tracking: px(2.5), fill: fill, body)
  let fin = cover.steps.last().a
  let f2(x) = { let r = str(calc.round(x * 100) / 100); if not r.contains(".") { r += ".00" } else if r.split(".").at(1).len() == 1 { r += "0" }; r }
  let amp(k) = calc.min(calc.max(fin.at(k), 0), 1)
  let order = range(cover.groups.len()).sorted(key: i => cover.groups.at(i).centre.at(0))
  let BLOCK = 380
  let INSET = 150
  let ly = h * 0.15
  let insetY = ly + 168
  block(width: width * 1cm, height: height * 1cm, clip: true, {
    place(..P(0, 0), image("images/cover/base.jpg", width: px(w)))
    for g in cover.groups {
      for o in g.options {
        if amp(o.k) > 0.5 { place(..P(g.box.at(0), g.box.at(1)), image("images/cover/opt" + str(o.k) + ".png", width: px(g.box.at(2)))) }
      }
    }
    place(rect(width: 100%, height: 100%, fill: c-bg.transparentize(42%), stroke: none))
    place(bottom, rect(width: 100%, height: 45%, stroke: none,
      fill: gradient.linear(c-bg.transparentize(100%), c-bg.transparentize(30%), c-bg, angle: 90deg)))
    for (row, gi) in order.enumerate() {
      let g = cover.groups.at(gi)
      let (cx, cy) = g.centre
      let bx = w * (0.47 + 0.235 * row)
      let am = g.options.map(o => amp(o.k))
      let win = if am.at(0) >= am.at(1) { 0 } else { 1 }
      let dim = g.options.at(win).dim
      let tx(x) = ox + x * k
      place(curve(stroke: 2.4 * k * 1cm + c-sel.transparentize(10%),
        curve.move((tx(g.rim.at(0).at(0)) * 1cm, g.rim.at(0).at(1) * k * 1cm)),
        ..g.rim.slice(1).map(p => curve.line((tx(p.at(0)) * 1cm, p.at(1) * k * 1cm))), curve.close()))
      place(line(start: (tx(cx) * 1cm, cy * k * 1cm), end: (tx(bx + INSET / 2) * 1cm, (insetY + INSET + 12) * k * 1cm), stroke: 1.6 * k * 1cm + c-sel.transparentize(10%)))
      place(..P(cx - 5, cy - 5), circle(radius: px(5), fill: c-sel, stroke: none))
      for (i, o) in g.options.enumerate() {
        let y = ly + 26 + i * 44
        let col = if i == win { c-sel } else { c-text.transparentize(55%) }
        place(..P(bx, y - 20), mono-px(22, upper(o.kind), fill: col))
        place(..P(bx, y - 20), box(width: px(262), align(right, mono-px(22, f2(am.at(i)), fill: col))))
        place(..P(bx + 276, y - 9), line(length: px(BLOCK - 276), stroke: px(2) + c-text.transparentize(82%)))
        if am.at(i) > 0 { place(..P(bx + 276, y - 9), line(length: px((BLOCK - 276) * am.at(i)), stroke: px(2) + col)) }
      }
      place(..P(bx, insetY - 34), mono-px(18, "RESIDUAL", fill: c-label))
      let sc = INSET / calc.max(g.box.at(2), g.box.at(3))
      let o = g.options.at(win)
      place(..P(bx, insetY), box(width: px(INSET), height: px(INSET), clip: true, radius: px(2), stroke: px(1.5) + c-sel.transparentize(20%),
        place(dx: px((INSET - g.box.at(2) * sc) / 2), dy: px((INSET - g.box.at(3) * sc) / 2),
          image("images/cover/res-opt" + str(o.k) + ".png", width: px(g.box.at(2) * sc)))))
      place(..P(bx + INSET + 20, insetY + 6), mono-px(22, "DIA " + f2(dim.d)))
      place(..P(bx + INSET + 20, insetY + 36), mono-px(22, if "depth" in dim { "DEPTH " + f2(dim.depth) } else { "THROUGH" }))
    }
    // the program the fit wrote
    let prog = cover.base.map(l => text(fill: c-label, l)) + order.map(gi => {
      let g = cover.groups.at(gi)
      let am = g.options.map(o => amp(o.k))
      text(fill: c-text, g.options.at(if am.at(0) >= am.at(1) { 0 } else { 1 }).line)
    })
    place(bottom + left, dx: 0.75in, dy: -3.6cm, text(font: mono, size: 6.5pt, tracking: 0.04em, stack(spacing: 0.75em, ..prog)))
    place(bottom + right, dx: -0.75in, dy: -3.6cm, align(right, stack(spacing: 0.5em,
      caps(fill: c-text)[Decided · #cover.nSteps steps · #cover.evals renders],
      caps[Test part #cover.seed · irys renders blended by amplitude · a recorded fit])))
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
      caps[November 2026])
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
  ]
]}

#let abstract-text = [
  We recover editable CAD programs (a plate with holes, counterbores, slots, bosses and patterns, each with its dimensions) from photographs by analysis by synthesis: a search over programs scored by description length, with every candidate's dimensions fitted through a differentiable renderer. Such a fit reports a Fisher error bar for every dimension. We ask whether those error bars, or the fit's residuals, tell a right answer from a wrong one. On held-out synthetic parts they do not. Among #V("recon.wsig.n") parts, #V("recon.wsig.tight_wrong") of the #V("recon.wsig.tight") whose every error bar is under 1 mm are wrong, and the largest error bar separates wrong answers from right ones with an area under the ROC curve of #F("recon.wsig.auc", 2). Four image-based checks (residual on the part against the table, outline offset, unexplained residual blobs, score margin to the runner-up) do little better: with thresholds fitted on half of #V("fresh.parts") fresh parts, they flag #V("chk.fit.caught") of #V("chk.odd.wrong") wrong answers on the other half. Most wrong answers explain the photographs they were fitted to. A photograph the fit has not seen does better, used the right way. Recovering again with one more photograph and flagging the part when its features change catches #V("nbv.caught") of #V("nbv.wrong") wrong answers on #V("nbv.n") fresh parts, with #V("nbv.fa") false alarms among #V("nbv.right") right ones, and it works as well on either half of the parts. We have not yet ruled out that some of those changes come from the search's own run-to-run variation. Scoring the first answer's residual in that photograph does not (area under the curve #F("nbv.hold_auc", 2)), and choosing which photograph to add, where the finalist programs disagree most, is no better than a random one. We also report a continuous relaxation over features that made identification worse. Every photograph is synthetic.
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

A drawing of a part is a short program: "a 69 by 56 by 7 mm plate, chamfered, with a 2.6 mm hole and a boss" is a dozen numbers. Recovering that program from photographs takes two steps. *Identification* decides which features the part has. *Measurement* decides their dimensions. Analysis by synthesis does both by rendering candidate programs and keeping the one whose render best explains the photographs @kulkarni2015picture @ellis2018graphics. With a differentiable renderer @li2018edge the measurement step is a least-squares fit, and least squares gives every dimension an error bar from the Fisher information.

A user who gets back a program with every dimension at ±0.1 mm will trust it. This paper is about why they should not. The Fisher error bar is the curvature of the score at the answer the search found. It says how well that answer is pinned if the model is right, and nothing about whether the right features were found @white1982misspecified. A plate 2 mm too short with its hole missed can sit in a basin as narrow as the true one.

We measure how often this happens and whether anything computed from the fit can catch it. Our contributions are:

- *A recovery pipeline* that searches CAD programs by description length @rissanen1978mdl through a differentiable renderer, as a testbed (@sec:method).
- *A held-out measurement of when its error bars mislead.* On fresh synthetic parts, tight error bars are nearly uninformative about whether the answer is right (@sec:sigma).
- *A negative result for post-hoc checks.* Four residual-based checks, with thresholds fitted on one half of fresh parts and tested on the other, catch few wrong answers. Part 3000 shows why: its wrong answer leaves a clean residual (@sec:check).
- *What does help.* More photographs, and a check that uses one: recover again with one more photograph and flag the part if its features change. It catches three in four wrong answers with few false alarms (@sec:views, @sec:agree).

Every photograph here is rendered, so every result excludes what a real camera, print and room would add. The claim is about the fit's self-assessment, which synthetic data tests cleanly, because the truth is known exactly.

= The recovery <sec:method>

A program is a plate (width, depth, height, and a sharp, filleted or chamfered corner) with an ordered list of features on its top face (through-holes, counterbores, slots, bosses, linear and circular hole patterns) and its pose on the table. We score a program in nats,

$ "score" = underbrace(-log p("photos" | "render"("program", theta)), "residual") + underbrace(1/2 log det F(theta), "parameters") + underbrace(-log p("program"), "program"), $

with a Huber noise model, a Laplace parameter cost from the Fisher information $F = J^top Sigma^(-1) J$ @schwarz1978bic @grunwald2007mdl, and a uniform grammar prior. The noise variance is scaled by the residual's autocorrelation area, measured on the open table, so smooth shading errors are not counted as independent pixels.

The search starts from a box, proposes edits (add a feature at a residual blob, remove one, turn a hole into a counterbore or slot, merge holes into a pattern, change the corner), fits each by Levenberg–Marquardt and keeps a beam of two. The best four distinct programs are refitted at full resolution and the lowest score wins. The Jacobian comes from edge sampling @li2018edge in irys @pedersen2026irys, through a deterministic photo model (closed-form shading, spherical-harmonic light, one key light with soft shadows, and ambient occlusion whose derivative we take by treating its 16 fixed rays as directional lights). A printed AprilTag @olson2011apriltag fixes each camera and the metric scale.

Test photographs are irys path-traced renders of a part in PLA of one of six colours beside the tag, under a random environment or a synthetic room, at 2016×1512, passed through a phone camera model (defocus, shot and read noise, tone curve, JPEG). Parts are drawn from the grammar's generator. Every setting was frozen on a 20-part development set before any held-out run. Two held-out sets follow: the first held-out set (80 parts, seeds 3020–3099) and the *fresh set* (100 parts, seeds 4000–4099), which we generated after the first set was analysed. The fresh set is reused by the runs of @sec:check, @sec:views and @sec:agree, each a separate run of the search; its Wilson intervals cover the sampling of parts, not the run-to-run variance of the search, which we have not measured.

#figure(fig-recon(),
  caption: [#lead[The recovery loop.] The search edits a CAD program, fits each edit's dimensions through the renderer's edge-sampled Jacobian, scores it in nats, and keeps it only if the description of the photographs gets shorter. Bar lengths are schematic.],
) <fig:recon>

= Accuracy <sec:acc>

#figure(
  table(
    columns: (2fr, 1fr, 1fr),
    align: (left, right, right),
    table.header([*Set (3 photos each)*], [*within 1 mm*], [*right features*]),
    [held-out parts, first run (#V("recon.n.parts"))], [#V("recon.n.p1") #text(size: 0.85em)[(#ci("recon.n.p1_ci")%)]], [#V("recon.n.topo") #text(size: 0.85em)[(#ci("recon.n.topo_ci")%)]],
    [fresh set, seeds 4000–4099 (#V("fresh.parts"))], [#V("fresh.p1") #text(size: 0.85em)[(#ci("fresh.p1_ci")%)]], [#V("fresh.topo") #text(size: 0.85em)[(#ci("fresh.topo_ci")%)]],
  ),
  caption: [#lead[Recovery accuracy on held-out synthetic parts.] Worst dimension per part, after the plate's quarter-turn symmetry. Wilson 95% intervals in parentheses. Most failures are wrong features, chiefly a hole read as a counterbore or the reverse; among parts with the right features the median worst-dimension error is #F("recon.n.med_ok", 2) mm. `data/measured.tsv`.],
) <tab:acc>

About two in five parts come back within 1 mm on every dimension, and about half with the right features (@tab:acc). We compare against no other method; the point of this paper is not the accuracy but what the fit says about it. @fig:examples shows two parts it gets right and one it gets wrong.

#figure(fig-recon-examples(),
  caption: [#lead[Three development parts, three synthetic photographs each.] Right of the photographs, the fit's overlay: the recovered outline on the crop, and the residual (red brighter, blue darker than the model). Parts 3009 and 3012 pass at 0.16 and 0.32 mm. Part 3016 fails: its hole is read as a counterbore of the hole's outer radius, the commonest confusion. `data/recon-examples.json`.],
) <fig:examples>

= Error bars do not flag wrong answers <sec:sigma>

The Fisher standard deviations are too small by a median factor of #V("recon.sig.opt") and do not rank the errors (Spearman $rho = #V("recon.sig.rho")$). One scale, $sigma' = #V("recon.sig.c") sigma_F$, fitted on even seeds restores 68% coverage on odd seeds, as any fitted scale must; because $sigma_F$ does not rank errors, $sigma'$ is an average error with a unit, not a per-dimension error bar. The cause we suspect is bias from the appearance model, which moves an edge the same way in every photograph, so more pixels shrink $sigma_F$ without shrinking the error.

The worse failure is that $sigma$ is conditional on the features being right. Among the #V("recon.wsig.n") held-out parts that ran (the other 4 of the 80 failed before the search because the tag detector found no tag in a photograph), #V("recon.wsig.tight") have $sigma' <= 1$ mm on every dimension, and #V("recon.wsig.tight_wrong") of those are wrong, #V("recon.wsig.tight_wtopo") with the wrong features. As a test for a wrong answer, a part's largest $sigma$ has an area under the ROC curve of #F("recon.wsig.auc", 2) (95% interval #F("recon.wsig.auc_ci", 2)–#F("recon.wsig.auc_ci", 2, i: 1)), where 0.5 is chance. This is the gap between aleatoric and model uncertainty @kendall2017uncertainties, in a setting where the model is a discrete program. @fig:sigma shows every part.

#figure(fig-sigma(),
  caption: [#lead[Error bars against errors.] Each of the #V("recon.wsig.n") held-out parts at its largest calibrated error bar $sigma' = #V("recon.sig.c") sigma_F$ and its actual worst error; parts with the wrong features, which have no worst error, sit in the top band. The scale was fitted on the even seeds; the figure shows all parts. In the shaded region every error bar is under 1 mm, and #V("recon.wsig.tight_wrong") of its #V("recon.wsig.tight") parts are wrong. `data/sigma-vs-error.csv`.],
) <fig:sigma>

= Residual checks do not either <sec:check>

If the error bars cannot see a wrong program, perhaps the residual can. A missing or misplaced feature should leave residual on the part that the open table does not have. We computed four signals on each finished recovery:

- *residual excess*: mean robust residual near the part over the same on the open table;
- *outline offset*: mean disagreement between the model's silhouette and the segmented part, in pixels;
- *unexplained blob*: the largest residual blob left on the top face, as an equivalent radius;
- *finalist margin*: the score gap in nats from the winner to the runner-up program.

Here a part is wrong if it has the wrong features or any dimension off by more than 1 mm, so the #(V("fresh.parts") - V("fresh.p1")) wrong parts of @tab:acc include #(V("fresh.parts") - V("fresh.topo")) with wrong features. On the fresh set we fitted thresholds on the even seeds, allowing at most 20% false alarms, and tested on the odd seeds. The fitted rule caught #V("chk.fit.caught") of #V("chk.odd.wrong") wrong answers with #V("chk.fit.fa") false alarms among #V("chk.odd.right") right ones. Looser hand-set thresholds caught #V("chk.ph.caught") of #V("chk.odd.wrong") at #V("chk.ph.fa") of #V("chk.odd.right") false alarms. Neither is a usable trust signal (@fig:check). (The odd half happens to be harder, #V("chk.odd.wrong") wrong of 50 against 22 on the even half, so these rates are noisy.)

Part 3000 shows why. Its recovered plate is #F("p3000.dw", 2) mm too narrow and #F("p3000.dh", 2) mm too tall, and its hole is missing. Every Fisher $sigma$ is at most #F("p3000.sig", 2) mm, the residual on the part is #F("p3000.excess", 2) times the table's (that is, no excess), and no blob remains. From the one photograph it was recovered from (@fig:p3000), the wrong program explains the image. No function of the residual can flag an answer that leaves no residual.

#figure(fig-part3000(),
  caption: [#lead[A confident wrong answer.] Part 3000 from one synthetic photograph (left) and the recovery's overlay (right: the recovered outline on the crop, and the residual, red brighter and blue darker than the model). The plate comes back 2.15 mm short and 1.08 mm tall, and the hole at its far edge, seen at a grazing angle, is missing. The residual is clean and every error bar is tight. From irys commit `084d424`, the version vcad used.],
) <fig:p3000>

#figure(fig-check(),
  caption: [#lead[Residual checks on #V("fresh.parts") fresh parts.] Each dot is a part, split by whether the recovery was right. The two groups overlap on every signal; a threshold that flags many wrong parts flags many right ones too. The fourth signal, an unexplained residual blob, was zero on 97 of the 100 parts and is not drawn; its fitted threshold flags two wrong parts and no right ones. `data/check-fresh.csv`.],
) <fig:check>

= Photographs do <sec:views>

What separates part 3000's answer from the truth is a view the photographs did not take. On the 20-part development set, one photograph per part put #V("recon.1v.p1") within 1 mm and three photographs #V("recon.3v.p1")\; the features were right on #V("recon.1v.topo") against #V("recon.3v.topo"). On the #V("fresh.parts") fresh parts, with the same settings and only the first photograph of each, #V("fresh.1v.p1") came back within 1 mm (#ci("fresh.1v.p1_ci")%) against #V("fresh.p1") with three (#ci("fresh.p1_ci")%), and #V("fresh.1v.topo") had the right features against #V("fresh.topo"). Paired, #V("fresh.3over1") parts were right with three photographs and wrong with one, and #V("fresh.1over3") the other way. A third photograph helps accuracy. The next section uses it to say when an answer is wrong.

= A held-out photograph flags wrong answers <sec:agree>

Part 3000 suggests the test: a wrong program that explains two photographs need not explain a third. We tried three ways of using the third photograph, on fresh parts rendered from eight directions each. Every part is recovered from two base views, then again with a third view added. #V("nbv.n") parts finished before we stopped the run; the counts below are on those. They are not the easy ones: in the earlier three-photograph run they were right #V("nbv.sub_right") times in #V("nbv.n") and had the right features #V("nbv.sub_topo") times, against #V("nbv.rest_right") and #V("nbv.rest_topo") in #(100 - V("nbv.n")) for the parts that did not finish. Each recovery starts from scratch; the three-photograph recovery is not started from the two-photograph answer.

#figure(
  table(
    columns: (2.2fr, 1fr, 1fr),
    align: (left, right, right),
    table.header([*Check on the two-photograph answer*], [*wrong caught*], [*right flagged*]),
    [features change with a third photograph], [*#V("nbv.caught")/#V("nbv.wrong")*], [#V("nbv.fa")/#V("nbv.right")],
    [#h(1em) even seeds], [#V("nbv.even_caught")/#V("nbv.even_wrong")], [#V("nbv.even_fa")/#V("nbv.even_right")],
    [#h(1em) odd seeds], [#V("nbv.odd_caught")/#V("nbv.odd_wrong")], [#V("nbv.odd_fa")/#V("nbv.odd_right")],
    [residual checks on the same photographs (@sec:check, odd seeds)], [#V("chk.fit.caught")/#V("chk.odd.wrong")], [#V("chk.fit.fa")/#V("chk.odd.right")],
  ),
  caption: [#lead[Flagging wrong answers.] A part is flagged when recovering it again with one more photograph changes its features. The last row is the best in-sample check of @sec:check, on three-photograph recoveries from a different run of the fresh set and at no extra compute, so it is a reference rather than a like-for-like comparison. `data/measured.tsv`.],
) <tab:agree>

#figure(fig-agree-examples(),
  caption: [#lead[The agreement check on three fresh parts.] Each row shows the two base photographs and the third, then the truth and the recoveries from two photographs and from all three. Part 4035: two photographs miss both bosses and shrink the plate; the third view finds them, the features change, and the part is flagged. Part 4022: both recoveries agree and are right. Part 4036: both miss a 2.5 mm hole and a counterbore the same way, so the check trusts a wrong answer, which is the failure that leaves a third of trusted answers wrong. Programs in millimetres, pose omitted. `data/agree-examples.json`.],
) <fig:agree>

*Does the answer change?* Flag the part if the recovery with the third photograph has different features from the recovery without it. This flags (@tab:agree) #V("nbv.caught") of the #V("nbv.wrong") wrong two-photograph answers (#ci("nbv.caught_ci")%) and #V("nbv.fa") of the #V("nbv.right") right ones. It has no threshold to fit, so we report both halves of the parts: on the even seeds it flags #V("nbv.even_caught") of #V("nbv.even_wrong") wrong answers and #V("nbv.even_fa") of #V("nbv.even_right") right ones, on the odd seeds #V("nbv.odd_caught") of #V("nbv.odd_wrong") and #V("nbv.odd_fa") of #V("nbv.odd_right"). Among the #V("nbv.trusted") parts it does not flag, #V("nbv.trusted_right") of the two-photograph answers are right, against #V("nbv.right") of #V("nbv.n") overall. It cannot catch an error that the third photograph repeats, which is why a third of the unflagged answers are still wrong.

One confound is not ruled out. The search is not deterministic across machines (@sec:limits), so some of these changes could be the search landing differently rather than the third photograph adding evidence. Each part's two recoveries ran in the same process on the same machine, but we have not run the control that would settle it: recovering twice from the same two photographs and counting how often the features change. Until then the check is best read as a stability test of the recovery, which is also what a user can run.

*The residual in the third photograph.* Render the two-photograph answer in the third view, fit that view's light to its own geometry with the geometry held fixed, and measure the residual excess as in @sec:check. As a test for a wrong answer it has an area under the curve of #F("nbv.hold_auc", 2) (95% interval #F("nbv.hold_auc_ci", 2)–#F("nbv.hold_auc_ci", 2, i: 1)): no better than chance. The light absorbs most of what the wrong geometry gets wrong.

*Choosing the third photograph.* Render the search's finalist programs from each candidate camera and take the view where they disagree most, using only the candidate's camera, not its pixels. With the chosen view #V("nbv.chosen") parts come back right, with a fixed random view #V("nbv.random"). The chosen view fixed #V("nbv.chosen_only") parts the random one missed and missed #V("nbv.random_only") it fixed; in #V("nbv.same") parts it chose the random view. Adding a view helps; choosing it, this way, does not.

The rule we ship follows: take three photographs, recover from two and from all three, and return the program as trusted only if both have the same features; otherwise ask for another photograph. On these parts it returns about half the parts as trusted, and #V("nbv.trusted_right") of those #V("nbv.trusted") are right (#ci("nbv.trusted_ci")%), against #V("nbv.right") of #V("nbv.n") without the check. It costs one more recovery per part. The residual checks of @sec:check cost nothing extra.

= A relaxation that made identification worse <sec:amp>

Since most failures are a hole-or-counterbore choice, we tried making that choice continuous. Each loose hole or counterbore became a pair of alternatives with amplitudes $a in [0, 1]$ on a simplex; the model image blends renders without and with each, $I = I_0 + sum_k a_k (I_k - I_0)$, whose derivative in $a_k$ is exact; the score charges $a_k L_k$ plus an anneal $beta a (1 - a)$ that drives amplitudes to 0 or 1 @liu2019darts @louizos2018l0. On three small problems it behaved. On the #V("ampg.n") held-out parts, paired against the greedy choice on the same recoveries, it found the right features on #V("ampg.a_topo") against #V("ampg.g_topo"), fixing #V("ampg.fixed") and breaking #V("ampg.broke")\; on the fresh parts, #V("fresh.amp_topo") against #V("fresh.topo"), fixing #V("fresh.amp_fixed") and breaking #V("fresh.amp_broke"). The main cause is the anneal: a real hole whose two alternatives split the evidence near 0.45 each loses both. Annealing presence and choice separately ($a_"hole" = p q$, $a_"cbore" = p(1-q)$) is the obvious fix and is untested.

= Limitations <sec:limits>

- *Synthetic photographs.* Rendered by the renderer the method is built on. Real photographs add appearance error, which we expect to make error bars less informative, not more.
- *One family of parts*, a plate with top-face features.
- *No baselines.* The accuracy in @tab:acc is not compared with any other method.
- *The agreement check's confound.* We have not measured how often the features change when the search runs twice on the same photographs (@sec:agree), nor tried the held-out residual with the light held from the base views.
- *Single runs.* The greedy search is not deterministic across machines, and we have not measured that variance. The agreement check is measured on the #V("nbv.n") of 100 fresh parts that finished.

= Conclusion

In analysis-by-synthesis recovery of CAD programs, the fit's own error bars and residuals say little about whether the program is right. On held-out synthetic parts, tight error bars are wrong almost as often as loose ones, and residual checks fitted on one half catch few wrong answers on the other, because most wrong answers explain the photographs they were fitted to. What does help is evidence the fit has not seen, used as a test of stability rather than of fit: recovering again with one more photograph and asking whether the features change catches three in four wrong answers with few false alarms. A system that reports CAD dimensions with error bars should say plainly that those bars assume the features are right, and should run that check before it does.

The code is the `irys-recon` crate of irys (Apache-2.0); each row of `data/measured.tsv` names the commit and run that produced it.


#heading(outlined: true, numbering: none)[References]
#show bibliography: it => { show "?.": "?"; show "!.": "!"; it }
#bibliography("refs.bib", style: "nature", title: none)
