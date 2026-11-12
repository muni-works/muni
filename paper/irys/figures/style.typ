// Shared tokens for paper/irys's drawn figures (the same values as irys.typ's preamble).
// Each figure lives in its own file, imports this, and exports one `fig-*()` function.
#import "@preview/cetz:0.4.2"
#let c-bg      = rgb("#0b0907")
#let c-surface = rgb("#15110d")
#let c-line    = rgb("#2a2119")
#let c-line-hi = rgb("#4a3a2a")
#let c-text    = rgb("#e8e1d2")
#let c-label   = rgb("#a08d70")
#let c-sel     = rgb("#ff5f00")   // the thing being explained, the active path
#let c-ok      = rgb("#39ff14")
#let c-warn    = rgb("#ffd400")   // tang's colour
#let c-fault   = rgb("#ff2052")   // vcad's colour
#let c-info    = rgb("#00f0ff")   // geometry, rays
#let c-irys    = rgb("#ff2bd6")   // irys's colour
#let sans    = ("IBM Plex Sans",)
#let mono-m  = ("IBM Plex Mono Medm", "IBM Plex Sans Medm")
#let s-xs = 6.5pt
#let s-sm = 7.5pt
// a label in the figures' mono caps
#let lbl(pos, body, anchor: "center", fill: c-label, size: s-xs, font: mono-m) = cetz.draw.content(pos, anchor: anchor, text(font: font, size: size, fill: fill, tracking: 0.04em, body))
// a prose note inside a figure
#let note(pos, body, anchor: "north-west", width: 4cm, fill: c-label) = cetz.draw.content(pos, anchor: anchor, box(width: width, text(font: sans, size: s-xs, fill: fill, body)))
