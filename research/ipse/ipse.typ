// IPSE: a robot brain that learns from its own life.
#let backronym = [Interoceptive Predictive Self-Emergence]

#set document(title: "IPSE: Interoceptive Predictive Self-Emergence", author: "Cam Pedersen")
#set page(paper: "us-letter", margin: (x: 0.7in, y: 0.8in), columns: 2, numbering: "1")
#set text(size: 10pt)
#set par(justify: true)
#set heading(numbering: "1.")
#show heading: set block(above: 1.2em, below: 0.6em)

#place(top + center, float: true, scope: "parent", clearance: 2em)[
  #text(17pt, weight: "bold")[IPSE: Interoceptive Predictive Self-Emergence]
  #v(0.3em)
  #text(11pt)[Measuring Behavior-Invariant Self-Representation in a Developmentally Trained Humanoid]
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
#include "sections/045-ethics.typ"
#include "sections/05-experiments.typ"
#include "sections/06-lesion.typ"
#include "sections/07-discussion.typ"

#bibliography("refs.bib", style: "ieee")
