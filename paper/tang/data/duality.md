# The bound and the tile are one LP

The claim being tested: the fastest kernel and the proof that it is
fastest are the dual and primal solutions of one linear program, read off
the comprehension's views, and the duality gap is the distance from
optimal. This note says what tang now computes, what it found, and where
the claim does not hold. Code: `crates/tang-compile/src/tensor_io_lp.rs`.
Experiment: `cargo run --release -p tang-bench --example io_dual`
(`TUNE=1` adds the GPU autotuner's pick on the local device). Lean:
`proofs/TangProofs/Duality.lean`, `Trace*.lean`.

## Corrections after the paper review (read this first)

This section overrides the rounds below where they disagree. Rounds 2–4 are
kept as history. Their machine constants (600 ns H200 latency, 1–2 µs launch
taken from the traces, `reg_words = 4096`) are superseded.

### Which numbers are right

Commands, from the repo root:

```bash
python3 scripts/ncu/floor_table.py
```

```bash
cargo run --release -p tang-bench --example io_dual
```

| claim in the paper | verdict | right number |
|---|---|---|
| Q8 GEMV "63.5 µs measured" | **not one kernel** | `dop00_gemv_q8_0` in `ops_t1` is the mean of three shapes launched under one name, grouped by name in #186's table. See the shapes below. |
| Q8 GEMV "58.7 µs / 0.92" (round 4) | **withdraw** | Computed from that mean, with a hypothesized L1 term. |
| Q8 GEMV "26.5 µs / 0.42" (round 3) | **superseded** | Same mean, older constants. |
| "0.92" in `fraction-of-light.md` | different quantity | The vocab head's 3090 throughput as a fraction of peak (864 / 936 GB/s), not predicted/measured. |
| attention traffic "2–2.8×" | **should be 2.0–3.0×** | `schedule_auto` / single-level dual tile: 3090 2.83× (N=1024), 2.95× (N=4096); M4 1.97×, 1.99×. |
| reviewer's 1.76× | a different ratio | Single-level dual / two-level dual on the 3090 at N=4096 (1460 / 830 MB). |
| reviewer's 2.0× | correct for the M4 | |

Q8_0 GEMV by shape, H200 (#186 raw trace, `ops_t1`). The floor is defined below:

| shape | MB | measured µs | floor µs | floor/meas | with L1 hypothesis |
|---|--:|--:|--:|--:|--:|
| 4096×2048 | 8.9 | 7.4 | 2.5 | 0.34 | 5.1 µs, 0.69 |
| 2048×4096 | 8.9 | 9.9 | 2.5 | 0.25 | 5.1 µs, 0.51 |
| 151936×2048 (vocab head) | 330.6 | 172.2 | 69.7 | 0.40 | 158.9 µs, 0.92 |

The mean of those measured times is the 63.5 µs. The 0.92 survives only for
the vocab head, where a single constant (the assumed L1 rate) is compared
with one asymptote.

### The L1 wavefront term is a hypothesis, not a floor

Round 4 called it "derived, not fitted" and "sound". That overclaimed:
* The rate (one line per SM-cycle) is assumed; no counter validates it.
* Counting every request gave 77 µs on the mean-of-shapes row, above the
  measured 63.5. I then counted only the weight requests. That choice was
  made after seeing the overshoot. It is a fork in the analysis.
* The integer counts read from the source are about 5× low. Replace's
  `sm__inst_executed` (#194, `3090-inst/`) gives 0.148 warp instructions per
  DRAM byte on this GEMV; my source count is 0.029.
* Plain instruction issue cannot be the limit. Those measured counts give
  32 µs of issue time on the 3090 (of 145 µs) and 17 µs on the H200 (of
  63.5 µs) at 4 instructions per SM-cycle. `ex_gate_up` T=1: 1.1 µs of 10.7.

`IssueCost` is now off unless a caller sets it, and is not in the table's
floor column. What remains unexplained: the H200 big kernels run at 0.30–0.64
of the floor, and this repo has no validated term for that gap.

### The floor as implemented

```text
T = L + max( λ + B/BW,  F/P,  ⌈G/S⌉·λ )
S = SMs · min(threads_per_SM / block, regs_per_SM / (regs · block), hw limit)
```

`StepKernel::floor`, with `L` launch, `λ` DRAM latency, `B` bytes, `F/P` flops
over peak, `G` workgroups. The Little's-law term
`B·λ / (resident threads · bytes per thread)` lives only in `TimeFloor`; it is
not in this formula, and it never bound with bytes per thread counted from the
schedule (round 2). The paper's formula should be this one.

Justifying `⌈G/S⌉·λ`: if every workgroup makes at least one DRAM round trip,
each occupies a slot for at least `λ`. A slot then hosts at most `⌊T/λ⌋`
workgroups, so `S·⌊T/λ⌋ ≥ G`, which gives `T ≥ ⌈G/S⌉·λ`. It is a makespan
bound for unit jobs on `S` machines. It needs `S` to be an upper bound on
resident workgroups; smem limits are left out, so `S` can only be too large.
**The term binds on none of the kernels in the table**, so it is justified but
carries no weight in the validation. `flops` is 0 in the table (not populated).

Adding `L` to the rest assumes the empty-kernel overhead does not overlap the
kernel's memory activity. That is an assumption.

**Constants:**

| | λ | L | status |
|---|---|---|---|
| 3090 | 470 ns | 0.77 µs | λ assumed. L is an empty kernel in a CUDA graph, measured in #160 on a shared GPU, independent of the traces. |
| H200 | 340 ns | 0.48 µs | Both measured on an idle H200 (#196, `scripts/review/latency.cu`), independently of the traces. λ is a one-thread pointer chase over 4 GB (672 cycles, TLB misses included). L is an empty kernel in a 2000-node CUDA graph, 1 block; it is 0.54 µs at 132 blocks and 0.78 µs at 528. The published H100 figure was 353 ns. |
| H200, kernel ≤ 50 MB | 145 ns | 0.48 µs | Measured L2 hop over 1 MB (#196). |

The H200 has no byte counters on the pods, so `B` is the 3090's ncu count.
A kernel that fits the 50 MB L2 can be served from it, so for those `B/BW` is
**not a proven floor on the H200** (column "H200 L2?"). #189's repack reached
1.02 of peak that way.

### Per-kernel floor table (every kernel ≥ 0.5 MB with bytes on both GPUs)

| kernel | MB | G×block | H200 L2? | 3090 meas µs | floor µs (term) | floor/meas | H200 meas µs | floor µs (term) | floor/meas | L1? µs | L1?/meas |
|---|--:|---|---|--:|--:|--:|--:|--:|--:|--:|--:|
| moe_t1 dop02_ex_gate_up | 14.7 | 320×256 | yes | 22.1 | 16.9 (stream) | 0.77 | 10.7 | 3.7 (stream) | 0.34 |  |  |
| moe_t1 dop03_ex_down | 9.3 | 160×256 | yes | 14.7 | 11.2 (stream) | 0.76 | 5.4 | 2.6 (stream) | 0.48 |  |  |
| moe_t1 dop05_sh_down | 1.3 | 32×256 | yes | 5.5 | 2.7 (stream) | 0.48 | 3.5 | 0.9 (stream) | 0.26 |  |  |
| moe_t1 dop04_sh_gate_up | 2.6 | 64×256 | yes | 5.8 | 4.1 (stream) | 0.70 | 3.1 | 1.2 (stream) | 0.38 |  |  |
| moe_t8 dop02_ex_gate_up | 100.7 | 2560×256 | no | 122.0 | 108.8 (stream) | 0.89 | 59.4 | 21.8 (stream) | 0.37 |  |  |
| moe_t8 dop04_ex_down | 70.4 | 1280×256 | no | 92.6 | 76.4 (stream) | 0.83 | 23.6 | 15.5 (stream) | 0.66 |  |  |
| moe_t8 dop05_sh_gate | 1.3 | 32×256 | yes | 13.3 | 2.7 (stream) | 0.20 | 12.3 | 0.9 (stream) | 0.07 |  |  |
| moe_t8 dop06_sh_up | 1.5 | 32×256 | yes | 13.4 | 2.9 (stream) | 0.22 | 11.8 | 0.9 (stream) | 0.08 |  |  |
| moe_t8 dop08_sh_down | 1.4 | 32×256 | yes | 11.0 | 2.7 (stream) | 0.25 | 8.5 | 0.9 (stream) | 0.11 |  |  |
| moe_t8 dop09_y | 0.8 | 64×256 | yes | 3.8 | 2.1 (stream) | 0.56 | 2.5 | 0.8 (stream) | 0.32 |  |  |
| moe_t48 dop08_ex_gate_up | 417.4 | 7680×256 | no | 506.3 | 447.2 (stream) | 0.88 | 182.4 | 87.8 (stream) | 0.48 |  |  |
| moe_t48 dop10_ex_down | 228.2 | 15360×256 | no | 273.4 | 245.0 (stream) | 0.90 | 124.5 | 48.4 (stream) | 0.39 |  |  |
| moe_t48 dop11_sh_gate | 1.6 | 48×256 | yes | 11.8 | 2.9 (stream) | 0.25 | 19.1 | 1.0 (stream) | 0.05 |  |  |
| moe_t48 dop12_sh_up | 1.5 | 48×256 | yes | 11.7 | 2.8 (stream) | 0.24 | 17.2 | 0.9 (stream) | 0.05 |  |  |
| moe_t48 dop14_sh_down | 1.7 | 192×256 | yes | 9.6 | 3.0 (stream) | 0.31 | 6.5 | 1.0 (stream) | 0.15 |  |  |
| moe_t48 dop15_y | 5.5 | 384×256 | yes | 9.4 | 7.1 (stream) | 0.76 | 4.0 | 1.8 (stream) | 0.44 |  |  |
| moe_t48 dop09_ex_silu | 2.6 | 960×256 | yes | 5.7 | 4.1 (stream) | 0.71 | 2.8 | 1.2 (stream) | 0.42 |  |  |
| moe_t48 dop03_xq | 0.6 | 384×256 | yes | 2.9 | 1.8 (stream) | 0.63 | 2.0 | 0.7 (fill) | 0.38 |  |  |
| moe_t48 dop18_norm | 0.6 | 384×256 | yes | 3.1 | 1.9 (stream) | 0.62 | 1.9 | 0.8 (fill) | 0.41 |  |  |
| moe_t48 dop16_resid | 0.9 | 384×256 | yes | 3.2 | 2.2 (stream) | 0.70 | 1.6 | 0.8 (stream) | 0.50 |  |  |
| moe_t48 dop19_xq_out | 0.5 | 384×256 | yes | 3.0 | 1.8 (stream) | 0.61 | 1.5 | 0.7 (fill) | 0.48 |  |  |
| ops_t1 q8_0 4096x2048 | 8.9 | 256×256 | yes | 18.0 | 10.8 (stream) | 0.60 | 7.4 | 2.5 (stream) | 0.34 | 5.1 | 0.69 |
| ops_t1 q8_0 2048x4096 | 8.9 | 256×256 | yes | – | 10.8 (stream) | – | 9.9 | 2.5 (stream) | 0.25 | 5.1 | 0.51 |
| ops_t1 q8_0 151936x2048 | 330.6 | 9496×256 | no | 382.7 | 354.5 (stream) | 0.93 | 172.2 | 69.7 (stream) | 0.40 | 158.9 | 0.92 |

3090: 23 kernels, floor/meas min 0.20 median 0.63 max 0.93; over 1: []
h200: 24 kernels, floor/meas min 0.05 median 0.38 max 0.66; over 1: []

**Result.** No kernel exceeds its floor on either GPU. On the 3090 the big
kernels are tight (0.76–0.93). On the H200 the floor is loose everywhere
(0.05–0.66, median 0.38). The term is always `stream` or `fill`. The kernels
are all GEMV-class or small epilogues, so this validates nothing about
attention or scans.

### The two-level match was partly by construction

`reg_words = 4096` was the schedule space's largest register tile. The sweep
in `io_dual` shows how narrow that is. Matmul 4096³ and attention N=4096 on
the M4 (`[rows × columns, keys]`):

| register words | matmul tile, MB | attention tile, MB |
|---|---|---|
| 2048 | 64×32, 12952 | 64×32, 32; 1636 |
| **4096** | **64×64, 8657** | **64×64, 32; 1091** |
| 8192 | 128×64, 6510 | 128×32, 32; 830 |
| 16384 | 128×128, 4362 | 128×64, 64; 554 |
| 52000 (register file, see below) | 256×128, 3288 | 512×32, 64; 226 |

* The match holds only for capacities in [4096, 8192). With the actual
  register file the model predicts tiles far larger than the autotuner picks.
* The autotuner cannot choose those. Its space stops at 4×4 registers × 256
  threads, and at key chunks of 16 or 32. Both M4 picks (64×64 matmul, chunk
  32 attention) sit at that boundary. So the honest statement is: *inside
  the schedule space the two-level model picks the corner the autotuner
  picks*. It does not show that the register file sets the tile.
* The model charges nothing for lost occupancy from a large register tile,
  which is likely why real hardware wouldn't want the file-sized tile. That
  is untested.
* The M4 register file: about 208 KB per core is published for Apple 7/8
  (`philipturner/metal-benchmarks`); M4 is a later GPU, so it is a proxy. The
  3090's 65536 words is 256 KB per SM.

**`schedule_auto` and the autotuner are different things.** `schedule_auto` is
a static heuristic: 64×64 matmul and 16×16 attention on every device. The
autotuner is the timed search (`TUNE=…`). Only the M4 has autotuner picks:
matmul 64×64 at 4096³ (32×64 at 1024³), attention 64×32 at N=4096 (16×16 at
N=1024).

**3090 attention: the autotuner keeps 16×16, against every model.**
Replace ran this on an idle rented 3090 (#196). There was no Vulkan
driver, so it used CUDA lowerings, not wgpu.

| | N=1024 | N=4096 |
|---|---|---|
| autotuner pick | 16 rows × 16 keys, 24.5× bound | 16×16, 24.1× bound |
| `schedule_auto` | 16×16 | 16×16 |
| single-level dual | 48 × 48 | 48 × 48 |
| two-level dual (schedule limit) | 128 × 32, value columns split | same |
| matmul 1024³ | autotuner 64×64 (= `schedule_auto`, 1.95× bound) | |

**What the measurement says about the model:**
* **No model predicts what wins on the 3090.** The timed search picks the
  smallest tile in its space, moving 2.8–3.0× the dual tile's traffic. The
  model ranks by traffic; the 3090 kernel at that tile is not traffic-bound,
  so less traffic doesn't buy time.
* **Model and autotuner disagree across devices.** The M4 picked 64×32 at
  N=4096. So whatever makes the M4 pick agree with the model doesn't carry to
  the 3090's CUDA lowering.
* **Next run:** per-tile times on the 3090. `RACE=1` in `io_dual` times every
  candidate and prints the best time per LP tile:
  `RACE=1 TUNE=3090 cargo run --release -p tang-bench --features cuda --example io_dual`.

### M4 per-tile race (every autotuner candidate timed, `RACE=1 TUNE=1 cargo run --release -p tang-bench --example io_dual`)

| kernel | best on hardware | two-level / dual tile | schedule_auto | autotuner | spread of top 5 |
|---|---|---|---|---|---|
| matmul 1024³ | 64×64×16, 0.551 ms | 64×64 (two-level) 0.551–0.559 ms | 64×64×32, 0.559 ms | 32×64×16, 0.554 ms | 1.4%, traffic 138–206 MB |
| matmul 4096³ | 64×64×32, 29.59 ms | 64×64 (two-level) | same | same | 3.5% |
| attention N=1024 | key chunk 16, 16×64, 3.86 ms | dual 32×64: 4.77 ms (+23%) | same as best | same as best | — |
| attention N=4096 | 64×64, 51.5 ms | dual 32×64: 57.2 ms (+11%) | 16×64: 54.8 ms (+6%) | 64×64 (= best) | — |

- Matmul time is flat across traffic: the top 5 tiles span 1.5× in LP traffic but ≤3.5% in time. The traffic objective does not rank these tiles.
- Attention: the one-level dual tile loses on both sizes. At N=1024 the lowest-traffic tile (64×64, 71 MB) is 29% slower than the 273 MB winner. Traffic is not what decides attention on the M4 either.
- matmul 4096³ lists a split-K=256 subgroup candidate at 0.098 ms; that is faster than peak FLOPs allow, so the kernel is wrong (not checked for correctness in RACE mode) and is excluded.
- 3090 per-tile race not run yet (needs an idle 3090: `RACE=1 TUNE=3090 cargo run --release -p tang-bench --features cuda --example io_dual`).

### What else does not hold up

* Rounds 3–4's step floors and lever bounds use the mean bytes-per-thread
  spreading and the old constants. Round 4's fusion "−25 to −38% of wall"
  used a 6.9 µs τ; Replace's #194 removed 96 of 548 launches and the step got
  *slower* (4.05 → 4.44 ms). Those bounds are upper bounds only and should
  not be cited as predictions.
* Round 2's "class flip at 16 B per thread" was a fit, as it said.

### Lean: exactly what is mechanized

`proofs/` is on main; `lake build` passes (9055 jobs) with no `sorry` and no
axioms beyond Lean's and Mathlib's. Everything is over ℝ or an abstract monoid,
not floating point, and nothing connects these definitions to the Rust IR
automatically (except the exported `stabilize_softmax` trace).

| topic | theorem | statement |
|---|---|---|
| view composition | `Form.eval_compose`, `View.read_compose` | Composing affine views (any integer coefficients and offsets) reads the same element as reading through both. |
| fusion | `substitute_map_sound`, `substitute_map_sound₂` | Splicing a map into a commutative-monoid comprehension through composed views preserves its value. |
| split / tiled reductions | `split_reduction` | Folding a monoid over chunks and combining equals folding over the concatenation. |
| online softmax | `OSM.combine_assoc`, `OSM.combine_comm`, `OSM.sem_combine`, `OSM.run_eq_softmax` | The state monoid is associative and commutative, and running it equals two-pass softmax. |
| derived gradients | `vjp_sum_comp`, `vjp_fiber`, `softmax_avg_deriv` | The VJP of a sum of affine-read, differentiable scalar terms is the sum of per-element adjoints, and the flash backward identity holds. |
| stabilizing max | `stabilized_softmax_eq`, `stabilized_softmax_hasFDerivAt`, `softmaxShift_deriv_shift` | Subtracting any `c(x)` leaves softmax unchanged, and its derivative in `c` is zero. |
| exported trace | `combine_eq_osm` | The combine `stabilize_softmax` actually emitted equals `OSM.combine`. |
| IO duality | `weak_duality`, `box_hbl`, `box_volume`, `tiles_needed` | For arrays read through **coordinate subsets**, fitting tile exponents sum to at most covering HBL exponents, and **box** tilings of `V` points need at least `V/M^σ` tiles. |

**Outside the mechanization:**
* Strides and multi-term addresses (`x[t+k]`) in the IO results. Fusion
  covers any affine view; `Duality` covers only subsets `φ_j ⊆ coords`.
* Arbitrary, non-box schedules: the discrete HBL inequality is not mechanized,
  so the lower bound for general schedules is cited (Christ et al.).
* Traffic counting (red-blue pebbling), gather bounds, the time floor,
  floating-point error, and correctness of the lowering to CUDA/WGSL/MSL.

## The LP

A kernel iterates a box `V = ∏_q [N_q]` (point dims, reduce dims, and the
reduce dims of every nested contraction) and reads arrays through views.
A pick view of array `j` is a projection `φ_j` onto a set of coordinates.
In exponents of a fast memory of `B` words, with `β_q = log_B N_q`:

```
dual  (tile):   max Σ_q x_q    s.t.  Σ_{q∈φ_j} x_q ≤ 1 − a_j    every operand tile fits
                                     x_q ≤ β_q                  no tile exceeds its extent
primal (bound): min Σ_j (1−a_j)s_j + Σ_q β_q t_q
                               s.t.  Σ_{j∋q} s_j + t_q ≥ 1      every coordinate covered
```

* **Primal → bound.** One stretch of `M` I/Os has `2M` words available and
  performs at most `∏_j (2M s_j/Σs / D_j)^{s_j} ∏_q N_q^{t_q} ∏_atomic N_q`
  body evaluations. That is the Hölder–Brascamp–Lieb inequality with loop
  bounds: Christ, Demmel, Knight, Scanlon and Yelick (2013), extended to
  arbitrary bounds by Dinh and Demmel (2020). So traffic is
  `≥ M·(|V|/F − 1)`.
* **Dual → tile.** The tile is `T_q = (M/J)^{x_q}`, with the budget split
  over the `J` operands.
* **The gap.** Strong duality makes the two optima equal: every solve
  returns both and checks `primal − dual ≈ 0` (`LpSolution::gap`). The
  remaining gap is between the bound's traffic and the dual tile's
  traffic, and it is a constant factor (below).

**Atomic coordinates.** A reduce dim of a nested contraction whose result
is consumed nonlinearly and never stored is *atomic*. Attention's head dim
`c` in `S = QKᵀ` is one, because `exp` needs the whole dot product. A
schedule must finish each such reduction inside one stretch, so `x_q = β_q`
and the arrays' budgets shrink by `a_j`. The alternative is to spill the
partial sums: then the inner result is one more array and `q` is free. A
schedule may pick either, so the bound is the minimum over the two models.

**Composite time floor.**
`TimeFloor = max(bytes / DRAM BW, flops / peak, launches × latency)`, with
the binding term named. `Machine::{RTX3090, M4}` carries the rates.

## Unit tests (`tensor::io_lp::tests`)

| test | result |
|---|---|
| `matmul_lp_is_hong_kung` | `σ = 3/2`, `s = x = (½,½,½)`, gap 0. Bound `M·(n³/(2M/3)^{3/2} − 1) ≈ 1.84·n³/√M` (Irony–Toledo–Tiskin form; COSMA's `2n³/√M` is ~9% stronger). Dual tile is a cube of side `√(M/3)`. |
| `attention_is_saha_ye` | For `M ≥ d²` the bound is a constant fraction of `N²d²/M` (scales ×4 in `N`, ×½ in `M`). For `M < d²` it is a constant fraction of `N²d/√M` (×½ for 4× `M`). This is Saha & Ye's `Θ(min(N²d²/M, N²d/√M))` (arXiv 2402.07443), from the LP alone. |
| `attention_dual_tile_is_flash_blocks` | The dual tile is `T_i = T_j = M/(4d)` = 48 for `M = 12288`, `d = 64`. Those are FlashAttention's `B_r = B_c = M/(4d)` (Dao et al., Alg. 1), derived, not given. |
| `small_matmul_hits_extent_bounds` | Short `k`: the extent bound binds (`t_k > 0`), gap 0. |
| `weak_duality_random` | 200 random projection LPs: primal feasible, gap < 1e-7. |
| `trace_is_current` | The Lean trace file equals what tang-compile exports today. |

## The experiment: dual tile vs what tang picks

All LPs below are read off the IR by `TensorGraph::kernel_lp` after tang's
pass pipeline. For attention that means the nested `S = QKᵀ` inside the
flash kernel, with its `c` marked atomic. Traffic is in MB at f32.

### Matmul

| device (M) | n | dual tile | dual traffic | `schedule_auto` tile | its traffic | autotuner (M4, timed) | its traffic | bound |
|---|---|---|---:|---|---:|---|---:|---:|
| 3090 (12288) | 1024 | 64×64×64 | 138 | 64×64 (k-chunk 32) | 138 | – | – | 71 |
| 3090 (12288) | 4096 | 64×64×64 | 8657 | 64×64 | 8657 | – | – | 4555 |
| M4 (8192) | 1024 | 52×52×52 | 172 | 64×64 | 138 | 32×64 (k 16) | 206 | 87 |
| M4 (8192) | 4096 | 52×52×52 | 10670 | 64×64 | 8657 | 64×64 (k 32) | 8657 | 5579 |

* **3090: match.** The dual's `√(M/3) = 64` is the output tile tang's
  heuristic picks (16×16 threads × 4×4 registers).
* **M4: tang's tile beats the dual.** The dual budgets `M/3` for each of
  A, B and C, but tang accumulates C in registers and stages only A and B
  k-chunks. So the real constraint is `T_i·T_k + T_k·T_j ≤ M` with C free,
  and a larger tile fits. The LP does not know which arrays live in
  registers. That is a modelling gap, not a refutation: with C removed from
  the shared-memory budget, the dual tile grows to `√(M/2)·…` and tang's
  64×64 sits inside it.
* **The autotuner optimizes time, not traffic.** It was timed on this M4
  (`TUNE=1`, wgpu/Metal). At 4096³ it keeps 64×64 (same as `schedule_auto`,
  1.55× the bound). At 1024³ it picks 32×64 with 16-wide k-chunks. That
  moves 1.5× more bytes than the dual tile (2.36× the bound) but makes
  512 workgroups instead of 256. At this size occupancy beats IO, and the
  time floor's memory term is not binding enough to matter.

### Attention forward (8 heads, N, d = 64, causal)

| device (M) | N | dual tile (q rows × k rows) | dual traffic | tang tile | tang traffic | autotuner | bound | floor @ bound | floor @ tang |
|---|---|---|---:|---|---:|---|---:|---|---|
| 3090 | 1024 | 48 × 48 | 96 | 16 × 16 | 273 | – | 11.1 | 0.030 ms compute | 0.291 ms memory |
| 3090 | 4096 | 48 × 48 | 1460 | 16 × 16 | 4312 | – | 179 | 0.483 ms compute | 4.61 ms memory |
| M4 | 1024 | 32 × 32 | 138 | 16 × 16 | 273 | 16 × 16 (273 MB) | 16.7 | 0.250 ms compute | 2.27 ms memory |
| M4 | 4096 | 32 × 32 | 2164 | 16 × 16 | 4312 | **64 × 32 (1091 MB)** | 268 | 4.00 ms compute | 35.9 ms memory |

* **The autotuner moves toward the dual and past it.** On the M4 at
  N = 4096, the timed autotuner picks 64 query rows × 32-key chunks. That
  is 4× tang's default and 1090 MB, which is *half* the dual tile's
  traffic (4.1× the bound). The equal `M/J` split again assumes that
  Q, K, V and O all share fast memory. The kernel keeps O (the online state)
  in registers, so Q (64×64) plus the K and V chunks (32×64 each) fill all
  8192 words. At N = 1024 it keeps 16 × 16: little reuse to win, so
  parallelism wins.
* **Default heuristic: mismatch, and the dual is closer.** The LP derives FlashAttention's
  block size from the views. tang's scalar flash kernel stages 16 query
  rows × 16-key chunks, which is 2.8× (3090) or 2× (M4) more traffic than
  the dual tile. The wider tiles are only found by the timed
  autotuner. The default `schedule_auto` / `nest_contractions` heuristic
  never picks them.
* **The time floor moves from compute to memory.** At the bound, attention
  is compute-bound on both devices. At tang's traffic it is memory-bound,
  with a floor 9–10× higher. That is the headroom a dual-sized tile would
  reclaim, if registers allow it (a 48-row tile of a 66-wide online state
  needs about 3.2K registers per row group).
* **The gap is constant.** The dual tile's traffic is 8.2–8.7× the bound
  at every N and M. The ratio is flat in N, so the dual tile is
  `Θ`-optimal and the 8× is the bound's constant: `N²d²/(4M)` from the
  atomic-unit count, against FA's achievable `≈ 4N²d²/M` causal.

## Coverage: what fits the LP

| view / op | fits? | what happens |
|---|---|---|
| affine pick view (transpose, broadcast, slice, head split `64h+2i` on separate coords) | yes | a projection |
| **guarded** pick view (zero padding) | yes | reads ⊆ the projection; the bound stays valid (padding only lowers the footprint) |
| multi-term form (`x[t + k]`, strided/dilated conv, polyphase) | **no** | HBL holds for general linear maps, but the LP's constraints then range over the lattice of subgroups (Christ et al. §6), which is exponential and not implemented. The array is *dropped* (`LpCoverage::non_projective`). That is sound (fewer arrays only weaken the bound) but loose: for a convolution the bound misses the input-reuse term. |
| **gather** view (`W[sel[t,k]]`, embeddings, paged KV) | **partly** | the address is data, so there is no projection. The gathered array is dropped from the LP (`LpCoverage::gathered`), and `Lp::gather_bound` adds it back as compulsory traffic, `max(bound(rest), Σ\|rest\| + U·slice)`, with `U` the distinct slices the index data touches. That is sound for the given data. `Lp::expected_distinct` gives `E(1 − (1 − k/E)^N)` for uniform top-k routing, which is #186's analytic decode floor. The reuse term of a grouped matmul (each expert slice against its tokens) still needs the per-expert token counts, and skewed routing changes it. |
| nested contraction consumed nonlinearly | yes, as *atomic* | the atomic/spill choice is the min of two LPs. `attention_bound` does both; `kernel_lp` from the IR builds the atomic model only. |
| causal / sliding masks (`select` on `iota`) | partly | the LP counts the full box. The bound is valid for tang's CDAG, which evaluates masked scores, but a mask-skipping schedule is a different CDAG and could halve it. |
| scans (`Op::Scan`), operators | no | not comprehensions; compulsory traffic only |
| tiny extents (`d < M^{x}`) | yes | extent constraints `x_q ≤ β_q` (`t_q > 0` in the primal) |

**Where constants and asymptotics break.**
* The primal's constant is HBL's. It is 1.84 vs 2 for matmul. For attention
  the atomic bound `N²d²/(4M)` is ~8× below what any known schedule
  achieves. That is the Θ-constant Saha & Ye leave unstated.
* The time floor uses peak rates and a fixed launch latency. The M4
  figures (120 GB/s, 4.3 TFLOP/s, 10 µs) are nominal, not measured.
* Registers are a level for the *tile* (`Lp::tile_levels`, below), but
  the *bound* uses one level at `regs + smem` words. That is sound and
  loses nothing at this scale. L2 is not modeled.

## Round 2 (history; see Corrections): registers, bytes in flight, H200

### Two-level dual tile (`Lp::tile_levels`)

The single-level dual charges every operand to shared memory. tang (and any
GPU GEMM) keeps the accumulator in registers. The two-level dual puts the
output array (matmul's `C`, attention's online `O`) in registers
(`Machine::reg_words` per workgroup) and the inputs in shared memory
(`mem_words`). The footprints on each level must sum to at most its
capacity, and the innermost loop must run over a coordinate the output does
not depend on (the accumulator stays resident). The search is exhaustive
over power-of-two tiles and register/shared splits. The bound stays
single-level at `regs + smem` (sound, since on-chip storage is at most that).

`reg_words = 4096` is the schedule space's largest register tile (`reg` up
to 4×4 points × 256 threads). It is not the hardware register file.

| kernel (from the IR, `io_dual`) | single-level dual | **two-level dual** | M4 autotuner | traffic |
|---|---|---|---|---|
| matmul 4096³, M4 | 52×52 | **64×64**, C in registers | 64×64 | 8657 MB, the same as tang's |
| matmul 4096³, 3090 | 64×64 | **64×64** | (schedule_auto 64×64) | |
| attention fwd N=4096 d=64, M4 | 32 rows × 32 keys | **64 rows × 32 keys**, O in registers, Q/K/V in shared | **64×32** | 1090 MB vs 2164 MB, half, as the autotuner measured |
| attention fwd N=4096 d=64, 3090 | 48 rows | 128 rows × 32 keys, value columns split in two | not tuned | 830 MB vs 1460 MB |

So the register level **explains both M4 autotuner picks**. The "half the
dual's traffic" gap from round 1 is the online state moving out of shared
memory. Caveats:
* The match depends on `reg_words`. At 8192 words the matmul tile would
  be 128×64, which tang's space can't express.
* On the 3090 the IR LP leaves the value-column coordinate free and
  prefers splitting it (128×32, recomputing `QKᵀ` per half). The hand LP
  (`attention_lp`, `e` atomic) gives 64×64. Which one wins on hardware was
  not measured.
* Tests: `levels_match_m4_autotuner` (also checks bound ≤ two-level ≤
  single-level traffic).

### Bytes in flight (`Occupancy`, `TimeFloor::with_occupancy`)

Little's law: sustained bandwidth ≤ bytes in flight / latency, so a kernel
takes at least `bytes · latency / in_flight`. `in_flight` is resident
threads (from grid, block, registers per thread and the SM limits) × the
bytes one thread keeps outstanding. That term joins the composite floor and
is named `bytes-in-flight` when it binds. Machine constants:
* 3090: 82 SMs × 1536 threads, latency 470 ns, bandwidth-delay 0.44 MB.
* H200: 132 × 2048, latency 600 ns (assumed; not measured), 2.9 MB.

Launch floors are the smallest kernel in #186's traces: 2 µs on the 3090,
1 µs on the H200 inside a CUDA graph.

### Predicted vs measured: #186's kernels

From `scripts/ncu/predict_floor.py <#186's docs/bench/ncu> 96 64 16`. Bytes
are the 3090's ncu counts, and registers per thread come from the H200
trace. Per-thread in flight `b`:
* 96 B: the int-MMA Q4_K inner loop issues 8 + 24 + 64 B of independent
  loads per super-block before using them.
* 64 B: the lane GEMV's `uint4` pair plus scales.
* 16 B: one vector load, a calibration rather than a schedule value.

A ✗ marks a "floor" above the measured time (not a floor).

| kernel | GPU | measured µs / light | b = 96 (schedule) | b = 64 | b = 16 (calibrated) |
|---|---|---|---|---|---|
| MoE `ex_gate_up` T=1 (320×256) | 3090 | 22.1 / 0.71 | 15.7 / 1.00 memory | same | same |
| | H200 | 10.7 / **0.29** | 3.1 / 1.00 memory | 3.1 / 1.00 | 6.7 / 0.46 in-flight |
| MoE `ex_down` T=1 (160×256) | 3090 | 14.7 / 0.68 | 10.0 / 1.00 | same | same |
| | H200 | 5.4 / **0.36** | 1.9 / 1.00 | 2.1 / 0.91 in-flight | 8.5 / 0.23 ✗ |
| MoE `ex_gate_up` T=8 | H200 | 59.4 / **0.35** | 21.0 / 1.00 | 21.0 / 1.00 | 22.4 / 0.94 |
| MoE `ex_down` T=8 | H200 | 23.6 / **0.62** | 14.7 / 1.00 | 14.7 / 1.00 | 15.6 / 0.94 |
| MoE `ex_gate_up` T=48 | 3090 | 506 / 0.88 | 446 / 1.00 | same | same |
| | H200 | 182 / **0.48** | 87 / 1.00 | 87 / 1.00 | 116 / 0.75 in-flight |
| MoE `ex_down` T=48 | 3090 | 273 / 0.89 | 244 / 1.00 | same | same |
| | H200 | 125 / **0.38** | 47.5 / 1.00 | 47.5 / 1.00 | 63 / 0.75 in-flight |
| Q8_0 GEMV 256×256 | 3090 | 144 / 0.88 | 128 / 1.00 | same | same |
| | H200 | 63.5 / **0.39** | 24.9 / 1.00 | 24.9 / 1.00 | 68 / 0.36 ✗ |

### Predicted vs measured: H200 decode step

Group floors are #186's analytic bytes. A group's bytes are spread over its
launches by thread count, and each launch's floor is summed.

| config | wall ms | measured light | predicted light, b = 96 | b = 64 | b = 16 |
|---|---|---|---|---|---|
| hand N=1 | 4.04 | **0.18** | 0.68 | 0.65 | 0.44 |
| hand N=8 | 9.83 | **0.23** | 0.89 | 0.88 | 0.58 |
| hand N=48 | 29.67 | **0.28** | 0.95 | 0.94 | 0.37 |
| derived N=1 | 4.39 | **0.16** | 0.54 | 0.51 | 0.29 |
| derived N=8 | 10.91 | **0.20** | 0.77 | 0.75 | 0.46 |
| derived N=48 | 28.40 | **0.29** | 0.89 | 0.88 | 0.49 |

**Verdict: the new floor does not predict the H200.**
* **The 3090 is predicted.** Every big kernel is bandwidth-bound there at
  any `b ≥ 16`, as measured (0.7–0.9).
* **The H200 is not, with schedule-derived `b`.** With `b = 64–96 B` and
  unloaded latency, every big kernel has more than the 2.9 MB
  bandwidth-delay product in flight (82k resident threads × 64 B = 5 MB).
  Little's law then predicts light ≈ 1, against a measured 0.3–0.5.
  #186's diagnosis ("too few bytes in flight") is not reproduced by
  counting threads × issued loads.
* **The class flip comes out only with `b ≈ 16 B`.** Then the 3090 stays
  bandwidth-bound while the H200 turns in-flight-bound. That is
  qualitatively #186's finding, but the per-kernel error is up to 2.3×,
  and four kernels predict a time above the measured one. So `b ≈ 16 B` is
  a fit, not a floor.
* **The step: launches explain part of N=1, nothing explains the rest.**
  The launch term (~550–830 launches × 1 µs) accounts for a share of the
  N=1 gap: predicted 0.51–0.68 vs measured 0.16–0.18. At N=48 the floor
  is within 10% of pure bandwidth, while the step runs 3.4× slower.

What the model is missing:
* **Loaded latency.** At 50% of peak, HBM latency is well above 600 ns.
* **Effective outstanding requests.** Dependent dequant chains, the
  per-SM miss queue and L1 MSHR limits all cut it below what the threads
  issue. tang can't see this, and it needs per-SM counters (ncu on the
  H200, unavailable in RunPod containers).
* **Tails.** Gate_up T=1 is ~2.8 load rounds per thread.
* **Bytes.** The H200 light uses the 3090's bytes; the 50 MB L2 changes them.

The next measurement that would separate these: ncu
`l1tex__t_sectors_pipe_lsu_mem_global_op_ld_lookup_miss` and
`lts__average_gcomp_input_sector_*` on a host with H100/H200 counters.

## Round 3 (history; see Corrections): fill/drain and the step's critical path

Replace's #189 found that the H200 decode step isn't limited by steady-state
bandwidth. Its GEMVs are small, and each pays a fill and a drain, summed
along the dependent kernel chain.

### The terms (`StepKernel::floor`, `step_floor`)

Per kernel:

`t ≥ launch + max(bytes/BW + latency, flops/peak, ⌈waves⌉ · latency)`

* **`bytes/BW + latency`:** the first byte arrives one DRAM latency after
  the start, then the kernel streams at peak.
* **`⌈waves⌉ · latency`:** each wave of workgroups needs at least one
  dependent round trip.
* **`launch`:** the cost of an empty graph node.

The step floor is the longest path through the kernel DAG, with
independent kernels overlapping, and at least `Σ bytes / BW`. The binding
term is named per kernel (`fill`, `stream`, `waves`, `compute`, `launch`)
and per step (`chain` or `bandwidth`).

**Calibration from first principles, not fitted to the measured times:**
* DRAM latency: 470 ns on the 3090, 600 ns on the H200 (the H200 value is
  assumed).
* Bandwidth: the datasheet.
* `launch`: the smallest kernel in #186's traces (2 µs on the 3090, 1 µs on
  the H200 in a graph).
* Waves: from grid, block, and registers per thread against the SM limits.
  Waves match #189's ncu numbers on the 3090: 0.65 predicted for
  `ex_gate_up` T=1, 0.65 measured.

Script: `scripts/ncu/critical_path.py <#186's docs/bench/ncu>`. Test:
`step_chain`.

### Per kernel, predicted vs measured

| kernel | 3090 meas / **pred** µs | H200 meas / **pred** µs | H200 binding | H200: 3090 µs × SM-rate (0.53) |
|---|---|---|---|---|
| MoE `ex_gate_up` T=1 (0.40 waves on H200) | 22.1 / **18.2** | 10.7 / **4.7** | stream | 11.8 |
| MoE `ex_down` T=1 | 14.7 / **12.4** | 5.4 / **3.5** | stream | 7.8 |
| shared `sh_gate_up` T=1 (0.06 waves) | 5.8 / **5.3** | 3.1 / **2.1** | fill | |
| shared `sh_gate` T=8 | 13.3 / **3.9** | 12.3 / **1.9** | fill | |
| MoE `ex_gate_up` T=8 | 122 / **110** | 59.4 / **22.6** | stream | 64.9 |
| MoE `ex_down` T=8 | 92.6 / **77.7** | 23.6 / **16.3** | stream | 49.3 |
| MoE `ex_gate_up` T=48 | 506 / **448** | 182 / **88.6** | stream | 269 |
| MoE `ex_down` T=48 | 273 / **246** | 125 / **49.1** | stream | 145 |
| Q8_0 GEMV 256×256 | 144 / **130** | 63.5 / **26.5** | stream | 76.7 |

* **Sound everywhere:** predicted ≤ measured on every kernel, on both GPUs.
* **3090: tight.** The big kernels come within 0.82–0.90 of measured; the
  model explains the 3090.
* **H200: not tight.** The big kernels predict 0.38–0.69 of measured. Fill
  matters only for the sub-wave shared-expert GEMVs, and even those run
  1.5–10× over their floor.
* **The big H200 kernels sit between the floor and the SM-rate column**
  (3090 time × the SMs × clock ratio). Their H200/3090 speedup is 2.1–3.9×,
  against 5.1× in bandwidth and 1.9× in SM issue rate. That fits #189's
  finding that the GGUF Q8_0 layout's instruction cost per byte caps them.
  The missing per-kernel term is **instruction issue per byte**
  (dequantization), which this floor does not count: the flops term has no
  integer or shift ops in it. That term needs a count of the lowered
  kernel's instructions per byte, which tang could emit (follow-up).

### The decode step (H200, one stream: the chain is the trace order)

| config | wall ms | bytes/BW | **chain floor** | predicted light | measured light | fill share of the floor |
|---|---|---|---|---|---|---|
| hand N=1 | 4.04 | 0.72 | **1.48** | 0.49 | 0.18 | 51% |
| hand N=8 | 9.83 | 2.23 | **2.98** | 0.75 | 0.23 | 25% |
| hand N=48 | 29.67 | 8.32 | **9.51** | 0.87 | 0.28 | 13% |
| derived N=1 | 4.39 | 0.72 | **1.76** | 0.41 | 0.16 | 59% |
| derived N=8 | 10.91 | 2.23 | **3.49** | 0.64 | 0.20 | 36% |
| derived N=48 | 28.40 | 8.32 | **10.24** | 0.81 | 0.29 | 19% |

* **Fill and launch along the chain are real:** about half of the N=1
  floor, so the chain floor is 2× the bandwidth floor at N=1.
* **They don't explain the step.** Measured is 2.5–3.1× above the chain
  floor at every N. The remaining time is mostly the per-kernel issue
  limit above, over the ~830 launches.

### Levers: upper bounds on what each could gain (against the chain floor)

| config | (a) shared expert beside the routed chain | (a′) any two adjacent kernels with ≤ 1 wave together run concurrently | (b) each kernel's weights already in L2 | (a′) + (b) |
|---|---|---|---|---|
| hand N=1 | −0% (one fused kernel) | −11% | −33% | −44% |
| hand N=8 | −0% | −3% | −25% (to bytes/BW) | −25% |
| hand N=48 | −0% | −3% | −13% (to bytes/BW) | −13% |
| derived N=1 | −5% | −26% | −28% | −52% |
| derived N=8 | −9% | −11% | −36% (to bytes/BW) | −36% |
| derived N=48 | −3% | −7% | −19% (to bytes/BW) | −19% |

Each lever, and its assumptions:
* **(b) L2 prefetch:** each kernel streams from L2 instead of DRAM. L2 is
  assumed at 10 TB/s and 260 ns, not measured. The step stays at least
  bytes/BW, because DRAM still has to deliver every byte.
* **(a′) concurrency:** greedy pairing of neighbours, which ignores data
  dependence, so it is an upper bound on what reordering independent work
  can buy.
* **Scope:** the bounds are on the *floor's* time. Today they buy at most
  that fraction of the floor's ~1.5–10 ms, not of the 4–30 ms measured;
  the issue-limited remainder is untouched by either lever.

**For Replace, by N:**
* **N=1:** prefetch plus concurrency could take the floor from ~1.6 ms to
  ~0.85 ms. Prefetch is worth about 3× concurrency on the hand engine and
  about as much as it on derived. Running the shared expert beside the
  routed experts alone is worth ≤ 9%.
* **N ≥ 8:** the floor is already near bytes/BW, so neither lever matters
  until the issue limit is fixed (the aligned Q8 repack in the derived
  path, #189).

## Round 4 (history; see Corrections): instruction issue, prefetch charged, fusion

### Instruction-issue term (`IssueCost`)

`t ≥ launch + latency + issue`, where `issue = max(wavefronts, int_ops/64) / (SMs · clock)`.

The counts come from the lowered source in `tensor_cuda_int8.rs`, not from a
fit to the measured times:
* **L1 wavefronts:** one per distinct 128-byte line a warp request touches,
  one per SM-cycle. Only the DRAM operand's requests are counted, so the
  term stays a floor.
* **int32 thread-ops:** 64 per SM-cycle on both Ampere and Hopper.

The two lowerings:
* **`gemv_kernel_q8_0`:** each lane loads a 136-byte unit as 17 `uint2`
  loads. Lanes sit 136 B apart, so every request touches 32 lines: 17·32
  wavefronts per 32·136 B, about 8 B per SM-cycle. Integer work is ≈ 76
  ops a unit (32 `dp4a`, 16 funnel shifts, address and select ops).
* **Q4_K `gemv_kernel` (k = 2048):** 8 lanes × 4 rows per warp. The 8
  weight requests of each unit touch 16 lines: 8·16 wavefronts per 32·72 B,
  about 18 B per SM-cycle. Integer work is ≈ 116 ops a unit.

| kernel | 3090 meas / pred µs (binding) | H200 meas / pred µs (binding) | H200 pred/meas, round 3 → **4** |
|---|---|---|---|
| Q8_0 GEMV, GGUF blocks, 119 MB | 144 / 130 (stream) | 63.5 / **58.7 (issue)** | 0.42 → **0.92** |
| MoE `ex_gate_up` T=1, Q4_K lanes | 22.1 / 18.2 | 10.7 / 4.7 (issue ≈ stream) | 0.44 → 0.44 |
| MoE `ex_down` T=1 | 14.7 / 12.4 | 5.4 / 3.6 | 0.66 → 0.67 |
| MoE `ex_gate_up` T=8 | 122 / 110 | 59.4 / 23.0 | 0.38 → 0.39 |
| MoE `ex_down` T=8 | 92.6 / 77.7 | 23.6 / 16.6 | 0.69 → 0.70 |
| MoE T=48 (int-MMA, shared-staged: issue not counted) | 506 / 448; 273 / 246 | 182 / 88.6; 125 / 49.1 | 0.49, 0.39 |

**Does it close the gap while staying sound?** Partly. It stays sound:
predicted ≤ measured on every kernel on both GPUs.
* **Q8_0 GEMV: closed.** On the H200 the L1-wavefront term binds at about
  8 B per SM-cycle ≈ 2.1 TB/s, 0.92 of measured. On the 3090 the same
  wavefront rate is 1.11 TB/s, above its 936 GB/s, so the 3090 stays
  bandwidth-bound, as measured. This is #189's layout finding derived from
  the lowering, and it also says why the aligned repack (4 lines per
  request) reaches 0.89.
* **Q4_K MoE GEMVs: not closed.** Their requests touch half as many lines
  per byte, so the wavefront term sits at about the bandwidth term and
  they stay at 0.39–0.70.
  * Counting the activation requests as well (24 more per unit) would bind
    them, but for the Q8_0 GEMV that count already exceeds the measured
    time (77 µs > 63.5). So the one-line-per-cycle rule is too coarse to
    add them soundly.
  * Measuring `l1tex__data_pipe_lsu_wavefronts` on an H100/H200 with
    counters would settle it.
* **T=48 int-MMA kernels:** not modeled (shared-memory staged; the issue
  count of its MMA loop isn't done).

### L2 prefetch, charged to the prefetcher

The prefetching kernel now streams the next matrix's bytes as well: its
stream term grows by `B_next/BW`. The next kernel fills from L2.

| config | chain floor | every dense GEMV prefetches the next | only where it pays |
|---|---|---|---|
| hand N=1 / 8 / 48 | 1.48 / 2.98 / 9.51 ms | **+28% / +15% / +4%** | −1% / −0% / −0% |
| derived N=1 / 8 / 48 | 1.76 / 3.49 / 10.24 ms | **+23% / +13% / +4%** | −1% / −0% / −0% |

* **The bound now matches Replace's net-negative result (#191).** A dense
  GEMV's matrix (2–15 MB) costs its prefetcher 0.4–3 µs of streaming, more
  than the next kernel saves (one fill latency plus the DRAM–L2 bandwidth
  difference).
* **Prefetch only pays off off the critical path:** issued from a kernel
  with slack (compute-bound attention) or on a side branch. Even selected
  pair by pair it is worth ≤ 1% of the floor.
* The round-3 "−25 to −36%" figure was wrong: it never charged the
  prefetcher.

### Fusion of block-local chains (upper bound per fusion)

Adjacent kernel pairs in the trace whose dependence can be block-local
(`FUSE` in `critical_path.py`), from the H200 N=1 traces:

| pair | per step |
|---|---|
| `cx_norm_q8 → cx_gemvk2_t1` (norm+quantize → dense GEMV prologue) | 49 |
| `cx_moe_add_norm → cx_gemvk2_t1` (hand) / `dop09_xq_out → cx_gemvk2_t1` (derived) | 48 / 47 |
| `cx_moe_gu_d2 → cx_moe_down_d2f` (hand) / `ex_gate_up → ex_down` (derived) | 48 / 47 |
| `dop01_xq → ex_gate_up` (derived) | 47 |
| `sh_gate_up → sh_down` (derived) | 47 |

Each fused pair removes one dependent kernel's `τ`. The table gives two
values of `τ`:
* **floor τ** = launch + latency = 1.6 µs;
* **measured τ** = 6.9 µs (#191's cold-GEMV fit, which includes launch).

| config | fusable / kernels | saving at floor τ | saving at measured τ |
|---|---|---|---|
| hand N=1 | 145 / 548 | −0.23 ms (16% of floor) | −1.00 ms (**25% of wall**) |
| hand N=8 | 145 / 548 | −0.23 ms | −1.00 ms (10%) |
| hand N=48 | 193 / 858 | −0.31 ms | −1.33 ms (4%) |
| derived N=1 | 239 / 830 | −0.38 ms (22% of floor) | −1.65 ms (**38% of wall**) |
| derived N=8 | 380 / 971 | −0.61 ms | −2.62 ms (24%) |
| derived N=48 | 334 / 1469 | −0.53 ms | −2.30 ms (8%) |

**For Replace, per fusion at N=1 (measured τ):**
* norm → GEMV prologue (≈ 96 pairs): −0.66 ms;
* gate|up → down per expert (47–48): −0.33 ms;
* the derived path's quantize → gate|up and shared gate|up → down (47 each):
  −0.32 ms each.

Fusion is the only lever here that grows as N shrinks, which matches #191.

Caveats:
* **norm → GEMV is block-local** because every block recomputes the norm
  of one hidden vector: 2048 values, cheap. The derived path already does
  this (`GemvShape::fused`).
* **gate|up → down per expert is block-local only if one block (or a
  cluster) holds an expert's whole intermediate row** (512 values). Today
  32 CTAs share an expert. Fusing means those CTAs each recompute the
  others' slices, or a cluster with distributed shared memory. That cost is
  not in the bound.
* **The savings are upper bounds.** The fused kernel keeps all its bytes,
  so only `τ` goes away. The real saving is smaller by whatever the fusion
  adds (recomputed norms, lower occupancy).

## Lean

* **`Tang.Duality.weak_duality`.** For any covering HBL exponents `s` and
  any fitting tile exponents `x`, `Σ x ≤ Σ s`. LP weak duality for this
  pair, mechanized.
* **`box_hbl`, `box_volume`.** For a box tile with sides `T_q ≥ 1`,
  `∏ T ≤ ∏_j |φ_j(E)|^{s_j}`, and it is `≤ M^{Σs}` when every footprint is
  `≤ M`.
* **`tiles_needed`.** `n` tiles of volume `≤ M^σ` covering `V` points
  number at least `V/M^σ`. Together these give **no box-tiled schedule
  moves fewer words than the primal**.
* **Not mechanized.** The same statement for arbitrary schedules, which
  needs the discrete HBL inequality for non-box sets (Loomis–Whitney in
  the matmul case). It is not in Mathlib, and proving it is a project of
  its own.
* **`Tang.Trace.combine_eq_osm`.** The combine of the online-softmax
  monoid that tang's `stabilize_softmax` actually built for
  `Σ e^{s−m} v / Σ e^{s−m}` is checked in Lean. It is exported node for
  node from its tang-expr graph into `Trace.lean` (generated; the Rust test
  `trace_is_current` fails if it drifts). Lean proves it equals `OSM.combine`,
  so the real rewrite inherits associativity, tiling and flash = two-pass
  softmax. Caveat: the trace's `log₂ e` literal is read as the real number.
  The f64 constant differs in the last bit, and `Select` at `a = b` picks
  `b` (= `max`).
