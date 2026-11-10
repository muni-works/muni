# Seeing Is Measuring

Draft preprint on image-to-CAD recovery: three phone photographs and a printed tag in, an editable
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
programs from photographs: a feature must pay for itself".

## Status

Done in the draft: method, the development set and 124-part held-out gate (moved from irys), failure
modes and per-feature error, calibrated σ′, the feature-amplitude relaxation (section 4) and its
implementation (irys `crates/irys-recon/src/amp.rs`, branch `claude/recon-amplitudes`).

TODO (marked in the text):

- ~~Amplitude experiments (a)–(c)~~ done (data/amp-*.json, amp.* rows).
- **Gate with amplitude finals.** Rerun the 100-part in-grammar gate with the finalists' optional
  features relaxed, against greedy MDL. Needs wiring `amp::fit` into `search::recover`'s final stage.
- **M2, real photographs.** Print five gate parts (kit in `~/Developer/irys-assets/recon-m2-kit`),
  three phone photos each, calipers. Replaces the "synthetic photographs" limit.
- **Real-object grammar** (section 6): shell with per-edge radii, features on any face, recesses,
  patterns as one feature, estimated masks. The cover object (`images/enclosure.jpg`, Cam's
  IMG_0905) is the motivating example.
- Abstract and conclusion sentences on the amplitude results.
- Plate-height bias (0.18 mm low) is untraced.
