# Seeing Is Measuring

Draft preprint on irys's differentiable renderer (`crates/irys-diff` in ecto/irys): PRB on a GPU
wavefront with tang-compiled BSDFs, bit-exact replay, pose gradients through instanced CAD, and the
rose-arm benchmark shared with `paper/vcad` ("Exact Gradients Through a BRep Kernel", muni#40).
Published as `/research/irys`.

    make            # irys.pdf
    make png        # out/p*.png

## Numbers

Every measured value in `irys.typ` is read from `data/measured.tsv`; a missing key is a build error.
Each row is `key  value  source`, where the source names the irys `docs/design.md` line, the commit
that introduced it and the test or example that measures it. `data/env.tsv` pins irys, vcad and rose.

## Blind review (2026-11-07) and where each point stands

Verdict: reject. Fixed in the text: Fig 7 rebuilt from data with every configuration named; a
recovery-examples figure (photos, overlays, a failure); related work on inverse CAD, program
synthesis, Mitsuba 3 and photogrammetry (all checked); jargon defined or removed; the photo-model
split stated; Wilson intervals on the recovery table; Fig 1 cut. In other sessions: recovery fit
through the path tracer; 100+ parts with out-of-grammar ones, error CDFs and calibrated σ; a Mitsuba 3
baseline; the device edge-sampler bias. Still to do: real photographs (M2), and a separate
anonymised acmart build for a venue.

## Open items before submission

The title is a promise; these make it true (Cam, 2026-11-07: "fix the details, aiming for greatness"):

- ~~**M1, synthetic gate to 15/20 at 1 mm.**~~ Done 2026-11-07: 15/20 at 1 mm, 16/20 topology with the
  differentiated AO and no FD columns (irys `de62b0a`, `recon.3a.*`).
- **M2, real photographs.** Print five gate parts, photograph each three times beside the tag with a
  phone, recover, and measure with calipers. The caliper table becomes the paper's centre figure, and
  the "Photographs are synthetic" limit comes out of the scope section.
- **Honest uncertainties.** The Fisher σ are optimistic (design log); calibrate them against the gate's
  actual errors and report coverage.

- **Regenerate every row in one pass on one recorded machine:** `IRYS_REV=<rev> repro/repro.sh`
  (clones irys and rose at pinned commits, runs every gate test and the two rose examples in release,
  and `repro/collect.py` merges their `PAPER` lines with `data/constants.tsv`). Not run yet. Today's rows were measured on different days at different commits, on an
  M-series Mac whose chip was not recorded. Timings quoted are release builds only; debug-build
  numbers from the design log were left out on purpose.
- **Bibliography.** Checked against publisher and author pages on 2026-11-07. Replace
  `pedersen2026vcad` with its arXiv id.
- **One-run results.** The rose fit (Fig 2) is a single run; convergence over seeds and starts is not
  measured. The 2f secondary term passes its rose check at 64 seeds and misses at 256.
- **irys brand colour** (`#b48cff` in `fam-color`) is a placeholder; take it from the landing page.
- The rose-arm fit and the BRep benchmark need the rose CAD (rose `832192f`); irys `103e3da` must stay
  reachable (merge without squash).
