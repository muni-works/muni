#!/usr/bin/env bash
# Regenerate every number in irys.typ from a fresh irys clone, on one machine, in one pass.
#
#   paper/irys/repro/repro.sh [workdir]
#
# 1. clones irys at the pinned commit (its Cargo.lock pins tang and vcad),
# 2. runs the gate tests and examples in the release profile; each one already
#    prints `PAPER<TAB>key<TAB>value` for the quantity it measures and still
#    asserts its own bound,
# 3. collects the values into ../data/measured.tsv (collect.py), merged with
#    ../data/constants.tsv (truths and design facts no code measures).
#
# Needs: git, a Rust toolchain, python3, a GPU (Metal/Vulkan), and for the rose
# rows the rose CAD at $ROSE_REV ($ROSE, default ./work/rose) and the Blender
# demo exports under $IRYS_ASSETS. Takes about an hour; close other GPU work.
set -euo pipefail

IRYS_REPO=${IRYS_REPO:-https://github.com/ecto/irys.git}
IRYS_REV=${IRYS_REV:?set IRYS_REV to the irys commit that carries the PAPER lines}
ROSE_REPO=${ROSE_REPO:-https://github.com/ecto/rose.git}
ROSE_REV=${ROSE_REV:-832192f32a1634ea856e0a8ded40eacd84e9d9e7}
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${1:-$HERE/work}
DATA=$HERE/../data

mkdir -p "$WORK" "$DATA/raw"
[ -d "$WORK/irys/.git" ] || git clone --filter=blob:none "$IRYS_REPO" "$WORK/irys"
git -C "$WORK/irys" fetch -q origin "$IRYS_REV" || true
git -C "$WORK/irys" checkout -q --force "$IRYS_REV"
export ROSE=${ROSE:-$WORK/rose}
[ -d "$ROSE/.git" ] || git clone --filter=blob:none "$ROSE_REPO" "$ROSE"
git -C "$ROSE" checkout -q --force "$ROSE_REV"

{
  echo "irys_rev	$IRYS_REV"
  echo "rose_rev	$ROSE_REV"
  echo "rustc	$(rustc --version)"
  echo "host	$(uname -srm)"
  echo "cpu	$(sysctl -n machdep.cpu.brand_string 2>/dev/null || grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
  echo "gpu	$(system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/Chipset Model/{print $2; exit}' || nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
  echo "date	$(date -u +%Y-%m-%dT%H:%MZ)"
} > "$DATA/raw/env.tsv"

cd "$WORK/irys"
F="--release --locked -p irys-diff --features gpu,assets"
{
  cargo test $F --test phase1 --test phase2a --test phase2b --test phase2c --test phase2d \
    --test phase2e --test phase2f -- --nocapture --test-threads=1
  # timing and study tests are #[ignore]d in CI
  cargo test $F --test phase2e -- edge_term_timing --ignored --nocapture
  cargo test $F --test phase2f -- secondary_estimators_compared --ignored --nocapture
  # throughput: three runs, the paper quotes the range
  for i in 1 2 3; do cargo test $F --test phase2a -- gpu_throughput --nocapture; done
  # the rose fit (one run, as the paper says) and the shared BRep benchmark
  IRYS_SEC_N=4 cargo run $F --example rose_fit -- "$WORK/out/rose_fit" --vis --iters 600
  LIN=1 N=100000 SEEDS=8 H=0.1 K=16 cargo run $F --example rose_brep
} 2>&1 | tee "$DATA/raw/tests.log"

python3 "$HERE/collect.py" "$DATA/raw/tests.log" "$DATA/constants.tsv" "$IRYS_REV" > "$DATA/measured.tsv"
echo "wrote $DATA/measured.tsv ($(wc -l < "$DATA/measured.tsv") values)"
