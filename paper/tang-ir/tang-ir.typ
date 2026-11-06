// Research paper: tang's tensor IR — views and comprehensions.
// Same treatment as paper/ribt (muon "Pilot Light", dark).
// Build: make (IBM Plex from fonts/, system fonts ignored so builds are reproducible).
// Every number traces to BENCHMARKS.md or docs/tensor-ir.md in the tang repository.

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
#let brand-family(name) = brand-names.find(n => n.at(0) == lower(name)).at(1)
#show brand-re: it => text(fill: fam-color.at(brand-family(it.text)), it)

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
#let aside(title, body) = pad(left: 0.35in, right: 0.35in, block(width: 100%, inset: (left: 12pt, y: 2pt), stroke: (left: 0.6pt + c-line-hi), above: 2.2em, below: 2.2em, breakable: false, {
  set text(size: s-sm, fill: c-label)
  set par(spacing: 1.1em, leading: 0.68em)
  show strong: set text(fill: c-text)
  block(below: 0.9em, text(font: mono-m, size: s-xs, fill: c-sel, tracking: track, upper([Aside · ] + title)))
  body
}))

#let title = [Two Primitives Are Enough]
#set document(title: "Two Primitives Are Enough", author: "Cam Pedersen (Municipal Robotics)")

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
#set heading(numbering: "1.1")
#show strong: set text(font: sans-sb)
#show emph: set text(font: ("IBM Plex Sans",), style: "italic")
#show link: set text(fill: c-text)
#show link: it => if type(it.dest) != str { it } else { underline(stroke: 0.5pt + c-label, offset: 2pt, it) }
#show heading: set text(font: sans, weight: 400, fill: c-text, hyphenate: false)
#let numlabel(it) = text(font: mono-m, size: s-xs, fill: c-label, tracking: track, counter(heading).display(it.numbering))
#show heading.where(level: 1): it => block(above: 2.2em, below: 1.1em, sticky: true, width: 100%, {
  if it.numbering != none { place(left, dx: -1.15in, dy: 0.32em, box(width: 1.0in, align(right, numlabel(it)))) }
  text(font: sans-sb, size: s-lg, tracking: -0.01em, it.body)
})
#show heading.where(level: 2): it => block(above: 1.65em, below: 0.55em, sticky: true, {
  if it.numbering == none { return text(font: sans-m, size: s-md, it.body) }
  place(left, dx: -1.15in, dy: 0.22em, box(width: 1.0in, align(right, numlabel(it))))
  text(font: sans-m, size: s-md, it.body)
})
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
    #caps(if it.kind == table [Table] else [Fig] + nb + it.counter.display(), font: mono-sb, fill: c-text)#h(0.7em)#it.body
  ])
}
#show cite: set text(fill: c-label)

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
    ([CUDA, mma.sync], 0.328, c-ok),
  )
  for t in (0.1, 0.3, 1, 3, 10) {
    line((lx(t), -0.2), (lx(t), 2.75), stroke: 0.3pt + c-line)
    lbl((lx(t), -0.45), [#t ms])
  }
  let torch = 0.449
  line((lx(torch), -0.2), (lx(torch), 2.75), stroke: (paint: c-sel, thickness: 0.7pt, dash: "dashed"))
  lbl((lx(torch), 3.0), [PyTorch TF32 · 0.449], fill: c-sel)
  for (k, (name, t, col)) in rows.enumerate() {
    let y = 2.1 - k * 0.85
    lbl((x0 - 0.2, y + 0.22), name, anchor: "east", fill: c-text, font: sans-m, size: s-sm)
    rect((lx(0.1), y), (lx(t), y + 0.44), fill: col.transparentize(55%), stroke: 0.5pt + col)
    lbl((lx(t) + 0.12, y + 0.22), [#t], anchor: "west", fill: c-text)
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

// ---- title page ---------------------------------------------------------------
#page(margin: (x: 0.75in, top: 0.7in, bottom: 0.65in))[
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
  #move(dx: -0.045 * s-display, text(font: sans-sb, size: s-display, tracking: -0.02em)[Two Primitives\ Are Enough])
  #v(0.5em)
  #line(length: 22%, stroke: 2pt + c-label)
  #v(0.7em)
  #text(size: s-lg, fill: c-label)[Deriving flash attention, its backward pass, and whole-model kernels from affine views and monoid comprehensions]
  #v(0.5in)
  #caps[Cam Pedersen · Municipal Robotics]
]

#page(margin: (x: 0.75in, top: 1.1in, bottom: 1.05in))[
  #block(width: 4.9in)[
    #heading(outlined: false, numbering: none)[Abstract]
    #set text(size: 10pt)
    #set par(leading: 0.8em, spacing: 1.25em)
Deep learning frameworks reach peak speed through hand-written kernels: one per
operator, per backend, per fusion pattern. Each kernel freezes decisions (what to fuse, where
data lives, how threads share work) that depend on the model, the shape and the chip. We
describe the tensor IR in _tang_, a Rust differentiable-computing library, which replaces those
kernels with two primitives: _views_, affine maps from an iteration space to tensor
coordinates, and _comprehensions_, reductions under a monoid whose body is a scalar expression
graph. Fusion is one substitution rule. Flash attention is not written; it falls out of a
rewrite that recognizes online softmax as a monoid, plus one staging rule. Gradients of
comprehensions are comprehensions, so the backward pass, including a flash-style attention
backward with no $n times n$ intermediates, comes from the same passes. Number formats and thread
mappings are schedule fields that cannot change the result, and a per-kernel autotuner chooses
among them on the device. The same graphs lower to WGSL, CUDA (with `mma.sync` tensor cores),
Metal (with simdgroup matrices), OpenCL, GLSL and C. On an RTX 3090 a transformer block's
forward pass derived this way runs 1.37× faster than PyTorch with TF32, and a whole Qwen3-8B
4-bit decode step runs as one IR graph at 55% of memory-bandwidth speed of light. The compiler
contains no operator-specific code.
  ]
]

= Introduction

A modern model is a few dozen distinct operators. A modern framework is thousands of kernels,
because every pair of (operator, backend) needs one, and every profitable fusion such as
attention with its softmax, a matmul with its bias and activation, or a norm with the projection
that follows needs another. FlashAttention @dao2022flash is the clearest case: a large speedup
that came from rewriting one operator by hand so its $n times n$ score matrix never reaches memory.
Its backward pass took another hand-written kernel, and each new chip generation takes another
rewrite.

Hand kernels are forks. Each re-derives the same arithmetic and freezes a schedule that was right
for one shape on one device. We measured how often that schedule is wrong. Causal attention at
$n = 512$ on an Apple M4 Max is fastest as the _naive_ graph with $n^2$ threads, because the scores
fit in cache and parallelism is the bottleneck. At $n = 1024$ it wants the tiled flash schedule.
Matmul at $128 times 576 times 1536$ wants a $16 times 16$ shared-memory tile; at $1024^2$ the same
tile loses. Rules of thumb tuned on the M4 picked the wrong matmul schedule on an NVIDIA RTX 3090.
The winning schedule depends on the graph, the chip and the size, not on the operator.

This paper argues that a whole model should go through an IR small enough to reason about, and that
everything a hand kernel encodes can be recovered as either an algebraic rewrite or a schedule
choice. tang's tensor IR (`tang_compile::tensor`, about 24k lines of Rust) has two primitives:

- *Views*, affine index maps that express broadcast, transpose, slicing, striding, padding and
  per-head column selection without touching memory.
- *Comprehensions*, $"out"[i] = plus.o_k "body"(x_0[v_0(i,k)], x_1[v_1(i,k)], dots)$, where
  `body` is a scalar expression graph and $plus.o$ is a monoid.

Contributions:
+ An IR in which fusion, flash attention, logsumexp and Welford variance are instances of two
  general rewrites (§3).
+ Reverse-mode differentiation that maps comprehensions to comprehensions, including the
  online-softmax monoid and a proof procedure that removes the stabilizing max's gradient. Together
  with nested contractions, this yields an attention backward with no $n times n$ tensors (§4).
+ Precision as a schedule, with an emulating interpreter that predicts a format choice's error
  before it runs (§5).
+ Lowerings to six targets from shared emitters, and measurements against hand kernels, PyTorch
  and the memory-bandwidth limit on three chips (§6, §7).

= Background: tang

tang is a `no_std` Rust library that started as a geometry and physics math crate. One `Scalar` trait
covers `f32`, `f64` and dual numbers, so a simulation written once yields exact derivatives by
changing a type parameter. `tang-expr` traces Rust closures into a scalar DAG of nine RISC
operations, which it can differentiate symbolically, simplify and compile. The tensor IR uses that
scalar DAG as its body language, so every comprehension body can be differentiated, simplified and
compared structurally. Higher crates (`tang-gpu`, `tang-llm`, `tang-train`) run programs the IR
produces.

= The IR

== Views

A view maps a point of an iteration space to a source tensor's coordinates with one affine form
per source dimension, $"offset" + sum_j c_j dot "idx"_j$. Broadcast is a zero form, transpose a
permutation, slice an offset, stride a coefficient. A form with two terms expresses "head $h$ reads
columns $64h + 2i$". Views compose by substitution. They are the only way a comprehension reads
its inputs, so every layout decision is a view and every view can be analyzed.

A view may be _guarded_: an out-of-range read returns the monoid's identity (zero) rather than
raising a shape error. Padded, dilated and transposed (polyphase) convolutions and overlap-add are
guarded reads, with no padding operator. The gradient of a guarded read removes a coordinate
rather than scattering. For $x[c, t + 3k - 9]$, $partial x[c, tau]$ reads
$partial y[o, tau - 3k + 9]$ through a guard, so padding contributions never reach $x$.

Grouped-query attention's $"head" \/ "heads_per_group"$ is not affine. The IR expresses heads as
two dimensions, $["groups", "per_group"]$, and the views do the rest. Dimensions can be fixed or
symbolic (`Dim::Sym("seq")`). Construction, rewriting and differentiation work with symbols, and
`bind` makes them concrete for scheduling and lowering.

== Comprehensions and monoids

The only compute operation is

$ "out"[i_1, dots, i_p] = plus.o.big_(k_1, dots, k_r) "body"(x_0[v_0(i, k)], dots, x_m [v_m (i, k)]) $

A map is a comprehension with no reduce dimensions. Sum and max are monoids. Matmul is
$sum_k a[i,k] b[k,j]$. Attention scores, convolution and gather are the same operation with
different views. The monoid's `combine` is itself a scalar graph, and a comprehension may carry
tuple-valued state. Online softmax is the monoid on $(m, l, "acc")$; arg-max is the monoid on
$("index", "value")$.

== Rewrites

*Fusion is one rule.* A map is a pure function of its inputs, so `substitute_maps` splices its body
into every consumer and composes the views. Map→map, map→reduce and transpose→anything are the
same case. The rule is cost-aware: a map is not recomputed inside a reduction unless it is cheap.
Reductions are never substituted. They are _inlined_ by a schedule decision, which separates
algebra from scheduling. A row-major reshape that only merges dimensions is a view, not a copy.

*Epilogues ride the reduction.* A map that reads a reduction point for point (a bias, an activation,
the $"acc" \/ l$ that finishes softmax) runs on the thread that holds the final accumulator.

*Siblings share a pass.* Two reductions over the same space and monoid with the same readers become
one reduction under the product monoid (`merge_siblings`). The gate and up projections of a SwiGLU
MLP become one tuple-valued matmul, the activation becomes its epilogue, and the normalized input is
read once.

*Flash attention is a rewrite.* `stabilize_softmax` finds $m = max_j s_j$ and every
$sum_j g dot exp(s_j - m)$ over the same canonical $s$, with masks and scales allowed, and replaces
them with one reduction under the online-softmax monoid. The value column of $sum_j p_j v_j$ becomes
a point dimension of the fused comprehension. Nothing $n times n$ is materialized. Logsumexp,
Welford variance and top-$k$ are the same rewrite with different monoids. @fig-rewrite shows the attention case.

#figure(fig-rewrite(),
  caption: [The rewrite that derives flash attention. The naive graph writes the scores and probabilities as $n times n$ buffers (dashed). Fusion splices the maps into their readers; `stabilize_softmax` merges the max and both exponential sums into one reduction whose state is $(m, l, "acc")$. No attention-specific code is involved; scheduling then finds the tiled kernel.],
) <fig-rewrite>

== Schedules

A comprehension says _what_ to compute. Schedule fields say _how_, and they cannot change the
answer:

- `inline`: recompute inside the consumer instead of writing a buffer.
- `split`: one workgroup per point, with threads striding the reduce space and tree-combining. This
  is valid for any monoid because combine is associative, including online softmax.
- `tile`, `tile_2d`: blocks of threads, each owning a register tile of points. The emitter tracks
  every address as an affine form over loop variables. Anything that does not depend on the lane
  axis is staged in workgroup memory once per reduce chunk. That covers buffer reads (K and V
  tiles, matmul operand tiles) and inlined sub-computations (the $q dot k$ scores).
- `precision`: storage and accumulation formats (§5).

`schedule_auto` encodes three rules distilled from measurement. `autotune_kernels` times each
candidate mapping per materialized node on the device, using the graph's real inputs, and caches the
winner by device and kernel source. With substitution and the online-softmax rewrite, the staging
rule produces flash attention's real structure: rows × lanes per workgroup, cooperative score
tiles, and online softmax in registers. Nobody wrote that kernel.

= Gradients are comprehensions

For $y = plus.o_k "body"(x[v(i,k)])$, the gradient with respect to $x$ through a _pick_ view is
found by renaming coordinates. The coordinates that $v$ picks become $x$'s output dimensions, the
rest become reduce dimensions, and every other view is pushed through the same renaming. The body is
differentiated by `tang-expr`'s symbolic `diff`. A dimension read through any other form (an
offset, stride, diagonal or broadcast) stays an output dimension, and the body is gated by
$[c = "form"]$ through `iota`, a node that turns coordinates into values. Max gates its term to the
arg-max. The backward graph is an ordinary graph, so the same passes optimize it. Rotary embedding
and GQA gradients come from the gated scatter with no special handling.

*The online-softmax monoid* has its own rule. With the forward's $m$ and accumulators read back,
$partial "acc"_i \/ partial s_j = g_i exp(s_j - m) - "acc"_i [s_j = m]$, so the flash-fused graph
differentiates and its gradients equal the naive graph's.

*A stabilizing max has no gradient.* Softmax is invariant to shifting its scores, so the
$[s = m]$ terms sum to zero, but only in exact arithmetic. While those terms exist, the max must be
materialized and masked tiles cannot be skipped. `backward` drops them when it can prove the loss
does not depend on $m$. Each node downstream of $m$ gets a degree in $t = exp(-m)$, either
$t^k h$ or $a + kappa m$ with $h, a$ free of $m$, using only identities such as
$t^a t^b = t^(a+b)$ and $sum_j t h_j = t sum_j h_j$ when $t$'s row does not depend on $j$. The output
$o \/ l$ then has degree 0. If every path from $m$ ends at a degree-0 node, $partial L \/ partial m
equiv 0$ and the gradient is not built. The f64 evaluation of a training step is unchanged to
$2.7 times 10^(-19)$ absolute at gradients of order $10^6$.

*Flash backward is nesting.* `hoist_invariant_factors` distributes sums
($sum_c tilde(P) dot "dO" dot V -> tilde(P) dot sum_c "dO" dot V$). `schedule_nested_contractions`
then inlines a short contraction (one reduce dimension of at most 128) into every tile that reads
it. The attention backward reads $S = Q K^top$ and $"dP" = "dO" V^top$ only through $tilde(P)$ and
$"dS"$, which the dQ, dK and dV tiles recompute per staged block on tensor cores. On CUDA this removed
S, $tilde(P)$, dP, the max over S and three correction kernels from a transformer training step,
reducing 63 kernels to 49 and the summed best-per-kernel time from 1.80 to 1.22 ms at sequence
length 512 (RTX 3090).

= Precision is a schedule

f16 is a different way to run the same program, not a different program. Each node has a
_storage_ format, applied where a value is written to memory, and an _accumulation_ format,
applied to a reduction's running state after each combine. The graph stays exact math.

The interpreter predicts the error. `eval` is pure f64. `eval_emulated` rounds every stored value
and every accumulator step to its scheduled format (round to nearest even, subnormals, overflow),
with body arithmetic in f64. An `ErrorBudget` accepts or rejects a schedule before it runs.
Emulation matches the GPU's f16 kernels to 1 ulp when the reduction order is the same. Reduction
order matters: AdaIN's variance over $T = 2000$ with an f16 accumulator has error
$2.8 times 10^(-4)$ under a 256-thread split and $1.3 times 10^(-2)$ with one thread per row, while
the sequential emulation predicts $7.9 times 10^(-3)$. Emulation models the worst case.
`tune_precision` lowers buffers to half precision one move at a time and keeps a move only if the
program stays within budget and gets faster.

= Lowering

Shared emitters produce the point, split and tiled schedules, register tiles, guarded views,
epilogue fusion and tuple monoids once. A dialect switch then handles buffer access and surface
syntax.

- *WGSL* (portable default, through wgpu on Metal, Vulkan and DX12). f16 storage is packed two per
  `u32`, because the toolchain rejects `enable f16`.
- *CUDA.* Matmul-shaped tiles run on `mma.sync` (TF32 m16n8k8, or f16/bf16 m16n8k16 when the
  operands are half precision) with `cp.async` staging rings. Block shapes are tuning candidates.
  `cuda_flash_kernel` recognizes the online-softmax comprehension and keeps $O$, the row max and the
  partial sums in `mma` registers. The score accumulator is reused as the A operand of $O += P V$
  after permuting keys within each 8-wide step, which is legal because the reduction is
  associative.
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

= Evaluation

*Setup.* Apple M4 Max (Metal), NVIDIA RTX 3090 (Vulkan and CUDA 12), and a Qualcomm QCS8550 in a
Booster K1 humanoid robot (Adreno 740, Cortex-X3). PyTorch 2.10 + cu128 with CUDA events. Unless
stated otherwise, tang times are kernel-only. Several runs shared the GPU with other tenants. We
mark those, and report minima rather than means, because contention only adds time. Every derived
result is checked against an f64 interpreter; agreement is $10^(-6)$ to $10^(-4)$ relative,
depending on format.

== Derived vs hand-written kernels

tang shipped hand-written WGSL kernels before the IR existed, which makes a controlled comparison
possible: same runtime, same chip, same inputs. @tab-hand is one consistent run on the M4 Max,
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
  caption: [Hand-written vs derived on M4 Max (Metal via WGSL). The hand training step's attention
  backward ran on the CPU because no one had written a GPU version. The derived step had no such
  gap, because none of it was written.],
) <tab-hand>

Every hand kernel is matched or beaten. The schedules that win differ across operators and sizes.
On the 3090 under Vulkan, the derived transformer block first _lost_ to the hand path. Three
chip-agnostic fixes followed: cost-aware substitution, keeping reductions schedulable under their
epilogues, and a bank-conflict-free tile layout. After them, the autotuned block won there too
(2.5 vs 3.1 ms at seq 128, 6.2 vs 10.4 ms at seq 512).

== Against PyTorch

@tab-torch tracks a 9-head GQA transformer block ($d = 576$, $"ff" = 1536$, rotary embeddings,
SwiGLU) on the RTX 3090 as the backends matured. Through WGSL, which has no access to tensor cores,
derived kernels stayed 2.5–4× behind PyTorch. With the CUDA lowering, flash attention on
`mma.sync` and the backward passes of §4, the forward block passes PyTorch (@fig-trajectory).

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, right, right, right, right),
    [Block, seq], [WGSL first], [WGSL fused], [CUDA now], [Torch fp32/TF32],
    [fwd 128], [1.97], [1.06], [*0.178*], [0.306 / 0.286],
    [fwd 512], [4.41], [3.34], [*0.328*], [0.602 / 0.449],
    [fwd+bwd 128], [5.0], [3.15], [*0.552*], [1.196 / —],
    [fwd+bwd 512], [10.1], [8.19], [*1.467*], [1.719 / —],
    [4 layers, step 128], [—], [—], [*3.92*], [4.40],
  ),
  caption: [Transformer block on the RTX 3090. The CUDA column and PyTorch were measured in
  interleaved rounds under `flock`, best of six; times in ms; PyTorch's 4-layer step uses fused AdamW. The WGSL columns come from earlier runs and are
  shown to make the trajectory visible.],
) <tab-torch>

#figure(fig-trajectory(),
  caption: [Transformer block forward, seq 512, RTX 3090, log scale. The same derived graph under three generations of lowering; only the last reaches tensor cores. Dashed: PyTorch with TF32.],
) <fig-trajectory>

On the CUDA path, the derived inference attention kernel is 0.032 ms at seq 512, down from 0.178 ms
before the `mma.sync` rewrite. The seq-512 forward block is 1.37× faster than PyTorch with TF32. The
training step is at parity or slightly ahead. We do not claim a general win over cuBLAS: a lone fp32
matmul at $1024^2$ through WGSL reaches 7.6 TFLOPS against cuBLAS's roughly 19. The gain comes from
fusion across operator boundaries that a library of separately tuned operators cannot do.

== A whole model as one graph

Qwen3-8B with MLX 4-bit weights runs as one IR graph per decode step, lowered by
`to_cuda_decode` into 506 kernels and captured as a CUDA graph. Nibble unpacking and the
$q dot s + b$ dequantization are a map the GEMV reads. That map is inlined and evaluated in
registers as weights stream in. @fig-decode shows where the remaining time goes. The KV-cache update is a `select` over a runtime position, which the
lowering turns into loop bounds, so a step touches only live cache rows.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, right, right, right),
    [Qwen3-8B, 3090], [decode, short ctx], [decode, 4k ctx], [prefill 512],
    [speed of light (936 GB/s)], [220 tok/s], [192 tok/s], [—],
    [tang IR, device step], [*122 tok/s* (55%)], [*104 tok/s* (54%)], [*774 tok/s*],
  ),
  caption: [Measured while another job held about 98% of SM time, so the true numbers are likely
  higher. Teacher-forced on 64 greedy tokens against an exactly dequantized f32 CPU reference: max
  logit error $1.7 times 10^(-4)$, with 64/64 arg-max agreement.],
) <tab-qwen>

#figure(fig-decode(),
  caption: [Where a Qwen3-8B decode step goes at 4k context: the sum of isolated kernel launches (10.3 ms; the captured graph runs in 9.6). The large GEMVs dominate; about 400 small reductions and maps add 1.3 ms of mostly fixed launch cost. Dashed: the time to stream the weights and KV cache once at 936 GB/s.],
) <fig-decode>

The same graph builder lowers to Metal. There, prefill and decode programs share one copy of the
weights through buffer binding, prefill can start from a nonzero offset (300 + 200 tokens is
bit-identical to 500), and the next token is chosen on the device by an arg-max monoid, so decoding
reads back 8 bytes per token.

== Edge hardware

On the K1's Adreno 740, a derived matmul reaches 322 GFLOP/s at $1024^3$, which is 21% of the
measured fp32 peak, and a full transformer forward pass plus all seven weight gradients runs in
19.1 ms. Rules tuned for desktop GPUs under-fill the Adreno's six compute units. The best schedule
there (an $8 times 8$ register tile with 8-deep chunks) is 1.45× better than `schedule_auto`'s
choice, which again argues for search over remembered rules. Through `to_c` on one Cortex-X3 core, a
batch-1 GRU policy step (6 contractions plus gate math, fused into one kernel) takes 22.5 µs median
and a locomotion MLP takes 6.7 µs, both within $6 times 10^(-7)$ of f64.

= Verification

Speed claims depend on every kernel being correct. `tang-verify` runs each GPU kernel against its
CPU oracle on the same input, starting from the device's own state. Before each kernel runs, it fills
the kernel's outputs with NaN, so unwritten memory cannot pass as a plausible 0. When a check fails,
it identifies the responsible kernel by provenance: whose correct values ended up in this
buffer. It was built after four structural bugs in a hand-written engine slipped past every unit
test. One was a byte offset added where a float offset was meant, which wrote k's values over q.
Derived kernels are less exposed to that class of bug, because addresses come from affine forms
rather than pointer arithmetic. The IR path also has a structural oracle: the f64 interpreter runs
the identical graph.

= Related work

Halide @ragan2013halide separated algorithm from schedule. TVM @chen2018tvm and Ansor
@zheng2020ansor added learned and searched schedules. Tensor Comprehensions @vasilache2018tc used
polyhedral comprehensions. tang inherits the separation and the search. What it adds is
monoid-valued comprehensions whose combine is an analyzable scalar graph, which turns online softmax
into a rewrite rather than a template, and differentiation inside the IR, so the backward pass is
also derived and scheduled. Triton @tillet2019triton makes hand kernels easier to write; tang tries to
make them unnecessary. FlashAttention @dao2022flash @dao2023flash2 and its backward are hand
derivations of what §3 and §4 produce mechanically. Online softmax itself is due to Milakov and
Gimelshein @milakov2018online. XLA and TorchInductor fuse elementwise chains around library calls.
tang has no library calls to fuse around.

= Limitations

- *Measurement conditions.* Several key runs (the Qwen3 decode and the flash-backward kernels) were
  taken on shared GPUs. We report minima, which bound the code's speed from below, but they are not
  idle-machine numbers.
- *No real cost model.* `schedule_auto` is three measured rules, and the autotuner is the honest
  answer until a cost model exists.
- *Non-affine indexing.* Paged KV caches and MoE routing need a gather view that reads an index
  tensor, and that view blocks some fusion.
- *Scatter gradients* reduce over the whole source coordinate they gate on, so a stride-2 read pays
  2× in the backward pass.
- *Body arithmetic* is f32 on every path. Storage and accumulators honor f16.
- *Distributed placement* exists as a rewrite (sharded reductions joined by an all-reduce expressed
  as a comprehension over the monoid's combine), but transport goes through the host.

= Conclusion

Two primitives, affine views and monoid comprehensions, are enough to express a transformer, its
gradient and its quantized inference. Fusion, flash attention and the flash backward are rewrites
and schedule choices over those primitives, not kernels. Because the schedule is searched per chip,
the same source beats hand kernels on Metal, Vulkan and an embedded Adreno, and passes PyTorch on
a transformer block on CUDA. A hand-written kernel does not disappear in this design. It becomes an
intrinsic: a known-fast implementation of one comprehension shape on one chip, which the compiler
uses when it wins and replaces when it doesn't.

#aside[Reproducibility][
  Every number in this paper comes from `BENCHMARKS.md` in the tang repository (snapshot in `data/`), which records the command, date and machine state for each measurement. The IR is in `crates/tang-compile/src/tensor*.rs`; its design notes are in `docs/tensor-ir.md`.
]

#heading(outlined: true, numbering: none)[References]
#show bibliography: it => { show "?.": "?"; show "!.": "!"; it }
#bibliography("refs.bib", style: "nature", title: none)
