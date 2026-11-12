# Seeing Is Measuring

Preprint on image-to-CAD recovery: three phone photographs and a printed tag in, an editable
CAD program out. Built on irys (`paper/irys`, the companion paper), split out of its former
"Dimensions from photographs" section on 2026-11-10. Same preamble, fonts and provenance pattern as
`paper/irys`, so the two read as siblings.

    make            # recon.pdf
    make png        # out/p*.png

## Numbers

Every measured value in `recon.typ` is read from `data/measured.tsv` with `V()`/`F()`; a missing key
is a build error. Each row is `key  value  source`, naming the irys report and commit. The `recon.*`
rows were moved from `paper/irys/data/measured.tsv`; `recon.fm.*`, `recon.err.*` and the rest were
added from irys `docs/recon-v1-gate100-report.md` @ `812dc62`. Pending results are printed in yellow
as `[TODO: …]` in the PDF; never a number the data does not support.

## Title

"Seeing Is Measuring" (Cam, 2026-11-10; moved here from the irys paper). Subtitle: "Editable CAD
programs from photographs".

## Status

A short note (the long draft is `recon-long.typ`). Every number in the text is measured; there
are no pending results. The claim: on held-out synthetic parts the fit's error bars and residual
checks say little about whether the recovered program is right, and more photographs help
(fresh seeds 4000-4099: 16/100 within 1 mm from one photograph, 41/100 from three).

Not in the note, and the work that would make it a full paper: real printed parts measured with
calipers, a baseline method, the presence-and-choice amplitude parameterisation, and error bars
that rank errors.

## What the paper needs, in order

1. ~~**Amplitude finals on held-out parts.**~~ Done 2026-11-10 on the 80 held-out synth3 parts: worse than greedy (topology 37 vs 44 of 80, fixed 0, broke 7; `ampg.*`). Cause: per-amplitude anneal deletes features whose alternatives split the evidence. Next: presence p and choice q annealed separately, a proper parameter cost, rerun on fresh seeds 4000..4099 (rendered on mew, `assets/fresh3`). Original plan: Wire `amp::fit` into `search::recover`'s final
   stage (relax each finalist's optional features, seeded from the search's proposals). Render a
   new set (seeds 4000..4099, never looked at), run greedy and amplitude finals on the same photos,
   3 seeds each. Reports: <= 1 mm, topology, hole/counterbore confusions, paired (McNemar). About
   100 parts x 2 methods x 3 seeds x ~10 CPU-min = ~100 core-hours on mew. This decides whether
   the amplitude section is a contribution or a note.
2. **Run-to-run variance of the greedy search.** Part 3016 gave two answers on two machines. Rerun
   the existing 100 parts 3 times on one machine and report agreement. Falls out of item 1.
3. **Baselines** on the same photos: (a) BIC instead of the Laplace term; (b) silhouette-only fit
   (no shading term); (c) a trivial one (the grammar's mean part, or the bounding box from the tag);
   (d) one external method, e.g. multi-view stereo + primitive fitting, or a learned image-to-CAD
   model. (a)-(c) are flags on the existing code.
4. **Error bars that rank errors.** Fisher sigma has Spearman -0.15 with the error. Try: a bias
   term per parameter class from the appearance residual; sigma from refits across the three
   leave-one-photo-out fits; or seed-to-seed spread. Gate: rho > 0.3 on held-out parts. Also
   recalibrate the 1/2 log det F term in the score (currently off by ~ln 17.8 nats per parameter).
5. **Real photographs.** Print 20+ parts (kit: `~/Developer/irys-assets/recon-m2-kit`, five so
   far), three phone photos each, calipers. Until then the title claims more than the paper shows.
6. **Ablations on held-out parts**, not the 20 development parts: noise-correlation scaling, beam
   width, program prior, AO gradient, path-traced final fit.
7. **Known defects to trace:** plate height 0.18 mm low in 91% of parts; tag not found in 4 of 100
   clean synthetic photos; slot length (p90 2.5 mm).
8. **Grammar for real objects** (section 7): shell with per-edge radii, features on any face,
   recesses, patterns as one feature, estimated masks.
9. **Structure, Cam's call:** the reviewer read section 3 (the arm fit) as unrelated to the rest,
   and Fig 3 as padding.
