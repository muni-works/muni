#!/usr/bin/env bash
# The shared rose-arm benchmark (paper §9.7): irys renders vcad's frozen-plan mesh of rose's shoulder
# plate and pulls its image gradient back through the seam. Pinned commits; needs a GPU-less Rust
# toolchain only. Writes ../data/raw/irys.log, which collect.py reads.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${1:-$HERE/work}
IRYS_REV=5e09686360bf58749c9af689215da11f2d0d0e22
ROSE_REV=832192f32a1634ea856e0a8ded40eacd84e9d9e7
mkdir -p "$WORK"
[ -d "$WORK/irys/.git" ] || git clone -q https://github.com/muni-works/irys.git "$WORK/irys"
[ -d "$WORK/rose/.git" ] || GIT_LFS_SKIP_SMUDGE=1 git clone -q https://github.com/muni-works/rose.git "$WORK/rose"
git -C "$WORK/irys" checkout -q --force "$IRYS_REV"
git -C "$WORK/rose" checkout -q --force "$ROSE_REV"
cd "$WORK/irys"
# The render-FD step sweep: the table reports h = 0.1 mm (the last run); the other two bound the
# render FD's own step error.
: > "$HERE/../data/raw/irys.log"
for H in 0.02 0.05 0.1; do
  ROSE="$WORK/rose" LIN=1 N=100000 SEEDS=8 H=$H K=16 \
    cargo run --release -p irys-diff --example rose_brep 2>&1 | tee -a "$HERE/../data/raw/irys.log"
done
