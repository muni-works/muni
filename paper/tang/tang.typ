// Research paper: tang's tensor IR — views and comprehensions.
// Same treatment as paper/ribt (muon "Pilot Light", dark).
// Build: make (IBM Plex from fonts/, system fonts ignored so builds are reproducible).
// Every number traces to BENCHMARKS.md or docs/tensor-ir.md in the tang repository.

#let web = sys.inputs.at("target", default: "pdf") == "html"
#show math.equation: it => if web and it.alt != "in-frame" { html.elem("span", attrs: (class: "math"), html.frame(it)) } else { it }
#show math.equation: set text(font: "New Computer Modern Math", fallback: true)
#show math.equation: it => { show regex("[A-Za-z0-9]"): set text(font: "IBM Plex Sans"); it }

// ---- color roles (as vision.typ) -------------------------------------------
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

// product names in their family color, as in the vision paper's periodic table
#let brand-names = (("tang", "make"), ("ipse", "mind"), ("frog", "mind"))
#let fam-color = (make: c-ok, mind: c-sel)
#let brand-re = regex("(?i)\\b(tang|ipse|frog)\\b")
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
#let aside(title, body) = if web { html.elem("aside", attrs: (class: "aside"), { html.elem("div", attrs: (class: "aside-title"), title); body }) } else { pad(left: 0.35in, right: 0.35in, block(width: 100%, inset: (left: 12pt, y: 2pt), stroke: (left: 0.6pt + c-line-hi), above: 2.2em, below: 2.2em, breakable: false, {
  set text(size: s-sm, fill: c-label)
  set par(spacing: 1.1em, leading: 0.68em)
  show strong: set text(fill: c-text)
  block(below: 0.9em, text(font: mono-m, size: s-xs, fill: c-sel, tracking: track, upper([Aside · ] + title)))
  body
}))
}

#let title = [Don't Write Kernels, Derive Them]
#set document(title: "Don't Write Kernels, Derive Them", author: "Cam Pedersen (Municipal Robotics)")

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
      pad(x: -hf-out(), grid(columns: (1fr, auto), caps(title), caps[Municipal Robotics]))
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
#show emph: set text(font: ("IBM Plex Sans",), style: "italic")
#show link: set text(fill: c-text)
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
#set enum(indent: 0em, body-indent: 0.85em, spacing: 1.15em, numbering: n => text(font: mono-m, size: s-xs, fill: c-label, str(n)))

#set table(stroke: (x, y) => (
    top: if y == 0 { 0.6pt + c-line-hi } else if y == 1 { 0.6pt + c-line-hi } else { 0.35pt + c-line },
    bottom: 0.6pt + c-line-hi,
  ), inset: (x: 6pt, y: 4.6pt))
#show table: set text(font: sans, size: s-sm, number-width: "tabular", hyphenate: false)
#show table: set par(leading: 0.62em, justify: false)
#show table.cell.where(x: 0): it => if it.y == 0 { it } else { set text(font: sans-m, fill: c-text); it }
#show table.cell.where(y: 0): it => {
  set text(font: mono-m, size: s-xs, fill: c-label, tracking: track)
  upper(it)
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
// Web figures: drawn bodies become inline SVG via html.frame (as ribt.typ); tables stay <table>s.
#show figure: it => if web and it.kind != table {
  let lab = if it.has("label") { str(it.label) } else { "" }
  let body = html.frame(block(width: 4.8in, fill: c-bg, inset: 6pt, { set math.equation(alt: "in-frame"); it.body }))
  let cap = if it.caption != none { html.elem("figcaption", [#html.elem("span", attrs: (class: "fig-label"))[Fig #context it.counter.display(it.numbering)] #it.caption.body]) }
  html.elem("figure", attrs: if lab == "" { (class: "narrow") } else { (id: lab, class: "narrow") }, { body; cap })
} else if web and it.kind == table {
  // tables: same caption markup as drawn figures, caption above the table
  let lab = if it.has("label") { str(it.label) } else { "" }
  let cap = if it.caption != none { html.elem("figcaption", [#html.elem("span", attrs: (class: "fig-label"))[Table #context it.counter.display(it.numbering)] #it.caption.body]) }
  html.elem("figure", attrs: if lab == "" { (:) } else { (id: lab) }, { cap; it.body })
} else { it }

// ---- figures ----------------------------------------------------------------
#import "@preview/cetz:0.4.2"

// the title illustration: causal attention at n = 1024 as the derived flash kernel sees it.
// One square per (32-query, 32-key) tile. Tiles above the diagonal are skipped by the affine mask
// and never launched; diagonal tiles run masked (orange); the rest are full tiles whose brightness
// falls off with distance from the diagonal. Nothing n × n is ever written.
#let tiles(n: 32, size: 17.0) = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let s = size / n
  let g = s * 0.16
  for i in range(n) {
    for j in range(n) {
      let x = j * s
      let y = (n - 1 - i) * s
      if j > i {
        if calc.rem(i + j, 2) == 0 {
          circle((x + s / 2, y + s / 2), radius: s * 0.035, fill: c-line, stroke: none)
        }
      } else if j == i {
        rect((x + g, y + g), (x + s - g, y + s - g), fill: c-sel.transparentize(20%), stroke: none)
      } else {
        let d = (i - j) / n
        let a = 30% + 62% * d
        rect((x + g, y + g), (x + s - g, y + s - g), fill: none, stroke: (paint: c-label.transparentize(a), thickness: 0.45pt))
      }
    }
  }
})

#let lbl(pos, body, anchor: "center", fill: c-label, size: s-xs, font: mono-m) = cetz.draw.content(pos, anchor: anchor, text(font: font, size: size, fill: fill, tracking: 0.04em, body))

// Fig: the naive attention graph and the one comprehension it rewrites to.
#let fig-one() = {
  // Idle rented RTX 3090, CUDA lowering, f32 graph, every point checked against the f64 interpreter.
  let rows = json("data/figure1-cuda.json").filter(r => r.op == "fwd")
  let pick(k) = rows.find(r => r.point == k)
  let base = pick("naive").ms
  let row(k, name) = {
    let r = pick(k)
    let e = calc.floor(calc.log(r.max_rel_err))
    let m = calc.round(r.max_rel_err / calc.pow(10.0, e), digits: 1)
    ([#name], [#r.kernels], [#calc.round(r.hbm_bytes / 1e6, digits: 1) MB], [#calc.round(r.ms, digits: 2)], [#calc.round(r.ms_min, digits: 2)–#calc.round(r.ms_max, digits: 2)], [#calc.round(base / r.ms, digits: 1)×], [$#m times 10^(#e)$])
  }
  table(
    columns: (auto, auto, auto, auto, auto, auto, auto),
    align: (left, right, right, right, right, right, right),
    [schedule], [kernels], [traffic], [ms], [range], [vs naive], [rel. error],
    ..row("naive", [as written]),
    ..row("checkpoint", [checkpointing]),
    ..row("flash", [flash]),
    ..row("searched", [*searched*]),
  )
}

#let fig-rewrite() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let w = 1.95
  let h = 0.95
  let gap = 0.42
  let nodes = (
    ([$S = q k^top$], [n × n], true),
    ([$m = max_j S$], [n], false),
    ([$P = e^(S - m)$], [n × n], true),
    ([$l = sum_j P$], [n], false),
    ([$O = P V \/ l$], [n × d], false),
  )
  let y = 3.2
  for (k, (t, shape, big)) in nodes.enumerate() {
    let x = k * (w + gap)
    rect((x, y), (x + w, y + h), fill: c-surface, stroke: (paint: if big { c-fault } else { c-line-hi }, thickness: 0.6pt, dash: if big { "dashed" } else { none }))
    content((x + w / 2, y + h / 2 + 0.1), text(size: s-sm, fill: c-text, t))
    lbl((x + w / 2, y + 0.18), shape, fill: if big { c-fault } else { c-label })
    if k < nodes.len() - 1 { line((x + w, y + h / 2), (x + w + gap, y + h / 2), stroke: 0.5pt + c-line-hi, mark: (end: ">", fill: c-line-hi, size: 0.12)) }
  }
  let total = nodes.len() * w + (nodes.len() - 1) * gap
  lbl((0, y + h + 0.3), [naive graph · 5 comprehensions · two n × n buffers], anchor: "west")
  // the rewrite
  line((total / 2, y - 0.15), (total / 2, 1.75), stroke: 0.6pt + c-label, mark: (end: ">", fill: c-label, size: 0.14))
  lbl((total / 2 + 0.18, 2.45), [substitute\_maps · stabilize\_softmax], anchor: "west", fill: c-text)
  // the fused comprehension
  let bw = 9.6
  let x0 = (total - bw) / 2
  rect((x0, 0.35), (x0 + bw, 1.6), fill: c-surface, stroke: 0.9pt + c-sel)
  content((total / 2, 1.08), text(size: s-sm, fill: c-text)[$O[i, c] = plus.o.big_j (m, l, "acc") lr(|) med q_i dot k_j, med v_(j c)$])
  lbl((total / 2, 0.6), [one reduction · online-softmax monoid · c is a point dim], fill: c-sel)
  lbl((0, 0.0), [then: tile rows × lanes · stage q·k per 32-key chunk · state in registers], anchor: "west")
})

// Fig: a transformer block forward at seq 512 on the RTX 3090, as the backends matured.
#let fig-trajectory() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let W = 9.2
  let x0 = 2.9
  let lx(t) = x0 + (calc.log(t) + 1) / 2 * W
  let rows = (
    ([WGSL, first], 4.41, c-label),
    ([WGSL, fused], 3.34, c-label),
    ([CUDA, mma.sync], 0.331, c-ok),
  )
  for t in (0.1, 0.3, 1, 3, 10) {
    line((lx(t), -0.2), (lx(t), 2.75), stroke: 0.3pt + c-line)
    lbl((lx(t), -0.45), [#t ms])
  }
  let torch = 0.396
  line((lx(torch), -0.2), (lx(torch), 2.75), stroke: (paint: c-sel, thickness: 0.7pt, dash: "dashed"))
  lbl((lx(torch), 3.0), [PyTorch CUDA graph · 0.396], fill: c-sel)
  for (k, (name, t, col)) in rows.enumerate() {
    let y = 2.1 - k * 0.85
    lbl((x0 - 0.2, y + 0.22), name, anchor: "east", fill: c-text, font: sans-m, size: s-sm)
    rect((lx(0.1), y), (lx(t), y + 0.44), fill: col.transparentize(55%), stroke: 0.5pt + col)
    lbl((lx(t) + 0.12, y + 0.22), [#t], anchor: "west", fill: c-text)
  }
})

// Fig: the Qwen3-8B decode step as one IR graph. Top: the whole step. Bottom: one of the 36
// layers, colored by what each node costs at 4k context (ms from fig-decode, RTX 3090).
#let fig-qwen-graph() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let h = 0.62
  let node(x, y, w, body, col, sub: none, dash: none) = {
    rect((x, y), (x + w, y + h), fill: c-surface, stroke: (paint: col, thickness: 0.6pt, dash: dash))
    lbl((x + w / 2, y + h / 2 + if sub == none { 0 } else { 0.09 }), body, fill: c-text, font: sans-m, size: s-xs)
    if sub != none { lbl((x + w / 2, y + 0.13), sub, fill: if col == c-line-hi { c-label } else { col }, size: 5.5pt) }
  }
  let arrow(a, b, col: c-line-hi) = line(a, b, stroke: 0.45pt + col, mark: (end: ">", fill: col, size: 0.09))
  let chain(y, xs, items) = {
    for (k, (w, body, col, sub)) in items.enumerate() {
      node(xs.at(k), y, w, body, col, sub: sub)
      if k < items.len() - 1 { arrow((xs.at(k) + w, y + h / 2), (xs.at(k + 1), y + h / 2)) }
    }
  }
  let place(x0, gap, items) = {
    let xs = ()
    let x = x0
    for (w, ..rest) in items { xs.push(x); x += w + gap }
    xs
  }
  // the step
  let top = (
    (1.55, [embed], c-line-hi, [gather]),
    (2.7, [36 × decoder layer], c-sel, [below]),
    (1.35, [RMSNorm], c-line-hi, none),
    (1.55, [LM head], c-sel, [0.56 ms]),
    (1.5, [arg-max], c-ok, [monoid]),
    (1.55, [state′], c-ok, [8 bytes back]),
  )
  let yt = 4.6
  let xt = place(0, 0.32, top)
  chain(yt, xt, top)
  // the layer, in two rows
  let r1 = (
    (1.35, [RMSNorm], c-line-hi, none),
    (1.6, [q|k|v GEMV], c-sel, [1.25 ms]),
    (1.75, [q/k norm · rope], c-line-hi, none),
    (1.65, [cache write], c-ok, [in place]),
    (1.4, [q · k], c-info, [0.73 ms]),
    (1.9, [softmax · Σ p v], c-info, [1.13 ms]),
  )
  let r2 = (
    (1.4, [o GEMV], c-sel, [0.75 ms]),
    (1.0, [\+ x], c-line-hi, none),
    (1.35, [RMSNorm], c-line-hi, none),
    (1.75, [gate|up GEMV], c-sel, [2.76 ms]),
    (1.35, [silu · ×], c-line-hi, none),
    (1.55, [down GEMV], c-sel, [1.84 ms]),
    (1.0, [\+ x], c-line-hi, none),
  )
  let y1 = 2.55
  let y2 = 1.1
  let x1 = place(0, 0.26, r1)
  let x2 = place(0, 0.26, r2)
  chain(y1, x1, r1)
  chain(y2, x2, r2)
  // wrap from the end of row 1 to the start of row 2
  let e1 = calc.max(x1.last() + r1.last().at(0), x2.last() + r2.last().at(0))
  let w1 = x1.last() + r1.last().at(0)
  line((w1 - 0.4, y1), (w1 - 0.4, y1 - 0.42), (0.7, y1 - 0.42), stroke: 0.45pt + c-line-hi)
  arrow((0.7, y1 - 0.42), (0.7, y2 + h))
  // the expansion bracket from the layer node
  let lx = xt.at(1)
  rect((-0.2, y2 - 0.25), (e1 + 0.2, y1 + h + 0.3), fill: none, stroke: (paint: c-line, thickness: 0.4pt, dash: "dashed"))
  line((lx + 0.2, yt), (-0.2, y1 + h + 0.3), stroke: (paint: c-line, thickness: 0.4pt, dash: "dashed"))
  line((lx + 2.5, yt), (e1 + 0.2, y1 + h + 0.3), stroke: (paint: c-line, thickness: 0.4pt, dash: "dashed"))
  // legend
  let leg = (
    (c-sel, [4-bit GEMV · dequantization inlined]),
    (c-info, [attention · reads live cache rows only]),
    (c-ok, [in place / on device]),
    (c-line-hi, [maps and small reductions]),
  )
  for (k, (col, t)) in leg.enumerate() {
    let lx = calc.rem(k, 2) * 6.4
    let ly = 0.45 - calc.floor(k / 2) * 0.38
    rect((lx, ly - 0.09), (lx + 0.3, ly + 0.09), fill: c-surface, stroke: 0.6pt + col)
    lbl((lx + 0.42, ly), t, anchor: "west", fill: c-text)
  }
})

// Fig: where a Qwen3-8B decode step goes at 4k context (sum of isolated launches, RTX 3090).
#let fig-decode() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let s = 1.0
  let segs = (
    ([gate|up], 2.76, c-sel),
    ([down], 1.84, c-sel.transparentize(25%)),
    ([qkv], 1.25, c-sel.transparentize(45%)),
    ([Σ p·v], 1.13, c-info.transparentize(35%)),
    ([o], 0.75, c-sel.transparentize(60%)),
    ([q·k], 0.73, c-info.transparentize(60%)),
    ([LM head], 0.56, c-label.transparentize(30%)),
    ([small kernels], 1.32, c-line-hi),
  )
  let x = 0
  for (k, (name, t, col)) in segs.enumerate() {
    rect((x * s, 1.0), ((x + t) * s, 1.7), fill: col, stroke: 0.4pt + c-bg)
    if t > 1.0 { lbl(((x + t / 2) * s, 1.35), [#t], fill: c-bg, font: mono-sb) }
    // legend: two rows of four
    let lx = calc.rem(k, 4) * 2.95
    let ly = 0.5 - calc.floor(k / 4) * 0.42
    rect((lx, ly - 0.1), (lx + 0.2, ly + 0.1), fill: col, stroke: none)
    lbl((lx + 0.3, ly), [#name #h(0.3em) #text(fill: c-label)[#t]], anchor: "west", fill: c-text)
    x += t
  }
  lbl((x * s + 0.12, 1.35), [10.3 ms], anchor: "west", fill: c-text)
  // speed of light at 4k: 4.26 GB weights + 0.6 GB KV at 936 GB/s
  let sol = 5.2
  rect((0, 2.0), (sol * s, 2.3), fill: none, stroke: (paint: c-ok, thickness: 0.6pt, dash: "dashed"))
  lbl((sol * s + 0.15, 2.15), [bandwidth limit · 5.2 ms], anchor: "west", fill: c-ok)
})

// Fig: the attention backward, before and after nesting (CUDA, RTX 3090, seq 512).
#let fig-backward() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let box(x, y, w, t, sub, big: false, hot: false) = {
    rect((x, y), (x + w, y + 0.8), fill: c-surface, stroke: (paint: if hot { c-sel } else if big { c-fault } else { c-line-hi }, thickness: if hot { 0.9pt } else { 0.6pt }, dash: if big { "dashed" } else { none }))
    content((x + w / 2, y + 0.5), text(size: s-sm, fill: c-text, t))
    lbl((x + w / 2, y + 0.16), sub, fill: if big { c-fault } else if hot { c-sel } else { c-label })
  }
  let arrow(a, b) = line(a, b, stroke: 0.5pt + c-line-hi, mark: (end: ">", fill: c-line-hi, size: 0.1))
  // before
  lbl((0, 6.25), [before · 63 kernels · 1.80 ms], anchor: "west")
  let xs = (0, 2.05, 4.1, 6.15, 8.2)
  let tops = (([$S = Q K^top$], [n × n]), ([$max_j S$], [n]), ([$tilde(P) = e^(S - m)$], [n × n]), ([$"dP" = "dO" V^top$], [n × n]), ([corrections], [3 kernels]))
  for (k, (t, sub)) in tops.enumerate() { box(xs.at(k), 5.0, 1.85, t, sub, big: sub == [n × n] or k == 4) }
  let tiles = (([dQ], 1.0), ([dK], 4.1), ([dV], 7.2))
  for (t, x) in tiles {
    box(x, 3.4, 2.0, t, [tile])
    for k in range(5) { arrow((xs.at(k) + 0.92, 5.0), (x + 1.0, 4.2)) }
  }
  // after
  line((-0.1, 2.75), (10.15, 2.75), stroke: (paint: c-line, thickness: 0.4pt, dash: "dotted"))
  lbl((0, 2.35), [after · 49 kernels · 1.22 ms · nothing n × n written], anchor: "west", fill: c-sel)
  for (t, x) in tiles {
    rect((x - 0.15, 0.0), (x + 2.15, 1.95), fill: none, stroke: 0.9pt + c-sel)
    content((x + 1.0, 1.62), text(size: s-sm, fill: c-text, t))
    box(x, 0.2, 2.0, [$S, "dP"$ per block], [on mma], hot: true)
  }
})


// ---- title page ---------------------------------------------------------------
#if not web {page(margin: (x: 0.75in, top: 0.7in, bottom: 0.65in))[
  #set par(leading: 0.5em)
  #grid(columns: (auto, 1fr, auto), column-gutter: 0.8em, align: horizon,
    caps(fill: c-text)[Municipal Robotics · Research],
    line(length: 100%, stroke: 0.5pt + c-line-hi),
    caps[November 2026])
  #v(1.6em)
  #image("images/muni-logo.svg", width: 0.95in)
  #v(0.35in)
  #align(center, tiles(size: 11.5))
  #v(0.1in)
  #grid(columns: (1fr, auto), align: (left, right),
    caps[Causal attention, n = 1024 · one square per 32 × 32 tile · nothing n × n written],
    caps(fill: c-sel)[Derived, not written])
  #v(1fr)
  #move(dx: -0.045 * s-display, text(font: sans-sb, size: s-display, tracking: -0.02em)[Don't Write Kernels,\ Derive Them])
  #v(0.5em)
  #line(length: 22%, stroke: 2pt + c-label)
  #v(0.7em)
  #text(size: s-lg, fill: c-label)[Chasing the Speed of Light: Kernels from a Tensor IR of Views and Comprehensions]
  #v(0.5in)
  #caps[Cam Pedersen · Municipal Robotics]
]}

#let abstract-text = [
Every fast model today runs on kernels someone wrote by hand, one per operator, per chip and per fusion. Each one freezes choices about what to fuse, where data lives and how threads share work, and those choices are right for one shape on one device. We think kernels should be derived instead.

tang's tensor IR is built from two constructs. _Views_ are affine maps from an iteration space to tensor coordinates. _Comprehensions_ are reductions under a monoid whose body is a scalar expression graph. Everything else is either a rewrite or a schedule. Fusion is one substitution rule. We do not write a flash attention kernel. The compiler derives its schedule by recognizing online softmax as a monoid. Gradients of comprehensions are comprehensions, so the same passes derive and optimize the backward pass. That includes a flash-style attention backward that writes no $n times n$ intermediates on the three GPU backends we measured (on CUDA through a fused kernel that computes in bf16 and so misses an f32 tolerance, and on WGSL and Metal at a cost we report). The recent superoptimizers we discuss derive only the forward. Precision and thread mapping are schedule fields that cannot change the math (precision changes only rounding, which an emulator budgets with known failure modes), chosen per kernel by measurement on the device.

One graph lowers to WGSL, CUDA tensor cores, Metal simdgroup matrices, OpenCL, GLSL and C, from a datacenter GPU and a desktop GPU and a laptop down to a humanoid robot's phone-class SoC. On an idle RTX 3090 a derived transformer block's forward pass at sequence length 512 is 1.2× faster than PyTorch captured in a CUDA graph with TF32; at length 128 PyTorch is 1.2× faster, and forward plus backward ties. Qwen3-8B decodes as a single IR graph at 148.7 tok/s, tied with llama.cpp at short context and at 92% of it at 4k. We wrote no kernel for any one operator. A short list of emitters is keyed on the shape of a graph rather than on an operator: CUDA's flash kernel (the online-softmax monoid), the fused Hopper attention backward, the narrow GEMV (matrix–vector product) stage, the integer tensor-core stage and the chunked scan plan. Derived attention is not uniformly fast. At $d = 64$ the forward trails FlashAttention-2 at every size we tested, and on the RTX 3090 no tensor-core forward is generated at $d = 128$, which makes it about 150× slower than FlashAttention-2 there. We then derive the kernels of a hand-tuned engine that serves an 80B mixture-of-experts model on one H200. With the work made equal, the derived MoE expert layer is 18% slower than the engine's hand kernels at batch 1 and 7% slower at batch 4, ties at 8 and is 5% faster at 64. Inside the model, where the derived path runs only from 16 window rows up, a decode step takes 5–12% less time at 16 to 48 concurrent streams over five interleaved rounds on one H200, though the derived path misses the engine's 48-stream agreement gate, 98.93% against a 99% bar. The derived head-dim-256 attention and gated-delta scan cut the engine's own time to first token at 44k tokens from 8.33 s to 5.54 s, but vLLM on the FP8 checkpoint reaches first token about 12× faster than the engine, so this is a gain over our own baseline, not over the state of the art. At $d = 256$ the derived attention runs at 0.43–0.54 of FlashAttention-3's speed forward and 0.22–0.40 backward.

Finally, we ask how far a kernel is from the fastest any implementation could be. For a comprehension over affine views, the least memory traffic and the tile that attains it are the primal and dual of one linear program, and we prove weak duality in Lean for arrays indexed by subsets of the loop coordinates, along with the soundness of the core rewrites. A time floor built on that bound, with launch cost measured on both GPUs and DRAM latency measured on the H200 and assumed on the RTX 3090, never exceeds the measured time on the 24 GEMV-class and epilogue kernels we validated on two GPUs. On the RTX 3090 it reaches 0.76–0.93 of measured time on the large kernels. On the H200 it reaches only 0.05–0.66 (median 0.38), and we have no validated term for the gap. Inside the schedule space, a two-level version of the program picks the tile the M4 Max autotuner picks, but only for register capacities between 4096 and 8192 words, and the traffic-optimal tile does not win on time. In a timed race of every candidate tile on the M4 Max and the RTX 3090, no candidate ran faster than the floor. A per-tile estimate built on it picks a tile within 2.5% of the fastest on seven of eight kernels and loses the eighth by 1.27×.
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

A modern model has a few dozen distinct operators. A modern framework has thousands of kernels. Every (operator, backend) pair needs one. So does every fusion that pays, such as attention with its softmax, a matmul with its bias and activation, or a norm with the projection after it. FlashAttention @dao2022flash is the best-known case. Its large speedup came from rewriting one operator by hand so its $n times n$ score matrix never reaches memory. Its backward pass took a second hand-written kernel. Hopper took a third @shah2024flash3, and Blackwell's FP4 tensor cores are taking a fourth.

Each hand kernel is a separate copy of the same arithmetic, and each one freezes a schedule that was right for one shape on one device. We measured how often that schedule is wrong: the fastest schedule changes with the size, the chip and even between runs on the same machine (§7.1). The winning schedule is a property of the graph, the chip and the size, not of the operator.

Our thesis is that *a kernel is a theorem, not a program*. Every fast kernel we know of is a claim of the form "this comprehension, reassociated under this monoid and placed in this memory, equals the naive one over the reals." Such a claim can be derived, checked and searched. It does not need to be written. It can also be bounded: the least traffic any box-tiled schedule of a comprehension can move, and the tile that moves it, are dual solutions of one linear program. A theorem fixes what is computed. How fast it runs is still a schedule, and §11 lists the schedules tang does not yet have. If that is right, the kernel library should be replaced by an algebra small enough to reason about, together with a search over its schedules. @fig-one shows one graph under the schedules that the field knows by name.

#[#set figure.caption(position: top)
#figure(fig-one(), kind: image,
  caption: [One causal attention graph ($n = 4096$, $d = 64$, f32) under four schedules, lowered to CUDA on an idle RTX 3090. Only where $S = q k^top$ and $P = "softmax"(S)$ live, and where kernels end, differ. Checkpointing and flash are points in this space, and the search lands on the flash placement: 18× faster than as written and 40× faster than checkpointing. Every point is checked against the f64 interpreter at this size, with tolerance $2 times 10^(-3)$; flash and the searched schedule use TF32 tensor cores. "Traffic" is the compiler's model of DRAM bytes, one pass per buffer, and "rel. error" is the largest error over the largest reference value. Times are medians of 7 samples.],
) <fig-one>]

The traffic column is not the time column. Checkpointing moves a third of the naive schedule's traffic and is 2.2× slower. The score contraction $S = q k^top$ accounts for more than the whole difference: 7.12 ms against 1.51 ms, with the same arithmetic and the same output. The naive schedule writes $k^top$ in its own small transpose kernel, so a warp's 32 lanes then read 32 adjacent floats. Checkpointing folds the transpose into the reader's view, so each lane reads its own row of $k$. Nsight shows the same 67.6 M L1 requests carrying 5.4 GB in one case and 35.5 GB in the other. The output is exact to $2 times 10^(-6)$, so the lowering is correct but loses coalescing, and a traffic model that counts DRAM bytes once per buffer cannot see it. Flash, which also has the least traffic, wins.

The backward tells a less flattering story. tang's fused attention backward kernel computes in bf16 tensor cores even when the graph is f32. On this graph its gradients miss the experiment's tolerance of $2 times 10^(-3)$, measured as max error over max reference against the f64 interpreter (error $1.5 times 10^(-2)$ in $d q$), so the search rejects it. Without the fused kernel the searched placement passes at $1.2 times 10^(-3)$ in 1.91 ms, against 0.74 ms for the failing fused version. The search also rejected one placement whose output was simply wrong, at error 7.0; that bug is caught by the check but not yet explained.

#if web [
  #html.elem("div", attrs: (id: "memory-dial", class: "derive-host"))
]

We propose writing the model once, as math, and letting the compiler derive every kernel. That works only if the IR is small enough to reason about and expressive enough that nothing important falls outside it. tang is a `no_std` Rust library that started as a geometry and physics math crate. Its `tang-expr` crate traces Rust closures into scalar expression graphs that it can differentiate, simplify and compile, and its tensor IR uses those graphs as its body language. The IR has two constructs.

- *Views*: affine index maps that express broadcast, transpose, slicing, striding, padding and per-head column selection without touching memory.
- *Comprehensions*: $"out"[i] = plus.o_k "body"(x_0[v_0(i,k)], x_1[v_1(i,k)], dots)$, where `body` is a scalar expression graph and $plus.o$ is a monoid.

Contributions:
+ *Kernels from rewrites.* Fusion, flash attention, logsumexp and Welford variance are instances of a small set of rewrites (§2).
+ *Derived backward passes.* Reverse-mode differentiation maps comprehensions to comprehensions, including the online-softmax monoid. A proof procedure removes the stabilizing max's gradient, and with nested contractions this yields an attention backward with no $n times n$ tensors (§3).
+ *Precision as a schedule.* An emulating interpreter checks a format choice against an error budget before it runs, with failure modes we report (§4).
+ *One graph, six targets.* Lowerings from shared emitters, measured against hand kernels, PyTorch and the bandwidth limit on four chips (§5, §7).
+ *A production engine, derived.* Top-$k$ routing as one monoid, integer tensor-core and narrow GEMV schedules, a segmented-sum gather backward, chunked scans, and Hopper attention schedules. With them, derived kernels replace hand kernels in an 80B MoE engine on an H200, faster in some regimes and slower in others, which we report (§8, §11). A whole derived decode step matches the hand engine on Qwen3-8B and trails it by 13–35% on the 80B MoE.
+ *The speed of light.* The traffic lower bound and the optimal tile are dual solutions of one linear program read off a kernel's views, with weak duality in Lean. A time floor built on it never exceeds measured time on 24 GEMV-class and epilogue kernels on two GPUs; it is close on the large kernels of the RTX 3090 and loose on the H200 (§9).

= The IR

== Views

A view maps a point of an iteration space to a source tensor's coordinates with one affine form
per source dimension, $"offset" + sum_j c_j dot "idx"_j$. Broadcast is a zero form, transpose a
permutation, slice an offset, stride a coefficient. A form with two terms expresses "head $h$ reads
columns $64h + 2i$". Views compose by substitution. They are the only way a comprehension reads
its inputs, so every layout decision is a view and every view can be analyzed.

A view may be _guarded_, so that an out-of-range read returns the monoid's identity (zero for sum, $-infinity$ for max) rather than
raising a shape error. Padded, dilated and transposed (polyphase) convolutions and overlap-add are
guarded reads, with no padding operator. The adjoint of a guarded read is itself a guarded read,
not a scatter. For $y[o, t] = sum_(c,k) w[o, c, k] x[c, t + 3k - 9]$, $partial x[c, tau]$ reads
$partial y[o, tau - 3k + 9]$ through the same guard, so out-of-range (padding) terms never reach $x$.

Grouped-query attention's $"head" \/ "heads_per_group"$ is not affine. The IR expresses heads as
two dimensions, $["groups", "per_group"]$, and the views do the rest. Dimensions can be fixed or
symbolic (`Dim::Sym("seq")`). Construction, rewriting and differentiation work with symbols, and
`bind` makes them concrete for scheduling and lowering.

A view may also _gather_. One source coordinate is then data, read from an index tensor that is a sibling argument of the same comprehension, $"form" + c dot "round"("idx")$. MoE routing ($W["sel"[t, k]]$), paged KV caches ($b_s dot "table"["blk"] + "off"$) and embedding lookups become ordinary reads rather than special operators. The gradient of a gathered read is a scatter-add, written as a dense gated sum, which costs $E$ times the needed work unless the keys are declared sorted (§8). An affine map read through a gather still fuses into it, and only nested gathers materialize.

== Comprehensions and monoids

The only compute operation is

$ "out"[i_1, dots, i_p] = plus.o.big_(k_1, dots, k_r) "body"(x_0[v_0(i, k)], dots, x_m [v_m (i, k)]) $

A map is a comprehension with no reduce dimensions. Sum and max are monoids. Matmul is
$sum_k a[i,k] b[k,j]$. Attention scores, convolution and gather are the same operation with
different views. The monoid's `combine` is itself a scalar graph, and a comprehension may carry
tuple-valued state. Online softmax is the monoid on $(m, l)$, the running max and the rescaled sum, and attention carries the weighted values with it as $(m, l, "acc")$; arg-max is the monoid on
$("index", "value")$.

== Rewrites

*Fusion is one rule.* A map is a pure function of its inputs, so `substitute_maps` splices its body
into every consumer and composes the views. Map→map, map→reduce and transpose→anything are the
same case. The rule is cost-aware, so a map is recomputed inside a reduction only when it is cheap.
Reductions are never substituted. They are _inlined_ by a schedule decision, which separates
algebra from scheduling. A row-major reshape that only merges dimensions is a view, not a copy.

*Epilogues run on the reducing thread.* A map that reads a reduction point for point (a bias, an activation,
the $"acc" \/ l$ that finishes softmax) runs on the thread that holds the final accumulator.

*Sibling reductions merge.* Two reductions over the same space and monoid with the same readers become
one reduction under the product monoid (`merge_siblings`). The gate and up projections of a SwiGLU
MLP become one tuple-valued matmul, the activation becomes its epilogue, and the normalized input is
read once.

*Flash attention is a rewrite.* `stabilize_softmax` finds $m = max_j s_j$ and every
$sum_j g dot exp(s_j - m)$ over the same canonical $s$, with masks and scales allowed, and replaces
them with one reduction under the online-softmax monoid. The value column of $sum_j p_j v_j$ becomes
a point dimension (an output dimension, not reduced over) of the fused comprehension. Nothing $n times n$ is materialized. Logsumexp,
Welford variance and top-k are the same rewrite with different monoids. @fig-rewrite shows the attention case.

#figure(fig-rewrite(),
  caption: [The rewrite that derives flash attention, schematically (the lab's typed graph also carries mask and scale maps, so the §2.3 counts are higher). The naive graph writes the scores and probabilities as $n times n$ buffers (dashed). Fusion splices the maps into their readers; `stabilize_softmax` merges the max and both exponential sums into one reduction whose state is $(m, l, "acc")$. No operator-keyed code is involved; scheduling then finds the tiled kernel.],
) <fig-rewrite>

The rewrite is not specific to plain attention. Anything that changes the score or the mask leaves the monoid structure alone, so it derives the same way.
#if web [
  The lab below runs tang's compiler, built to WebAssembly from the same crates as this paper, in your browser. Type a variant: it builds the naive graph, runs the real pass pipeline, then runs both programs on your GPU through WebGPU and checks them against tang's f64 interpreter.
  #html.elem("div", attrs: (id: "derive-lab", class: "derive-host"))
] else [
  @tab-gallery lists six variants the compiler derives.#footnote[The web edition derives these in the reader's browser and runs them through WebGPU: #link("https://muni.works/research/tang")[muni.works/research/tang].]
  #let gal = csv("data/derive-gallery.csv", row-type: dictionary)
  #figure(
    table(
      columns: (auto, auto, auto, auto, auto),
      align: (left, left, left, right, right),
      [variant], [score], [mask], [fwd kernels · n×n], [fwd+bwd kernels · n×n],
      ..gal.chunks(2).map(((f, b)) => (
        [#f.variant], raw(f.score), if f.mask == "" [—] else { raw(f.mask) },
        [#f.naive_kernels · #f.naive_nxn → *#f.derived_kernels · #f.derived_nxn*],
        [#b.naive_kernels · #b.naive_nxn → *#b.derived_kernels · #b.derived_nxn*],
      )).flatten()
    ),
    caption: [Six attention variants as typed into the lab, $n = 1024$, $d = 64$. Each cell is kernels · $n times n$ buffers, as written → derived (WGSL). The forward always becomes one kernel with nothing $n times n$; with nested contractions (§3) the backward also writes nothing $n times n$, in 7 kernels. Generated by `tang-derive-wasm`'s `gallery` example.],
  ) <tab-gallery>
]

== Rediscoveries

The rewrites above are general, so known algorithms fall out of them. @tab-rediscover lists the ones tang derives today. Each row was a paper or a hand kernel. In tang each is a monoid, a view or a schedule field, and none adds an operator.

#figure(placement: auto,
  table(
    columns: (auto, auto, auto),
    align: (left, left, left),
    [algorithm], [originally], [in tang],
    [online softmax], [Milakov & Gimelshein 2018 @milakov2018online], [monoid on $(m, l)$],
    [FlashAttention forward], [Dao et al. 2022 @dao2022flash], [`stabilize_softmax` + staging rule (which operands a tile copies into shared memory or registers)],
    [FlashAttention backward], [hand kernel @dao2022flash], [derived gradient, max elimination, nested contractions (§3)],
    [Welford variance], [Welford 1962 @welford1962], [monoid on $(n, mu, M_2)$],
    [logsumexp, arg-max], [folklore], [monoids on $(m, l)$ and $("index", "value")$],
    [top-$k$ routing], [hand kernel], [`Monoid::topk`, merge of sorted lists],
    [split-K GEMM], [hand kernel], [`split` on any associative monoid],
    [SwiGLU gate|up fusion], [hand kernel], [`merge_siblings` under a product monoid],
    [implicit-GEMM convolution], [hand kernel], [guarded views, flattened reduce dims],
    [paged KV cache], [vLLM], [gather view],
    [scatter-add backward, segmented], [hand kernel], [gated sum + `set_sorted` segment (§8)],
    [chunked SSD / gated delta rule], [Dao & Gu 2024 @dao2024ssd; Yang et al. 2025 @yang2025gdn], [affine scan monoid + chunked plan (§8)],
  ),
  caption: [Algorithms that tang derives rather than implements. Each derivation is checked against the f64 interpreter of the naive graph.],
) <tab-rediscover>

== Schedules

A comprehension says _what_ to compute. Schedule fields say _how_, and they cannot change the
math (precision changes rounding, §4):

- `inline`: recompute inside the consumer instead of writing a buffer.
- `split`: one workgroup per point, with threads striding the reduce space and tree-combining. This
  is valid for any monoid because combine is associative, including online softmax.
- `tile`, `tile_2d`: blocks of threads, each owning a register tile of points. The emitter tracks
  every address as an affine form over loop variables. Anything that does not depend on the lane
  axis is staged in workgroup memory once per reduce chunk. That covers buffer reads (K and V
  tiles, matmul operand tiles) and inlined sub-computations (the $q dot k$ scores).
- `precision`: storage and accumulation formats (§4).

`schedule_auto` encodes rules of thumb distilled from measurement. `autotune_kernels` times each
candidate mapping per materialized node on the device, using the graph's real inputs, and caches the
winner by device and kernel source. With substitution and the online-softmax rewrite, the staging
rule produces the structure of flash attention: rows × lanes per workgroup, cooperative score
tiles, and online softmax in registers.

= Gradients are comprehensions

For $y = plus.o_k "body"(x[v(i,k)])$, the gradient with respect to $x$ through a _pick_ view (one whose forms are each a single coordinate) is
found by renaming coordinates. The coordinates that $v$ picks become $x$'s output dimensions, the
rest become reduce dimensions, and every other view is pushed through the same renaming. The body is
differentiated by `tang-expr`'s symbolic `diff`, which covers its nine arithmetic operations (add, multiply, negate, reciprocal, square root, sine, atan2, $2^x$, $log_2$) plus a select. A dimension read through any other form (an
offset, stride, diagonal or broadcast) stays an output dimension, and `iota`, a node that turns coordinates into values, gates the body by
$[c = "form"]$. Max gates its term to the
arg-max. The backward graph is an ordinary graph, so the same passes optimize it. Rotary embedding
and GQA (grouped-query attention) gradients come from the gated scatter with no special handling.

*The online-softmax monoid* has its own rule. With the forward's $m$ and accumulators read back,
$partial "acc"_i \/ partial s_(i j) = g_j exp(s_(i j) - m_i) - "acc"_i [s_(i j) = m_i]$, where $g_j$ is key $j$'s value, so the flash-fused graph
differentiates and its gradients equal the naive graph's.

*A stabilizing max has no gradient.* That the max can be stopped is standard practice in logsumexp implementations. What is new here is a proof the compiler runs per graph. Softmax is invariant to shifting its scores, so the
$[s = m]$ terms sum to zero, but only in exact arithmetic. While those terms exist, the max must be
materialized and masked tiles cannot be skipped. `backward` drops them when it can prove the loss
does not depend on $m$. The proof tracks how each node downstream of $m$ scales with $t = exp(-m)$. In softmax, $p_j = exp(s_j - m) = t dot exp(s_j)$ has degree 1 in $t$, so does $l = sum_j p_j$, and so does $"acc" = sum_j p_j v_j$; their ratio $o = "acc" \/ l$ has degree 0, a function of the scores alone. In general a node is either $t^k h$ or $a + kappa m$ with $h, a$ free of $m$, combined by exact identities.#footnote[$t^a t^b = t^(a+b)$; $sum_j t h_j = t sum_j h_j$ when $t$'s row does not depend on $j$; $2^(a + kappa m) = 2^a t^(-kappa ln 2)$; $log_2(t^k h) = log_2 h - k m \/ ln 2$, again of the form $a + kappa m$.] If every path from $m$ ends at a degree-0 node, $partial L \/ partial m equiv 0$ and the gradient is not built. The f64 evaluation of a training step is unchanged (largest absolute difference $2.7 times 10^(-19)$).

*The flash backward recomputes inside tiles* (@fig-backward). `hoist_invariant_factors` factors row-invariant terms out of sums
($sum_c tilde(P) dot "dO" dot V -> tilde(P) dot sum_c "dO" dot V$). `schedule_nested_contractions`
then inlines a short contraction (one reduce dimension of at most 128) into every tile that reads
it. The attention backward reads $S = Q K^top$ and $"dP" = "dO" V^top$ only through $tilde(P)$ and
$"dS"$, which the dQ, dK and dV tiles recompute per staged block on tensor cores. On CUDA this removed
S, $tilde(P)$, dP, the max over S and three correction kernels from a transformer training step,
reducing 63 kernels to 49 and the summed best-per-kernel time from 1.80 to 1.22 ms at sequence
length 512 (RTX 3090). WGSL and Metal now nest the same contractions with scalar dot products in workgroup memory, so no GPU backend we measured (CUDA, WGSL, Metal) writes anything $n times n$. For now this costs speed. Forward plus backward runs at 0.68–0.93× the materialized schedule on Metal and 0.25–0.34× under Vulkan on a 3090, until the nested dots are register-blocked the way the `mma` path blocks them.

#figure(fig-backward(),
  caption: [The attention backward of a training step, before and after. Before, the scores, probabilities and $"dP"$ are written as $n times n$ buffers (dashed) and read by three gradient tiles. After the stabilizing max loses its gradient and invariant factors leave the sums, the short contractions $S$ and $"dP"$ are recomputed per staged block inside each tile, on tensor cores. CUDA, RTX 3090, seq 512; summed best-per-kernel times.],
) <fig-backward>

= Precision is a schedule

f16 is a different way to run the same program, not a different program. Each node has a
_storage_ format, applied where a value is written to memory, and an _accumulation_ format,
applied to a reduction's running state after each combine. The graph stays exact math.

The interpreter gives an error budget, with known failure modes. `eval` is pure f64. `eval_emulated` rounds every stored value
and every accumulator step to its scheduled format (round to nearest even, subnormals, overflow),
with body arithmetic in f64. An `ErrorBudget` accepts or rejects a schedule before it runs.
Emulation matches the GPU's f16 kernels to 1 ulp when the reduction order is the same. Otherwise the
order is part of the error: AdaIN's variance over $T = 2000$ with an f16 accumulator has error
$2.8 times 10^(-4)$ under a 256-thread split and $1.3 times 10^(-2)$ with one thread per row, while
the sequential emulation predicts $7.9 times 10^(-3)$. Emulation models one sequential fold; a tree-combining split beats it, and the per-row GPU kernel, though also sequential, comes out somewhat worse, which we attribute to its different accumulation order and fused arithmetic rather than having verified it. The prediction can be far off when the reduction length or order differs: a conv1d sum of 3,584 terms measures $3.1 times 10^(-2)$ against a predicted $5.6 times 10^(-3)$, a ConvNeXt LayerNorm statistic $6.9 times 10^(-2)$ against $1.5 times 10^(-4)$, and a pointwise matmul $1.7 times 10^(-2)$ against $1.4 times 10^(-4)$. Those predictions were made on smaller instances, whose shorter sums round less. At equal reduction length (matmul, AdaIN) prediction and measurement agree within about 1.7×.
`tune_precision` lowers buffers to half precision one move at a time and keeps a move only if the
program stays within budget and gets faster.

= Lowering

Shared emitters produce the point, split and tiled schedules, register tiles, guarded views,
epilogue fusion and tuple monoids once. A dialect switch then handles buffer access and surface
syntax.

- *WGSL* (portable default, through wgpu on Metal, Vulkan and DX12). f16 storage is packed two per
  `u32`, because wgpu's shader compiler (naga) rejected `enable f16` on our targets.
- *CUDA.* Matmul-shaped tiles run on `mma.sync` (TF32, the tensor cores' 19-bit float mode, m16n8k8, or f16/bf16 m16n8k16 when the
  operands are half precision) with `cp.async` staging rings. Block shapes are tuning candidates.
  `cuda_flash_kernel` recognizes the online-softmax comprehension and keeps $O$, the row max and the
  partial sums in `mma` registers. The score accumulator is reused as the A operand of $O += P V$
  after permuting keys within each 8-wide step, which is legal because the reduction is
  commutative and associative.
- *Metal (MSL).* Native `half` and `bfloat`. Contractions with f16 operands run on
  `simdgroup_half8x8` fragments. Reduce dimensions are flattened, so convolution becomes implicit
  GEMM, with dilated inputs staged once per chunk as a zero-padded, phase-de-interleaved window.
- *OpenCL and GLSL* for Adreno GPUs that have neither CUDA nor Metal. On one Adreno driver, WGSL is
  routed through GLSL because the direct SPIR-V path was miscompiled.
- *C*, for batch-1 control loops where a GPU round trip costs more than the arithmetic. A
  comprehension already is a loop nest, so `to_c` emits it directly with a vectorizable innermost
  point dimension, and `tang_run()` performs no allocation.

`Program::tuned` times each kernel's native lowering against the portable one and keeps the faster.
Kernel sources are canonicalized, so the same kernel at another layer is the same string and
compiles once.

= Verification

Speed claims depend on every kernel being correct. `tang-verify` runs each GPU kernel against its
CPU oracle on the same input, starting from the device's own state. Before each kernel runs, it fills
the kernel's outputs with NaN, so unwritten memory cannot pass as a plausible 0. When a check fails,
it names the kernel at fault by provenance: which earlier kernel's correct output the failing
buffer contains. We built it after four structural bugs in a hand-written engine slipped past every unit
test. One was a byte offset added where a float offset was meant, which wrote k's values over q.
Derived kernels are less exposed to that class of bug, because addresses come from affine forms
rather than pointer arithmetic. On the IR path there is a second check, because the f64 interpreter runs
the same graph as the GPU.

The rewrites themselves are mechanized in Lean 4 with Mathlib, with no `sorry` (`proofs/`, listed in `docs/proofs.md`). Over the reals, view composition, fusion, split and tiled reductions, online softmax as a commutative semigroup (the proof has no identity element, and the compiler supplies $(-infinity, 0)$), its equality with two-pass softmax, shift invariance, gradients of sum comprehensions, the zero gradient of a stabilizing max, and the flash backward identity are theorems. One combine exported from the compiler is proved equal to the verified online-softmax combine. Floating point is not modelled, and guarded and gathered views are outside the fusion theorem.

= Evaluation

*Setup.* Apple M4 Max (Metal), NVIDIA RTX 3090 (Vulkan and CUDA 12), a Qualcomm QCS8550 in a
Booster K1 humanoid robot (Adreno 740, Cortex-X3), and, for §8, an NVIDIA H200. PyTorch 2.10 for the shared-GPU runs and 2.8 for the idle-GPU runs, both cu128, timed with CUDA events. Unless
a caption says otherwise (@tab-hand includes submit and readback), tang times are kernel-only. Several runs shared the GPU with other tenants. We
mark those, and report minima rather than means, because contention only adds time. Derived results are checked against an f64 interpreter, except where a caption says otherwise. The tolerance differs per experiment and is stated with it: $10^(-6)$ to $10^(-4)$ relative for the kernels of §7.1–7.2, $2$–$5 times 10^(-3)$ for bf16 attention at $d = 256$, and arg-max agreement at 257 positions for the Qwen3-8B step.

== Derived vs hand-written kernels

tang shipped hand-written WGSL kernels before the IR existed, which makes a controlled comparison
possible: same runtime, same chip, same inputs. Here "as written" is the unfused graph, one kernel per comprehension; "derived" is any schedule the compiler produces, and the autotuner keeps the as-written graph's naive schedule as one candidate, which is why it can win. On the M4 Max the fastest schedule for causal attention flipped between two runs of the same code: in one run $n = 512$ was fastest naive ($n^2$ threads) and $n = 1024$ tiled, and @tab-hand, a later run, has the reverse. The naive graph wins when its scores fit in cache and parallelism, not bandwidth, is the bottleneck, which depends on the size and the machine's power state. A $16 times 16$ shared-memory matmul tile wins at $128 times 576 times 1536$ and loses at $1024^2$, and rules of thumb tuned on the M4 picked the wrong matmul schedule on an RTX 3090. @tab-hand is one consistent run on the M4 Max,
including about 1.8 ms of submit and readback per measurement.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, right, left),
    [op], [hand], [derived], [schedule],
    [causal attention $n = 1024$], [10.9 ms], [*3.31*], [naive ($n^2$ threads)],
    [causal attention $n = 512$], [4.91], [*2.02*], [auto (tiled)],
    [matmul $1024^2$], [6.68], [5.49], [auto],
    [rmsnorm $2048^2$], [2.52], [2.70], [split],
    [transformer block, seq 512], [23.9], [*10.1*], [per-kernel autotune],
    [decode block, q 1 / kv 1024], [8.80], [*3.28*], [per-kernel autotune],
    [training step, seq 128], [179], [*7.96*], [auto],
  ),
  caption: [Hand-written vs derived on M4 Max (Metal via WGSL). Every time includes about 1.8 ms of submit and readback, which dominates the small ops. The hand training step ran its attention backward on the CPU, since no GPU version existed, so that row shows coverage, not kernel quality.],
) <tab-hand>

Leaving aside the training step, the derived kernels win or lose by small margins on the small ops. With the 1.8 ms overhead subtracted, matmul is 1.32× faster than hand and rmsnorm 1.25× slower. The schedules that win differ across operators and sizes.
On the 3090 under Vulkan, the derived transformer block first _lost_ to the hand path. Three
chip-agnostic fixes followed: cost-aware substitution, keeping reductions schedulable under their
epilogues, and a bank-conflict-free tile layout. After them, the autotuned block won there too
(2.5 vs 3.1 ms at seq 128, 6.2 vs 10.4 ms at seq 512, both including about 1.25 ms of submit and readback).




== Against PyTorch

@tab-torch tracks a 9-head GQA transformer block ($d = 576$, $"ff" = 1536$, rotary embeddings,
SwiGLU) on the RTX 3090 as the backends matured. Through WGSL, which has no access to tensor cores,
derived kernels stayed 2.6–10× behind PyTorch. With the CUDA lowering, flash attention on
`mma.sync` and the backward passes of §3, the seq-512 forward block passes PyTorch (@fig-trajectory).

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, right, right, right, right),
    [Block, seq], [WGSL first], [WGSL fused], [CUDA], [eager Torch fp32/TF32],
    [fwd 128], [1.97], [1.06], [0.178], [0.306 / 0.286],
    [fwd 512], [4.41], [3.34], [0.328], [0.602 / 0.449],
    [fwd+bwd 128], [5.0], [3.15], [0.552], [1.196 / —],
    [fwd+bwd 512], [10.1], [8.19], [1.467], [1.719 / —],
  ),
  caption: [Transformer block on a shared RTX 3090 against eager PyTorch, an earlier run. The CUDA column and PyTorch were measured in
  interleaved rounds under `flock`, best of six; times in ms. The WGSL columns come from earlier runs and are
  shown to make the trajectory visible. @tab-torch-graph repeats the comparison on an idle GPU against PyTorch's faster modes, with a later build of tang, and is the one to cite.],
) <tab-torch>

On the CUDA path, the derived inference attention kernel alone is 0.032 ms at seq 512, down from 0.178 ms
before the `mma.sync` rewrite. @tab-torch compares against eager PyTorch, which launches about ten cuBLAS and flash kernels per block forward and is bound by launches at these sizes. Against a fair baseline the picture is narrower (@tab-torch-graph). On an idle RTX 3090, PyTorch captured in a CUDA graph with TF32 beats tang's forward at seq 128 (0.162 against 0.196 ms) and ties forward plus backward at seq 128 and 512. tang still wins the seq-512 forward against every PyTorch mode, 0.331 ms against 0.396 ms for the CUDA graph and 0.407 ms for `torch.compile`. A run on a contended GPU had tang's tuned training step at 5.05 ms against PyTorch's 4.21 ms, so the training-step ranking is not established.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, right, right),
    [block, ms], [tang, CUDA], [`torch.compile`, TF32], [CUDA graph, TF32],
    [fwd 128], [0.196], [0.388], [*0.162*],
    [fwd 512], [*0.331*], [0.407], [0.396],
    [fwd+bwd 128], [0.482], [1.553], [0.484],
    [fwd+bwd 512], [1.127], [1.724], [1.142],
  ),
  caption: [The same block against PyTorch's faster modes on an idle rented RTX 3090. Best of six interleaved rounds; medians are within 0.02 ms of these except tang's fwd+bwd at 128 (0.503). Within 2% we call a tie.],
) <tab-torch-graph> We do not claim a general win over cuBLAS: a lone $1024^2$ matmul on the derived CUDA TF32 tile
takes 0.103 ms at the default block shape and 0.088 ms at its best one, against cuBLAS TF32's 0.079 ms, 1.1× slower. The gain comes from
fusion across operator boundaries that a library of separately tuned operators cannot do.

#figure(fig-trajectory(),
  caption: [Transformer block forward, seq 512, RTX 3090, log scale. The same derived graph under three generations of lowering; only the last reaches tensor cores. Dashed: PyTorch captured in a CUDA graph with TF32. The CUDA bar and the dashed line are from the idle-GPU run of @tab-torch-graph; the WGSL bars are from earlier shared-GPU runs.],
) <fig-trajectory>

== Attention variants against FlexAttention and FA2

We ran the six attention variants from §2.3 on the RTX 3090 against FlexAttention @flexattention2024 (`torch.compile`, fp32 with TF32 and bf16) and FlashAttention-2 in bf16 where it supports the mask. FA2 here means the kernels bundled with PyTorch, run through its scaled-dot-product-attention (SDPA) `FLASH_ATTENTION` backend, because the `flash_attn` package could not be built on the test machine. Flashlight and EqiForge publish no code. Every row was checked against an f64 reference; tang is pure fp32 or TF32.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, right, right, right, right),
    [d = 64 unless noted, ms], [tang], [Flex fp32], [Flex bf16], [FA2 bf16],
    [soft cap, fwd, n = 2k], [*0.075*], [0.254], [0.172], [—],
    [ALiBi, fwd, n = 2k], [*0.060*], [0.171], [0.094], [—],
    [causal, fwd, n = 2k], [0.060], [0.171], [0.090], [*0.023*],
    [causal, fwd, n = 8k], [0.888], [0.635], [0.326], [*0.177*],
    [sliding window 128, fwd, n = 8k], [0.911], [0.037], [*0.034*], [—],
    [causal, fwd + bwd, n = 4k], [1.81], [0.968], [*0.420*], [0.469],
    [causal, fwd, n = 4k, d = 128], [17.1], [fails], [0.318], [*0.112*],
  ),
  caption: [Attention variants on an RTX 3090 (shared; small rows carry up to ±2× noise). FA2 is PyTorch's bundled kernel and runs only causal and bidirectional masks. The fwd + bwd row uses the earlier 9-kernel backward with materialized $n times n$ buffers, before the §3 and §8.3 rewrites. The full sweep, d = 64 and 128 with n from 1k to 8k, is in the repository.],
) <tab-flex>

Where a variant changes the score (soft cap, ALiBi), the derived forward is up to 3.4× faster than FlexAttention in fp32 up to $n = 4"k"$ and beats it in bf16 up to $n = 2"k"$ (the low end of that range is within the noise of a shared GPU), because the score modifier becomes part of the fused body. tang loses in three places, each a missing schedule rather than missing algebra. FA2 runs bf16 tensor cores where tang's tile is TF32. A sliding window is 25× slower because tang computes masked tiles that FlexAttention's block mask skips. And at $d = 128$ no tensor-core tile is chosen for the forward, a 150× gap at $n = 4"k"$ in @tab-flex. Across the full sweep the $d = 64$ forward wins 0 of 8 against FA2 and the $d = 128$ forward 0 of 24 against FlexAttention bf16. From $n = 2"k"$ the backward is 2.5–7× behind FlexAttention bf16, and 50× with a sliding window.

== A whole model as one graph

Qwen3-8B with MLX 4-bit weights runs as one IR graph per decode step, lowered by
`to_cuda_decode` into 584 kernels and captured as a CUDA graph. Nibble unpacking and the
$q dot s + b$ dequantization are a map the GEMV reads. That map is inlined and evaluated in
registers as weights stream in. @fig-qwen-graph shows the graph.

#figure(fig-qwen-graph(),
  caption: [One Qwen3-8B decode step as a single IR graph. Top: the step, from the token in `state` to the arg-max written back. Bottom: one of the 36 identical layers. Times are each node's share of the 4k-context step on the 3090, summed over layers, from the first build (@fig-decode). The current lowering emits 584 kernels for the whole step, captured as one CUDA graph.],
) <fig-qwen-graph>

The KV-cache update is a `select` over a runtime position, which the lowering turns into loop
bounds, so a step touches only live cache rows. @tab-qwen compares it with llama.cpp on the same card (engineering notes in the appendix, #link(<app-decode>)[Decode engineering notes]),
run back to back on the same weights. The model's greedy output matches an exact f32 reference token
for token.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, right, right),
    [Qwen3-8B, 3090], [short ctx], [1k ctx], [4k ctx],
    [speed of light (936 GB/s)], [220 tok/s], [—], [192 tok/s],
    [llama.cpp, Q4_0 GGUF], [149.4], [145.3], [134.9],
    [tang IR, device step], [*148.7*], [*141.4*], [*124.2*],
    [tang IR, first build (shared GPU)], [122], [—], [104],
  ),
  caption: [Decode, one stream. llama.cpp runs `llama-bench -n 128 -fa on` on a Q4_0 GGUF requantized from the same MLX checkpoint (dequantized to f16, then `llama-quantize`). Teacher-forced on 256 greedy tokens after a 21-token prompt against an exactly dequantized f32 CPU reference with f64 accumulation, on an idle RTX 3090: arg-max equal at 257/257 positions. The largest logit error is 0.98 at a largest logit of 55.7, from the f16 caches, and grows with context.],
) <tab-qwen>

Every change between the first build and the current one is a schedule or a lowering rule, not a kernel; the appendix lists them.

#figure(fig-decode(),
  caption: [Where a Qwen3-8B decode step went at 4k context in the first build: the sum of isolated kernel launches (10.3 ms; the captured graph ran in 9.6). The current build takes 8.05 ms. Dashed: the time to stream the weights and KV cache once at 936 GB/s.],
) <fig-decode>

The same graph builder lowers to Metal. There, prefill and decode programs share one copy of the
weights through buffer binding, prefill can start from a nonzero offset (300 + 200 tokens is
bit-identical to 500), and the next token is chosen on the device by an arg-max monoid, so decoding
reads back 8 bytes per token.

== Data-dependent addressing

A top-k MoE FFN builds as one graph: router GEMM, top-k, softmax weights, SwiGLU experts reading $W["sel"[t,k]]$ through gather views, then the weighted combine. Top-k is exact, and outputs match the f64 interpreter to $4 times 10^(-6)$ on Metal and $4 times 10^(-5)$ on CUDA (the router runs as a TF32 tile). @tab-moe has the timings.

#figure(
  table(
    columns: (auto, auto, auto),
    align: (left, right, right),
    [expert GEMMs + combine], [M4 Max], [RTX 3090 (CUDA)],
    [gathered (one graph)], [2.17 ms (464 GB/s)], [2.66 ms (378 GB/s)],
    [weights pre-gathered on the host, tiled], [2.89], [3.55],
    [weights pre-gathered, one thread per point], [2.91], [3.77],
  ),
  caption: [Top-k MoE at T = 8 tokens, D = 2048, E = 128 experts, k = 10, F = 512 (1 GB of weight reads). The data-dependent address costs nothing against the same expert math over weights gathered into contiguous buffers beforehand. The gathered graph is even faster; we have not isolated why, and do not claim the gap. 378 GB/s is 40% of the 3090's peak: per-point GEMV reads are uncoalesced. §8 adds the narrow GEMV schedule for gathered contractions.],
) <tab-moe>

== Edge hardware

On the K1's Adreno 740, a derived matmul reaches 322 GFLOP/s at $1024^3$, which is 21% of the
measured fp32 peak, and a full transformer forward pass plus all seven weight gradients at seq 128 runs
in 19.1 ms. Rules tuned for desktop GPUs under-fill the Adreno's six compute units. The best schedule
there (an $8 times 8$ register tile with 8-deep chunks) is 1.45× better than `schedule_auto`'s
choice, which again argues for search over remembered rules. Through `to_c` on one Cortex-X3 core, a
batch-1 GRU policy step (6 contractions plus gate math, fused into one kernel) takes 22.5 µs median
and a locomotion MLP takes 6.7 µs, both within $6 times 10^(-7)$ of f64.

= Deriving a production engine

Every kernel in the sections above is derived. To show where derivation has to go next, we report the other half of tang: the hand-written serving engine in `tang-llm`, which serves Qwen3-Coder-Next (80B parameters, 3B active, 4.5-bit GGUF in Q4_K and Q5_K) on one NVIDIA H200 with kernels written by hand. @tab-h200's numbers are not results of the IR; they are the target it has to reach.

#figure(
  table(
    columns: (auto, auto),
    align: (left, right),
    [H200, Qwen3-Coder-Next 80B-A3B], [measured],
    [single-stream decode end to end, no drafting], [234 tok/s],
    [with speculative drafting (MTP / suffix)], [319–439 tok/s],
    [prefill, 1k → 8k tokens], [6,424 → 7,534 tok/s],
    [batched decode step, B = 64], [1,814 tok/s],
    [serving, 64 concurrent decode-heavy streams], [1,279 tok/s],
    [serving at 64k context, batch 48 (production shape)], [1,155 tok/s],
  ),
  caption: [The target: tang-llm on a dedicated H200 (tang-llm commit `fcfbb9d7`). Its MoE layers run a hand-written int8 tensor-core kernel that reads activations in B-fragment order, which cut the B = 64 step from 38.9 to 35.2 ms. Lossless speculation uses a trained MTP head (3.15 tokens per window).],
) <tab-h200>

The hand engine also shows why the contract matters. Ported to GLM-5.3, the same MoE kernel is correct but up to 2.5× _slower_ than the engine's generic path below 64 tokens per expert. A kernel tuned for one model's expert shapes is a point in the schedule space, and on the next model it is the wrong point. It is one data point, but from a production engine, and it is §1's claim.

Deriving this engine needed constructs the IR lacked: a _gather_ view for routing tokens to experts, _integer_ tensor-core fragments with fused dequantization, a top-$k$ reduction, scans, and Hopper's asynchronous copies and warpgroup MMA as schedule fields. Each now exists, and each can replace hand kernels in the engine behind a switch, measured against them on the same bytes.

== The MoE layer

One full MoE layer of the engine builds as a single graph: router, top-$k$, expert-sorted gather, the gate|up and down expert GEMMs on GGUF Q4_K/Q5_K weights, SwiGLU and the weighted combine. The int8 path uses schedule fields only: GGUF blocks as an input storage format, int8 activations quantized by their writer, and an `IntMma` field that stages activations in fragment order for `m16n8k32` tensor cores. There is no new operator.

Routing is one reduction. `Monoid::topk(k)` keeps the $k$ best (index, value) pairs, sorted, with ties to the smaller index. Its combine is a merge of two sorted lists ($k^2 slash 2$ compare-selects), which is associative, so split and subgroup trees give the same answer. Top-10 over 512 experts is one 0.013 ms kernel in place of $k$ arg-max rounds, and a whole layer at batch 1 drops from 32 kernels and 0.199 ms to 13 kernels and 0.103 ms.

Batch 1 needs a different schedule. `Stage::Gemv` computes one dot per (position, row) on `dp4a`, with 16-byte loads of half super-blocks and partial sums combined by shuffles. Its producers fuse: the $x -> "Q8"$ and $"SwiGLU" -> "Q8"$ nodes are marked inline, and the GEMV computes and quantizes its operand row into shared memory in its prologue, rounding exactly as the writer did.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, right, right, right, right),
    [one layer, H200, ms], [derived expert half (stage)], [derived, equal work], [engine, hand-written], [derived / hand],
    [batch 1], [0.0356 (GEMV)], [0.0518], [*0.0439*], [1.18],
    [batch 4], [0.0763 (GEMV)], [0.0927], [*0.0868*], [1.07],
    [batch 8], [0.1062 (fragment)], [0.1230], [0.1248], [0.99],
    [batch 64], [0.2957 (fragment)], [*0.3179*], [0.3357], [0.95],
  ),
  caption: [One Qwen3-Coder-Next MoE layer (hidden 2048, 512 experts, top-10, FFN 512), derived against the engine's own kernels on the same bytes, on an idle H200. The engine's combine also adds the residual, runs the next RMSNorm and quantizes the activations to int8; "equal work" adds those three steps, timed as derived ops (0.016–0.022 ms), to the derived half. Medians of three rounds of L2-flushed medians. Outputs agree to $3 times 10^(-7)$ and top-$k$ is exact. Batch 1 and 4 use the fused GEMV stage, 8 and 64 the int8 fragment stage; the fragment stage at batch 1 takes 0.050 ms. Weights are random valid k-quant blocks.],
) <tab-moe-h200>

With equal work the derived layer loses at batch 1 and 4, by 18% and 7%, ties at 8 and wins by 5% at 64. The derived expert half alone is faster than the hand layer at batch 1, but only because the hand layer's time includes the residual, norm and quantization that ours leaves out. Fragment-order staging alone is worth about 20% on gate|up at batch 64. The hand MoE kernels took a dedicated tuning effort; the derived ones are a schedule search, and on equal terms they are not yet faster at small batch.

The backward of a gathered contraction was dense: every expert's weight gradient summed over every pair under a $["key" = e]$ gate, $E$ times the needed work. Declaring the key index sorted (`set_sorted`) tags that reduction with a segment, and the point loop binary-searches each key's run and sums only over it. The gate stays in the body, so a lowering that ignores the tag is still correct. The expert-weight gradient (E = 512) drops from 8.27 to 3.89 ms on the H200, 16.3 to 2.67 ms on the 3090 and 39.7 to 2.65 ms on the M4 Max, with identical error.

== Attention and scans in prefill

The engine's model alternates gated-delta (GDN) layers with full attention at head dimension 256, and prefill is where both cost. At $d = 256$ the old schedule left the online-softmax reduction untiled, and the score stayed an $n times n$ buffer at 2.8 TFLOP/s. Allowing the tile up to 256 lanes lets the score inline, and the Hopper flash shape takes over with no change to the graph or the emitters (@tab-d256).

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, right, right),
    [$d = 256$ forward, H200], [$n$ = 1k], [4k], [16k],
    [tang, non-causal], [*318*], [*398*], [*422*],
    [SDPA, non-causal], [306], [323], [318],
    [tang, causal], [220], [*310*], [*391*],
    [SDPA, causal], [*251*], [285], [295],
  ),
  caption: [TFLOP/s, bf16, 16k tokens per configuration, against PyTorch SDPA on the same idle H200; rel. error $2$–$3 times 10^(-3)$ against f64. FlashAttention-3 is faster than both (@tab-fa3-256).],
) <tab-d256>

SDPA is not the strongest baseline at this head dimension. Against FlashAttention-3 built for head dimension 256, on an idle H200 in a later run, tang's forward runs at 0.43–0.54 of FA3's speed and its backward at 0.22–0.40 (@tab-fa3-256). In that run tang's forward beats SDPA from $n = 4096$ up and loses at $n = 1024$ causal, and its backward loses to SDPA everywhere (SDPA's backward is not in the table).

#figure(
  table(
    columns: (auto, auto, auto, auto, auto, auto, auto),
    align: (left, left, right, right, right, right, right),
    [N], [causal], [tang fwd], [FA3 fwd], [SDPA fwd], [tang bwd], [FA3 bwd],
    [1024], [no], [0.433], [*0.199*], [0.450], [3.624], [*0.914*],
    [1024], [yes], [0.315], [*0.137*], [0.274], [2.666], [*0.574*],
    [4096], [no], [1.379], [*0.703*], [1.712], [8.748], [*3.079*],
    [4096], [yes], [0.885], [*0.377*], [0.963], [5.075], [*1.620*],
    [16384], [no], [5.177], [*2.783*], [6.785], [29.30], [*11.79*],
  ),
  caption: [Attention at $d = 256$, bf16, ms, idle H200: tang against FlashAttention-3 (built from `flash-attention/hopper` with head dim 256 in bf16 only) and SDPA. Medians of three rounds, spread under 2%; every library lands at relative error $2$–$5 times 10^(-3)$ against f64 on two heads. tang's backward is its forward-plus-backward program minus its forward.],
) <tab-fa3-256>

Gated delta rules, Mamba-2's SSD and linear attention are associative scans over an affine monoid on a matrix state. A `delta_scan` comprehension lowers by a chunked plan: a WY transform per chunk, a sequential state scan, and a parallel readout. Its backward is the derived reverse scan at chunk granularity. On the 3090 it matches fla's Triton kernels within 6% forward and beats mamba_ssm's SSD forward 1.3–1.8×. Against the engine's hand recurrence (a warp per state column, token by token), the chunked scan is 4.0–4.3× faster on the H200 and 2.1× on the 3090.

Both went into the engine behind switches, gated on the engine's own accuracy checks: KL divergence against the reference at 3k and 8k tokens with int8 and bf16 KV caches, equal greedy output, bitwise-identical batched decode, and a cached-prefix continuation equal to a cold one.

#figure(
  table(
    columns: (auto, auto, auto),
    align: (left, right, right),
    [Qwen3-Coder-Next prefill, H200], [TTFT, 44k tokens], [8k tokens],
    [engine, hand kernels], [8.33 s], [7,300 tok/s],
    [\+ derived GDN scan], [7.70 s], [8,200 tok/s],
    [\+ derived $d = 256$ attention], [6.17 s], [—],
    [\+ both], [*5.54 s*], [—],
  ),
  caption: [Time to first token with the int8 KV cache, warm. The baseline is this engine's prior code, not another serving stack: its attention ran about 5× below the derived kernel (roughly 70 TFLOP/s), and its GDN was a warp per state column, token by token. With the bf16 KV cache the derived attention takes 44k prefill from 6.67 to 5.79 s.],
) <tab-prefill>

These gains are over the engine's own prior code, and that baseline is far from the state of the art. vLLM 0.33 on the official FP8 checkpoint, on an idle H200 with DeepGEMM off, reaches first token in 0.17 s at 8k tokens and 1.08 s at 44k. The engine, on its 4.5-bit GGUF, took 2.1 s and 13.8 s in the same session, and 12.9 s with derived attention: vLLM is about 12× faster. The weight formats differ, so the comparison is not matched for precision, but a gap of an order of magnitude does not come from the format. The engine's 13.8 s in that run is also slower than the 8.33 s in @tab-prefill, which came from a warm server; we have not reconciled the two measurement paths, so @tab-prefill should be read as relative.

== Attention backward on Hopper

Training needs the backward. The derived attention backward was nine kernels that round-tripped P and dS through memory, at 13–25 TFLOP/s. A lowering recognizes the pattern the gradient pass produces, a tuple reduction over queries whose operands are pointwise maps of two short contractions, and emits one kernel per key block. It is a shape-keyed emitter. dK and dV stay in registers, and dQ is added with Hopper's bulk asynchronous reduce. Variants on `mma.sync`, on `wgmma` with two consumer warpgroups, and with a producer warpgroup are all derived from the same match, and the autotuner picks per shape. The fused kernel alone reaches 0.81–0.96× of SDPA's backward kernel at $d = 128$, and the whole program is 4–8× faster than the nine kernels. The whole backward program is slower than SDPA's: 0.43–0.74× at $d = 256$ in the run behind @tab-fa3-256, which does not tabulate SDPA's backward. The fused kernel also computes in bf16 tensor cores even for an f32 graph, which is fine for bf16 training but fails an f32 tolerance (§1).

== The derived MoE in the model

A layer that wins in isolation still has to win inside the model. Behind a switch, the derived MoE replaces the engine's expert kernels in every layer of Qwen3-Coder-Next. It passes the engine's accuracy checks at 3k and 8k tokens and is bitwise-equal batched at 8 streams; the 48-stream agreement gate has a 99% bar that the derived path misses at 98.93%. The hand engine fails it too in the same run, at exactly 99.00% against a strict inequality. Getting there exposed one numerical choice: a block-split sum of squares in RMSNorm, split 256 ways, pushed the KL divergence at 3k tokens to $2.8 times 10^(-4)$, over the $2 times 10^(-4)$ bar. Split 1024 ways it is $2.3 times 10^(-5)$, lower than the serial sum's $4.1 times 10^(-5)$. Precision is a schedule here too.

At 1–8 streams the derived path was slower, so the engine takes it only for windows of at least 16 rows and keeps the hand kernels below that. Above that cutoff it is faster. Over five interleaved rounds on one idle H200, with hand and derived alternating in fresh processes, a decode step takes 13.99 ms against 15.84 ms at 16 streams, 21.36 against 23.44 at 32 and 28.43 against 30.00 at 48 (medians). The derived step takes 5–12% less time, and the largest spread across rounds is 0.47 ms, so every round shows it. Earlier single runs disagreed because they compared different pods; hand at 48 streams has read 29.67 to 30.26 ms across four H200s. With equal work the layer alone is slower at batch 1 and 4, which matches where the cutoff sits.

The whole decode step can be derived as well. On an idle RTX PRO 6000, single stream, Qwen3-8B's derived step takes 4.72 ms at context 128 and 5.12 ms at 4k, against 4.82 and 5.19 ms for the hand engine, and produces the same 64 greedy tokens. Qwen3-Coder-Next's derived step, 1,924 kernels, also matches the hand engine's 64 greedy tokens but is slower: 5.89 ms against 5.21 at context 128 (13%) and 6.93 against 5.15 at 4k (35%). The gap grows with context; we have not yet broken it down by kernel.

= The speed of light

"Derived kernels beat hand kernels" is a claim about two programs. It says nothing about whether either is fast. The question that matters is how far a kernel is from the fastest any implementation could be. tang can answer it from the same comprehension it compiles.

== The floor and the tile are dual

For a comprehension over affine views, the least memory traffic of any tiled schedule comes from a linear program. Each view projects the iteration space onto one operand, and the Brascamp–Lieb inequality bounds how many iterations a tile can run for the data it holds @christ2013hbl. The program's optimum is the traffic lower bound. Its dual is a tile shape that attains it. So the bound and the schedule are two solutions of one problem, and the duality gap is how far a schedule is from optimal. tang builds this program from a kernel's views (`TensorGraph::kernel_lp`) and solves both sides.

It reproduces the classical bounds. Matmul gets exponent $3 slash 2$ with a $sqrt(M slash 3)$ cube tile. Attention gets Saha and Ye's $Theta(min(N^2 d^2 slash M, N^2 d slash sqrt(M)))$ @saha2024io, and its dual tile is FlashAttention's $M slash (4 d)$ blocks. We compared the dual with the tiles tang picks (@tab-dual). Two different things pick tiles: `schedule_auto` is a fixed rule that times nothing (in this comparison it gives 64 × 64 for matmul and 16 × 16 for attention; its tile depends on the kernel's shape and the backend), and the autotuner is a timed search. The comparison does not show that the model predicts the autotuner.

#figure(
  table(
    columns: (auto, auto, auto),
    align: (left, left, left),
    [kernel], [model tile], [what tang picks],
    [matmul $4096^3$, M4 Max, two levels], [64 × 64 at 4096 register words; 256 × 128 at the register file], [autotuner 64 × 64],
    [attention $n = 4096$, M4 Max, two levels], [64 rows × 32 keys at 4096 words; 512 × 32 at the register file], [autotuner 64 × 32],
    [attention $n = 1024$/4096, RTX 3090], [one level 48 × 48; two levels 128 × 32], [autotuner 16 × 16, the smallest tile in its space, moving 2.8–3.0× the one-level dual's traffic],
    [matmul $1024^3$, RTX 3090], [—], [autotuner 64 × 64, same as the rule],
  ),
  caption: [The tile the traffic program chooses against the tile tang picks. On the M4 Max the two-level program matches the autotuner only for register capacities from 4096 to 8192 words, which is the edge of the schedule space; with the real register file it chooses tiles the space cannot express, and it charges nothing for the occupancy a large register tile costs. On the RTX 3090 the timed search keeps the smallest attention tile, but dozens of attention candidates there time within 3% of each other, so that pick does not test the model.],
) <tab-dual>

We also timed the model's tiles directly, in a race against the searched ones. On the M4 Max, matmul time stays flat as tile traffic changes, and the one-level dual tile for attention is 11–23% slower than the winner. On the RTX 3090 dozens of attention candidates, the dual tiles included, time within 3% of each other, so the race cannot rank tiles there. In neither case does the traffic-optimal tile win on time.

We then checked two time figures against the same race. The first is the time floor of the next section. It does not depend on how a candidate stages its data, so one value holds for every tile of a kernel. No candidate beat it in any of the 892 timings, which cover matmul at $1024^3$ and $4096^3$ and attention at $n = 1024$ and $4096$ on both machines. On the RTX 3090 the fastest candidate runs at 1.38–2.34× the floor. On the M4 Max matmul runs at about 4× the floor and attention at 53–56×, so no term of the floor limits attention there.

The second figure charges each candidate the traffic of its own tile, at a cache bandwidth we probed separately. It is an estimate and not a floor. On the RTX 3090 most candidates run faster than it, 99 of 102 for matmul at $4096^3$, because we compute the traffic term for the WGSL tile and the CUDA kernel stages data differently. It is also not a prediction. We added the cache bandwidth, and a rule that an unstaged kernel reuses data per point, after a first race in which the pick lost. The candidate with the lowest estimate is within 2.5% of the fastest on seven of the eight kernel and machine pairs. On the RTX 3090 that says little, because dozens of candidates tie within 3%. The eighth pair is attention at $n = 1024$ on the M4 Max, where the pick is 1.27× slower than the winner. Its 4 × 4 register tiles give each thread a long serial online-softmax chain, and its grid has only 128 workgroups. The twelve fastest candidates use 512 workgroups and smaller register tiles. The estimate has no term for chain length. At $n = 4096$ the same tile shape has 512 workgroups and wins. The validation in the next section uses GEMV-class and epilogue kernels, not these tiled ones.

Weak duality is mechanized in Lean, over the reals, for a model where each array is indexed by a subset of the loop coordinates: fitting tile exponents sum to at most covering exponents, and a box tiling of $V$ points needs at least $V slash M^sigma$ tiles. Strides and multi-term addresses are outside it, and so are general schedules, which need the full discrete Hölder–Brascamp–Lieb (HBL) theorem. Guarded views fit the program as it is. For a gather view the bound is $max("HBL"("rest"), "compulsory" + U dot "slice")$, which is sound for the given index data and equals the analytic MoE floor under uniform top-$k$. Multi-term views, such as a convolution's $x + k$, are dropped from the program, which keeps the bound sound but loose. Masks are not modelled.

== From traffic to time

Traffic is one limit. A kernel's time floor is
$ t >= L + max(lambda + B slash beta, F slash pi, ceil(G slash S) lambda) $
for launch cost $L$, DRAM latency $lambda$, $B$ bytes at bandwidth $beta$, $F$ flops at peak $pi$, and $G$ workgroups with at most $S$ resident at once. The first term is the fill: one DRAM latency, then streaming at full bandwidth. The last is a makespan bound: if every workgroup makes at least one DRAM round trip, each holds a slot for at least $lambda$, so $S$ slots need at least $ceil(G slash S)$ rounds. Adding $L$ assumes launch overhead does not overlap memory traffic. A decode step's floor is the longest path through its kernel graph, where independent kernels may overlap.

The constants are measured independently of the kernels they predict. On the H200, an empty kernel in a CUDA graph costs 0.48 µs and a one-thread pointer chase over 4 GB costs 340 ns, on an idle machine. On the 3090, $L$ is an empty kernel in a CUDA graph (0.77 µs) and $lambda$ is an assumed 470 ns. Two terms we tried are not in the floor. A Little's-law bytes-in-flight term never bound with the bytes per thread counted from the schedule. An instruction-issue term was a hypothesis: we chose which requests to count after the full count overshot, and measured instruction counts show plain issue cannot be the limit.

We measured DRAM bytes with Nsight on the RTX 3090 and time on both chips for every kernel of at least 0.5 MB in the MoE layer at 1, 8 and 48 streams and the Q8 GEMVs: 24 GEMV-class and epilogue kernels. No kernel runs faster than its floor on either chip. On the 3090 the large kernels sit at 0.76–0.93 of the measured time (median over all, 0.63). On the H200 the floor is loose everywhere, 0.05–0.66 with a median of 0.38, and we have no validated term for the gap. The H200 pods expose no byte counters, so $B$ is the 3090's count, and for a kernel that fits the 50 MB L2, $B slash beta$ is not a proven floor on the H200. Attention and matmul tiles are compute-shaped and outside this validation: on the 3090 their traffic floors are 2–18% of their time, and against the TF32 peak the matmul tile reaches 0.47–0.62 and flash attention 0.25–0.28.

== What the floor says about decode

On the H200 a whole decode step's traffic floor is only 0.16–0.29 of its measured time, and the gaps between kernels inside the CUDA graph are only 0–8% of the step. The missing time is per kernel. A cold dependent GEMV costs 6.9 µs including launch, and any dependent kernel under about 2 MB costs about that much whatever it does. At one stream the hand engine's step, with the shared expert on a parallel branch, is 548 kernels in 4.04 ms, 7.4 µs each. That arithmetic suggests decode at small batch is bound by its chain of dependent kernels, but the obvious test refutes the simple form of it. Fusion did not speed up the step, because the work moved into tails on the same critical path (@tab-levers). What limits small-batch decode on the H200 is still an open term in the floor.

We used earlier versions of the floor, with superseded constants, to bound decode levers before building them (@tab-levers). Those bounds missed in both directions, so they are upper bounds at best and not predictions.

#figure(
  table(
    columns: (auto, auto, auto),
    align: (left, left, left),
    [lever], [bound from the floor], [measured, H200],
    [blind L2 prefetch of the next matrix], [−36%, then +4 to +28% (slower) once the prefetcher was charged], [net slower: next kernel −0.4 to −0.6 µs, prefetcher +0.6 to +4 µs],
    [shared expert on a parallel graph branch], [≤ 9% at one stream], [within noise at 1–8 streams; −6 to −13% at 16–48, bitwise equal],
    [fuse block-local chains], [−25% hand, −38% derived at one stream; 4–8% at 48], [no gain: with combine fused the derived step went from 4.05 to 4.44 ms, 96 of 548 launches removed],
  ),
  caption: [Decode levers, bounded by earlier versions of the step floor and then measured. Gains are against the step time; the parallel shared expert is a switch in the engine.],
) <tab-levers>

What the floor supports is narrower than its name. It is a lower bound that holds on every kernel we measured. On the RTX 3090 it is close for bandwidth-bound kernels. On the H200 it is loose, it says nothing yet about compute-shaped kernels, and as a guide to which optimizations pay it has been wrong as often as right.

= Related work

*Compilers and IRs.* MLIR's Linalg dialect @lattner2021mlir (a generic op with indexing maps and a body) and XLA @sabne2020xla are closest in the IR's shape. tinygrad @tinygrad shares the goal of few constructs and few hand-written kernels across backends. Futhark @henriksen2017futhark, Lift @steuwer2015lift and Dex @paszke2021dex are array languages with rewrites or differentiation. TensorIR @feng2023tensorir brings tensorized loops to Halide-style search. Suriana et al. @suriana2017halide synthesize associative reductions in Halide, which is the closest precedent for recognizing a monoid. TASO @jia2019taso and PET @wang2021pet superoptimize tensor graphs.

*Schedules.* Halide @ragan2013halide separated algorithm from schedule. TVM @chen2018tvm and Ansor @zheng2020ansor searched the schedule space with learned cost models, and Tensor Comprehensions @vasilache2018tc used polyhedral compilation. tang inherits the separation and the search.

*Deriving fused kernels.* The closest work is recent. Mirage @wu2024mirage superoptimizes multi-level $mu$Graphs with probabilistic equivalence checks. EqiForge @eqiforge2026 uses equality saturation to derive FlashAttention-style forward kernels. Flashlight @flashlight2025 generates flash-style kernels for arbitrary attention variants inside TorchInductor. tang differs on three axes. Its rewrite is deterministic, keyed on the monoid structure rather than found by search. It derives the _backward_ pass, including the gradient of the online-softmax monoid and the elimination of the stabilizing max. And it lowers to six targets, not one. AttentionEngine @attentionengine2025 and FlashInfer @flashinfer2025 generate attention variants from templates. Neither Flashlight nor EqiForge publishes code, so we measure against FlexAttention and FA2 instead (§7.3).

*Tile languages and hand kernels.* Triton @tillet2019triton, ThunderKittens @spector2024tk and TileLang @wang2025tilelang make kernels easier to write. FlashAttention @dao2022flash @dao2023flash2 @shah2024flash3 is the hand-derived frontier. Online softmax is due to Milakov and Gimelshein @milakov2018online. Baselines we measure against are fla @fla, mamba_ssm @mambassm, llama.cpp @llamacpp and vLLM @kwon2023vllm. ScanWeaver @scanweaver2026 compiles affine recurrences by associative scan lowering, and Event Tensor @eventtensor2026 compiles dynamic megakernels. tang aims to make writing kernels unnecessary, and treats these kernels as the targets derived code must reach.

*Lower bounds.* Communication lower bounds for loop nests over arrays come from the Brascamp–Lieb inequality @christ2013hbl, following Hong and Kung's red-blue pebble game @hong1981pebble. Pebbling bounds are now derived automatically for affine programs @olivry2020iolb @olivry2021ioopt @kwasniewski2021soap, and COSMA @kwasniewski2019cosma attains tight constants for matmul. Attention's I/O complexity is $Theta(N^2 d^2 slash M)$ for large caches @saha2024io. These analyze a fixed algorithm and model traffic only. tang reads the program off the kernel it compiles, uses its dual as a schedule, adds latency and launch terms, and checks the result against hardware counters. The time floor is a roofline @williams2009roofline with latency, launch and occupancy terms. SOL-ExecBench @solexecbench2026 scores kernels against per-problem speed-of-light bounds, but as a benchmark rather than from a compiler's IR.

*Generated kernels.* LLM agents now write CUDA, but KernelBench-Verified @kbverified2026 shows frontier models reward-hacking benchmarks by hard-coding test values. A derived kernel is checked by construction against an f64 interpreter of the same graph.

= What derivation covers and what remains

Deriving a production engine needed the IR constructs in @tab-roadmap. Each is built and measured above, with the limits stated here.

#figure(
  table(
    columns: (auto, auto, auto),
    align: (left, left, left),
    [gap], [construct], [result],
    [MoE routing], [`Monoid::topk`], [10 arg-max rounds → 1 kernel; layer 0.199 → 0.103 ms],
    [batch-1 gathers], [`Stage::Gemv`, fused producers], [expert half 0.036 ms at batch 1; 18% behind hand on equal work (@tab-moe-h200)],
    [gather backward], [sorted-key segments], [2.1–15× on the expert gradient],
    [recurrences], [scan monoid, chunked plan], [4× the hand recurrence; ties fla on the 3090],
    [$d = 256$ attention], [tile width in `schedule_auto`], [2.8 → 422 TFLOP/s; 44k TTFT 8.33 → 6.17 s],
    [Hopper backward], [recognized fused kernel, `wgmma`, warp specialization], [9 kernels → 1; 0.8–1.0× SDPA],
    [launch fusion], [cooperative staged maps, megakernels], [729 → 584 kernels; time-neutral on sm_86],
    [decode], [split GEMVs, load-bytes register model], [122 → 148.7 tok/s; ties llama.cpp at short context],
  ),
  caption: [The constructs a production engine needed, and what each one bought. None of these is an attention or MoE kernel. Each is a monoid, a schedule field or a lowering rule that any graph of the same shape gets. The table lists gains only; the next paragraph lists what each still loses.],
) <tab-roadmap>

What remains is also measured. The engine still uses hand kernels below 16 window rows. The derived Hopper forward runs at 0.42–0.60× of FlashAttention-3 at $d = 128$ and 0.43–0.54× at $d = 256$, and the backward at 0.22–0.40× of FA3's at $d = 256$: FA3 overlaps the softmax of one block with the GEMMs of the next, and loads through TMA from a producer warpgroup, and our consumers still issue their own copies. On the H200, fla's scans are 1.2–2.4× ahead at long sequences, because our state scan runs sequentially over chunks; the affine monoid is associative at any granularity, so a two-level scan is a schedule change. The WGSL flash tile still runs every key tile under a sliding-window mask (@tab-flex), and the Metal backward's nested dots are not yet blocked onto simdgroup matrices. `schedule_auto` is still rules, while every autotuning run writes (graph, chip, schedule, time) to a cache that can train a cost model. Sharded reductions joined by an all-reduce are already a rewrite, and only the transport is missing. The fused attention backward needs an f32 path, and one wrong placement that the check catches is not yet explained. Prefill is about 12× behind vLLM. Several earlier tables were taken on shared GPUs; the idle-GPU measurements in §1, §7 and §8 were not.

= Conclusion

Two constructs, affine views and monoid comprehensions, express a transformer, its gradient and its quantized inference. Lowering them to fast code still takes shape-keyed emitters for the hottest schedules. Fusion, flash attention and the flash backward become rewrites and schedule choices, not kernels. Because the schedule is searched per chip, the same source wins or stays close to hand kernels on Metal and Vulkan, runs on an embedded Adreno, and on CUDA beats PyTorch's best mode on a transformer block's forward pass at sequence length 512 while losing at 128.

The hand-written kernel does not disappear in this design. It becomes an intrinsic, a fast implementation of one comprehension shape on one chip, which the compiler uses when it wins and replaces when it doesn't. In the last hand-tuned engine we run, an 80B MoE model on an H200, the derived MoE layer is slower than the hand-written one at batch 1 and 4 on equal work and faster at 64, a derived decode step takes 5–12% less time from 16 streams up across five rounds, and derived prefill kernels cut the engine's time to first token at 44k tokens by a third, though vLLM remains about 12× faster.

The comparison with hand kernels was never the point. The traffic floor and the tile that reaches it are dual solutions of one program, so a compiler that derives kernels can also say how far each one is from a lower bound on its time. So far that floor holds on every kernel we measured and is close on the large kernels of the RTX 3090. On the H200 it is loose and we cannot yet say why, and the model behind it does not predict the tiles the autotuner picks. Small-batch decode on the H200 is the open case: it is far from its floor, and removing launches did not close the distance.

#aside[Reproducibility][
  Numbers come from `BENCHMARKS.md` in the tang repository, which records the command, date and machine state for each measurement; the idle-GPU measurements are in its section "Idle-GPU measurements" with raw outputs under `crates/tang-llm/docs/bench/review/`, and the floor table is in `docs/duality.md`. The `data/` directory next to this paper holds a snapshot of these files at tag `paper-2026-11-10b` (commit `15a66d95`). The whole-step decode results in §8 come from later runs on tang main; their outputs are in `data/whole-step/`. The IR is in `crates/tang-compile/src/tensor*.rs`; its design notes are in `docs/tensor-ir.md`.
]

#heading(outlined: true, numbering: none)[Appendix: decode engineering notes] <app-decode>

Every change between the first build and the current one is a schedule or a lowering rule, not a
kernel. Norms are materialized once instead of recomputed in every GEMV lane. 4-bit GEMVs under 16k
rows are split along $k$. The attention score kernel stops at the runtime length. A load-bytes model
picks the register dimension, so P·V shares the probabilities across the 4 GQA heads instead of
re-reading them. A cooperative lowering computes a small reduction (RMSNorm's sum of squares, the
per-head q/k-norm statistics) into shared memory once per block and evaluates the map that reads it
from there, which takes the step from 729 to 584 kernels. The first build had 506.

On the 3090, as on the H200 (§9.3), removing launches saved nothing. Inside a CUDA graph on sm_86, a
dependent launch costs what a grid barrier costs (0.77 vs 0.81 µs), so 145 fewer kernels is
time-neutral, and a persistent megakernel that runs the whole step as one launch with 437 phases is
correct but 19% slower, because one register budget for every stage spills the largest GEMV. The
gap to llama.cpp at 4k is in the kernels: the 4-bit GEMVs run at 60–82% of bandwidth, and attention
reads K and V about twice.

#heading(outlined: true, numbering: none)[References]
#show bibliography: it => { show "?.": "?"; show "!.": "!"; it }
#bibliography("refs.bib", style: "nature", title: none)
