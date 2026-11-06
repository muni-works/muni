// IPSE paper: 2-column academic layout, matching paper/whitepaper.typ.
#import "../../paper/lib/template.typ": (
  muni-orange, muni-gray, muni-light-gray,
  muni-font, muni-font-mono, muni-font-fallback, muni-font-mono-fallback,
)

#let title-short = "IPSE: Interoceptive Predictive Self-Emergence"
#let mono = (muni-font-mono, ..muni-font-mono-fallback)

#set document(title: title-short, author: "Cam Pedersen")

#set page(
  paper: "us-letter",
  margin: (x: 0.5in, top: 0.7in, bottom: 0.7in),
  columns: 2,
  numbering: "1",
  number-align: center,
  header: context {
    if counter(page).get().first() > 1 [
      #set text(font: mono, size: 9pt, fill: muni-gray)
      #title-short
      #h(1fr)
      Municipal Robotics
    ]
  },
  footer: context {
    if counter(page).get().first() > 1 [
      #set text(font: mono, size: 8pt, fill: muni-gray)
      Draft, November 2026
      #h(1fr)
      #counter(page).display()
      #h(1fr)
      Research
    ]
  },
)

#set text(font: (muni-font, ..muni-font-fallback), size: 9pt)
#set par(justify: false, leading: 0.9em, spacing: 1.5em)
#set heading(numbering: "1.1")
#show heading.where(level: 1): it => { v(1.5em); text(size: 16pt, weight: "bold", it); v(0.5em) }
#show heading.where(level: 2): it => { v(0.8em); text(size: 12pt, weight: "bold", it); v(0.3em) }
#show raw: set text(font: mono, size: 8pt)
#show table: set text(font: mono, size: 8pt)
#set figure(placement: top, scope: "parent", gap: 1em)
#show figure: set block(below: 2em)
#show figure.caption: it => {
  text(font: mono, size: 8pt, fill: muni-gray)[
    #text(weight: "bold")[#it.supplement #it.counter.display():]
    #it.body
  ]
}

// Title page
#page(columns: 1)[
  #v(8em)
  #align(center)[
    #text(size: 24pt, weight: "bold")[IPSE]
    #v(0.1em)
    #text(size: 16pt)[Interoceptive Predictive Self-Emergence]
    #v(0.4em)
    #text(size: 12pt)[
      Measuring Behavior-Invariant Self-Representation \
      in a Developmentally Trained Humanoid
    ]
    #v(0.6em)
    #text(font: mono, size: 11pt, fill: muni-gray)[Research draft, November 2026]
    #v(0.6em)
    #text(size: 12pt)[
      *Cam Pedersen* \
      Municipal Robotics · Cleveland, Ohio
    ]
    #v(2em)
    #text(size: 11pt, style: "italic", fill: muni-gray)[_ipse_ — Latin, "itself"]
  ]
]

// Abstract
#page(columns: 1)[
  #heading(outlined: false, numbering: none)[Abstract]
  #include "sections/00-abstract.typ"
]

// Contents
#page(columns: 1)[
  #outline(title: [Contents], indent: 1.5em, depth: 2)
]

#include "sections/01-intro.typ"
#include "sections/02-related.typ"
#include "sections/03-architecture.typ"
#include "sections/04-surprise.typ"
#include "sections/05-experiments.typ"
#include "sections/06-lesion.typ"
#include "sections/045-ethics.typ"
#include "sections/07-discussion.typ"

#bibliography("refs.bib", style: "ieee")
