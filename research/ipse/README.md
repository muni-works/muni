# IPSE paper

The paper about IPSE, the K1 brain in `muni-works/ipse`. This draft treats the
goal architecture as the target; the results section claims only what has
been measured, against a pre-registered gate with a control.

Build: `make` (needs `typst`). Output: `ipse.pdf`.

## Working in parallel

Each section is its own file under `sections/`, so lanes can edit without
conflicts. Each experiment has one owner lane and one pre-registration in the
ipse repo; the paper cites the prereg commit and the result PR.

| part | file | state | source of truth |
|---|---|---|---|
| name | `ipse.typ` | Interoceptive Predictive Self-Emergence | ipse `IPSE.md` |
| abstract | `sections/00-abstract.typ` | draft | — |
| intro | `sections/01-intro.typ` | draft | — |
| related work | `sections/02-related.typ` | draft, refs from 2026-11-06 arXiv survey | `refs.bib` |
| architecture | `sections/03-architecture.typ` | draft; bus, step organs, body merged | ipse `docs/architecture.md`, #753–#793 |
| surprise + modulators | `sections/04-surprise.typ` | not built | lane TBD |
| E1 surprise vs detectors | `sections/05-experiments.typ` | not pre-registered | — |
| E2 sleep A/B | `sections/05-experiments.typ` | not pre-registered; needs ~2 weeks of robot days | — |
| E3 inheritance | `sections/05-experiments.typ` | not pre-registered; needs first learned organ | — |
| E0 self-probe | `sections/05-experiments.typ` | not pre-registered; primary claim | ipse `IPSE.md` §3.5 |
| lesion study | `sections/06-lesion.typ` | not started; replay from tapes | — |
| discussion | `sections/07-discussion.typ` | draft | — |

Rule: no number enters the paper without a PR or commit that produced it.
