// Research post: RIBT (Real-time, In-Body Talk), a small streaming English TTS trained and run in tang's tensor IR.
// Written as the release announcement.
// Same treatment as paper/zero-context-memory (muon "Pilot Light", dark), trimmed to what this post uses.
// One source, two outputs: `--features html --format html --input target=html` builds the web
// post; without the input it builds the PDF. See web/scripts/build-posts.mjs.
// Every number below traces to a file under data/ (see data/README.md) or to a section of the
// lab log, ipse docs/voice-model.md, cited as §N.

#let web = sys.inputs.at("target", default: "pdf") == "html"
#show math.equation: it => if web { html.elem("span", attrs: (class: "math"), html.frame(it)) } else { it }
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

// product names in their landing-page color
#let brand-names = (("tang", "tang"), ("ipse", "ipse"), ("frog", "frog"))
// each product in its landing-page color (web/src/app/page.tsx), not its family
#let fam-color = (tang: rgb("#ffd400"), ipse: rgb("#ff5f00"), frog: rgb("#39ff14"))
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

#set document(title: "Real-time, In-Body Talk", author: "Cam Pedersen (Municipal Robotics)")

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
      pad(x: -hf-out(), grid(columns: (1fr, auto), caps[Real-time, In-Body Talk], caps[Municipal Robotics]))
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

// a waveform-ish strip for the title page: one bar per 10 ms frame, the shape of a short phrase
// the title illustration: a real RIBT utterance ("Could you tell me where the charging station is?") as a
// ridgeline landscape. One ridge per mel frame, frequency left to right, energy as height; the first
// frame is nearest and the sentence runs away into the distance. The first 48-frame chunk, the audio that
// plays 17.6 ms after the text is ready, is orange. Same data as the web cover (images/cover.json).
#let cover = json("images/cover.json")
#let ridges(width: 17.4, height: 7.6, stride: 2, f0: 20, f1: 232) = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let nb = cover.bands
  let nf = cover.frames
  let mel(f, b) = (str.to-unicode(cover.mel.at(f * nb + b)) - 48) / 63
  let n = calc.ceil((f1 - f0) / stride)
  let kp = 2.2
  let s1 = 1 / (1 + kp)
  let y-near = 0.0
  let y-far = height * 0.62
  let half-near = width / 2
  let amp = height * 0.42
  for r in range(n - 1, -1, step: -1) {
    let f = f0 + r * stride
    let z = r / (n - 1)
    let sc = 1 / (1 + kp * z)
    let y0 = y-far + (y-near - y-far) * ((sc - s1) / (1 - s1))
    let half = half-near * sc
    let pts = ()
    for b in range(nb) {
      let lo = calc.max(0, b - 1)
      let hi = calc.min(nb - 1, b + 1)
      let v = (mel(f, lo) + 2 * mel(f, b) + mel(f, hi)) / 4
      v = calc.max(0, (v - 0.12) / 0.88)
      let edge = calc.sin(calc.pi * (b + 0.5) / nb)
      pts.push((width / 2 - half + 2 * half * b / (nb - 1), y0 + amp * sc * v * v * (0.55 + 0.45 * edge)))
    }
    let hot = f < cover.chunk
    line((width / 2 - half, y0), ..pts, (width / 2 + half, y0), close: true, fill: c-bg, stroke: none)
    line(..pts, stroke: (paint: if hot { c-sel } else { c-label.transparentize(100% - (35% + 60% * sc)) }, thickness: if calc.rem(r * stride, 16) == 0 { 0.55pt } else { 0.3pt }))
  }
})


#let fig-pipeline() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let stages = (
    ([lilt], [G2P, CPU], [16 MB tables], false),
    ([acoustic], [enc + decoder], [18.65M], false),
    ([flow], [1 step], [21.88M], true),
    ([vocoder], [Vocos weights], [13.53M], false),
  )
  let w = 2.05
  let gap = 0.38
  let h = 1.25
  let x0 = 1.05
  let X(i) = x0 + i * (w + gap)
  lbl((0.3, h / 2), [text], fill: c-text, size: s-sm, font: mono-sb)
  line((0.62, h / 2), (x0 - 0.04, h / 2), mark: (end: "stealth", fill: c-label), stroke: 0.6pt + c-label)
  for (i, (name, sub, params, hot)) in stages.enumerate() {
    let x = X(i)
    rect((x, 0), (x + w, h), fill: if hot { c-sel.transparentize(82%) } else { c-surface }, stroke: 0.6pt + if hot { c-sel } else { c-line-hi })
    lbl((x + w / 2, h - 0.33), name, fill: if hot { c-sel } else { c-text }, size: s-sm, font: mono-sb)
    lbl((x + w / 2, h - 0.78), sub)
    lbl((x + w / 2, -0.32), params, fill: if hot { c-sel } else { c-text })
    line((x + w + 0.04, h / 2), (x + w + gap - 0.04, h / 2), mark: (end: "stealth", fill: c-label), stroke: 0.6pt + c-label)
  }
  let xe = X(4)
  lbl((xe + 0.45, h / 2 + 0.12), [audio], fill: c-text, size: s-sm, font: mono-sb)
  lbl((xe + 0.45, h / 2 - 0.2), [24 kHz])
  // what crosses each boundary
  let mid(i) = X(i) + w + gap / 2
  lbl((mid(0), h + 0.3), [phonemes])
  lbl((mid(1), h + 0.3), [mel + F0])
  lbl((mid(2), h + 0.3), [mel])
  // the aligner, used only to train
  let ax = X(1)
  rect((ax, -1.75), (ax + w, -0.95), fill: none, stroke: (paint: c-line-hi, thickness: 0.6pt, dash: "dotted"))
  lbl((ax + w / 2, -1.2), [aligner 0.57M], fill: c-label)
  lbl((ax + w / 2, -1.5), [training only])
  line((ax + w / 2, -0.95), (ax + w / 2, -0.55), mark: (end: "stealth", fill: c-label), stroke: (paint: c-label, thickness: 0.5pt, dash: "dotted"))
  lbl((ax + w + 0.15, -1.35), [durations, to train\ the predictors], anchor: "west")
  lbl((X(3) + w, -1.2), [54.1M in all], anchor: "east", fill: c-text)
  lbl((X(3) + w, -1.5), [Kokoro: 82M], anchor: "east")
})

// time to first audio, linear, to scale
#let fig-latency() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let xo = 2.1
  let sx = 0.024    // cm per ms
  let X(ms) = xo + ms * sx
  let top = 2.9
  for ms in (0, 100, 200, 300, 400) {
    line((X(ms), 0), (X(ms), top), stroke: 0.3pt + c-line)
    lbl((X(ms), -0.3), [#ms ms])
  }
  line((xo, 0), (X(420), 0), stroke: 0.6pt + c-line-hi)
  // the loop budget
  line((X(250), -0.05), (X(250), top + 0.1), stroke: (paint: c-warn, thickness: 0.6pt, dash: "dashed"))
  lbl((X(250), top + 0.38), [250 ms: end of speech to first audio, whole loop (target)], fill: c-warn)
  let rows = (
    ([RIBT], [streaming], 17.6, 27.5, c-sel),
    ([Kokoro], [CPU, whole sentence], 349, none, c-label),
    ([Kokoro], [MPS, whole sentence], 815, none, c-label),
  )
  for (i, (name, sub, ms, p90, col)) in rows.enumerate() {
    let y = top - 0.6 - i * 0.85
    lbl((xo - 0.15, y + 0.06), name, anchor: "east", fill: c-text, size: s-sm)
    lbl((xo - 0.15, y - 0.24), sub, anchor: "east")
    let end = calc.min(ms, 410)
    rect((xo, y - 0.13), (X(end), y + 0.13), fill: col, stroke: none)
    if ms > 410 {
      line((X(410), y), (X(425), y), mark: (end: "stealth", fill: col), stroke: 0.7pt + col)
      lbl((X(425) + 0.1, y), [#ms ms], anchor: "west", fill: c-text)
    } else {
      lbl((X(if p90 != none { p90 } else { ms }) + 0.12, y), [#ms ms], anchor: "west", fill: if col == c-sel { c-sel } else { c-text })
    }
    if p90 != none {
      line((X(ms), y), (X(p90), y), stroke: 0.6pt + c-sel)
      line((X(p90), y - 0.09), (X(p90), y + 0.09), stroke: 0.6pt + c-sel)
    }
  }
})

// UTMOS per set, four systems
#let fig-scores() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let xo = 1.9
  let sx = 8.2      // cm per UTMOS point
  let lo = 3.6
  let X(u) = xo + (u - lo) * sx
  let sets = (([WER-50], (3.789, 4.098, 4.394, 4.521)), ([listen-10], (3.691, 4.082, 4.336, 4.497)), ([held-50], (3.711, 4.136, 4.304, 4.464)))
  let cols = (c-line-hi, c-label, c-sel, c-text)
  let names = ([license-clean ckpt], [RIBT, own vocoder], [RIBT], [Kokoro af\_heart])
  let top = 3.1
  for (u, t) in ((3.6, "3.6"), (3.8, "3.8"), (4.0, "4.0"), (4.2, "4.2"), (4.4, "4.4"), (4.6, "4.6")) {
    line((X(u), 0), (X(u), top), stroke: 0.3pt + c-line)
    lbl((X(u), -0.3), t)
  }
  line((xo, 0), (X(4.62), 0), stroke: 0.6pt + c-line-hi)
  lbl((X(4.1), -0.7), [UTMOS (UTMOS22-strong), mean over the set])
  for (i, (name, us)) in sets.enumerate() {
    let y = top - 0.55 - i * 0.95
    lbl((xo - 0.2, y), name, anchor: "east", fill: c-text, size: s-sm)
    line((X(us.at(0)), y), (X(us.at(3)), y), stroke: 0.5pt + c-line-hi)
    for (k, u) in us.enumerate() {
      circle((X(u), y), radius: 0.085, fill: cols.at(k), stroke: none)
    }
    if i == 2 {
      // the real af_heart clips, copy-synthesis set (§29.1)
      line((X(4.488), y - 0.22), (X(4.488), y + 0.22), stroke: (paint: c-ok, thickness: 0.7pt))
      lbl((X(4.488) + 0.08, y - 0.34), [real clips 4.49], anchor: "west", fill: c-ok)
    }
  }
  for (k, n) in names.enumerate() {
    let x = xo + calc.rem(k, 2) * 4.2
    let yl = top + 0.65 - calc.quo(k, 2) * 0.32
    circle((x, yl), radius: 0.07, fill: cols.at(k), stroke: none)
    lbl((x + 0.15, yl), n, anchor: "west", fill: if k == 2 { c-sel } else { c-label })
  }
})

// the §22 trade: deep fine-tunes gain likeness and lose naturalness
// ---- title page ---------------------------------------------------------------
#if not web {page(margin: (x: 0.75in, top: 0.7in, bottom: 0.65in))[
  #set par(leading: 0.5em)
  #grid(columns: (auto, 1fr, auto), column-gutter: 0.8em, align: horizon,
    caps(fill: c-text)[Municipal Robotics · Research],
    line(length: 100%, stroke: 0.5pt + c-line-hi),
    caps[November 2026])
  #v(1.6em)
  #image("images/muni-logo.svg", width: 0.95in)
  #v(0.45in)
  #align(center, ridges(width: 17.8, height: 13.5, stride: 1))
  #v(0.1in)
  #grid(columns: (1fr, auto), align: (left, right),
    caps[“Could you tell me where the charging station is?” · one ridge per frame],
    caps(fill: c-sel)[First audio · 17.6 ms])
  #v(1fr)
  #move(dx: -0.045 * s-display, text(font: sans-sb, size: s-display, tracking: -0.02em)[Real-time,\ In-Body Talk])
  #v(0.5em)
  #line(length: 22%, stroke: 2pt + c-label)
  #v(0.7em)
  #text(size: s-lg, fill: c-label)[A small streaming voice, trained in one tensor IR]
  #v(0.5in)
  #caps[Cam Pedersen · Municipal Robotics]
]}

#let abstract-text = [
  In spoken dialogue, the latency that determines whether a reply feels conversational is the time from the end of the user's turn to the first sound of the response. For a text-to-speech system, the corresponding quantity is the time to first audio, not throughput. We present RIBT (Real-time, In-Body Talk), a 54M-parameter streaming English TTS system consisting of a Rust port of the misaki phonemizer, a FastSpeech2-style acoustic model, a conditional flow-matching decoder distilled to a single step, and a Vocos vocoder. All networks are expressed as programs in the tensor IR of tang, our compiler; all trained components were trained in that IR without PyTorch, and the same programs execute on Metal, CUDA and WebGPU.

  On an M4 Max, RIBT produces its first audio a median of 17.6 ms after the text is available, at a real-time factor of 0.027. Kokoro-82M, which renders complete sentences, takes 349 ms on the same machine. The voice is distilled from Kokoro's af\_heart voice; Kokoro's training data included output from closed commercial TTS systems, and no Kokoro weights are included in RIBT. Measured against af\_heart, RIBT reaches a speaker similarity of 0.97–0.99, compared with Kokoro's own 0.98–0.99, a comparable word error rate on two of three test sets, and a lower predicted naturalness (UTMOS 4.39 against 4.52 on our main test set).
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

= Motivation

Turn-taking in human conversation is fast: the typical gap between speakers is about 200 ms, and responses delayed beyond roughly 300–400 ms are perceived as hesitant (§0). We target a 99th-percentile latency below 250 ms from the end of the user's speech to the robot's first sound. That budget includes speech recognition, endpointing and response generation, so the share available to synthesis is small.

Our previous system used Kokoro-82M @kokoro, a derivative of StyleTTS 2 with an iSTFTNet decoder @styletts2. Its output quality is high, but it synthesizes each utterance as a whole with bidirectional models, so no audio can be played until the entire utterance has been computed (§1). On an M4 Max, Kokoro's first audio arrived after 349 ms on the CPU and 815 ms on the GPU (§24.3); its real-time factor of 0.093 is adequate, so the limiting quantity is the time to first audio.

This gives three design requirements for RIBT: streaming synthesis with a low-cost first chunk, a model small enough to train and modify in-house, and a single implementation for a laptop, the robot and a web browser. The name also refers to a longer-term goal, a voice conditioned on the robot's physical state, which is outside the scope of this report.

#aside[Sources][
  Numbers marked §N refer to sections of the project's lab log. The evaluation files behind the tables, and the scripts that produced them, are published with this post in `data/`.
]

= A single tensor IR

#link("https://tang.toys")[tang] is our compiler and inference engine. Its tensor IR consists of affine views and a single operation, the comprehension

$ "out"[i] = plus.o.big_k "body"(x["view"(i, k)], dots) $

with a scalar body and a monoid. Matrix products, attention, convolutions, normalizations and the inverse STFT are instances of this form. Reverse-mode derivatives are again comprehensions, so backward passes are derived by the compiler rather than written by hand (§6). All networks trained for RIBT were trained in this representation. Python is used only for data preparation and for evaluation with external models (Whisper, UTMOS, WavLM).

Each training step compiles to one program containing the forward pass, the losses, the derived backward pass and the AdamW update. Optimizer state is double-buffered, so a step that produces non-finite values is discarded without a copy (§10). Before training, every graph is verified against tang's f64 interpreter, first by comparing derived gradients with finite differences and then by comparing one GPU step with the interpreter; worst-case relative errors were mostly between $10^(-7)$ and $10^(-5)$ (§13.3, §14.2, §15.2).

This approach has three practical consequences:

- *Portability.* The same graphs run on Metal and on CUDA (RTX 3090). The browser build executes tang's exported WGSL on WebGPU with no hand-written model code (@sec:browser).
- *Cost-driven operator choice.* Per-kernel costs determined several design rules: no recurrent layers, which are launch-bound at batch size one; polyphase convolutions with a reshape in place of transposed convolutions, which are 22 times faster and exact to $4 times 10^(-13)$ (§7); and fixed chunk shapes, so a single compiled program serves every chunk.
- *No separate inference stack.* The program that is trained is the program that is deployed.

The project also exposed more than two dozen limitations of the IR and its back ends, including Metal's 31-buffer argument limit, the absence of scan, gather and forward-mode differentiation, and CUDA-specific numerical errors. Verification against the f64 interpreter detected the numerical errors before they affected training. Several of these limitations have since been resolved upstream: guarded views, tanh, split reductions and shared parameter buffers.

= Architecture

#figure(fig-pipeline(),
  caption: [#lead[System overview.] Text is converted to phonemes on the CPU; three networks on the GPU produce a 24 kHz waveform. The flow decoder (orange) is the only generative stage. The aligner is used only to produce duration targets for training.],
) <fig:pipeline>

== Phonemization (lilt)

Kokoro uses misaki @misaki, a Python phonemizer built on spaCy. lilt is a stage-by-stage Rust port: spaCy's tokenization algorithm with its exported rules, an averaged-perceptron tagger distilled from spaCy's small English model, a line-by-line port of misaki's lexicon logic, and a number normalizer implemented independently (§12). It has no runtime dependencies and embeds about 16 MB of tables.

#figure(
  table(
    columns: 4,
    align: (left, right, right, right),
    table.header([*Set*], [*Sentences*], [*Word parity*], [*Port alone*]),
    [Held-out test], [9,470], [99.858%], [100.000%],
    [Edge cases], [130], [99.45%], [100.000%],
  ),
  caption: [#lead[Agreement of lilt with misaki 0.9.4] on in-vocabulary words. "Port alone" supplies spaCy's tokens and tags to lilt, so all remaining disagreement is due to the tagger. §12.3.],
)

lilt processes 274,000 words per second on one M4 Max core. In streaming mode a word is emitted as soon as no later input can change its pronunciation, on average 1.28 words behind the input, at 67 µs per call. Streamed and batch output are identical on all 9,600 test and edge-case sentences (§12.1, §12.4).

misaki passes out-of-vocabulary words to espeak-ng, which is licensed under GPL-3.0; lilt instead resolves them in order through rules for times, addresses and handles, morphological decomposition and compounding from known stems, initialisms, a 2 MB letter-context decision tree fitted to its own lexicon, and letter-by-letter spelling (§27). On 9,599 test and edge-case sentences, one sentence still loses a word, a Chinese-script parenthetical. On 82 sentences built around names, neologisms and technical terms, Whisper recognizes 75 of the 82 target words. The decision tree reaches 58% exact accuracy (68% ignoring stress) on 8,806 held-out lexicon words.

== Aligner

The duration predictor is trained on per-phoneme frame counts. We obtain them with an aligner following RAD-TTS @badlani2021align (0.57M parameters, forward-sum loss, monotonic alignment search; §13). Its word boundaries differ from those of a wav2vec2 forced aligner by a median of 18.4 ms, close to that aligner's 20 ms resolution.

== Acoustic model

The acoustic model follows FastSpeech2 @ren2020fastspeech2 (18.65M parameters): a four-block transformer encoder, a reference encoder that derives the speaker from a speech clip, duration, pitch and energy predictors, a hard length regulator, and an eight-block ConvNeXt decoder that outputs 100 log-mel bands and frame-level F0 (§14). Trained with an L1 loss, it oversmooths: above 0.7 kHz its mel spectrograms retain only 21–42% of the harmonic and formant fine structure of the recordings (§15.4).

== Flow decoder distilled to one step

A conditional flow-matching decoder @mehta2024matcha (21.88M parameters) conditioned on the acoustic model's mel and hidden state restores this detail (§15). Because a 16-step sampler is too slow for streaming, we distill it into a shortcut model @frans2024shortcut: the same network, conditioned on the step size and trained on input–output pairs from the teacher's ODE. The one-step student matches the 16-step teacher's mel error to three decimal places. A sampling temperature of $tau = 0.3$ retains most of the restored structure without the roughness introduced at $tau = 1$ (§15.5, §17.4). One step takes 9–12 ms for two seconds of speech (§15.7).

== Vocoder

The vocoder has the Vocos architecture @siuzdak2023vocos: ConvNeXt blocks at frame rate followed by an inverse-STFT head (13.53M parameters). We first trained our own vocoder adversarially in the IR (§10). Swapping STFT components between our output and real audio showed that its magnitude spectra were as accurate as those of the public Vocos checkpoint while its phase was not: real phase combined with our magnitudes scored as well as Vocos, whereas our phase combined with real magnitudes scored below our own vocoder (§29.1). Because the architecture and mel front end are identical, RIBT uses the public Vocos weights (MIT), imported into our generator by renaming tensors. The imported model matches the PyTorch implementation to $1.5 times 10^(-5)$ when both use the same GELU approximation, and it improved UTMOS by 0.17–0.30 on our test sets (§29.2).

= Voice

An initial checkpoint trained only on LibriTTS-R @koizumi2023librittsr (CC BY 4.0) was intelligible but had low predicted naturalness (§18). Fine-tuning on individual readers, using LibriTTS-R's roughly 20 minutes per speaker and up to 48 hours per reader that we aligned from LibriVox, increased speaker similarity but not naturalness, because our vocoder did not reproduce restored MP3 recordings well (§20–§22).

The released voice is therefore distilled from a TTS teacher. We rendered 92,050 utterances (135 hours) with Kokoro's af\_heart voice from 52,000 LibriTTS-R transcripts and 40,000 conversational and robot-specific lines, plus the 50 held-out texts, normalized to LibriTTS-R's loudness, with the 50 held-out texts and all evaluation texts excluded from training (§24.1). The phoneme sequences are those produced by Kokoro for each rendering. Starting from the LibriTTS-R checkpoint, we fine-tuned the acoustic model and the flow teacher, and re-distilled the one-step student (§24.2). The acoustic fine-tune increased UTMOS by 0.23–0.42 and speaker similarity to af\_heart from 0.88–0.92 to 0.96–0.98 (§24.3).

#aside[Provenance][
  The RIBT voice is *distilled from Kokoro-82M's af\_heart voice* (kokoro 0.9.4, misaki 0.9.4). Kokoro's weights are released under Apache-2.0. Kokoro's training data included synthetic audio from closed commercial TTS providers that it does not name; the terms of those providers apply to whoever generated that data. The open questions are the likeness of the af\_heart voice and Kokoro's data lineage. *No Kokoro weights are included in RIBT*: every RIBT network was trained by us, starting from a checkpoint trained only on LibriTTS-R, which remains available as a license-clean model. The vocoder is the public Vocos checkpoint (MIT), trained on LibriTTS.
]

= Extensions beyond the teacher

*Context-dependent prosody.* Kokoro's prosody does not depend on preceding dialogue. RIBT includes a 0.25M-parameter module that encodes the previous turn and conditions the duration, pitch and energy predictors. It is trained on targets derived by rule from af\_heart's own prosody, with magnitudes taken from studies of focus in English intonation @xu2005focus. Given the preceding questions "Who put it on the table?" and "Where did you put it?", the module places the accent of "I put it on the table." on the intended word in 23 of 24 pairs, raising it by about five semitones (§25.5). Without a preceding turn the output is identical to the base model. The module is included in the code; its weights are not part of this release.

*Teacher selection.* Rendering corpus lines several ways and keeping the best by intelligibility, UTMOS and speaker similarity reduced the teacher's word error rate from 3.41% to 2.91% (§26.2). Retraining the acoustic model on the selected renderings, plus 750 lines of robot-specific vocabulary, increased UTMOS by 0.02–0.05 on every test set (§26.4).

*Regional accent.* lilt implements an optional Upper Midwest accent: the vowel of "bag" is raised toward that of "bait" before /g/, and the vowel of "go" is lengthened. Interjections are adapted accordingly, e.g. "Ope!" (§26.7, §26.8). The release enables it by default.

= Streaming <sec:stream>

Streaming requires no retraining (§19). Words enter lilt one at a time. The encoder and predictors are re-run on the token prefix (2–5 ms), and all but the last two words are committed: their durations and pitch are frozen, so audio that has been played is never revised. Frames are rendered in chunks of 48 through the decoder, the one-step flow and the vocoder, using a fixed 128-frame window with left and right context and a short crossfade. All state is held on the host.

Measured on the LibriTTS-R checkpoint, streamed and non-streamed synthesis differ by less than 0.05 UTMOS, with no change in word error rate, and spectral flux at chunk boundaries is unchanged (§19.3). With the full text available, the released model produces first audio after a median of 17.6 ms (90th percentile 27.5 ms) at a real-time factor of 0.027, with no buffer underruns on ten test sentences (`data/latency`).

#figure(fig-latency(),
  caption: [#lead[Time to first audio on an M4 Max, linear scale.] RIBT streams (median 17.6 ms; whisker at the 90th percentile). Kokoro does not stream, so its first audio is the complete first sentence. The 250 ms line is the target for the entire conversational loop, not for synthesis alone.],
)

When the text arrives incrementally from a language model at 15 words per second, first audio follows the first word by about 0.5 s, because the first chunk requires committed text worth roughly one second of speech (§19.4). In this setting latency is dominated by text arrival rather than computation.

= Comparison with Kokoro

We evaluate on three sets: WER-50 (50 LibriTTS-R test sentences), listen-10 (ten conversational sentences) and held-50 (the 50 af\_heart texts excluded from training). Naturalness is predicted with UTMOS22-strong @saeki2022utmos, word error rate is computed from Whisper small.en transcripts @radford2022whisper, and speaker similarity is the cosine similarity between each utterance's WavLM-base-plus speaker embedding @chen2022wavlm and the centroid of 121 real af\_heart recordings.

#figure(
  table(
    columns: (1.4fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right),
    table.header([*Measure*], [*WER-50*], [*listen-10*], [*held-50*]),
    [UTMOS, RIBT], [4.394], [4.336], [4.304],
    [UTMOS, Kokoro af\_heart], [4.521], [4.497], [4.464],
    [Word error, RIBT], [2.71%], [2.44%], [1.73%],
    [Word error, Kokoro], [2.61%], [0.81%], [1.73%],
    [Similarity, RIBT], [0.987], [0.980], [0.970],
    [Similarity, Kokoro], [0.990], [0.982], [–],
  ),
  caption: [#lead[RIBT and its teacher]: default settings, seed 0. Two of RIBT's three errors on listen-10 come from one sentence, where the spoken time "four fifteen" is transcribed as "4.15" (§29.2). Kokoro's similarity is not reported on held-50, whose reference clips are af\_heart itself. `data/eval`.],
) <tab:compare>

#figure(fig-scores(),
  caption: [#lead[UTMOS on the three test sets] for the LibriTTS-R checkpoint, the af\_heart-distilled model with our own vocoder, RIBT with the Vocos weights, and Kokoro. The green mark is real af\_heart recordings on a held-out set. `data/eval`.],
)

Speaker similarity and word error rate are close to the teacher's; UTMOS is 0.13–0.16 lower on every set. For reference, 50 held-out real af\_heart recordings score 4.488 (§29.1), within 0.06 of the teacher on every set; the teacher is therefore close to the metric's value for the voice itself, which bounds what distillation can recover on this metric.

= Browser deployment <sec:browser>

RIBT also runs entirely in a web browser. lilt is compiled unchanged to WebAssembly, and the acoustic model, flow decoder and vocoder run on WebGPU using tang's WGSL output: an exporter builds each graph at fixed bucket shapes, applies the same optimization passes as the native runtime, and serializes the kernels and their dispatch order. The JavaScript runtime only uploads buffers and dispatches kernels (`data/browser`).

#figure(
  table(
    columns: (1.6fr, 1fr),
    align: (left, right),
    table.header([*Measure (Chrome, M4 Max)*], [*Value*]),
    [Audio vs. native, same weights], [≤ $6 times 10^(-5)$ rel. RMS],
    [Durations vs. native], [identical],
    [Audio vs. native, f32 weights], [1–2% rel. RMS],
    [Weights: acoustic / flow / vocoder], [40.6 / 43.8 / 27.1 MB],
    [Real-time factor (warm)], [0.014],
    [Page load to first audio (localhost)], [about 1.05 s],
  ),
  caption: [#lead[WebGPU deployment.] Weights are stored in f16, except the pitch and energy heads (1.7M parameters), which are kept in f32; the 1–2% difference from the f32 model is due to this quantization. Five test sentences.],
)

The weights total about 112 MB (about 115 MB including lookup tables); over a network, download time rather than computation determines the latency of the first utterance.

= Release

- *Code* (MIT): lilt, the four networks as tang programs, training and evaluation, the streaming engine and the browser runtime: #link("https://github.com/muni-works/ribt")[muni-works/ribt].
- *Weights*: acoustic model, one-step flow student, imported Vocos vocoder and the af\_heart reference clip, with SHA-256 checksums in the manifest (`data/release.toml`): #link("https://huggingface.co/municipal-robotics/ribt")[municipal-robotics/ribt].
- *Default settings*: one flow step at $tau = 0.3$, seed 0, a one-semitone pitch increase and the Upper Midwest accent; each is configurable.

= Limitations and future work

- *Deployment conditions.* All measurements were taken on a laptop GPU. Measurements on the robot's onboard computer, within the full dialogue loop, are pending.
- *Latency with incremental text.* Computation takes 17.6 ms (median), but waiting for sufficient committed text takes about 0.5 s. A smaller first chunk combined with a playout policy driven by the text arrival rate has not yet been evaluated.
- *Voice provenance.* The released voice depends on a distillation teacher. The license-clean checkpoint and training pipeline can be used with new recordings; a vocoder that reproduces restored recordings faithfully would remove the need for a teacher.
- *Evaluation.* Naturalness is estimated with UTMOS; no listening test with multiple listeners has been run.
- *Body-state conditioning.* The prosody module already accepts dialogue context; conditioning on the robot's physical state is future work.

= Conclusion

RIBT is a 54M-parameter streaming TTS system that produces first audio 17.6 ms after receiving text on an M4 Max, with no measurable loss of quality from streaming. All of its networks are tang programs that run unchanged on Metal, CUDA and WebGPU. Its voice, distilled from Kokoro's af\_heart, matches the teacher in speaker similarity and word error rate and scores 0.13–0.16 lower on UTMOS. Code and weights are released with this report.

#heading(outlined: true, numbering: none)[References]
#show bibliography: it => { show "?.": "?"; show "!.": "!"; it }
#bibliography("refs.bib", style: "nature", title: none)
