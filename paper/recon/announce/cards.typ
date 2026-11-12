// Two 1080×1350 (4:5) cards for the Seeing Is Measuring announcement.
// typst compile --root .. --font-path ../fonts --ignore-system-fonts --format png --ppi 150 cards.typ "card-{p}.png"
#let bg = rgb("#0b0907")
#let surface = rgb("#15110d")
#let line-c = rgb("#2a2119")
#let text-c = rgb("#e8e1d2")
#let label = rgb("#a08d70")
#let sel = rgb("#ff5f00")
#let ok = rgb("#39ff14")
#let fault = rgb("#ff2052")
#let warn = rgb("#ffd400")
#let sans = ("IBM Plex Sans",)
#let sans-sb = ("IBM Plex Sans SmBld", "IBM Plex Sans")
#let mono = ("IBM Plex Mono", "IBM Plex Sans")
#let mono-m = ("IBM Plex Mono Medm", "IBM Plex Sans Medm")

#set page(width: 7.2in, height: 9in, margin: (x: 0.55in, top: 0.6in, bottom: 0.5in), fill: bg)
#set text(font: sans, fill: text-c, size: 15pt)
#set par(leading: 0.5em, spacing: 0.5em)
#set block(spacing: 0.5em)

#let caps(body, fill: label, size: 10pt) = text(font: mono-m, size: size, tracking: 0.14em, fill: fill, upper(body))
#let foot = {
  v(1fr)
  line(length: 100%, stroke: 0.6pt + line-c)
  v(0.5em)
  grid(columns: (1fr, auto), align: (left + horizon, right + horizon),
    caps[muni.works/research · seeing is measuring],
    image("../images/muni-logo.svg", height: 0.32in))
}

// ---- card 1: the confident wrong answer -----------------------------------------
#caps[Municipal Robotics · Research]
#v(0.25in)
#text(font: sans-sb, size: 34pt, tracking: -0.02em)[Every error bar\ under 0.11 mm.]
#v(0.05in)
#text(font: sans-sb, size: 34pt, tracking: -0.02em, fill: fault)[Wrong part.]
#v(0.22in)
#block(radius: 6pt, clip: true, image("../images/recon/3000-v0.jpg", width: 100%))
#v(0.22in)
#grid(columns: (auto, 1fr), column-gutter: 0.18in, row-gutter: 0.14in,
  caps[Truth], text(font: mono, size: 12pt)[69.0 × 56.2 plate · *a hole* · a boss],
  caps[Found], text(font: mono, size: 12pt, fill: fault)[66.8 × 55.7 plate · no hole · a boss],
)
#v(0.18in)
#text(size: 14pt, fill: label)[Recovered from one photo. Plate 2.15 mm short, the hole at its far edge missed, a clean residual. Nothing the fit reports says it's wrong.]
#foot

#pagebreak()

// ---- card 2: what catches it ----------------------------------------------------
#caps[Municipal Robotics · Research]
#v(0.25in)
#text(font: sans-sb, size: 30pt, tracking: -0.02em)[How do you know the\ CAD is wrong?]
#v(0.12in)
#text(size: 16pt, fill: label)[Recover again with one more photo. If the features change, don't trust it.]
#v(0.18in)
#let bar(name, k, n, col, note) = {
  grid(columns: (1fr, auto), align: (left + bottom, right + bottom),
    text(size: 13pt)[#name], text(font: mono-m, size: 13pt, fill: col)[#k of #n caught])
  v(0.07in)
  box(width: 100%, height: 0.2in, radius: 3pt, fill: surface, clip: true,
    place(left, box(width: 100% * k / n, height: 0.2in, fill: col)))
  v(0.04in)
  text(size: 11pt, fill: label)[#note]
  v(0.12in)
}
#caps[Wrong answers flagged, held-out parts]
#v(0.14in)
#bar([Residual checks on the same photos], 4, 37, fault, [0 false alarms in 13 right answers])
#bar([Features change with a third photo], 30, 40, ok, [2 false alarms in 23 right answers])
#v(0.02in)
#grid(columns: (1fr, 1fr, 1fr), column-gutter: 0.08in,
  block(radius: 4pt, clip: true, image("../images/recon/4035-b0.jpg", width: 100%)),
  block(radius: 4pt, clip: true, image("../images/recon/4035-b3.jpg", width: 100%)),
  block(radius: 4pt, clip: true, stroke: 2pt + warn, image("../images/recon/4035-b5.jpg", width: 100%)),
)
#v(0.08in)
#grid(columns: (2fr, 1fr), column-gutter: 0.08in,
  align(center, caps[Two photos: plate only]),
  align(center, caps(fill: warn)[\+ third: two bosses]))
#v(0.16in)
#text(size: 14pt)[Part 4035 changed when the third photo arrived, so it's flagged. vcad will take three photos and only call a part trusted when both answers agree.]
#v(0.04in)
#text(size: 11pt, fill: label)[Synthetic photos, 63 held-out parts.]
#foot
