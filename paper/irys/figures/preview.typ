// Standalone preview of one figure: typst compile --root .. --input fig=<name> figures/preview.typ out.png
#import "style.typ": *
#set page(width: 5.2in, height: auto, margin: 0.2in, fill: c-bg)
#set text(font: sans, fill: c-text, size: 9pt)
#let name = sys.inputs.at("fig", default: "")
#import "replay.typ": fig-replay
#import "determinism.typ": fig-determinism
#import "edge.typ": fig-edge
#import "frames.typ": fig-frames
#import "secondary.typ": fig-secondary
#import "recon.typ": fig-recon
#import "rosefit.typ": fig-rosefit
#let figs = (replay: fig-replay, determinism: fig-determinism, edge: fig-edge, frames: fig-frames, secondary: fig-secondary, recon: fig-recon, rosefit: fig-rosefit)
#figs.at(name)()
