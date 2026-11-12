#import "style.typ": *
// Feature amplitudes: the image is a blend of the program without the feature and with it,
// weighted by a in [0, 1]. Schematic: the plate, the hole and the bars are drawn, not measured.
#let fig-amp() = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  let plate(x, y, hole: 0.0, cb: false) = {
    rect((x, y), (x + 2.2, y + 1.5), stroke: 0.6pt + c-text.transparentize(25%), fill: c-surface, radius: 0.1)
    if hole > 0 {
      if cb { circle((x + 1.35, y + 0.75), radius: 0.36, stroke: 0.5pt + c-info.transparentize(100% - hole * 100%), fill: c-bg.transparentize(100% - hole * 50%)) }
      circle((x + 1.35, y + 0.75), radius: 0.22, stroke: 0.5pt + c-sel.transparentize(100% - hole * 100%), fill: c-bg.transparentize(100% - hole * 100%))
    }
  }
  // the three images
  plate(0.0, 2.6)
  lbl((1.1, 4.4), [$I_0$ #h(0.3em) WITHOUT])
  plate(3.2, 2.6, hole: 1.0)
  lbl((4.3, 4.4), [$I_1$ #h(0.3em) WITH])
  plate(7.0, 2.6, hole: 0.45)
  lbl((8.1, 4.4), [$I_0 + a (I_1 - I_0)$], fill: c-irys)
  content((2.65, 3.35), text(font: mono-m, size: 9pt, fill: c-label)[,])
  line((5.6, 3.35), (6.8, 3.35), stroke: 0.6pt + c-label, mark: (end: ">", size: 0.13, fill: c-label))
  lbl((6.2, 3.6), [BLEND])
  // the amplitude's slider
  line((7.0, 2.2), (9.2, 2.2), stroke: 0.6pt + c-line-hi)
  circle((7.0 + 0.45 * 2.2, 2.2), radius: 0.09, fill: c-irys, stroke: none)
  lbl((7.0, 1.95), [0], anchor: "north")
  lbl((9.2, 1.95), [1], anchor: "north")
  lbl((7.0 + 0.45 * 2.2, 1.95), [$a$], anchor: "north", fill: c-irys)
  // the gradients
  note((0.0, 1.75), width: 6.4cm)[*Amplitude.* $partial I \/ partial a = I_1 - I_0$ is exact and needs two renders and no edge term.]
  note((0.0, 1.05), width: 6.4cm)[*Dimensions.* $partial I \/ partial theta = a thin partial I_1 \/ partial theta$, edge-sampled in the $a = 1$ branch. At $a = 0$ the column vanishes.]
  note((0.0, 0.35), width: 6.4cm)[*Length.* The feature costs $a L$ nats. An anneal $beta thin a (1 - a)$ drives $a$ to 0 or 1, and the fit then emits the ordinary program.]
  note((7.0, 1.2), width: 3.6cm, fill: c-label)[A counterbore at depth 0 is a hole, so the hole lies on the boundary of the counterbore's parameters.]
})
