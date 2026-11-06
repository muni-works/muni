// IPSE: a robot brain that learns from its own life.
// Backronym is open. Candidates (Cam to pick):
//   Innate, Predictive, Sleeping, Embodied
//   Inherited Predictive Somatic Engine
//   Integrated Predictive Sensorimotor Ecology
#let backronym = [*I*\u{200B}nnate, *P*\u{200B}redictive, *S*\u{200B}leeping, *E*\u{200B}mbodied]

#set document(title: "IPSE: A Robot Brain That Learns From Its Own Life", author: "Cam Pedersen")
#set page(paper: "us-letter", margin: (x: 0.7in, y: 0.8in), columns: 2, numbering: "1")
#set text(size: 10pt)
#set par(justify: true)
#set heading(numbering: "1.")
#show heading: set block(above: 1.2em, below: 0.6em)

#place(top + center, float: true, scope: "parent", clearance: 2em)[
  #text(17pt, weight: "bold")[IPSE: A Robot Brain That Learns From Its Own Life]
  #v(0.3em)
  #text(11pt)[#backronym]
  #v(0.6em)
  Cam Pedersen · Muni Works
  #v(0.3em)
  #text(9pt, fill: gray)[DRAFT — goal architecture; results marked TBD are not measured]
]

#include "sections/00-abstract.typ"
#include "sections/01-intro.typ"
#include "sections/02-related.typ"
#include "sections/03-architecture.typ"
#include "sections/04-surprise.typ"
#include "sections/05-experiments.typ"
#include "sections/06-lesion.typ"
#include "sections/07-discussion.typ"

#bibliography("refs.bib", style: "ieee")
