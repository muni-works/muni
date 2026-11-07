#!/usr/bin/env bash
# Regenerate every table and figure in vcad.typ from a fresh vcad clone.
#
#   paper/vcad/repro/repro.sh [workdir]
#
# 1. clones vcad at the pinned commit (its Cargo.lock pins phyz, loon and tang),
# 2. applies report.patch, which only adds `PAPER<TAB>key<TAB>value` eprintln!s
#    to the gate tests (see instrument.py), so each gate still asserts its bound,
# 3. runs the gate tests (release profile, one thread so timings don't contend),
# 4. collects the printed values into ../data/measured.tsv (collect.py),
#    which vcad.typ reads for every number in its tables and figures.
#
# Needs: git, a Rust toolchain (rustup picks vcad's rust-toolchain if present), python3.
# Takes ~30 min on a 24-core box; run it on a build machine, not a laptop.
set -euo pipefail

VCAD_REPO=${VCAD_REPO:-https://github.com/ecto/vcad.git}
VCAD_REV=${VCAD_REV:-d10f279d9693d307c7faa7289ec6490b12f0bd77}
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${1:-$HERE/work}
DATA=$HERE/../data

mkdir -p "$WORK" "$DATA/raw"
if [ ! -d "$WORK/vcad/.git" ]; then
  git clone --filter=blob:none "$VCAD_REPO" "$WORK/vcad"
fi
cd "$WORK/vcad"
git fetch -q origin "$VCAD_REV" || true
git checkout -q --force "$VCAD_REV"
git apply "$HERE/report.patch"

{
  echo "vcad_rev	$VCAD_REV"
  echo "rustc	$(rustc --version)"
  echo "host	$(uname -srm)"
  echo "cpu	$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || sysctl -n machdep.cpu.brand_string)"
  echo "date	$(date -u +%Y-%m-%dT%H:%MZ)"
} > "$DATA/raw/env.tsv"

run() { # crate, test targets...
  local crate=$1; shift
  local args=()
  for t in "$@"; do args+=(--test "$t"); done
  cargo test --release --locked -p "$crate" "${args[@]}" -- --nocapture --test-threads=1
}

{
  run vcad-kernel-diff m0_extrude_volume m1_frozen_lift m2_boolean_hole m3_boundary_trim \
    m3_mass_properties m4_fillet_radius m5_reverse_mode \
    m6_synthesized_seeding m7_cone_torus m9_many_parameters m10_second_order m10_perf
  run vcad-kernel-physics m8_rollout_gradient m8_spinup_demo m8_anchor_channel m8_surface_skin \
    m11_adjoint_rollout m11_contact_gradient
  run vcad-eval document_gradient
  # the flywheel L-BFGS run is #[ignore]d in vcad's CI for runtime (~13 min); run it here
  cargo test --release --locked -p vcad-kernel-diff --test m3_flywheel_optimize -- --ignored --nocapture --test-threads=1
} 2>&1 | tee "$DATA/raw/tests.log"

git -C "$WORK/vcad" checkout -q -- .
python3 "$HERE/collect.py" "$DATA/raw/tests.log" > "$DATA/measured.tsv"
echo "wrote $DATA/measured.tsv ($(wc -l < "$DATA/measured.tsv") values)"
