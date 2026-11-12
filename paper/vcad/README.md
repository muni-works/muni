# Exact Gradients Through a BRep Kernel

Draft preprint on vcad's differentiable seam (`crates/vcad-kernel-diff` and its consumers in
`vcad-kernel-physics::diff` and `vcad-eval::diff`). Published as `/research/vcad`.

    make            # vcad.pdf
    make png        # out/p*.png, one per page
    (cd ../../web && npm run posts -- vcad)   # web post + public/research/vcad.pdf

## Numbers

Every measured value in `vcad.typ` is read from `data/measured.tsv`; a missing key is a build
error. To regenerate it from scratch (on a build machine, ~90 min):

    repro/repro.sh            # clones vcad at the pinned commit into repro/work/

`repro.sh` applies `repro/report.patch` (made by `repro/instrument.py`), which only adds
`eprintln!("PAPER\t<key>\t<value>")` after statements in vcad's gate tests that already compute a
measured quantity, runs those tests, keeps the full log in `data/raw/tests.log`, the machine in
`data/raw/env.tsv`, and collects the values with `repro/collect.py`. Each gate still asserts its
own bound, so a run that writes `measured.tsv` is also a run in which every gate passed.

Design notes the text draws on live in the vcad repo: `docs/differentiable-seam-m0-m2.md` through
`-m11.md` and `docs/differentiable-seam-closeout.md`. The architecture section follows the
vcad/phyz/tang plan (`docs/launch/full-tang.html` in vcad); none of its gates is claimed as a result.

The two disagreements with finite differences an earlier draft reported were seam bugs, fixed in
vcad PR 1080 and described in §9.4. The measured run was made at the PR's head, 7af5dce; main has
it squash-merged as a3ad5ec with an identical tree, which is the commit `repro.sh` pins.
