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

// ---- card 1: what we built --------------------------------------------------------
#caps[Municipal Robotics · Research]
#v(0.25in)
#text(font: sans-sb, size: 40pt, tracking: -0.025em)[Photos in.]
#v(0.02in)
#text(font: sans-sb, size: 40pt, tracking: -0.025em, fill: sel)[Editable CAD out.]
#v(0.2in)
#grid(columns: (1fr, 1fr, 1fr), column-gutter: 0.08in,
  block(radius: 4pt, clip: true, image("../images/recon/4035-b0.jpg", width: 100%)),
  block(radius: 4pt, clip: true, image("../images/recon/4035-b3.jpg", width: 100%)),
  block(radius: 4pt, clip: true, image("../images/recon/4035-b5.jpg", width: 100%)),
)
#v(0.12in)
#align(center, text(font: mono-m, size: 18pt, fill: label)[↓])
#v(0.08in)
#block(width: 100%, inset: 0.2in, radius: 6pt, fill: surface, stroke: 0.6pt + line-c, {
  set text(font: mono, size: 14pt)
  set par(leading: 0.7em)
  text(fill: label)[\# part 4035, recovered]
  linebreak()
  [base #text(fill: sel)[59.61 49.73 14.33]]
  linebreak()
  [boss #text(fill: sel)[18.95 −14.88 5.20 11.93]]
  linebreak()
  [boss #text(fill: sel)[0.22 −5.82 6.28 3.58]]
})
#v(0.16in)
#grid(columns: (1fr, 1fr), column-gutter: 0.2in,
  [#text(font: sans-sb, size: 24pt, fill: ok)[0.13 mm] \ #text(size: 12pt, fill: label)[worst error, every dimension]],
  [#text(font: sans-sb, size: 24pt)[3 photos] \ #text(size: 12pt, fill: label)[and a printed tag. No scanner.]],
)
#v(0.12in)
#text(size: 13pt, fill: label)[A program you can edit, not a mesh. Every candidate rendered and fitted through irys, our differentiable renderer. Synthetic test photos.]
#foot

#pagebreak()

// ---- card 2: what catches it ----------------------------------------------------
#caps[Municipal Robotics · Research]
#v(0.25in)
#text(font: sans-sb, size: 30pt, tracking: -0.02em)[And it knows when\ it's wrong.]
#v(0.12in)
#text(size: 16pt, fill: label)[Error bars can't tell you. A second look can: recover with one more photo, and if the features change, flag it.]
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
#text(size: 14pt)[Two photos missed both bosses. The third caught it, so the check flagged the first answer. Coming to vcad: three photos, and a part is trusted only when the answers agree.]
#v(0.04in)
#text(size: 11pt, fill: label)[Synthetic photos, 63 held-out parts.]
#foot
