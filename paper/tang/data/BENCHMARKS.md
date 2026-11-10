# Tang Benchmarks

**Date:** 2026-08-11
**Hardware:** Apple M4 Max (16 cores: 12P + 4E), 48 GB RAM, integrated GPU
**Toolchain:** `cargo bench -p tang-bench --release` (criterion 0.5)

The "before" column throughout is the 2026-02-28 run on the same hardware,
prior to the row-major GEMM kernels in `tang-la::gemm`. See
[What changed](#what-changed) for why the numbers moved.

## CPU Training (`cpu_training`)

### Linear Layer

| Benchmark | Before | Now | Speedup |
|-----------|--------|-----|---------|
| `linear_forward/fwd/4x128->64` | 146 µs | **2.26 µs** | 65x |
| `linear_forward/fwd/16x576->576` | 6.83 ms | **213 µs** | 32x |
| `linear_forward/fwd/1x576->1536` | 14.6 ms | **106 µs** | 138x |
| `linear_backward/bwd/16x576->576` | 3.58 ms | **543 µs** | 6.6x |

### SwiGLU FFN

| Benchmark | Before | Now | Speedup |
|-----------|--------|-----|---------|
| `swiglu/fwd/4x64` | 443 µs | **10.0 µs** | 44x |
| `swiglu/bwd/4x64` | 364 µs | **31.7 µs** | 11x |
| `swiglu/fwd/16x576` | 54.8 ms | **2.22 ms** | 25x |
| `swiglu/bwd/16x576` | 46.5 ms | **6.26 ms** | 7.4x |

### Grouped-Query Attention (causal)

| Benchmark | Before | Now | Speedup |
|-----------|--------|-----|---------|
| `gqa/fwd/seq8_d64_h4` | 269 µs | **17.0 µs** | 16x |
| `gqa/fwd/seq32_d64_h4` | 409 µs | **73.6 µs** | 5.6x |

### RMSNorm / RoPE

Neither is matmul-bound, so both are roughly unchanged.

| Benchmark | Before | Now |
|-----------|--------|-----|
| `rmsnorm/fwd/16x64` | 2.1 µs | 1.78 µs |
| `rmsnorm/fwd/16x576` | 18.8 µs | 14.6 µs |
| `rope/apply/seq32_d64` | 6.2 µs | 6.18 µs |
| `rope/apply/seq128_d64` | 26.2 µs | 24.9 µs |

### Loss Functions

| Benchmark | Before | Now |
|-----------|--------|-----|
| `loss/seq_ce/seq32_v256` | 20.7 µs | 19.3 µs |
| `loss/seq_ce/seq128_v256` | 85.0 µs | 79.4 µs |
| `loss/seq_ce_grad/seq32_v256` | 5.43 ms | 4.97 ms |
| `loss/seq_ce_grad/seq128_v256` | 22.3 ms | 20.3 ms |

`seq_ce_grad` is still the slowest CPU path by a wide margin and does not go
through GEMM — it is the next thing worth looking at.

### KV Cache (CPU, tang-infer)

| Benchmark | Before | Now |
|-----------|--------|-----|
| `kv_cache/prefill_128tok` (4 layers, kv_dim=128) | 21.7 µs | 17.7 µs |
| `kv_cache/decode_128steps` (4 layers, 1 tok/step) | 36.3 µs | 35.8 µs |

### Sampling

Unchanged — no matmul involved.

| Benchmark | Before | Now |
|-----------|--------|-----|
| `sampling/greedy_v256` | 405 ns | 415 ns |
| `sampling/topk40_v256` | 2.3 µs | 2.24 µs |
| `sampling/topk40_rep_pen_v256` | 2.3 µs | 2.36 µs |

### Quantization

| Benchmark | Before | Now | Speedup |
|-----------|--------|-----|---------|
| `quantize/q8_roundtrip_576` | 655 ns | 612 ns | 1.1x |
| `quantize/q4_roundtrip_576` | 865 ns | 754 ns | 1.1x |
| `quantize/q8_matvec_576x576` | 208 µs | **72.8 µs** | 2.9x |

The matvec win is from hoisting the per-block scale out of the elementwise
loop and moving the `in_dim` bounds test out of it into a separate tail block,
which is what had been blocking vectorization. Both kernels still accumulate
in `f64`; see [What's still missing](#whats-still-missing).

### Dense GEMM

`DMat::mul_mat` and `Tensor::matmul` both route through `tang-la::gemm`, which
is register-tiled and NEON-vectorized for `f32`/`f64`. `--features threads`
splits the output rows across a rayon pool.

**512x512x512 f32** (`cargo run -p tang-bench --example probe_linear --release`):

| Path | Time | GFLOP/s | vs. before |
|------|------|---------|------------|
| Before (naive triple loop) | 8.19 ms | 33 | — |
| `gemm`, 1 core | 2.74 ms | 98 | 3.0x |
| `gemm`, `--features threads` | **0.487 ms** | **551** | **16.8x** |
| Accelerate (`--features accelerate`) | 0.18 ms | 1,478 | 45x |

Accelerate still wins by ~2.7x because it reaches Apple's AMX coprocessor,
which NEON code cannot. The portable path is now within striking distance
rather than 45x behind, and it is the only path available off macOS.

### BLAS Acceleration (Apple Accelerate)

`DMat::mul_mat` with `--features accelerate` dispatches to `cblas_sgemm`/`cblas_dgemm` via Apple's Accelerate framework (AMX/NEON). Zero-copy — `DMat` is already column-major matching CBLAS layout.

| Type | Generic (before) | `gemm` | `gemm` + threads | Accelerate |
|------|------------------|--------|------------------|------------|
| f32 | 8.19 ms | 2.74 ms | 0.487 ms | 0.18 ms |
| f64 | 15.5 ms | — | — | 0.67 ms |

Enable with `cargo build --features accelerate` (macOS only). Falls through to the `gemm` kernels for non-f32/f64 types.

## What changed

Three things, in descending order of measured impact:

1. **`Tensor::transpose` allocated a `Vec` per element.** It was built on
   `from_fn` with an `idx.to_vec()` inside the closure, so a 576x576 transpose
   did 331,776 heap allocations. `Linear::forward` called it on the weight
   matrix on every forward pass, which was 70% of that benchmark's time. The
   2-D contiguous case is now a cache-blocked copy.
2. **No GEMM.** `DMat::mul_mat` was a naive triple loop and `Tensor::matmul`
   round-tripped both operands through `DMat` element-by-element. Both now call
   `tang-la::gemm`, which blocks over `k`, holds a 4-row tile of `C` in vector
   registers across the whole panel, and dispatches `f32`/`f64` to NEON.
3. **Linear layers transposed to multiply.** Weights are stored `[out, in]`, so
   `gemm_nt` contracts along contiguous rows of both operands directly. The
   weight gradient uses `gemm_tn` the same way. No transposed copy is
   materialized in either direction.

## What's still missing

- **No x86 SIMD.** The microkernels are NEON-only; on x86 `f32`/`f64` fall
  through to the generic path. AVX2/FMA kernels are two more `kernels!`
  expansions in `crates/tang-la/src/gemm.rs`.
- **Threading only splits rows.** `par_rows` splits `m`, which is the batch
  dimension for `Tensor::matmul_nt` — a batch of 16 gets 4 tasks, not 12.
  Splitting `n` as well would need the kernels to take raw pointers.
- **Quantized matvec accumulates in `f64`.** Q8 exists to make weights `i8`;
  the kernel should do `i8`x`i8`->`i32` dot products (NEON `sdot`) with
  on-the-fly activation quantization. Changing the public signature off
  `&[f64]` is a breaking change, so it is not done here.
- **`Parameter::randn` costs 3.6 ms per 576x576 matrix.** `Rng::normal` uses
  Box-Muller and discards the sine half, so every sample pays two RNG draws
  plus `ln`/`sqrt`/`cos`. Caching the second variate is a 2x win on model
  construction, but it changes the seeded RNG stream.
- **The `faer` feature is dead.** `crates/tang-la/Cargo.toml` declares it and
  pulls the optional dependency, but `faer` appears nowhere in
  `crates/tang-la/src/` outside two doc comments. The README claim that it
  "enables world-class f64 performance" has been removed; the feature itself is
  left in place pending a decision to wire it up or drop it.
- **`la`/`tensor`/`train` are vendored twice.** `crates/tang/src/{la,tensor,train}`
  are copies of the standalone crates that differ only in import paths, and
  they have already drifted (different panic messages, 161 differing lines in
  `layers.rs`). Every change above had to be applied in both places.

---

## GPU Inference (`gpu_inference`)

All GPU benchmarks use wgpu compute shaders. Sizes match SmolLM2-135M
(d_model=576, n_heads=9, n_kv_heads=3, head_dim=64, ff_dim=1536, vocab=49152).

### Embedding Lookup

| Benchmark | ns/iter | ~Time |
|-----------|---------|-------|
| `embedding/lookup/v256_d64_s32` | 31,476 | 31.5 µs |
| `embedding/lookup/v49152_d576_s128` | 41,736 | 41.7 µs |
| `embedding/lookup/v49152_d576_s1` | 31,560 | 31.6 µs |

### RMSNorm

| Benchmark | ns/iter | ~Time |
|-----------|---------|-------|
| `rmsnorm/fwd/16x64` | 31,366 | 31.4 µs |
| `rmsnorm/fwd/128x576` | 40,985 | 41.0 µs |
| `rmsnorm/fwd/1x576` | 32,182 | 32.2 µs |

### Interleaved RoPE

| Benchmark | ns/iter | ~Time |
|-----------|---------|-------|
| `rope_interleaved/fwd/s128_h9_d64` | 40,506 | 40.5 µs |
| `rope_interleaved/fwd/s1_h9_d64` | 31,051 | 31.1 µs |
| `rope_interleaved/fwd/s512_h9_d64` | 58,349 | 58.3 µs |

### Matmul (LLM projection sizes)

| Benchmark | ns/iter | ~Time | Description |
|-----------|---------|-------|-------------|
| `matmul_llm/mm/qkv_proj_s128` | 146,336 | 146 µs | [128,576]@[576,576] |
| `matmul_llm/mm/qkv_proj_s1` | 40,003 | 40.0 µs | [1,576]@[576,576] |
| `matmul_llm/mm/ffn_up_s128` | 378,013 | 378 µs | [128,576]@[576,1536] |
| `matmul_llm/mm/ffn_up_s1` | 61,410 | 61.4 µs | [1,576]@[576,1536] |
| `matmul_llm/mm/ffn_down_s128` | 399,599 | 400 µs | [128,1536]@[1536,576] |
| `matmul_llm/mm/ffn_down_s1` | 107,770 | 108 µs | [1,1536]@[1536,576] |
| `matmul_llm/mm/lm_head_s128` | 11,400,571 | 11.4 ms | [128,576]@[576,49152] |
| `matmul_llm/mm/lm_head_s1` | 1,302,962 | 1.30 ms | [1,576]@[576,49152] |

### SwiGLU Fused

| Benchmark | ns/iter | ~Time |
|-----------|---------|-------|
| `swiglu_fused/fused/128x1536` | 51,051 | 51.1 µs |
| `swiglu_fused/fused/1x1536` | 34,313 | 34.3 µs |

### KV-Cached Attention

| Benchmark | ns/iter | ~Time |
|-----------|---------|-------|
| `kv_attention/prefill_q128_kv128` | 989,550 | 990 µs |
| `kv_attention/decode_q1_kv256` | 761,508 | 762 µs |
| `kv_attention/decode_q1_kv1024` | 2,968,394 | 2.97 ms |

### GPU KV Cache Ops

| Benchmark | ns/iter | ~Time |
|-----------|---------|-------|
| `kv_cache/append_128tok` | 73,342 | 73.3 µs |
| `kv_cache/get_keys_gpu_256tok` | 17,275 | 17.3 µs |

### Full Transformer Layer (d=576, h=9, kv=3)

| Benchmark | ns/iter | ~Time |
|-----------|---------|-------|
| `transformer_layer/prefill_s128_d576` | 3,417,569 | **3.42 ms** |
| `transformer_layer/decode_s1_kv256_d576` | 2,677,459 | **2.68 ms** |

---

## GPU Training (`gpu_training`)

### Matmul (square)

| Benchmark | ns/iter | ~Time |
|-----------|---------|-------|
| `matmul/16x16` | 29,353 | 29.4 µs |
| `matmul/32x32` | 30,582 | 30.6 µs |
| `matmul/64x64` | 33,885 | 33.9 µs |
| `matmul/128x128` | 35,710 | 35.7 µs |

### Fused Elementwise

| Benchmark | ns/iter | ~Time |
|-----------|---------|-------|
| `fused_elementwise/add_sq_256` | 66,910 | 66.9 µs |
| `fused_elementwise/add_sq_1024` | 65,463 | 65.5 µs |
| `fused_elementwise/add_sq_4096` | 72,052 | 72.1 µs |

### Linear / Sequential / Training

| Benchmark | ns/iter | ~Time |
|-----------|---------|-------|
| `linear_forward_128x64` | 111,377 | 111 µs |
| `linear_backward_128x64` | 131,256 | 131 µs |
| `sequential_2_8_1_fwd_bwd` | 596,925 | 597 µs |
| `training_step_xor` | 2,180,537 | 2.18 ms |
| `mse_loss_64` | 290,317 | 290 µs |

---

## Throughput Estimates (SmolLM2-135M, 30 layers)

Based on single-layer GPU benchmarks extrapolated to 30 layers:

| Scenario | Per-layer | 30 layers + LM head | Tokens/sec |
|----------|-----------|---------------------|------------|
| **Prefill** (128 tokens) | 3.42 ms | ~114 ms | ~1,123 tok/s |
| **Decode** (1 token, kv=256) | 2.68 ms | ~82 ms | ~12 tok/s |

Decode is memory-bandwidth-bound: attention scales linearly with KV cache length.
LM head matmul (576x49152) adds ~1.3 ms per decode step.

## Kernels vs tensor IR (`kernels_vs_ir`)

**Date:** 2026-10-11. Same hardware. See `crates/tang-compile/src/tensor.rs`
for the IR (views + comprehensions + monoids) and `tensor_wgsl.rs` /
`tensor_tile.rs` for the schedules.

### CPU: hand kernels vs the *scalar* `tang-expr` IR (f64)

The scalar IR interprets a closure per element and cannot express a tensor
op as one node, so it loses everywhere and the gap grows with size. This is
the motivation for the tensor-level IR, not a result about it.

| block | size | hand | ir | ir_opt | trace+compile |
|---|---|---|---|---|---|
| swiglu act | 1M | 2.6 ms | 42.8 ms | 42.4 ms | – |
| rmsnorm | 16×576 | 15 µs | 90 µs | 78 µs | 77 ms |
| rmsnorm | 16×2048 | 52 µs | 330 µs | 281 µs | 1.06 s |
| matvec | 255 | 14 µs | 414 µs | 534 µs | 92 ms |

### GPU: hand-written causal attention vs attention *derived* from tensor IR

Single head, d = 64, f32. `hand` is `kv_attention_fused`. The `ir_*`
columns are the same naive `softmax(q·kᵀ/√d + mask)·v` graph under
different compiler schedules: `naive` materializes the n×n scores;
`flash` is after `substitute_maps` + `stabilize_softmax` (one
online-softmax reduction over `[rows, value-columns]` points with q·k
recomputed inside, nothing n×n in memory); `split` adds a 256-thread tree
reduction per point; `tiled` is `schedule_tile_2d` with 64 value-column
lanes × 4 rows per workgroup, the k/v tiles *and the q·k scores* staged
cooperatively in workgroup memory per 32-key chunk. Times include ~1.3 ms
of submit + readback; `autotune`'s kernel-only timing of `tiled` at
n = 1024 is ~0.5 ms.

| n | hand | ir_naive | ir_flash | ir_flash_split | ir_flash_tiled |
|---|---|---|---|---|---|
| 128 | 1.33 ms | 1.68 ms | 1.33 ms | 3.6 ms | 1.40 ms |
| 512 | 4.26 ms | 2.30 ms | 4.15 ms | 5.1 ms | **2.99 ms** |
| 1024 | 10.3 ms | 3.9 ms | 7.7 ms | 16.5 ms | **1.35 ms** |

Takeaways:

- Every derived schedule matches the hand kernel's output (checked at
  n = 100, 512, 1024); none contains attention-specific code.
- The tiled schedule is flash attention's real structure — rows × lanes,
  cooperative score tiles, online softmax — and it came out of three
  general rules: substitution, the online-softmax monoid rewrite, and
  "stage anything the lane axis does not depend on". At n = 1024 it is
  7.6× faster than the hand kernel and ~3× faster than the naive graph.
- The lane layout is only good *with* tiling: `split` recomputes the
  scores per lane and regresses. Schedules are not independent of the
  algebra, which is why `schedule_auto` looks for a lane axis first.

### GPU: hand-written matmul vs matmul derived from tensor IR

`hand` is `tang_gpu::matmul::matmul`. The IR version is one comprehension,
`Σ_k a[i,k]·b[k,j]`, under the same three schedules; `tiled` is a 16×16
point tile per workgroup with the `a` and `b` tiles staged in workgroup
memory (`schedule_tile_2d`), the classic shared-memory matmul, derived.

| n | hand | ir_naive | ir_split | ir_tiled |
|---|---|---|---|---|
| 256 | 1.50 ms | 1.47 ms | 2.38 ms | 1.45 ms |
| 1024 | 4.14 ms | 4.2–5.6 ms | 12.3 ms | 5.73 ms |

The derived matmul is at parity with the hand kernel. Shared-memory
staging does not pay on this chip either: the operands already live in
cache, so the extra barriers cost more than the global reads they save.

### GPU: rmsnorm and swiglu, hand vs derived

`hand` is `GpuRMSNorm::forward` (one workgroup per row, shared-memory
reduction) and `swiglu_fused_pub`. The IR rmsnorm is `x · rsqrt(mean(x²)+ε)`
after `substitute_maps`: one Sum reduction and one map.

| rmsnorm | hand | ir_naive | ir_split | ir_tiled |
|---|---|---|---|---|
| 128×576 | 1.46 ms | 1.49 ms | 1.48 ms | 1.50 ms |
| 2048×2048 | 2.16 ms | 3.90 ms | **2.31 ms** | 6.32 ms |

| swiglu | hand | ir |
|---|---|---|
| 65 536 | 1.57 ms | 1.55 ms |
| 4 194 304 | 2.09 ms | 2.25 ms |

| adam step | hand (`dispatch_adam`, 1 in-place kernel) | ir (3 maps) |
|---|---|---|
| 65 536 | 1.59 ms | 1.63 ms |
| 4 194 304 | 2.34 ms | 2.38 ms |

Note the winner flips: attention wanted the naive schedule, rmsnorm wants
the split one (its reduce axis is 2048 wide and there are only 2048 rows,
so one thread per row starves the GPU). Same compiler, same cost of
being wrong, different answer per op — which is the case for autotuning
rather than a fixed heuristic.

### `schedule_auto`

A fixed rule distilled from the tables above: a materialized reduction
whose points end in a lane axis (16–128 wide, with rows above it) *and*
that has a lane-invariant single-use producer to share is tiled rows ×
lanes with that producer inlined and staged cooperatively; otherwise one
with fewer than 2¹⁴ points and a reduce axis ≥ 64 is split across a
256-thread workgroup; everything else stays one thread per point. It lands within noise of the
best hand-picked schedule for attention (tiled), rmsnorm (split) and
matmul (naive-ish; the tile does not pay here). It does not choose between
algebras — materialized scores vs online softmax — which is `autotune`'s
job.

### GPU: a whole transformer block, hand-written vs derived

The `gpu_transformer_layer` prefill path (rmsnorm → q/k/v → interleaved
RoPE → GQA causal attention (9 heads, 3 kv heads, d=64) → wo → residual →
rmsnorm → SwiGLU → residual, d_model 576, ff 1536) rebuilt as one tensor
IR graph (`tang_bench::ir_block`) and run under `substitute_maps` +
`stabilize_softmax` + `schedule_auto`. Identical weights; outputs agree
with the hand path and with the f64 interpreter to 5e-7.

| seq | hand | ir_auto | ir_tuned |
|---|---|---|---|
| 128 | 5.07 ms | 4.63 ms | **4.45 ms** |
| 512 | 24.1 ms | 14.3 ms | **13.9 ms** |

`ir_tuned` is the per-kernel autotuner's schedule, measured once per
(program, device) and kept in a `TuningCache` file (`crates/tang-bench/
target/tang-tuning-block-<seq>-<kv>.txt`); later runs load it.

Decode (one query token against a rotated k/v cache, the launch-bound
regime where hand kernels were expected to look best):

| q / kv | hand | ir_auto | ir_tuned |
|---|---|---|---|
| 1 / 256 | 4.75 ms | **2.96 ms** | 2.98 ms |
| 1 / 1024 | 7.78 ms | 2.79 ms | **2.73 ms** |

The derived block issues 10 kernels to the hand path's ~16 and its
attention kernel reads the cache once; both matter when every dispatch
costs more than the math.

(10 kernels; `examples/block_kernels.rs` times each one. An earlier
version of `schedule_auto` lane-tiled the plain k/v projections and lost
1.5 ms to it — the tile only pays when there is a lane-invariant
sub-computation to share, which is now the rule.)

GQA's `head / heads_per_group` is not affine, so heads are expressed as
`[groups, per_group]` dims and the views do the rest; the causal mask is an
input. Nothing in the compiler knows what a transformer is.

### Per-kernel autotuning

`ir_gpu::autotune_kernels` times every thread mapping in
`schedule_candidates` for each materialized comp on the device, with the
graph's real inputs in place, and keeps the fastest
(`examples/block_autotune.rs`). Candidates: one thread per point, a
256-thread split, rows × lanes, and the classic 16×16 shared-memory tile.

| seq | hand | `schedule_auto` | autotuned |
|---|---|---|---|
| 128 | 4.93 ms | 4.07 ms | 4.03 ms |
| 512 | 24.3 ms | 15.3 ms | **13.5 ms** |

The tuner agrees with `schedule_auto` on every reduction and attention
kernel and overrides it on three projection matmuls, where the 16×16 tile
wins at these shapes (128×576×1536: tiled 1.39 ms vs one-thread-per-point
2.66 ms vs hand 2.97 ms) although it lost at 1024². That is the whole
argument in one table: the right schedule depends on the shape and the
chip, and measuring beats remembering.

### Derived backward pass

`ir_block_gpu::tests::derived_block_backward_on_gpu` differentiates the
whole block (`backward` on the algorithm graph), runs the gradient graph
through `substitute_maps` + `schedule_auto` + `to_wgsl`, and compares the
GPU gradients w.r.t. the input and `wq` against the f64 interpreter:
max error 5e-7, 42 kernels. There is no hand-written backward kernel for
any of it; rope and GQA gradients come out of the `iota`-gated scatter.

### GPU: a training step, hand-written vs derived

`GpuTrainTransformerBlock` is tang-gpu's hand-written trainable block (no
rope, no biases; its attention backward runs on the CPU over copied
activations — nobody wrote the GPU version). The derived step is the same
block built in IR with `rope: false, bias: false`, `backward` for the
input and all seven weights, then `substitute_maps` + `schedule_auto` +
`to_wgsl`, one program. All nine outputs match to ~1e-6.

| seq | hand fwd+bwd | derived fwd+bwd |
|---|---|---|
| 32 | 60.9 ms | **4.87 ms** |
| 128 | 174 ms | **10.1 ms** |

The asymmetry is the point: the hand path has a fast forward and a slow
backward because a GPU backward for attention was never written. The
derived path has neither problem, because nothing about it was written.

### A derived training loop

`examples/train_loop.rs`: block forward + MSE loss + backward for every
weight as one 47-kernel program, Adam as one program per weight (bias
corrections are a 2-element input, updated each step), new weights and
moments fed back GPU-side with `GpuBuffer::copy_from`. Loss on a fixed
target: 0.606 → 0.038 in 30 steps. Nothing in the loop is hand-written.

## M4 Max, one consistent run (2026-10-12, final branch state)

The sections above were measured on different days as the branch grew
and the machine's power state wandered. This table is one run of
`cargo bench -p tang-bench --bench kernels_vs_ir -- kvi_gpu` on the final
code; the readback floor during this run was ~1.8 ms (the machine was in
its slow state, so absolute times are ~1.5× the earlier sections).

| op | hand | best derived | schedule |
|---|---|---|---|
| causal attention 128 | 3.70 ms | **1.82 ms** | tiled |
| causal attention 512 | 4.91 ms | **2.02 ms** | auto (tiled) |
| causal attention 1024 | 10.9 ms | **3.31 ms** | naive (n² threads) |
| matmul 1024² | 6.68 ms | 5.49 ms | auto |
| rmsnorm 2048×2048 | 2.52 ms | 2.70 ms | auto (split) |
| swiglu 4M | 2.50 ms | 2.71 ms | map |
| adam step 4M | 2.67 ms | 2.71 ms | map |
| transformer block seq 128 | 5.02 ms | **3.74 ms** | auto |
| transformer block seq 512 | 23.9 ms | **10.1 ms** | per-kernel autotune |
| decode block q1 / kv 256 | 5.29 ms | **2.13 ms** | auto |
| decode block q1 / kv 1024 | 8.80 ms | **3.28 ms** | per-kernel autotune |
| training step seq 32 | 65.8 ms | **4.73 ms** | auto |
| training step seq 128 | 179 ms | **7.96 ms** | auto |

## Kernels vs tensor IR on an RTX 3090 (Vulkan)

**Date:** 2026-10-12. Ubuntu 24.04, driver 580, wgpu Vulkan backend. Same
branch, same code, no per-chip knowledge anywhere in the compiler; the
tuning cache is keyed by device name. Readback floor is ~1.25 ms here.

All 11 GPU tests pass with the same ~1e-6 errors as on the M4.

| op | hand | best derived | schedule |
|---|---|---|---|
| causal attention 1024, d=64 | 3.85 ms | **1.40 ms** | tiled rows×lanes |
| causal attention 512 | 1.88 ms | 1.42 ms | tiled |
| matmul 1024² | 2.31 ms | 2.35 ms | 16×16 tile |
| rmsnorm 2048×2048 | 5.96 ms | 6.05 ms | naive (16 MB readback) |
| swiglu 4M | 6.62 ms | 6.22 ms | map |
| adam step 4M | 5.88 ms | 5.97 ms | map |
| transformer block seq 128 | 3.13 ms | **2.50 ms** | per-kernel autotune |
| transformer block seq 512 | 10.4 ms | **6.20 ms** | per-kernel autotune |
| decode block q1 / kv 256 | 2.49 ms | 1.71 ms | per-kernel autotune |
| decode block q1 / kv 1024 | 3.85 ms | 1.68 ms | auto |
| training step seq 32 | 53.6 ms | **3.71 ms** | auto |
| training step seq 128 | 175 ms | **9.64 ms** | auto |

What the second chip taught the compiler (all of it landed in this
branch):

- The block initially *lost* here (5.5 ms vs 3.0) while winning on the
  M4. Per-kernel profiling showed `substitute_maps` folding the
  normalization, residual add and SwiGLU activation (with its `exp`) into
  the projection matmuls' bodies — recomputed once per output column.
  The M4 shrugged; the 3090 did not. Substitution is now cost-aware.
- Folding a matmul into its bias-add map (one thread per point) hid the
  reduction from every tiled schedule. Reductions now stay materialized
  under maps; that is what let the autotuner pick the 16×16 tile for the
  projections and take the block from 5.1 ms to 2.5 ms.
- The staged tiles were laid out point-major, so consecutive lanes read
  words 32 apart: 32-way bank conflicts. Point-minor layout took the
  16×16 matmul tile from 6.25 ms to 2.35 ms (hand parity) on the 3090
  and changed nothing on the M4.
- `schedule_auto`'s rules of thumb were distilled on the M4 and are
  wrong for matmul here (naive 2.77 vs tiled 2.35); `split` on a 66-wide
  tuple is catastrophic on NVIDIA (59 ms). The per-kernel autotuner is
  the answer on both chips, with the rules as its starting point.

M4 figures earlier in this file were measured on a different day;
absolute times on that machine drift by ±2× with its power state (the
same commit measured 1.35 ms and 3.8 ms for tiled attention an hour
apart). Compare columns within one table, not across days.

## Register tiles (both chips)

`TNode.reg = (rx, ry)`: each thread owns an rx×ry block of points of a
16×16-thread tile, with its own accumulators and hoisted reads; the
staged tiles grow to 64×64 points. Same emitter, same staging rules —
the only new idea is "more than one point per thread". Matmul 1024²,
`cargo bench ... kvi_gpu_matmul`:

| | hand | one point/thread tile | 2×2 | 4×4 |
|---|---|---|---|---|
| M4 Max (floor ~1.8 ms) | 6.82 ms | 5.74 ms | 5.51 ms | **5.23 ms** |
| RTX 3090 (floor ~1.25 ms) | 2.27 ms | 2.41 ms | 1.98 ms | **1.92 ms** |

Kernel-only that is roughly 1.5× the hand matmul on both chips. With the
register tiles in the autotuner's candidate list the transformer block
moves again (per-kernel autotune, fresh cache):

| block | hand | derived, autotuned |
|---|---|---|
| M4 seq 128 | 5.02 ms | **3.65 ms** |
| M4 seq 512 | 23.9 ms | **5.61 ms** |
| 3090 seq 128 | 4.94 ms | **3.89 ms** |
| 3090 seq 512 | 13.1 ms | **6.71 ms** |

(3090 hand numbers in this run are ~50% above the earlier run on the same
code; that box was not idle. The derived column moved by the same factor.)

### `schedule_auto` after the second chip

With the register-tiled matmul in its rules, `schedule_auto` alone — no
measurement — now beats the hand path on both chips:

| block, rules only | hand | derived (`schedule_auto`) |
|---|---|---|
| M4 seq 128 | 5.87 ms | **3.44 ms** |
| M4 seq 512 | 23.9 ms | **5.55 ms** |
| 3090 seq 128 | 3.05 ms | **2.61 ms** |
| 3090 seq 512 | 10.8 ms | **5.58 ms** |
| matmul 1024², M4 | 6.81 ms | **4.61 ms** |
| matmul 1024², 3090 | 2.27 ms | **1.90 ms** |

The tuner still exists for the next chip; the rules are what it found.

### Training step at seq 512

| | hand fwd+bwd | derived fwd+bwd |
|---|---|---|
| M4 Max | 1.01 s | **17.5 ms** |
| RTX 3090 | 1.15 s | **11.3 ms** |

The hand path's CPU-side attention backward is quadratic in sequence
length; the derived one is a graph like any other.

### Placement

`shard_reduction` splits a reduce axis into partial reductions (one per
device) and `fold_partials` writes the all-reduce as a comprehension over
the monoid's combine. `examples/shard_attention.rs` runs the flash-fused
attention's 256 keys as two partial (m, l, acc) states on two wgpu
devices and merges them with the online-softmax combine: max error
1.7e-6 (M4) / 1.4e-6 (3090) against the single-device result. Transport
is host-mediated; the IR side of sequence parallelism is done.

## Against PyTorch (RTX 3090, kernel-only)

Everything above compares derived kernels with tang's own hand-written
ones, and every criterion number includes ~1.3 ms of submit + readback.
This section is the comparison that matters: `scripts/torch_bench.py`
(PyTorch 2.10 + cu128, CUDA events, fp32 with TF32 off) against
`examples/kernel_only.rs` (50 launches, one sync, divide) on the same
3090, same shapes.

| op | tang hand | tang derived (best) | PyTorch fp32 | derived ÷ torch |
|---|---|---|---|---|
| matmul 1024² | 1.38 ms | 0.54 ms (4×4 register tile) | **0.112 ms** (TF32: 0.079) | 4.8× |
| matmul 128×576×1536 | 0.38 | 0.20 | **0.030** | 7× |
| matmul 512×576×1536 | 0.65 | 0.28 | **0.053** | 5× |
| causal attention n=512, d=64 | 1.31 | 0.27 | **0.090** (sdpa) / 0.040 (naive) | 3–7× |
| causal attention n=1024 | 3.55 | 0.77 | **0.180** / 0.078 | 4–10× |
| transformer block fwd, seq 128 | 2.25 | 1.97 | **0.295** | 6.7× |
| transformer block fwd, seq 512 | 10.1 | 4.41 | **0.610** | 7× |
| block fwd+bwd, seq 128 | (CPU bwd) | 5.0 | **1.32** | 3.8× |
| block fwd+bwd, seq 512 | (CPU bwd) | 10.1 | **1.73** | 5.9× |
| adam step 4M | 0.85 | 0.54 | **0.395** | 1.4× |

So the derived kernels are 2–4× faster than tang's hand-written ones and
4–7× slower than PyTorch. Both statements are true; only the second one
says how fast this is.

Where the gap is, and how much of it this path can close:

- **Matmul instruction quality.** 0.54 ms at 1024² is ~4 TFLOPS; cuBLAS
  fp32 reaches ~19 TFLOPS on this part. The derived tile uses scalar
  loads, a 4×4 register tile, 32-wide chunks with a barrier each, and no
  double buffering. An 8×8 register tile with `vec4` loads and a 128×128
  block is the known recipe for ~10–15 TFLOPS in a portable shader —
  roughly 3× from here, within ~2× of cuBLAS. That is the ceiling for
  fp32 through WGSL.
- **Tensor cores are off the table.** TF32/FP16 MMA is not reachable from
  WGSL/wgpu today (no cooperative-matrix extension). That is the other
  2–4× PyTorch has, and it is a backend question (MSL simdgroup matrices,
  CUDA via `tang-expr`'s CUDA dialect), not a schedule question.
- **Launch overhead.** The block issued 20 kernels (72 with backward)
  when this table was taken, each as its own command buffer through
  wgpu; seq 128 forward was 1.97 ms for ~0.6 ms of math. Since then:
  one submission per program, and three fusion passes — epilogue
  fusion (bias, activation and the softmax normalizer run on the thread
  holding the final accumulator), views through affine reshapes, and
  sibling-reduction merging (gate and up projections as one
  tuple-valued matmul) — bring the forward block to 16 kernels (62
  with backward). PyTorch's 0.295 ms is ~10 cuBLAS/flash launches.
- **Attention.** Flash-attention proper keeps the (m, l, acc) state in
  registers across a 64-key tile computed as two small tensor-core
  matmuls; ours recomputes q·k cooperatively into shared memory with
  scalar FMAs. Same structure, 4–10× slower execution, for the two
  reasons above.

### After the fusion passes and vec4 stage reads

Same script, both chips, one run each. The 3090 run had the GPU to
itself (1% util); its CPU was loaded (load avg 26), which is why the
PyTorch block numbers — launch-bound on the CPU side — came out higher
than the first table's. Both PyTorch columns are shown.

| op | 3090 before | 3090 after | PyTorch (1st / this run) | M4 after |
|---|---|---|---|---|
| matmul 1024² | 0.54 ms | **0.28** (7.6 TFLOPS) | 0.112 / 0.114 | 0.52 |
| matmul 128×576×1536 | 0.20 | **0.10** | 0.030 / 0.035 | 0.13 |
| matmul 512×576×1536 | 0.28 | **0.16** | 0.053 / 0.054 | 0.23 |
| attention n=512 | 0.27 | 0.25 | 0.090 | 0.26 |
| attention n=1024 | 0.77 | 0.74 | 0.180 | 0.76 |
| block fwd, seq 128 | 1.97 | **1.06** (16 kernels) | 0.295 / 0.566 | 1.14 |
| block fwd, seq 512 | 4.41 | **3.34** | 0.610 / 1.208 | 3.37 |
| block fwd+bwd, seq 128 | 5.0 | **3.15** (62 kernels) | 1.32 / 2.11 | 3.53 |
| block fwd+bwd, seq 512 | 10.1 | **8.19** | 1.73 / 1.99 | 13.2 |
| adam 4M | 0.54 | 0.47 | 0.395 / 0.451 | — |

What moved it:

- **Fusion** (epilogues for tuple-state reductions, views through
  affine reshapes, sibling merging) plus one submission per program:
  the launch-bound seq-128 block, −46% forward, −37% training step.
- **`vec4` reads of the point-minor stage.** A thread's register-tile
  points are contiguous there, so a 4-wide tile reads each operand as
  one vector per r0 instead of four scalars: matmul 1024² 0.54 → 0.28 ms
  on the 3090 and 0.78 → 0.52 on the M4. This is the shared-memory
  load-issue bound the previous section predicted; the next rungs on the
  same ladder are 8×8 tiles with vec4 (now that loads are cheap enough
  to feed them), `vec4` global loads into the stage, and double
  buffering.
- Coalesced staging loads alone changed nothing measurable; the tile
  was never global-load bound at these sizes.
- With vec4 reads in place, a sweep of 8×8 register tiles (chunk 8, 16,
  32), an 8×8-thread block and a 32×8 block at 1024² still lands on
  16×16 threads × 4×4 × chunk 32 on both chips (3090: 0.29 ms vs 0.35
  for 8×8; M4: 0.53 vs 0.50 for 8×8 chunk 16 — within noise), so
  `schedule_auto`'s rule stands. 8×8 is register-pressure bound: more
  FMAs per load but fewer workgroups in flight.
- Double-buffered staging (two stage sets, next chunk prefetched into
  registers during the reduce loop, one barrier per chunk) was tried and
  reverted: on the M4 the dynamically indexed prefetch arrays spill and
  the 4×4 chunk-32 tile went from 0.53 to 3.2 ms; on the 3090 it was
  neutral (0.28–0.33). Without async copies, the extra registers cost
  more than the hidden latency is worth on either chip.

The gap to PyTorch is now 2.5× on matmul, 3–4× on attention and the
block forward, 4× on the training step (against its quieter numbers).
What remains is tensor cores (unreachable from WGSL; a backend
question) and the rest of the instruction-quality ladder above.

### A native dialect: Metal simdgroup matrices (first cut)

`tensor_msl.rs` lowers a matmul-shaped tile — one reduce axis, body
`a·b`, each operand read along one tile axis and the reduce axis, any
affine layout — to MSL with `simdgroup_float8x8` fragments, through
wgpu 25's MSL passthrough. The comp's epilogue (bias, activation) runs
on the stored block. Kernels that don't fit stay WGSL, so a program is a
mix. Correct on ragged shapes (staged tiles) and full tiles (fragments
loaded straight from device memory); 12/12 GPU tests.

M4 Max, kernel-only (`mma` column of `kernel_only`):

| shape | WGSL 4×4 register tile | simdgroup matrices |
|---|---|---|
| 1024² | 0.56 ms | 0.93 |
| 128×576×1536 | 0.13 | 0.27 |
| 512×576×1536 | 0.25 | 0.48 |

So on this chip the first-cut fp32 simdgroup kernel is 1.7–2× *slower*
than the FMA tile. Ablations: the staged version spent two thirds of
its time in scalar staging; fragments straight from memory halved
that but the MMA loop itself runs at ~2.3 TFLOPS, where the FMA tile
runs at 3.7. MLX's fp32 GEMM on the same hardware shows what the
instruction is worth with vectorized staging, swizzled tiles and
deeper software pipelining; that is engineering on top of a lowering
that now exists, and `program_for` keeps WGSL the default until it
wins. The structural claim stands: the same comprehension lowered to a
second dialect with no op-specific code, epilogue included. The CUDA
dialect (tensor cores proper, where the gap to PyTorch lives) is the
same shape of work with nvcc in the loop.

### Tensor cores: the CUDA dialect (RTX 3090, nvcc harness)

The same bilinear tile lowered to CUDA C++ with `wmma` 16×16×8 TF32
fragments (`tensor_cuda.rs`; 64×64 block, four warps of 32×32, operands
staged through shared memory from any affine layout, epilogue on the
stored block). tang-gpu runs on wgpu and cannot dispatch CUDA, so this
is measured by `scripts/cuda_bench.cu`: the derived kernel and
`cublasSgemm` (fp32, then `CUBLAS_TF32_TENSOR_OP_MATH`) on the same
device, CUDA events, 50 launches. Error is against fp32 cuBLAS; TF32
inputs give ~1e-3 relative, as expected.

| shape | tang wmma (TF32) | tang WGSL (fp32) | cuBLAS fp32 | cuBLAS TF32 |
|---|---|---|---|---|
| 1024² | **0.150 ms** (14 TFLOPS) | 0.28 | 0.113 | 0.079 |
| 1024² + bias + silu epilogue | 0.159 | — | 0.107 (+ separate kernels) | 0.079 |
| 128×576×1536 | 0.052 | 0.10 | 0.031 | 0.015 |
| 512×576×1536 | 0.091 (10 TFLOPS) | 0.16 | 0.053 | 0.048 |
| 4096³ | 6.58 (21 TFLOPS) | — | 5.67 | 3.98 |

First cut, no tuning: 1.4–1.9× cuBLAS TF32 at the LLM shapes, 1.65× at
4096³, with the bias/activation epilogue fused for free (cuBLAS needs
extra launches for that). The remaining gap is the standard GEMM
engineering — 128×128 blocks with 8 warps, `cp.async` double buffering,
`ldmatrix`-friendly swizzles — on top of a lowering that now exists.
Together with the WGSL numbers above this is the whole picture: the
derived kernels are 2–4× faster than tang's hand kernels through the
portable path, and within 2× of cuBLAS through the native one, from one
comprehension and no op-specific code.

### The whole block on CUDA (`to_cuda` + cudarc, RTX 3090)

`TensorGraph::to_cuda` emits a program for the CUDA driver: matmul-shaped
tiles as the wmma kernel above, every other kernel the WGSL transpiled
to CUDA C++ (generated WGSL is regular enough that a line-level
translation with a 20-line prelude covers the naive, split and tile
emitters — no second emitter). `tang_bench::ir_cuda::CudaExecutable`
compiles with nvrtc and launches in program order. Two layout passes
landed on the way: `relayout` (a producer's point dims reordered to
its consumer's reads) and `merge_reduce_dims` (adjacent reduce dims
read contiguously fold into one), which turn the attention-output
projection Σ_{g,r,d} into a 576-wide matmul — so 5 of the block's 16
kernels run on tensor cores.

| | CUDA (5 kernels on tensor cores) | Vulkan/WGSL | PyTorch fp32 |
|---|---|---|---|
| block fwd, seq 128 | **0.62 ms** | 1.06 | 0.30 / 0.57 |
| block fwd, seq 512 | **1.86 ms** | 3.34 | 0.61 / 1.21 |

Per kernel at seq 512: five wmma matmuls 0.05–0.18 ms each, the
elementwise and split kernels 2–14 µs each (the Vulkan path's ~0.1 ms
per-kernel floor is gone), and the attention tile 1.25 ms — two thirds
of the total. Correctness: 5e-5 relative against the f64 evaluation at
seq 128 (TF32 inputs).

### Attention on tensor cores

`cuda_flash_kernel` recognizes the fused attention comp — an
online-softmax reduction over keys whose score is an inlined bilinear
comp (here two terms, the rope even/odd halves) plus a mask over
(i, j), whose value is a read along (j, lane), and whose normalizer is
the epilogue map — and emits a flash kernel: 64 queries per 128-thread
block, keys in 64-chunks, `S = Σ_t Q_t·K_tᵀ` and `O += P·V` as wmma
TF32 fragments, the online softmax on the stored score block with the
comp's own mask/value/normalizer expressions evaluated where they
belong. Nothing attention-specific is hard-coded beyond that shape.

| | before | after |
|---|---|---|
| attention kernel, seq 128 | 0.098 ms | **0.042** |
| attention kernel, seq 512 | 1.25 | **0.150** |
| block fwd, seq 128 | 0.62 | **0.59** |
| block fwd, seq 512 | 1.86 | **0.76** |

Six of the block's sixteen kernels now run on tensor cores. Back to
back in one session (GPU shared with another tenant at ~27%), the
like-for-like comparison — tang's CUDA path uses TF32 tensor cores, so
PyTorch gets `allow_tf32` too:

| block forward | PyTorch fp32 | PyTorch TF32 | tang (CUDA, TF32) |
|---|---|---|---|
| seq 128 | 0.32 ms | 0.34 | 0.59 |
| seq 512 | 0.98 | 0.48 | **0.78** |

So at seq 512 the derived block is 1.6× PyTorch-TF32 and faster than
PyTorch-fp32; at seq 128 it is launch-bound (16 launches to PyTorch's
~10 fused cuBLAS/sdpa calls) at 1.8×. The remaining per-kernel time is
the matmul tiles at 1.4–1.9× cuBLAS TF32 and the ten small kernels at
a few µs each; the next rungs are the standard GEMM ladder (128×128
blocks, `cp.async` pipelining) and fusing the small kernels into their
neighbours' prologues. Same error as before (5e-5 relative at seq
128).

### Training step on CUDA, and choosing per kernel

The training step (forward + every gradient, 62 kernels) runs through the
same path. Two more lowering generalizations went in: bilinear tiles
with several terms (rope's even/odd halves) and several outputs (the
merged gate/up projection as one width-2 wmma tile, operands staged
once). The width-2 tile turned out *slower* than the WGSL tile for
gate/up (0.25 vs 0.18 ms at seq 512: its stored-C block doubles shared
memory and halves occupancy). Instead of a threshold,
`CudaExecutable::new_tuned` compiles the program with the native
lowerings on and off — same kernels, same bindings — and keeps, per
kernel, whichever is faster on the device. It keeps 4 of 7 native
forward kernels at seq 128, 3 of 7 at seq 512, and 9–13 of 21 in the
training step.

| | tang CUDA (tuned) | PyTorch fp32 | PyTorch TF32 |
|---|---|---|---|
| block fwd, seq 128 | 0.58 ms | 0.32 | 0.34 |
| block fwd, seq 512 | 0.81 | 0.98 | 0.48 |
| block fwd+bwd, seq 128 | 2.18 | 1.46 | — |
| block fwd+bwd, seq 512 | 4.80 | 2.15 | — |

(3090 shared with another tenant; run-to-run spread on the training step
is about ±15%.) The forward is at PyTorch's level; the training step is
1.5–2.2× behind, and its slowest kernels are the attention backward
(score recomputation and the online-softmax gradient, not on tensor cores
yet) — a flash-backward lowering is the same kind of work as the forward
one.

### Toward flash backward: three generic scheduling fixes

The training step's breakdown showed its time spread over attention-backward
kernels that were scheduled badly for generic reasons, not for lack of an
attention-specific lowering:

- **Tiles need reuse.** `schedule_auto`'s matmul rule now requires an
  operand shared along the lanes and one shared along the rows; `Σⱼ` and
  `maxⱼ` over the 512×512 attention tensors (no operand shared across a
  tile) become split reductions instead of staging-only tiles.
- **`split_reduce_dims`.** A reduction over several dims with a small one
  (≤ 16) becomes an inner reduction over the rest — keeping the small dim
  as a leading point dim — and an unrolled monoid fold. dK for grouped
  heads, `Σ_{r,i} dS·q`, becomes `Σ_r (Σ_i …)`, and the inner one tiles
  (0.46 → 0.19 ms at seq 512).
- **Recompute big maps in every reducing consumer.** A map all of whose
  consumers reduce, and that is bigger than their outputs, is inlined
  into each of them and staged cooperatively — dS (n² per head) is
  recomputed inside the dQ and dK tiles instead of written out, which is
  the flash-backward structure.

`CudaExecutable` and `torch_bench.py` now both report the minimum over
five batches. End-to-end numbers after these changes are pending a quiet
window on the 3090: during this session it ran at 99% utilization from
other jobs (two RL trainers, a voice model, an image server, video
encodes), which slowed PyTorch's reference run by 2–3× as well.

### Main after #42–#47, RTX 3090

This is the state after the CUDA backend in tang-gpu (#43), split-K (#44), whole-model compilation (#45) and the flash-backward contractions (#47), at commit `4a033e4`.

Method: four rounds under `flock ~/tang-gpu.lock`, with GPU utilization from other tenants between 1% and 98%. Both sides report the minimum over five batches.
- tang's numbers moved less than 3% across the rounds.
- PyTorch's moved 2–4×, so the PyTorch column is the best value seen in any round.
- tang runs its matmuls and attention as TF32 on tensor cores. PyTorch is shown in fp32 and, where `torch_bench.py` measures it, TF32.

| | tang (CUDA) | PyTorch best (fp32 / TF32) | ratio |
|---|---|---|---|
| block fwd, seq 128 | **0.27 ms** | 0.29 / 0.31 | tang 1.1× faster |
| block fwd+bwd, seq 128 | **0.69** | 1.28 / — | tang 1.85× faster |
| block fwd, seq 512 | 0.72 | 0.60 / **0.45** | PyTorch TF32 1.6× faster |
| block fwd+bwd, seq 512 | 1.94 | **1.72** / — | PyTorch 1.13× faster |
| 4-layer training step (fwd + bwd + AdamW), seq 128 | **3.60** (planned, in place, CUDA graph) | 4.27 fused AdamW | tang 1.2× faster |
| 4-layer step, peak memory | **229 MB** | 239 MB fused AdamW / 293 foreach | |

Per kernel, the tuner keeps every tensor-core lowering at seq 512 (23 of 23 in the training step) and 20 of 23 at seq 128.

What's left at seq 512:
- The forward is behind TF32 PyTorch because its attention and matmul tiles are 64×64 blocks with TF32 fragments. The 128×128/8-warp tiles and `cp.async` pipelining are still to do.
- The training step's remaining attention-backward tensors (S, P̃, dP and two correction terms) are still materialized; see #47.

What this does and does not show: the compiler derives the *structure* of
the fast kernels (flash attention, register-tiled matmul, sequence
parallelism) from the algebra, with no op-specific code, and picks per
chip. It does not yet generate the instruction-level quality of a vendor
library, and through this backend it cannot reach tensor cores at all.

### Flash backward on tensor cores (CUDA)

Two generalizations of the existing lowerings, recognized from the comps
`backward` produces (`dump_train_cuda` prints them), no attention API:

- **State-materializing forward.** `flash_tile` also matches an
  online-softmax reduction whose score is read from a buffer (the training
  step keeps `S` for the backward) and one that is itself the root,
  writing its `(m, l, acc)` state. The score block is staged from the
  buffer (keys fastest), `O += P·V` stays on wmma. Key tiles that the
  affine mask covers are skipped (`score_mask`, now shared with the Metal
  attention plan), and the block drops to two warps when four would leave
  the device under-filled.
- **dS recomputed in the dQ/dK tiles.** `bilinear_tile` accepts an operand
  that is an inlined map over buffers and iotas; `cuda_mma_kernel`
  evaluates the map while staging, each read composed through the map's
  view, in the order of the buffer it reads along the most dims. dS
  (`schedule_auto` already inlines it into every reducing consumer) is
  rebuilt inside the dK tile (both rope halves, width 2) and the two dQ
  tiles from `S`, `max`, `dP` and the two correction terms.

Per kernel (`cuda_train_kernels`, min of 10; the 3090 at 98–99%
utilization from other tenants throughout, so ±30% between runs):

| kernel | seq 128 WGSL | native | seq 512 WGSL | native |
|---|---|---|---|---|
| online-softmax forward `[3,3,n,1,64,3]` | 0.070 | 0.029–0.037 | 0.254 | 0.119–0.125 |
| dK (both halves), Σ over queries | 0.020 | 0.037 | 0.193 | 0.108 |
| dQ half 1, Σ over keys | 0.015 | 0.026 | 0.131 | 0.087 |
| dQ half 2 | 0.015 | 0.026 | 0.131 | 0.087 |

Sum of best-per-kernel: 0.82 → 0.78 ms (seq 128), 2.35 → 2.06 ms (seq 512).
At seq 128 the dQ/dK tiles lose (18 blocks); `Program::tuned` keeps the
WGSL ones there. Gradients at seq 128 against the f64 evaluation: relative
1.5–3.1e-4 on every weight gradient (unchanged from before; TF32). dwq and
dwk are ~4e-19 in the reference (the loss does not reach them at this
scale) — absolute error 2.7e-19, i.e. zero at the gradients' scale (1e6),
so only the absolute error is meaningful there.

Training step in one lock window (two alternating rounds, base = #46):

| | base | this | PyTorch fp32 |
|---|---|---|---|
| block fwd+bwd, seq 128 | 1.68 / 2.39 | 1.52 / 1.95 | 2.11 |
| block fwd+bwd, seq 512 | 5.88 / 7.10 | 5.91 / 5.30 | 5.07 |
| `whole_model 4 128 cuda`, one block × 4 | 13.2 | 8.0 | — |

(PyTorch's own reference was 2–3× slower than in a quiet window too: its
seq-512 step is 1.85–2.15 ms when the GPU is free.) Under this load the
end-to-end difference is inside the noise; the per-kernel table is the
measurement that holds.

Negatives:

- Causal tile skipping did not change the forward's time (0.123 vs 0.125
  ms): 72 blocks on 82 SMs, the last row block (no skipping) is the
  critical path. Two warps per block (144 blocks) is ~5% faster; one warp
  (288) is slower at seq 512 (0.200 ms: V staged once per 16 rows).
- The dQ/dK tiles cannot skip masked tiles: dS has the max-gradient term
  (`select(s == max)`) outside the masked exponential, so a masked
  element is not provably zero from the comp.
- The two dQ halves recompute dS twice: `merge_siblings` runs before
  `schedule_auto` inlines dS, so they are not merged.
- Not yet flash backward in full: S, P̃ = exp(S − max), dP and two n×n
  correction terms are still materialized by their own kernels (≈ 0.25 ms
  at seq 512). Recomputing them in the tiles needs dP = dO·Vᵀ as a nested
  contraction inside the staging, which this lowering does not do.

### Split-K for tiles that cannot fill the device

The training step's matmuls with small outputs and long reductions
(dx through the 1536-wide MLP, the grouped-head dK/dV over 1536 or 512)
had 24–72 64×64 blocks for 82 SMs. `cuda_mma_kernel` now splits the
reduction until there are about 246 blocks (each split keeps ≥ 4 chunks):
each split stores its partial block to a module-scope buffer, the last
to arrive (an atomic counter per tile, reset after use) sums the splits
in fixed order and runs the epilogue. Multi-output tiles whose stored C
would outgrow the operand stages use the same global path, so their
shared memory is the stages only — the merged gate/up tile now beats the
WGSL one instead of losing on occupancy. With that, the tuner keeps all
19 native kernels in the training step (was 13 at seq 128, 12 at 512).

Per-kernel timing is now the minimum over single event-bracketed
launches: the 3090 was at 98% from other tenants (time-sliced), and
batched wall-clock put a ~0.23 ms slice floor under every kernel.
Kernel times below are contention-free; end-to-end ones are not.

| kernel (seq 512) | before (best of native/WGSL) | split-K |
|---|---|---|
| dx, `[512,3,64]` Σ over 1536 | 0.146 ms | 0.044 |
| dx MLP down, `[512,576]` Σ 1536 | 0.172 | 0.106 |
| gate/up backward, `[512,576,2]` Σ 1536 | 0.312 | 0.203 |
| gate/up forward, `[512,1536,2]` Σ 576 | 0.209 | 0.150 |
| q/k/v/o projections, `[512,192|576]` Σ 576 | 0.050–0.054 | 0.025–0.040 |
| sum of all 62 kernels | 2.89 | 2.36 |
| sum of all 62 kernels, seq 128 | 1.34 | 0.83 |

End to end, same lock window (contended; torch slowed too):

| | tang before | tang split-K | PyTorch fp32 | PyTorch TF32 |
|---|---|---|---|---|
| block fwd, seq 128 | 1.61 ms | 0.55 | 0.56 | 0.52 |
| block fwd, seq 512 | 1.60 | 1.22 | 1.27 | 0.92 |
| block fwd+bwd, seq 128 | 2.87 | 1.59 | 2.38 | — |
| block fwd+bwd, seq 512 | 5.78 | 4.79 | 3.60 | — |

Every gradient matches the f64 evaluation as before (relative error
1.5–3e-4 on gradients of magnitude 1e6, identical with split-K off).
Remaining at seq 512: the materialized online-softmax forward (0.25 ms,
score from a buffer, no native lowering yet), the attention-backward
reductions over 512 keys at tile (32, 8, 32) (0.19, 0.13, 0.13 ms, no
native lowering) — the flash-backward work — and the 512×512 score
recomputations.

### The GEMM ladder: `mma.sync`, `cp.async`, block shapes as candidates (RTX 3090)

`cuda_mma_kernel` is rewritten on raw PTX instead of `wmma`. It is still generic over any affine operand layout, multi-term and multi-output tiles, and split-K.
- `mma.sync` m16n8k8 TF32 with documented fragment layouts. The epilogue (bias, activation, split-K partials and their reduction) runs straight from the accumulator registers, so the stored-C shared block is gone.
- `cp.async` staging into a ring of `stages` buffers (16-byte copies where the shared row is contiguous and aligned in global memory, 4-byte zero-filling copies for any other layout, synchronous stores for map operands). One barrier per chunk, and the next k step's fragments load while this one's mma issue.
- Fragments read as `float2`: the k slots and the columns inside a fragment pair are permuted (a reduction is order-free, and output columns are ours to place). Padding is chosen so these reads are conflict-free (A stride ≡ 8, B ≡ 4 mod 32).
- TF32 rounding as one integer add (`x + 0x1000`; the mma ignores the low 13 bits). This is the same round-to-nearest-away as `cvt.rna`, which is emulated in about 4 instructions on sm_86. Errors are unchanged.
- Staging loops have a fixed trip count where threads tile the block evenly, so the index math hoists out of the k loop.

The block shape is a schedule parameter, `MmaShape { bm, bn, warps, chunk, stages, split_target }`. `MMA_SHAPES` lists six candidates: 64×64/4 warps with chunk 32 and 3 stages; the same without split-K; chunk 16 with 4 stages; chunk 32 with 2 stages and the old split-K target of 246; 128×64/4 warps; and 128×128/8 warps. `Program::tuned` now times every distinct variant of every native kernel against the transpiled WGSL, keeps the fastest per kernel, and caches the choice.

Per matmul, nvcc harness (`scripts/cuda_bench.cu`, which now reports the minimum over 10 batches of 20 launches), quiet GPU:

| shape | before (wmma) | default shape | best shape | cuBLAS fp32 | cuBLAS TF32 |
|---|---|---|---|---|---|
| 1024² | 0.144 ms | 0.103 | **0.088** (128×128/8w) | 0.105 | 0.079 |
| 512×576×1536 | 0.085 | 0.051 | **0.046** (64², k16×4) | 0.052 | 0.046 |
| 512×576×192 | 0.024 | 0.024 | **0.016** (64², no split) | 0.016 | 0.013 |
| 512×1536×576 | 0.110 | **0.040** | 0.040 | 0.075 | 0.042 |

The derived tiles now match or beat cuBLAS TF32 at the model's two large shapes. They are 1.1× behind it at 1024² and 1.25× behind at the small q/k/v projection.

Flash forward: fold the grouped-query heads into the block. A lead dim that neither the keys, the values nor the mask depend on (the 3 query heads sharing a K/V head) becomes part of the block's rows, so K and V are staged once for all of them. The query slice per head is picked so the device still fills (16 rows × 3 heads at seq 512).

| attention forward kernel | before | folded |
|---|---|---|
| seq 128 | 0.053 ms | **0.046** |
| seq 512 | 0.287 | **0.177** |

End to end, same lock window, 4 interleaved rounds. tang varied less than 2%. PyTorch is the best of the rounds; it was clean only in the first window, 22:19, and 2–4× slower under load at 22:54.

| | tang main (#49) | tang now | PyTorch best fp32 / TF32 |
|---|---|---|---|
| block fwd, seq 128 | 0.263 ms | **0.210** | 0.300 / 0.307 |
| block fwd+bwd, seq 128 | 0.682 | **0.572** | 1.232 / — |
| block fwd, seq 512 | 0.726 | 0.48–0.49 | 0.593 / **0.454** |
| block fwd+bwd, seq 512 | 1.939 | **1.574** | 1.721 / — |

Correctness:
- forward at seq 128: 7.8e-5 relative to the f64 evaluation, unchanged;
- training-step gradients: 2.6–3.1e-4 relative, for every one of the six block shapes forced in turn (`TANG_MMA_VARIANT`), the same as before.

Negatives, measured and not kept as defaults:
- 128×128 blocks lose at every model shape: there are too few tiles for 82 SMs (8–24 blocks). They only win at 1024². With 4 warps of 64×64 they lose even there (0.13–0.17 ms), and so do 128×64 blocks at these sizes.
- Split-K at the old target (246 blocks) is now a loss on most shapes. The faster mainloop makes the partial round trip dominate (512×1536×576: 0.040 without split, 0.058 with it). Its target is 100 by default and it remains a candidate; the tuner picks it for some seq-128 tiles.
- Conflict-free `float2` fragment reads: no measurable change on their own, kept because they are not slower.
- Register double-buffering of fragments across k steps: no change on its own. It is kept: it is the structure the larger warp tiles need.
- Dropping TF32 rounding altogether (raw fp32 bits): no faster than the 1-add rounding, and 3× the error.
- `asm volatile` on the mma: no difference.
- Flash with 32-query slices × 3 heads (96 rows) needs more than 99 KB of shared memory and falls back. 16 × 3 is the shape that fits and fills.

What is left at seq 512 forward (0.48 vs 0.45 ms TF32): attention is still 0.18 ms. Its O accumulator round-trips through shared memory every key chunk (wmma's accumulator layout is opaque). The next step is moving it to `mma.sync` with O in registers and K/V through `cp.async`.
### Flash attention on `mma.sync` (RTX 3090)

`cuda_flash_kernel` is rewritten on the GEMM ladder's raw `mma.sync` m16n8k8 TF32 fragments. It recognizes the same comps as before: the inference form (normalizer epilogue), the training step's state-materializing forward (score from a buffer, writes `(m, l, acc)`), folded grouped-query heads, and causal key ranges derived from the mask.
- Each warp owns 16 rows. `S = Σ_t Q_t·K_tᵀ` accumulates into registers. The comp's mask expression and the online softmax run on those registers, with the row max reduced across the fragment's quad.
- The same registers are the A operand of `O += P·V`, with no shuffle and no shared-memory round trip. The accumulator's column pair (2tq, 2tq + 1) is the A fragment's k pair (tq, tq + 4) once the keys inside each 8-wide step are permuted, which a reduction allows. V's columns are paired the way the GEMM pairs B's, so its fragments are `float2` reads (row strides chosen conflict-free).
- O, the row max and the per-thread partial row sums stay in registers across key chunks. The quad's sums are added once at the end, and the epilogue (normalizer or state) runs from the registers.
- K and V come through a `cp.async` ring. K uses 16-byte copies where its layout is contiguous along the head dim. V here is a map (value + bias), so it is evaluated while staging, as the GEMM does for map operands.
- Masked key chunks at either end of a row block's range are left out of the pipeline. The heaviest row blocks launch first.
- The shape is a schedule parameter, `FlashShape { bi, bj, stages, kw }`. `kw` warp groups split each step's keys and merge their `(m, l, O)` through shared memory at the end, which doubles the warps for the same rows (96 three-warp blocks at seq 512 otherwise). `FLASH_SHAPES` has one candidate per `MMA_SHAPES` variant, so `Program::tuned` picks per kernel.

The two dQ halves are one tile now. `merge_siblings` also merges siblings that read the same big map `schedule_auto` recomputes in every reader (dS). It used to require identical readers, and the halves are read through different reshapes; a reshape reader gets a copy of its slot. `split_reduce_dims` runs the merge again, because the halves only appear after the layout passes. dS is recomputed once for both halves.

Per kernel (minimum over single launches, 3090 at 1–30% utilization from other tenants, 00:06–00:12):

| kernel | seq 128 before | after | seq 512 before | after |
|---|---|---|---|---|
| attention forward (inference) | 0.047 ms | **0.013** | 0.178 | **0.032** |
| online-softmax forward of the training step, `(m, l, acc)` | 0.030 | **0.014** | 0.118 | **0.053** |
| dQ, both halves | 0.020 + 0.020 | **0.023** + 2 × 0.004 copies | 0.116 + 0.117 | **0.126** + 0.009 |

Flash shapes at seq 512 (one contended window, so only the ranking holds): 32 keys × 2 warp groups 0.039 ms; 64 keys × 1 group 0.052; 32 × 1 with 3 stages 0.056; 16 × 4 stages 0.068; a fixed 32-query slice 0.069. 64 keys × 2 groups does not fit in 99 KB with two stages and falls back. The default is now 32 × 2.

End to end: six interleaved rounds under `flock`, 23:41–00:06, each round base (#50, `35d629d`), this branch, then PyTorch. The GPU was at 1–22% at round starts. Best of each:

| | tang main (#50) | tang now | PyTorch best fp32 / TF32 |
|---|---|---|---|
| block fwd, seq 128 | 0.215 ms | **0.178** | 0.306 / 0.286 |
| block fwd+bwd, seq 128 | 0.567 | **0.552** | 1.196 / — |
| block fwd, seq 512 | 0.484 | **0.328** | 0.602 / 0.449 |
| block fwd+bwd, seq 512 | 1.575 | **1.467** | 1.719 / — |
| 4-layer training step, seq 128 (planned, in place, CUDA graph) | 4.03 | **3.92** | 4.40 fused AdamW (4.41 TF32) |

The seq-512 forward is now 1.37× faster than PyTorch TF32; it was 1.07× slower.

Correctness at seq 128, against the f64 evaluation (computed outside the GPU lock):
- forward: 7.8e-5 relative, for every one of the six flash shapes forced in turn (`TANG_FLASH_SHAPE=bi,bj,stages,kw`), the same as before;
- training step: loss 1.2e-5, weight gradients 1.5–3.1e-4 relative, for every flash shape, the same as before. dwq and dwk are about 4e-19 in the reference, so they are compared by absolute error, which is 2.6e-19.

Not done, and why:
- **The backward still materializes S, P̃, dP and the two correction terms.** At seq 512 these are about 0.04 ms each (S, P̃, the max-gradient row sum), plus the dP tile and two smaller maps. Recomputing them in the dQ/dK/dV tiles needs two things this branch does not have:
  - S and dP as nested contractions: a small GEMM per staged block, on tensor cores, inside the staging of the outer tile. The scalar version, 128 FMAs per staged dS element, would cost more than the materialization it removes.
  - Removing the max-gradient terms, `select(s == max)·Σ…`. They are identically zero, since softmax is invariant to the shift, but only numerically so. While they remain, the stabilizing max over S has to be materialized for the row sums, and masked tiles cannot be skipped. The forward's online-softmax state already holds the same max, but `eliminate_common` cannot see that the two are equal.
- The dQ merge costs two 4 µs copies, because the halves are read through reshapes that a slot view cannot express.
### Flash backward: no n×n tensors in the attention backward (RTX 3090)

The training step's attention backward no longer writes S, P̃, dP or the correction terms. Four generic changes get there, plus one lowering gap fixed on the way. Each is described in `docs/tensor-ir.md`.

- **The stabilizing max has no gradient** (`backward`, `stabilizer_maxes`). The degree analysis in `t = exp(−m)` proves the loss does not depend on the attention max, so its `[s == m]` terms are not built. The materialized max over S and its row-sum kernels are gone. `stabilize_softmax` points the backward's reads of the max at the online state's slot 0. The f64 evaluation of the training step equals main's to 2.7e-19 absolute, with gradients around 1e6.
- **Sums distribute** (`hoist_invariant_factors`, run at the end of `split_reduce_dims`). `Σ_c P̃·dO·V` becomes `P̃·Σ_c dO·V`, a sum over a size-1 dim becomes a map, and unread args are dropped. That last step removed 9 more kernels from the step: their unread reads had pinned maps to memory.
- **Nested contractions** (`schedule_nested_contractions`, applied by `to_cuda`). S and dP are inlined into the dQ, dK and dV tiles through dS and P̃. `cuda_mma_kernel` computes them per staged block on `mma`:
  - the row side stays in A fragments for the whole kernel;
  - the k side is read per chunk;
  - the map is evaluated on the accumulator registers and written straight to its stage.
  
  The recomputed S takes the same k-slot pairing as the flash forward, so it is the sum the forward reduced. `merge_reduce_dims` keeps dV's `(r, i)` unmerged so P̃ can be recomputed there.
- **Masked chunks are skipped.** A staged operand that is a masked exponential in every term gives an affine zero condition. Chunks of queries (dK, dV) or keys (dQ) where that condition holds over the whole block are left out of the k range.
- **The gate/up backward at the default shape.** The multi-output, multi-term `[seq,576,2]` Σ1536 tile overflowed shared memory at 3 stages and had no lowering. A shape that overflows now gives up a ring stage, then halves its chunk. A 32×64 two-warp shape joins `MMA_SHAPES` as a candidate.

Per kernel: `cuda_train_kernels`, minimum over single launches. The attention backward and the gate/up backward, main (#51) against this branch:

| kernel | seq 128 main | this | seq 512 main | this |
|---|---|---|---|---|
| S = Q·Kᵀ | 0.012 | nested | 0.058 | nested |
| max over S | 0.009 | (state slot 0) | 0.022 | (state slot 0) |
| P̃ = exp(S − m) | 0.006 | nested | 0.041 | nested |
| dP | 0.007 | nested | 0.043 | nested |
| the P̃·D term and max-gradient row sums (3 kernels) | 0.018 | gone | 0.083 | gone |
| online-softmax forward | 0.014 | 0.020 (S inline) | 0.055 | 0.046 |
| dV | 0.017 | 0.017 | 0.041 | 0.052 |
| dK (both rope halves) | 0.023 | 0.023 | 0.127 | 0.074 |
| dQ (both rope halves) | 0.019 | 0.026 | 0.126 | 0.079 |
| D = rowsum(dO∘O) (this branch: and its 1/l scale) | 0.009 | 0.011 | 0.022 | 0.023 |
| gate/up backward `[seq,576,2]` Σ1536, default shape | 0.303 (no lowering) | 0.048 | 0.312 (no lowering) | 0.104 |
| sum of best per kernel, whole step | 0.92 (63 kernels) | 0.60 (49) | 1.80 (63) | 1.22 (49) |

Each change on its own, as a sum of best per kernel. These are cumulative, in commit order, with two rounds each:

| | seq 128 | seq 512 |
|---|---|---|
| main (#51) | 0.918 | 1.802 |
| + max gradient dropped | 0.881 | 1.736 |
| + gate/up default shape | 0.637 | 1.513 |
| + sums distribute, unread args dropped | 0.600 | 1.442 |
| + nested S, dP through shared scratch | 0.620 | 1.308 |
| + masked chunks skipped | 0.618 | 1.309 |
| + map on the accumulator registers (final) | 0.598 | 1.223 |

End to end: three interleaved rounds under `flock`, 01:34–01:37 UTC. Each round ran every build, then PyTorch, for the block, and the same for the 4-layer step. The 3090 was at 1–100% utilization from other tenants at round starts. Best of each:

| | main (#51) | − max grad | + gate/up | + distribute | + P̃ in dV, skip | this branch | PyTorch fp32 / TF32 |
|---|---|---|---|---|---|---|---|
| block fwd+bwd, seq 128 | 0.550 | 0.541 | 0.520 | 0.507 | 0.505 | **0.490** | 1.223 / — |
| block fwd+bwd, seq 512 | 1.466 | 1.403 | 1.398 | 1.353 | 1.302 | **1.144** | 1.733 / — |
| 4-layer step, seq 128 (planned, in place, CUDA graph) | 3.93 | 3.96 | 2.82 | 2.77 | 2.75 | **2.72** | 4.37 fused AdamW / 4.42 |

The "+ P̃ in dV, skip" column is commit `589eb8d`. Its `cuda_block` and `whole_model` did not call the nesting pass yet (only `cuda_train_kernels` did), so it measures dV's unmerged reduction dims and the skip without nesting.

The 4-layer step went from 3.93 to 2.72 ms. Most of that, 1.1 ms, is the gate/up fix: `whole_model` lowers at the default shape without the tuner, so on main each layer's gate/up backward ran as transpiled WGSL. The block fwd+bwd at seq 512 is now 1.51× faster than PyTorch fp32, up from 1.18×. At seq 128 it is 2.5×.

Correctness at seq 128, against the f64 evaluation (computed outside the GPU lock):
- inputs at the bench's default range (±0.1): loss 1.2e-5 relative, weight gradients 1.5–3.1e-4 relative, the same as main.
  - dwq and dwk are about 4e-19 in the reference, because the softmax rows saturate to one-hot. Their absolute error is now 1.2e3 and 1.9e3 against gradients of 1e6, where on main it was 2.7e-19.
  - On main, the max-gradient term cancelled `dP·P` exactly at the argmax: the same dP kernel computed both, so the result was 0 bit for bit.
  - Now dS = P̃·(dP − D) takes dP from TF32 operands and D = rowsum(dO∘O) in fp32. That is FlashAttention-2's formulation, and its error is at the TF32 level of the other gradients.
- inputs at ±0.02, where the softmax is soft and dwq/dwk are not zero (`TANG_SCALE=0.02`): main and this branch are equally accurate (dwq 3.3e-3 / 3.4e-3, dwk 1.4e-3 / 1.0e-3, others 1.8–4.7e-4 relative), for all seven block shapes forced in turn (`TANG_MMA_VARIANT=0..6`).

Negatives:
- At seq 128 the nested tiles with scratch were slower than materializing (0.620 vs 0.600 sum of best). dK and dQ have 18 blocks there. Evaluating the map on the accumulator registers (no scratch, no barriers) was needed to win at both lengths.
- The 32×64 two-warp shape helps dV and dQ at seq 128 by 2–5 µs. It loses at seq 512 (dK 0.112 vs 0.074). It is kept as a tuner candidate only.
- Shapes with 128-row blocks get no nested lowering: their invariant-side fragments exceed the 96-register budget. The tuner does not pick them for these tiles anyway.
- Skipping masked chunks barely shows (0.618 vs 0.620 at seq 128, flat at seq 512). The blocks whose rows are least masked are the critical path, as with the forward. The heaviest-first launch order the flash forward uses is not done here.
- The transpiled-WGSL twins of the nested tiles are scalar loops (1.4–2.4 ms at seq 512). They exist only so the tuner has a fallback, and it never picks them.

### Precision schedules on CUDA: f16/bf16 storage, m16n8k16 tensor cores (RTX 3090)

f16 and bf16 storage now lower on CUDA (see `docs/tensor-ir.md`, "Precision is a schedule"). The tensor-core tiles and flash attention run on `mma.sync` m16n8k16 f16/bf16 with fp32 accumulation when their operands are stored in half precision. `ir_precision::tune_precision` picks the schedule under an error budget against the f64 evaluation.

The 3090 was shared the whole time (tang-llm at 100% utilization), so the f32 baseline itself ran up to 2× its earlier numbers. Everything below is the best of six interleaved rounds (best of four for the 4-layer step), each run under `flock`, and the tang settings and PyTorch alternated within a round. Treat the figures as ratios within one window, not as absolute times.

**One matmul tile, by operand format** (`cuda_half_matmul`, fastest single launch over every block shape):

| m×k×n | TF32 | f16 | bf16 | f16 × f32 (B converted while staging) |
|---|---|---|---|---|
| 128×576×1536 | 0.0195 ms (11.6 TFLOP/s) | 0.0133 (17.0) | 0.0123 (18.4) | 0.0174 (13.0) |
| 512×576×1536 | 0.0471 (19.2) | 0.0287 (31.6) | 0.0287 (31.6) | 0.0328 (27.6) |
| 512×1536×576 | 0.0420 (21.6) | 0.0256 (35.4) | 0.0246 (36.9) | 0.0369 (24.6) |
| 1024³ | 0.0860 (25.0) | 0.0522 (41.1) | 0.0522 (41.1) | 0.0573 (37.4) |
| 4096³ | 4.56 (30.2) | 1.99 (68.9) | 2.00 (68.9) | 2.70 (50.9) |

At 4096³, f16 reaches 69 TFLOP/s, close to the 3090's dense FP16 peak with fp32 accumulation (about 71).

**The block and its fwd+bwd, by setting** (`cuda_precision`, every setting through `Program::tuned`). Times are whole-program `Program::time`, the metric `cuda_block` reports. Errors are max relative against f64 (mean in parentheses); fwd+bwd inputs are at ±0.02, where the softmax is soft (`TANG_SCALE=0.02`, see the flash-backward section):

| | f32 (TF32 tiles) | tiles in f16 | tiles in bf16 | `tune_precision` | all storage f16 | all storage bf16 |
|---|---|---|---|---|---|---|
| fwd, seq 128 | 0.197 ms, 8.3e-5 | 0.114, 8.0e-5 | 0.113, 5.9e-4 | 0.114, 8.0e-5 | 0.111, **inf** | 0.111, 1.4e-2 |
| fwd, seq 512 | 0.343, 1.1e-4 | 0.201, 1.0e-4 | 0.204, 6.8e-4 | **0.189**, 1.1e-4 | 0.187, **inf** | 0.190, 1.4e-2 |
| fwd+bwd, seq 128 | 0.536, 3.4e-3 (4.4e-4) | 0.406, 3.3e-3 (4.6e-4) | 0.406, 2.5e-2 | **0.376**, 3.3e-3 (4.6e-4) | 0.392, 1.0 | 0.390, 0.25 |
| fwd+bwd, seq 512 | 1.243, 2.1e-3 (3.2e-4) | 0.876, 1.9e-3 (3.5e-4) | 0.819, 1.6e-2 | 0.878, 4.5e-3 (1.3e-3) | 0.835, 1.0 | 0.846, 0.21 |

Sums of the per-kernel fastest launches (the search's cost, steadier under contention):

| | f32 | tiles f16 | `tune_precision` |
|---|---|---|---|
| fwd 128 | 0.201 | 0.137 | 0.137 |
| fwd 512 | 0.351 | 0.222 | 0.212 |
| fwd+bwd 128 | 0.557 | 0.438 | 0.438 |
| fwd+bwd 512 | 1.169 | 0.838 | 0.827 |

**What `tune_precision` keeps** (budget 1e-2 relative, f16 and bf16 tried per move, a move kept if it saves 1%):
- In every case, first the move "all tiles' operands in f16". The search tried bf16 too: in the forward it is as fast and 7× less accurate, and in training it is over budget.
- The kept buffers: the seven weight matrices, the normed activations feeding Q/K/V and gate/up, Q, K and V (both rope halves), the attention output, the gate/up product and the down projection's input. In training, also the transposed activations and gradients the weight-gradient tiles read (`[576, seq]`, `[1536, seq]`) and the attention-backward operands.
- Then a few single buffers: in fwd 128, the rope table and the attention input of `wo`; in fwd 512, gate/up's output and the block input. In fwd+bwd 512 it added gate/up's output in bf16, which saves 1.1% and doubles the error (2.1e-3 → 4.5e-3). That is a weak keep at the 1% threshold.
- Nothing else cleared the threshold: the small vectors (biases, norms) and the accumulators. Accumulators are not candidates on CUDA, since an f16 accumulator keeps a tile off the tensor cores.

**Against PyTorch**, same windows, best of each (`torch_bench.py` now with bf16 autocast, and TF32 for fwd+bwd):

| | tang f32 | tang `tune_precision` | PyTorch fp32 | PyTorch TF32 | PyTorch bf16 autocast |
|---|---|---|---|---|---|
| block fwd, seq 128 | 0.197 | **0.114** | 0.303 | 0.306 | 0.350 |
| block fwd, seq 512 | 0.343 | **0.189** | 0.657 | 0.484 | 0.280 |
| block fwd+bwd, seq 128 | 0.536 | **0.376** | 1.264 | 1.233 | 1.329 |
| block fwd+bwd, seq 512 | 1.243 | **0.878** | 1.873 | 1.622 | 1.764 |

Against PyTorch bf16 autocast, the block forward is 3.1× faster at seq 128 and 1.48× at 512. The fwd+bwd is 3.5× at seq 128 and 2.0× at 512. Against tang's own f32, half precision is 1.7–1.8× faster for the forward and 1.4× for fwd+bwd.

**The 4-layer training step** (`whole_model 4 128 cuda`, planned, in place, CUDA graph):
- `TANG_PRECISION_TILES=f16|bf16` applies the search's first move: every tile's operands in half, with weights, AdamW state and data kept f32 (fp32 master weights; half tiles convert them while staging).
- `TANG_TUNE=1` lowers each kernel at its tuned shape. Untuned, the half tiles sit at the default shape, which suits TF32.
- The full search is not run on this graph: about 830 candidate sources, hours of lock time.
- The error is over every output (loss, p', m', v') against f64. m′ after one step is the gradient, so its error is the gradient's.

| | best (CUDA graph) | mean rel. error | loss rel. error |
|---|---|---|---|
| tang f32, untuned (main's setting) | 5.95 ms | 1.5e-4 | 1.5e-6 |
| tang f32, tuned | 5.80 | 1.5e-4 | 1.2e-6 |
| tang tiles f16, tuned | **5.05** | 5.1e-3 | 5.1e-7 |
| tang tiles bf16, tuned | **5.05** | 1.3e-3 | 1.9e-6 |
| PyTorch fused AdamW: fp32 / TF32 / bf16 autocast | 4.48 / 4.21 / 4.40 | | |

In these windows the step ran at about 2.2× its quiet-machine time (2.72 ms), while PyTorch ran at about its earlier 4.4. So the ranking against PyTorch is not established here; the earlier quiet-machine runs had tang ahead. Within tang, half tiles are 13% faster than f32 in the same windows. bf16 gives four times smaller gradient error than f16 at the same speed: f16's range loses the small gradients without loss scaling.

f32 path: with no node in half precision, every CUDA source is byte-identical to main's (block fwd and train, seq 128/512, all 8 lowering variants). The digests match main bit for bit: `cuda_block` `20c8ff36…` / `47b96240…` / `5cff2ba3…` / `57e0a808…`, `whole_model 4 128 cuda` `9f41a84e…`, and every step of `train_loop`.

Negatives:
- **Half tiles were slower than TF32 until the operands were staged in their own layout** (0.12 → 0.17 ms for gate/up at seq 512). The block's weights are stored [out, in], so the B operand is contiguous along k. The first half path only had a 16-byte `cp.async` path for n-contiguous B and fell back to synchronous 2-byte loads. Staging k-contiguous B as [n][k] (m16n8k16's native B layout, one 32-bit load per register) and m-contiguous A as [k][m] with paired rows fixed it: gate/up went 0.122 → 0.057.
- **All storage in f16 overflows** (inf in the forward, relative error 1.0 in training). **All storage in bf16** costs 1.4e-2 in the forward and 0.2 in training. Only the tile operands go half; the softmax statistics, norms and residual stream stay f32.
- **In training, f16 tiles' gradients are 4× less accurate than bf16's** (mean 5.1e-3 vs 1.3e-3 on the 4-layer step). The block fwd+bwd budget still admits f16, at a max error equal to f32's, because the max is set by other outputs.
- **Doubling the k chunk for half tiles is a wash per shape.** It wins 512×1536×576 (0.0256 vs 0.0276) and loses 512×576×1536 (0.0317 vs 0.0287). It stays the default, and the shape tuner picks among the doubled shapes; `TANG_HALF_CHUNK=1` turns it off.
- **Converting an f32 operand while staging costs about a third of the f16 gain** (f16 × f32 at 13–51 TFLOP/s against 17–69). It is what keeps fp32 master weights cheap without a separate cast kernel, but storing the weights in half is faster for inference.
- **The search had to stop timing whole programs.** On the time-sliced GPU, the same program's wall time swung 2× between batches, and "same window" ratios still ranged from 0.5× to 2.2×. The cost became the sum of per-kernel fastest single launches.
- **It also had to cost each kernel at its best tile shape.** At the default shape, all tiles in f16 measured 1.08× slower in fwd+bwd, while `Program::tuned` made them 20% faster. Kernel costs are memoized by source, so a candidate times only the kernels it changes.
- **A single tile's move gains 2–3%**, below the old 3% threshold, so every move was rejected. The search now tries all tiles at once first, with a 1% threshold.
- **The noise floor is about ±1.5%.** Moves that set 576-element vectors to bf16 were kept for 1–4% "gains" that cannot be real. The final re-check against f32 only guards the total.
- **Flash attention in half saves little at these lengths**: 0.014 → 0.011 ms at seq 128 and flat at 512, against 0.12 → 0.057 for gate/up.
- **PyTorch bf16 autocast is slower than its fp32 at seq 128** (0.350 vs 0.303 ms forward), from per-op cast kernels. tang casts inside the tiles.

### Qwen3-8B through the tensor IR on CUDA (RTX 3090, batch 1)

The whole model, MLX 4-bit (`mlx-community/Qwen3-8B-4bit`: group 64, bf16 scales and biases), runs as **one IR graph per step**: `tang_bench::ir_qwen::step_graph`, lowered by `TensorGraph::to_cuda_decode` (`tensor_cuda_gemv.rs`), run through `Program` with the KV caches updated in place and the step captured as a CUDA graph. The runner is `examples/qwen_decode.rs` (`tiny`, `model`, `prefill`).

**What the lowering adds** (see the module docs):

- *Warp reductions.* A reduction, or the map that reads it point for point (its epilogue), runs as one warp per point group. Lanes stride the reduce space a vector chunk at a time, and the body is evaluated generically. Each leaf is classified per chunk: invariant (one load), unit-stride (`float4` or `uint4`), or scalar. A short point dim that the largest operand ignores (the 4 query heads of a GQA group), or a GEMV's rows, is unrolled per thread.
- *Packed storage.* The nibbles are 8 per word, scales and biases are bf16 pairs, and the KV caches are f16 pairs. The graph sees logical values. The dequantization `q·s + b` is a map the matmul reads; it is inlined and evaluated in registers as the `uint4` streams in (`2²³ + q` as a float, minus `2²³`: no int-to-float per weight).
- *Runtime bounds.* Every reduction over the cache axis is `select(pos − j + ½, x, identity)`, with `pos` read from the step input. The lowering turns that into loop bounds (scores: a grid-stride loop that stops at the live rows). A step reads `len` rows of a 4352-row cache, not all of them. The cache update `select(j == pos, new, old)` is written over its donor and visits only that row.
- *Schedules:* `schedule_epilogues` (residual adds and SwiGLU fused into the GEMVs over two reduce dims) and `schedule_decode_maps` (RMSNorm and the roped key recomputed inside their GEMV or cache update). The residual stream is kept materialized; substituting it everywhere made each layer read every earlier layer's outputs. Gate and up are merged siblings, and q|k|v is one 6144-row weight.

A decode step has 506 kernels: 470 lowered here, and 36 transpiled (the roped q).

**Correctness.** The reference is a CPU f32 forward with the checkpoint dequantized exactly (PyTorch on mew). Teacher-forced on tang's own 64 greedy tokens (21-token prompt, f32 caches): max |logit error| 1.7e-4 (logits up to 51.6, mean 2.2e-5), and 64/64 argmax agree. So the reference's greedy text is tang's. The tiny random model (`qwen_decode tiny`) matches the interpreter at 1e-6 relative with f32 caches. With f16 caches it matches at 1e-4: the device caches are within 1 f16 ulp of the reference's, and a one-ulp flip of a cached value accounts for the rest. Prefill of 512 tokens on f16 tensor cores: next-token logits within 7.5e-3 of the reference, argmax equal. The full-model check with f16 caches could not be rerun: see the caveat below.

**Speed** (the 3090 was shared with a GAN training job at ~98% SM for the whole session, so every number has 1.5–2× noise. Device step times are the minimum of 5 batches of 20 graph replays, best of the runs).

| | decode, short ctx | decode, 4k ctx | prefill 512 |
|---|---|---|---|
| speed of light (936 GB/s) | 220 tok/s (4.26 GB of weights + scales) | 192 tok/s (+0.6 GB f16 KV) | — |
| tang IR, device step | **8.2 ms: 122 tok/s (55% SOL)** | **9.6 ms: 104 tok/s (54%)** | **662 ms: 774 tok/s** (f16 tiles; TF32: 606) |
| tang IR, host loop (embed, write, replay, read 151k logits) | 55–59 tok/s | — | — |
| tang-llm engine (resident server, speculative drafting on) | 52–217 tok/s by acceptance; ~25–48 ms per verify forward | 51–164 tok/s | 535–757 tok/s (≈3000-token prompts: 477) |
| llama.cpp | not installed on mew. Building it and fetching a GGUF needs downloads I did not make | | |

The host loop is half the device rate. Each step does three synchronous transfers: `Program::write` syncs, and a 600 KB logits readback follows every replay. Under time-slicing with another process, each sync waits a slice. An in-graph argmax would remove the readback.

**Where the 4k step goes** (sum of isolated launches, 10.3 ms; rows-per-warp 4):

| kernels | ms | per launch | achieved |
|---|---|---|---|
| gate\|up GEMV + SwiGLU (36) | 2.76 | 77 µs | 738 GB/s |
| down GEMV + residual (36) | 1.84 | 51 µs | 554 GB/s |
| qkv GEMV (36) | 1.25 | 35 µs | 409 GB/s |
| attention `Σ p·v / l` (36) | 1.13 | 31 µs | f16 V, 8.9 MB/layer |
| o GEMV + residual (36) | 0.75 | 21 µs | 450 GB/s |
| scores `q·k` (36) | 0.73 | 20 µs | f16 K |
| LM head GEMV (1) | 0.56 | 564 µs | 620 GB/s |
| softmax max/sum (72), cache row writes (72), norms (73), q rope (36), qk-norm sums (36) | 1.32 | 3–6 µs | launch-bound |

The gap to SOL (8.2 ms against 4.55 ms at short context) splits about evenly:

- *Small GEMVs below bandwidth.* The 4096- and 6144-row projections reach 410–450 GB/s against 740 GB/s for the merged 24576-row gate|up. They have fewer bytes in flight per warp, and a 20–35 µs kernel pays its ramp and tail.
- *Fixed per-kernel cost.* About 300 of the 506 launches are small reductions and maps at 3–6 µs each, roughly 1.3 ms. Fusing the softmax statistics into one kernel, the two cache writes into one, and a norm's sum into its map are the next steps.
- *At 4k:* attention is ~1.9 ms, f16 K and V at about 75% of bandwidth.

The f16 cache halved attention's bytes against f32 (scores 0.95 → 0.73 ms, `p·v` 1.17 → 1.13 ms with the extra unpacking). The int4 decode without int-to-float conversions made no measurable difference, so the GEMVs are not ALU-bound. Rows-per-warp 4 against 2 was 0–8% faster, inside the noise.

**Prefill** is the same graph builder at `seq = 512` (positions from 0, `ctx = seq`). The cost-aware substitution keeps each dequantized weight materialized, because 512 tokens read it. `merge_reduce_dims` then leaves a plain matmul, and it runs on `cuda_mma_kernel`. With the dequantized weights stored f16 (#55's m16n8k16 tiles, activations converted while staging), the 144 tiles take 280 ms, about 25 TFLOP/s; they took 552 ms in TF32. Dequantization takes 27 ms: 7.5 B f16 writes. Attention and norms through the warp kernels take 86 ms, and the cache writes 20 ms (one thread per column loops over the 512 rows). `ir_qwen::plan_slots` keeps one layer's f16 weights live, so intermediates take 1.0 GB.

**Caveat: mew's storage went bad mid-session.** Partway through, reading the Hugging Face copy of the checkpoint on mew started failing with EFAULT at 3.7 GB (`dd` reproduces it). One decode run before that read garbage weights: its logits were wrong while the tiny test still passed. A copy sent from the M4 (sha256 `f2d29621…`, equal to the blob name) sits in `~/qwenir/model`. The rerun of the full-model checks on it stalled: the process was stuck in the kernel freeing page tables, and the machine's clock was barely advancing. The decode correctness figures above come from the run before the fault (f32 caches). The f16-cache and rows-4 speed figures come from runs whose weights may have been corrupt; corrupt weights change the values, not the bytes moved.

**Missing for production in tang-llm:**

- *Weight sharing between programs.* Prefill and decode are separate `Program`s, each with a 4.3 GB copy of the weights. Fixing this needs either shared buffers in `Program` or one program with two captured kernel subsets.
- *Chunked prefill from a nonzero position.* Token `t` of a chunk lands in cache row `pos0 + t`, a data-dependent view (a guarded or offset view the lowering can address).
- *Sampling and stopping on the device.* An in-graph argmax or top-k avoids the logits readback.
- *A tuner for the decode kernels.* Rows per warp, warps and unroll per kernel, through `Program::tuned`.
- *Batching beyond 1, and paged or variable-length caches.*
- *A standalone, uncontended re-measurement once mew's hardware is checked.*

### Qwen3-8B through the tensor IR on Metal (M4 Max): shared weights, offset prefill, on-device argmax

The follow-up to the CUDA section above, run entirely on the M4 Max (mew was unavailable). The same graph builder, `tang_bench::ir_qwen::step_graph(dims, seq, kctx)`, now covers everything a step needs on the device. The runner is `examples/qwen_decode.rs` (`tiny`, `model`, `reference`, `compare`); `qwen_tok` maps text to ids and back with the Qwen3 tokenizer.

**What changed**

- *Metal lowering.* `TensorGraph::to_msl_decode` (`tensor_msl_gemv.rs`) generates the same kernels as `to_cuda_decode` and transliterates them to MSL: warps become simdgroups (`simd_shuffle_xor`), the packed 4-bit, bf16 and f16 loads become Metal helpers, and the grid wraps into y past 65535 threadgroups. An in-place update does not bind its donor among its reads; it reads the old value through `out`, because wgpu refuses one buffer bound both ways. Kernels with no decode lowering stay WGSL. The CUDA sources are byte-identical to #56's for #56's graphs: all kernel sources of the decode and prefill graphs, tiny and 8B-shaped, were diffed before and after every lowering change.
- *One compute pass per run.* On wgpu, `Program::capture` builds each kernel's pipeline, bind group and uniform once, so a run is one command buffer. Before, each of the 510 kernels was its own command buffer.
- *Shared weights.* `Program::with_shared` binds inputs to another program's buffers. The decode program owns the weights, the KV caches and `state`; every prefill program borrows all 765 of them and allocates only its chunk input and intermediates.
- *Prefill from an offset.* A prefill reads `[tokens…, p0]` from a `chunk` input. It appends cache rows `p0..p0+seq` and attends causally over cache rows `0..kctx`. The window `kctx` is a compile-time view of the shared full-capacity cache, so the cost does not depend on its 4352 capacity. Row `j` receives token `j − p0`, an index known only at run time, so the IR expresses it as a sum with one live term, `Σ_t pick(t, j − p0, k_rot[t])`, where `pick` is two nested `select` half-planes. The lowering's in-place update evaluates an inlined reduction as a loop whose bounds come from those predicates, so the loop has one iteration. The embedding row of a token and the rope angles of a position are the same kind of gather: they read the 4-bit embedding table and a `[cos|sin][ctx]` table on the device. Warp reductions now take both a lower and an upper runtime bound, and the bounds may depend on point coordinates (a per-token id).
- *Next token on the device.* `Monoid::argmax` is an `(index, value)` tuple monoid that keeps the first maximum on ties. `TensorGraph::comp_tuple` builds the reduction over the logits. An in-place map writes `(argmax, position + 1)` over `state`. The decode loop is one `run` and one 8-byte `state` readback per token, with no host writes.

**Correctness** (f16 KV caches throughout)

| check | result |
|---|---|
| tiny random model vs the interpreter (f64, f16 caches emulated): 9 decode steps, a 6-token prefill at p0 = 9, one more decode | rel. logit error ≤ 3.4e-6 (f32 caches: 1.1e-6); caches within 1 f16 ulp; on-device argmax and `state` equal the interpreter's at every step |
| full model, teacher-forced on prompt + tang's 64 greedy tokens, vs a CPU f32 reference (checkpoint dequantized exactly, f64 accumulation, `qwen_decode reference`) | max \|logit error\| 3.3e-2 at logits up to 57.3 (5.8e-4 relative), mean 2.0e-3; argmax 65/65 equal, so the reference's greedy text is tang's 64 tokens |
| greedy text, 24-token prompt | 64 tokens from a 24-token prefill + on-device decode identical to #56's design run on Metal (prompt as 24 decode steps, host argmax) |
| offset prefill: 300 tokens, then 200 more from p0 = 300, vs one 500-token prefill | next-token logits bit-identical (max error 0); 64 greedy tokens identical |

The 3.3e-2 is larger than #56's 1.7e-4, which was measured with f32 caches. The likely causes are the f16 caches (a one-ulp flip of a cached K or V moves a logit by ~1e-4 of its scale, and these flips accumulate over 36 layers) and Metal's fast-math `exp`/`sqrt`. The model was not rerun with f32 caches against the reference, so the split between the two is not measured.

**Memory** (bytes allocated by the programs)

| | decode | + prefill programs | total |
|---|---|---|---|
| shared (this PR) | 5.26 GB: 4.6 GB weights incl. the 4-bit embedding table, 0.64 GB f16 KV at 4352 positions | 0.5–1.3 GB of intermediates each (seq 24: 0.53; 500: 1.28; 300 + 200: 0.89 + 0.81) | 5.8–7.0 GB |
| separate programs (#56) | 4.6 GB + KV | another 4.3 GB of weights per prefill program, plus its own cache | ~11 GB for one prefill program |

The largest prefill intermediate is one layer's dequantized gate weight in f32: Metal's simdgroup tile stages f32, so the prefill weights are not stored f16 there.

**Speed. Caveat: the GPU was busy.** For the whole session another process kept the M4's GPU at 94–100% device utilization (`ioreg` "Device Utilization %", read with my runs idle). It was the user's, so I left it running. Every number below is a contended minimum, varies about 2× from run to run, and is a lower bound on what the code does on an idle M4.

| | decode, len 32 | decode, len 4096 | prefill 512 |
|---|---|---|---|
| speed of light (546 GB/s ÷ 4.3 GB) | 125 tok/s | ~110 tok/s (+0.6 GB KV) | — |
| #56's design on Metal (host embed, step write, 600 KB logits readback, host argmax) | 107 ms device (32 ms in one run with 4 rows per warp); 7.9 tok/s end to end | 131 ms | — |
| this PR, device step (min of 3×5 batches of 20) | 99 ms (10 tok/s, 8% SOL) | 87 ms (11.5 tok/s, 10%) | 8.7 s (59 tok/s) |
| this PR, end to end (run + `state` readback) | 7.1–9.1 tok/s | — | — |

Under this contention the end-to-end difference between host argmax and on-device argmax was not measurable: both loops are dominated by the device step. The isolated q|k|v GEMV (`examples/qwen_gemv.rs`: 16–32 copies in one pass) reached 150–200 GB/s. It was insensitive to rows per warp (2/4/8), warps per threadgroup (2/4/8) and unrolling, and a hand-unpacked variant without the vector-index arithmetic was within noise. So the GEMV itself runs at about a third of the bandwidth it would get on an idle GPU, or less. Without a quiet GPU I could not separate kernel quality from contention.

Prefill is slow for structural reasons as well as contention: the four projections per layer run on the f32 simdgroup tile over f32 dequantized weights (gate and up are unmerged on Metal because the tile takes one output), and attention runs through the warp kernels. A 4-bit simdgroup-matrix GEMM that dequantizes while staging (to `half`) would remove both the f32 weight writes and the f32 staging.

**Not done / next**

- Re-measure on an idle M4; then tune the Metal GEMV (an MLX-style `qmv` with x staged in threadgroup memory is the obvious candidate) and the per-dispatch cost of the ~510 kernels.
- A 4-bit half-precision simdgroup GEMM for prefill.
- The CUDA paths compile (`cargo build -p tang-bench --features cuda`) but were not run (see the PR).

## Kokoro-shaped ops (M4 Max, Metal, kernel-only)

TTS vocoder ops (Kokoro's iSTFTNet decoder, Vocos-style ConvNeXt) derived
from the IR, against PyTorch 2.14.1 on MPS. Both sides: fp32, 5 warmups,
50 launches, one sync (`examples/kokoro_ops.rs`,
`scripts/torch_kokoro_ops.py`). Every IR output is checked against a
straightforward f64 CPU reference (max error / max |ref| ≤ 1e-5, all ops
pass at 1e-6–1e-5); forward+backward is checked on a small instance
against the f64 interpreter (≤ 2e-7).

These ops need zero padding, so this branch adds **guarded views**: a
`View` with `guard: true` may read outside its source and gets 0 there.
Same-padded and dilated convs, the polyphase upsampler and the iSTFT
overlap-add are all guarded views; nothing op-specific was added. The
backward of a guarded read eliminates an out coordinate (`t = τ − 3k + 9`)
instead of scattering, so `dx` of a conv is a gather with a guarded `dy`
read, not a reduction over all of `t`.

Before = the first cut of this section (single-reduce tiler, im2col for
convs); after = multi-dim tiled reductions + epilogue fusion (below). MPS
rerun alongside the "after" column; it moved between runs (a 0.85→0.71,
f 0.41→0.24 ms), so both are listed. The M4 was noisy on later runs (a
direct/auto 2.43 vs 3.10 ms back to back); the table takes the best of
three full runs.

| op | before (ms) | after (ms) | windowed (ms) | windowed: algebra / schedule | MPS (ms) | windowed / MPS |
|---|---:|---:|---:|---|---:|---:|
| a conv1d 512→512 k7 d3, T 2000 | 2.926 im2col | 2.408 | **2.199** | direct / autotune (1 kernel), 3.34 TFLOP/s | 0.855 | 2.6× slower |
| b upsample 512→256 k20 s10, T 2000 → 20000 | 3.544 | 3.381 | 3.321 | unfold + bmm / auto (3); direct polyphase 3.98 (was 3.75) | 1.072 conv only · 1.274 | 3.1× slower |
| c iSTFT n_fft 20 hop 5, 4000 frames | 0.085 | 0.052 | 0.074 | DFT inlined into OLA / autotune (1) | 0.110 | 1.5× faster |
| d conv (a) + bias + snake | 3.021 im2col | 2.421 | **2.197** | direct + snake epilogue / auto (1 kernel) | 0.847 | 2.6× slower |
| e AdaIN C 512 T 2000, style 128 | 0.214 | 0.213 | 0.197 | auto (6) | 0.245 | 1.2× faster |
| f ConvNeXt block C 512 T 200 F 1536 | 0.571 | 0.544 | 0.550 | auto (8) | 0.246 | 2.2× slower |
| a fwd+bwd (dx, dw) | 6.137 | 6.173 im2col · 7.003 direct | 6.263 im2col · 6.627 direct (was 6.936) | im2col / auto (5) | 2.244 | 2.8× slower |
| f fwd+bwd (all 9 params) | 1.606 | 1.591 | 1.619 | auto (30) | 1.031 | 1.6× slower |

**Windowed staging** (this column): a staged read affine in the lane
axis, `t` and the unrolled inner reduce dims folds the overlapping vars
into one window per chunk. The conv's `x[c, t + 3k − 9]` stages
`64 + 3·6 = 82` floats per channel instead of `7 × 64`, so under the
16 KiB cap the chunk grows from 4 to 7 (the weight tile, 448 floats per
channel, is now the limit). Guarded windows rebuild the guarded coord
from the window position, so zero padding stays at staging. Windowed and
before columns are best of 3 serial runs on an otherwise idle M4 Max
(the machine was still noisy: one run of three was ~1.3× slow across the
board); "before" re-measured alongside: a 2.407, b 3.415, d 2.398,
a fwd+bwd 5.967 im2col. MPS best of 3 from the same session. The
polyphase upsample's direct kernel did not improve (its x window is
already small next to the `w[o, c, r + s·j]` tile).

Full per-schedule run, after (naive / `schedule_auto` / per-kernel autotune):

| op | algebra | naive | auto | autotune | before: auto |
|---|---|---:|---:|---:|---:|
| a | direct conv (1 kernel) | 12.39 | **2.43** | **2.41** | 12.69 |
| a | im2col | 34.34 | 2.96 | 2.95 | 2.93 |
| b | direct polyphase (1 kernel) | 15.87 | 3.64 | 3.68 | 15.73 |
| b | unfold + bmm + transpose | 20.91 | 3.38 | 3.40 | 3.55 |
| c | DFT + OLA | 0.112 | 0.052 | 0.054 | 0.086 |
| d | direct + snake (epilogue-fused: 1 kernel) | 12.57 | **2.46** | **2.42** | 12.88 (2 kernels) |
| d | direct, conv inlined under snake (1 kernel, untiled) | 12.32 | | | 12.36 |
| d | im2col + snake map | 34.33 | 2.95 | 2.94 | 3.02 |
| e | | 0.437 | 0.213 | 0.442 | 0.214 |
| f | | 1.20 | 0.544 | 0.608 | 0.571 |
| a fwd+bwd | direct | 36.71 | 7.00 | 7.03 | 44.03 |
| a fwd+bwd | im2col | 73.71 | 6.17 | 6.20 | 6.14 |
| f fwd+bwd | | 4.20 | 1.59 | 1.67 | 1.61 |

**Merged with #34** (generalized epilogues, `merge_siblings`, `relayout`,
`merge_reduce_dims` in `kokoro_ops`' pass list, coalesced + vec4 staging).
Same session, M4 Max, best schedule per op; the #35 binary rerun
alongside (the M4 throttled later in the session, so only the first
back-to-back pair is listed):

| op | #35 windowed (ms) | merged (ms) | merged: algebra / schedule |
|---|---:|---:|---|
| a conv1d | 2.216 | **2.036** | im2col / auto (direct/auto 2.30) |
| b upsample | 3.276 | **2.474** | bmm / auto (2 kernels, was 3) |
| c iSTFT | 0.075 | 0.072 | dft+ola / auto |
| d conv + bias + snake | 2.183 | **2.039** | im2col / autotune (direct/auto 2.31, 1 kernel) |
| e AdaIN | 0.194 | **0.157** | auto (4 kernels, was 6) |
| f ConvNeXt block | 0.579 | **0.429** | autotune (7 kernels, was 8) |
| a fwd+bwd | 6.383 | **4.816** | im2col / auto |
| f fwd+bwd | 1.643 | **1.246** | auto (30) |

Direct conv alone (one kernel) is unchanged within noise: interleaved
#35/merged runs on the throttled machine gave 2.81/3.98, 3.93/3.89,
3.81/3.83 ms. The exp/log epilogue rule survives as a schedule
heuristic (`unfuse_heavy_epilogue`): under a register tile, an epilogue
with exp/log runs as its own map.

What changed, and where the IR still loses:

- **Multi-dim reductions tile.** `tile_kernel` now chunks the largest
  reduce dim as `r0` and runs the others (`u{i}`: a conv's taps, the
  polyphase `j`) as inner loops inside each chunk step — unrolled when
  their product is ≤ 16, outside the register-tile copies so all 16
  copies share one staged read per step. Staged regions just gain the
  inner vars (they already supported them for nested comps).
  `tileable_red` accepts any reduction whose non-chunked dims multiply to
  ≤ 32. No conv-specific code: dx of the conv (`red = (o, k)`) and the
  polyphase upsample (`red = (j, c)`) take the same path.
- **Guards are applied when staging.** A guarded read used to stage the
  (possibly wrapped) value and `select` at every use — 16 copies × 7 taps
  of compares per step; 16.6 → 5.5 ms on its own. The region key now
  carries the guard's source coords, so the zero padding happens once per
  staged element.
- **Occupancy, not staging, was the last 2×.** Inner dims multiply every
  staged region (x: chunk·7·64, w: chunk·7·64). At chunk 8 that was 28 KiB
  of workgroup memory — one workgroup per M4 core — and 5.0 ms; capping
  staged memory at 16 KiB (chunk 4, also the WebGPU default limit) gives
  2.4 ms. The cap applies to every tiled kernel, halving the chunk until
  it fits.
- **Narrow trailing point dims are uniform, not lanes.** `tile_axes` picks
  the last two point dims ≥ 16 as the tile's x / y, so `dw[o, c, k]`
  tiles over `(o, c)` with `k` per-workgroup (36 → 7 ms fwd+bwd) and the
  polyphase `[o, q, r]` tiles over `(o, q)` with `r` uniform (15.6 →
  3.6 ms).
- **Epilogue fusion.** When a tiled reduction's only consumer is a map
  over the same points (identity view, unguarded), `schedule_auto` moves
  the tile schedule onto the map and inlines the reduction; the tiled
  kernel evaluates the map at write-out. (d) is now one kernel at (a)'s
  cost (2.42 vs 2.41 ms), and ConvNeXt's residual add fuses into the
  second pointwise matmul (9 → 8 kernels). Autotune sees an epilogue map's
  candidates as its reduction's tile candidates. A GELU epilogue measured
  *slower* fused (block 0.60 vs 0.56 ms), so maps containing exp/log stay
  separate — a measured rule, not a principled one.
- **Still 3× behind MPS on convs.** 2.4 ms for 7.3 GFLOP is ~3 TFLOP/s;
  MPS's 0.71 ms is ~10. The tile is the generic 16×16 threads × 4×4
  registers with scalar f32 shared-memory reads; MPS uses simdgroup
  matrix ops. The x region also stages each tap separately (`chunk·7·64`
  floats where the sliding window needs `chunk·(64 + 18)`), which is what
  forces chunk 4. A windowed region (merge an inner var into the offset
  span when its coefficient is a multiple of a lane coefficient) and
  `simdgroup_matrix`-style lowering are the next two steps.
- **fwd+bwd of the conv: im2col still wins (6.2 vs 7.0 ms).** Both
  gradients tile now, but `dw` re-stages `dy` for each of the 7 taps
  (`k` is per-workgroup) and the guarded `x` read inside it is staged per
  tap as above.

- **The upsample.** `conv_transpose1d` on MPS takes a 24 ms slow path; the
  same math as a polyphase conv1d (2 taps, 2560 output channels) is
  1.17 ms there. The IR's direct polyphase comp (reduce over `(j, c)`) now
  tiles (3.6 ms, was 15.6); unfold + one matmul per phase is 3.4 ms. The IR computes `conv_transpose1d(p = 0)` cropped to 20000
  samples — identical FLOPs to `p = 5`, offset by 5 samples (a `p = 5`
  form needs a third tap or a guarded weight read).
- **iSTFT wins** because `schedule_auto` inlines the 11-bin inverse DFT
  into the overlap-add (each output sample recomputes its 4 frames), so
  the whole head is one launch with no frame buffer. `torch.istft` is
  several kernels (complex polar, irfft, window, fold, envelope divide).
- **AdaIN wins** on launch structure: the stats are reductions and
  everything elementwise splices into one map.
- **ConvNeXt at T = 200 is launch-bound** (9 kernels forward, 30 for
  forward+backward; the two pointwise matmuls are only 0.3 GFLOP each).
  LayerNorm's mean and variance are separate reductions over C, each
  re-reading the depthwise conv output.
- **Autotune ≥ auto here, sometimes worse** (AdaIN 0.45 vs 0.21 ms,
  ConvNeXt 0.88 vs 0.57). It times each kernel in isolation for 10
  launches with the rest of the program cold; on these sub-0.1 ms kernels
  that measurement is noise-dominated. The tuner should time in program
  context and with more launches.
- Guarded reads of a map keep that map materialized (`f(0) ≠ 0` in
  general), so a conv over `snake(adain(x))` would read a buffer, not
  splice. Splicing is valid whenever the map is zero on zero input
  (snake is); not done yet.

## Precision schedules (M4 Max, Metal, kernel-only)

Precision is a per-node schedule field (`set_precision`, see
`docs/tensor-ir.md`): storage format of each buffer, accumulate format of
each reduction. `tune_precision` starts from the per-kernel autotuned f32
schedule, lowers one buffer at a time to f16 (largest first), runs it on
the device against the f64 CPU reference, and keeps it only if the whole
program stays within the error budget and is ≥ 3% faster; the final
choice is re-timed best-of-3 against f32 and dropped if the gain does not
hold. Error = max |got − f64| / max |f64|. "Predicted" is the f64
interpreter's emulation (`precision_error`) of the same assignment on a
small instance of the same builder.
`cargo run --release -p tang-bench --example kokoro_ops -- precision`.

| op | budget (rel) | f32 ms | chosen ms | speedup | chosen assignment | measured err | predicted err (small) |
|---|---|---:|---:|---:|---|---:|---:|
| a conv1d 512→512 k7 d3 T2000 | 1e-2 | 2.201 | 2.201 | 1.00× | all f32 | 4.0e-6 | 6.8e-7 |
| a conv1d 512→512 k7 d3 T2000 | 1e-3 | 2.204 | 2.204 | 1.00× | all f32 | 4.0e-6 | 6.8e-7 |
| b upsample 512→256 k20 s10 | 1e-2 | 3.919 | 3.662 | **1.07×** | w[256×512×20] f16 | 6.2e-5 | 1.4e-4 |
| b upsample 512→256 k20 s10 | 1e-3 | 3.931 | 3.825 | 1.03× | w[256×512×20] f16 | 6.2e-5 | 1.4e-4 |
| c iSTFT n_fft20 hop5 T4000 | 1e-2 | 0.073 | 0.073 | 1.00× | all f32 | 1.3e-6 | 9.3e-8 |
| c iSTFT n_fft20 hop5 T4000 | 1e-3 | 0.074 | 0.072 | 1.02× | OLA output f16 | 3.0e-4 | 2.4e-4 |
| e AdaIN C512 T2000 style128 | 1e-2 | 0.250 | 0.250 | 1.00× | all f32 | 7.3e-7 | 6.0e-7 |
| e AdaIN C512 T2000 style128 | 1e-3 | 0.249 | 0.249 | 1.00× | all f32 | 7.3e-7 | 6.0e-7 |
| f ConvNeXt C512 T200 F1536 | 1e-2 | 0.697 | 0.697 | 1.00× | all f32 | 9.7e-6 | 4.5e-8 |
| f ConvNeXt C512 T200 F1536 | 1e-3 | 0.695 | 0.695 | 1.00× | all f32 | 9.7e-6 | 4.5e-8 |
| matmul 1024³ | 1e-2 | 0.761 | 0.761 | 1.00× | all f32 | 1.8e-6 | 1.5e-6 |
| matmul 1024³ | 1e-3 | 0.758 | 0.758 | 1.00× | all f32 | 1.8e-6 | 1.5e-6 |

Every f16 *storage* trial fit both budgets (errors 1e-5–5e-4; an f16
output costs ~3e-4, the half-ulp of the result). The search said no
because almost nothing got faster:

- **Without matrix units, f16 storage buys bandwidth only, and these
  ops are not bandwidth-bound.** The convs and the 1024³ matmul run at
  ~3.3 TFLOP/s from staged f32 tiles: compute-bound, halving the bytes
  read changes nothing (a: x f16 2.18, w f16 2.23 vs 2.20 ms; matmul:
  a/b f16 0.76 vs 0.76). The upsample is the one op whose weight read shows: its
  10.5 MB `w` in f16 is 3–7% faster across runs. AdaIN, iSTFT and the
  ConvNeXt block are a few hundred µs of 6–8 small kernels — launch- and
  latency-bound at 80–100 GB/s against the M4 Max's ~400.
- **f16 outputs never pay** (a: 2.21 vs 2.20 ms; matmul 0.80 vs 0.76):
  two threads own the halves of one word, so the store is
  two atomics. An emitter that gives each thread a pair of points (the
  register tile already does) can write whole words.
- Run-to-run noise on the M4 is ±5% for sub-ms programs, which is why a
  kept choice is re-timed; earlier runs with a 2% bar "kept" AdaIN and
  ConvNeXt assignments that re-timed at 0.97–1.00×.

**Where the budget rejects f16.** Accumulators, not storage. f16
accumulation is lowered as rounding after every combine (the numerics of
an f16 accumulator; speed needs native half math), so these trials are
judged on error only. At rel 1e-3:

| op | reduction | measured (GPU) | predicted (interp., sequential) |
|---|---|---:|---:|
| a conv1d | out, Σ over (c, k) = 3584 terms | 3.1e-2 | 5.6e-3 (c = 32) |
| b upsample | Σ over (j, c) = 1024 | 1.5e-2 | 2.6e-3 (c = 32) |
| e AdaIN | variance Σ_t (x − μ)², T = 2000, one thread per row | 1.3e-2 | 7.9e-3 |
| e AdaIN | same, 256-thread split schedule | 2.8e-4 (admitted) | |
| e AdaIN | style projection W·s (128) | 2.9e-3 | 5.0e-4 (style 16) |
| f ConvNeXt | LayerNorm statistic Σ over C = 512 (n10) | 6.9e-2 | 1.5e-4 (C = 32) |
| f ConvNeXt | pointwise F→C matmul (1536) | 1.7e-2 | 1.4e-4 (F = 96) |
| matmul 1024³ | Σ_k, 1024 terms | 1.5e-2 | 1.2e-2 |
| snake `dα = Σ_t` (backward, T = 4096) | unit test | | > 1e-3, rejected |

The predicted column is for the small instances, whose shorter sums
round less; with the same reduction length (matmul, AdaIN) prediction
and measurement agree within ~1.5×. The AdaIN rows are the point: the
same f16 variance is rejected with one thread walking T and admitted
under a split, because the tree of 256 partial sums rounds at small
magnitudes. Precision and thread mapping are one search space.

## Native Metal backend: MSL lowering and simdgroup fragments (M4 Max, kernel-only)

`TensorGraph::to_msl` lowers the same kernels as the WGSL path to Metal
Shading Language and `tang_bench::ir_msl` runs them on buffers it owns
(feature `metal`; see `docs/tensor-ir.md`). Two things change against
WGSL: the kernels compile through Apple's compiler directly (no
wgpu/naga, native `half`), and an f16 × f16 → f32 contraction can be
scheduled onto `simdgroup_matrix` 8×8 fragments (`set_fragment`).

Method: every timing is 50 launches encoded into one command buffer
after a warm-up, one wait, divided; best of 3. WGSL is the existing
`kernel_only` / `kokoro_ops` method (one wgpu submission per run, one
sync); MPS is `scripts/torch_kokoro_ops.py` (5 warmups, 50 calls, one
`torch.mps.synchronize`), f32 and with `f16` (weights and activations
in half). All four were run serially in one session on an otherwise
idle M4 Max. Every IR result is checked over the full output against an
f64 reference (`err` = max |got − f64| / max |f64|).
`cargo run --release -p tang-bench --features metal --example msl_kernels`,
`... --example kokoro_ops -- msl`.

### Matmul and attention

| shape | WGSL best | MSL f32 best | MSL f16 operands, fragments | MPS f32 | MPS f16 |
|---|---:|---:|---:|---:|---:|
| matmul 1024³ | 0.587 (reg8), 3.66 TFLOP/s | 0.492 (auto), 4.37 | **0.191, 11.23** (err 8.3e-5) | 0.194, 11.08 | 0.176, 12.17 |
| matmul 128×576×1536 | 0.176 (auto), 1.29 | 0.090 (reg2), 2.52 | **0.040, 5.72** (9.8e-5) | 0.045, 5.00 | 0.046, 4.98 |
| matmul 512×576×1536 | 0.329 (auto), 2.75 | 0.214 (auto), 4.24 | **0.084, 10.79** (1.1e-4) | 0.097, 9.33 | 0.097, 9.37 |
| attention n=512, d=64, causal | 0.240 (flash_auto) | 0.078 (naive) | — | 0.043 (sdpa) | 0.054 |
| attention n=1024 | 0.746 (flash_auto) | 0.216 (naive) | — | 0.078 | 0.105 |

(ms, TFLOP/s.) The same f16 operands *without* fragments (scalar 4×4
register tile) run 0.498 / 0.099 / 0.213 ms: f16 storage alone buys
nothing on these compute-bound shapes; the matrix unit is the whole win.
An f16 output costs nothing either way now (native `half` stores: 0.190
vs 0.191 ms; the WGSL path's packed-word atomics made it slower).

### Kokoro ops

| op | WGSL best | MSL f32 best | MSL tuned @ 1e-3 (choice) | err | **MSL windowed fragments** | MPS f32 | MPS f16 |
|---|---:|---:|---:|---|---:|---:|---:|
| a conv1d 512→512 k7 d3 T2000 | 2.196 (3.34 TFLOP/s) | 2.296 (3.20) | 1.057 (6.94) x, w f16, conv on fragments | 5.3e-5 | **0.693 (10.6)** | 0.920 (7.98) | 0.672 (10.9) |
| b upsample 512→256 k20 s10 | 3.274 | 2.713 | 2.366: w, polyphase output f16; fragments rejected (3.77) | 4.6e-4 | **1.317** (8.0), err 8.4e-5 | 1.041 conv / 1.179 | 0.892 / 1.108 |
| c iSTFT n_fft 20 hop 5 T4000 | 0.073 | **0.018** | 0.023: all f32 | 1.4e-6 | — | 0.119 manual / 0.325 | 0.110 / 0.310 |
| d conv (a) + bias + snake | 2.201 | 2.363 | 1.066 x, w f16, fragments + snake epilogue (1 kernel) | 8.2e-5 | **0.698** (tuned; 1 kernel) | 0.820 | 0.786 |
| e AdaIN C512 T2000 style128 | 0.205 | **0.030** | 0.028: x, W, out f16 | 5.1e-4 | — | 0.250 | 0.272 |
| f ConvNeXt C512 T200 F1536 | 0.553 | 0.345 | 0.318: w1, normed act f16, pw1 on fragments | 2.0e-4 | 0.312 (pw2 eligible now, not kept: 0.420 forced) | 0.231 | 0.413 |
| a fwd+bwd (dx, dw) | 6.064 | 4.125 (im2col) | f32 only | | see next row | 2.194 | 2.064 |
| a fwd+bwd, dy given (y, dx, dw) | | 6.4 (autotune, loaded machine) | y, dx, dw on fragments (err 3.4e-4) | 3.4e-4 | **2.069** (y 0.69 · dx 0.69 · dw 0.67) | 2.194 | 2.064 |
| f fwd+bwd (all params) | 1.570 | 0.927 | f32 only | | — | 0.962 | 1.077 |

**Windowed fragments column** (PR on top of #37, `examples/conv_frag.rs`
and `kokoro_ops -- msl`). Measured on a *loaded* machine (a browser
process held the GPU; the f32 rows above re-measured 1.0–2× slower than
listed), so every number in this column is the min of two interleaved
rounds with MPS in the same window. MPS in that window: a 0.810 (f16) /
0.864 (f32), b conv-only 0.897 / 1.059 and with interleave 1.063 / 1.241,
d 0.763 / 0.825, fwd+bwd 2.071 / 2.290. Against those, a and d are ahead
of MPS f16 (0.69 vs 0.81, 0.70 vs 0.76) and fwd+bwd ties it; against the
idle-machine MPS figures in the table, a is 3% behind MPS f16 (0.693 vs
0.672), d ahead (0.698 vs 0.786), fwd+bwd level (2.07 vs 2.06), and the
upsample still behind MPS f32 (1.32 vs 1.04). Every output is checked
against f64; the forward ops sit at 5–8e-5, fwd+bwd at 3.4e-4 under the
1e-3 budget (`tune_precision` puts y, dx and dw all on fragments).

What changed:

- **Windowed staging.** A conv-shaped operand (one reduce dim read
  through its own forms, the free axis plus all other reduce dims through
  one form `st·n + Σ coef·tap`) is staged once per (channel chunk, time
  tile) as one zero-padded window — 16 × 83 halves for op a instead of a
  per-K-step im2col gather — de-interleaved by stride phase, and each tap
  loads its fragments from it at a shifted offset. The weight is staged
  once per chunk for all taps as tap planes `[k][o][c]`, one thread per
  `(o, c)` copying its taps with constant offsets. A/B in one process:
  conv 0.693 vs 1.048 ms gather, upsample 1.317 vs 3.630.
- **Where the time went** (op a): the MMA loop alone (staging stubbed)
  is 0.59 ms = 12.4 TFLOP/s; staging the weight through the generic view
  read cost +0.6 ms, the tap-fastest store order bank-conflicted (stride
  bm·cb) for another +0.3; one thread per (o, c) walking c fixed both.
  Measured and dropped: double-buffered staging (one barrier per chunk,
  0.74 vs 0.69), 128-wide n tiles (2×4 groups 0.82; 2×2 groups spill),
  per-lane `thread_elements` assembly of A from a natural-layout tile
  (1.57), 8 vs 16 channel chunks (equal).
- **Upsample** is bound by its weight reads `w[o, c, r + s·j]`: for one
  phase they are 40 B apart (0.93 ms with the loads stubbed vs 1.32).
  Ordering tiles batch(phase)-fastest so the ten phases of one tile share
  lines in L2 took it from 1.91 to 1.32. Folding the phase into the tile
  (one window, ten weight slices) is the remaining step.
- **Backward.** `dy = 1` (the fwd+bwd row) collapses dx and dw to plain
  sums, so the fragment row uses `L = Σ y ⊙ gy` (MPS times
  `backward(ones)`, same cost). dx is a transposed conv over gy and takes
  the window path (its weight view is guarded but provably in range, so
  it is staged as affine). dw is a GEMM over t per tap; its
  `x[c, t + 3k − 9]` is guarded, so it now loads fragments straight from
  device memory on every K chunk whose reads are all in range and
  gathers only the edge chunks: 2.24 → 0.67 ms. `fragment_plan` accepts
  `v_i · v_j` bodies with unread extra args (gradients keep the product
  rule's dropped factor).
- **ConvNeXt's second pointwise** (operand = inlined GELU map) is now
  eligible: the map is evaluated at staging and rounded to f16. It does
  not pay here (forced 0.420 vs 0.312 kept): GELU is recomputed per
  output-row tile, and at 0.3 GFLOP the block is launch-bound.

"Tuned" is `ir_msl::tune_precision` from the MSL-autotuned f32 schedule:
first, per contraction, the move "operands f16 + fragments"; then f16
storage per buffer, largest first; then f16 accumulators (native
rounding through `half`, timed like any move); a move is kept if the
program stays within budget vs f64 and gets ≥ 3% faster, and the final
choice is re-timed against f32. The 1e-2 budget made the same choices.

What this shows, and where fragments do not help:

- **Matmul reaches MPS.** Both operands are affine with a unit stride,
  so interior tiles load fragments straight from device memory (the
  spike's kernel shape: 64×64 tile, 2×2 SIMD groups of 4×4 fragments);
  ragged edge tiles gather into threadgroup memory with zero padding.
  11.2 TFLOP/s at 1024³ vs MPS f32 11.1 and f16 12.2; ahead of MPS at
  the two transformer shapes.
- **Conv as implicit GEMM: 2.2× over the f32 tile, still 1.15× (f32) /
  1.6× (f16) behind MPS.** The weight `w[o, (c,k)]` flattens to one
  unit-stride K and loads directly; `x[c, t + 3k − 9]` is guarded and
  dilated, so it is gathered per K-chunk through its view (zero padding
  at staging) — a 32×64 half tile per step with a div/mod per element.
  Staging *both* operands cost 2.4 ms, no better than f32; loading the
  weight directly is what got to 1.06. A windowed `x` stage (the f32
  tiler's trick) and a larger K chunk are the next steps.
- **The upsample's fragments lose (3.77 vs 2.71 ms f32).** Its weight
  read `w[o, c, r + s·j]` does not flatten `(j, c)` onto one stride and
  the phase `r` is a uniform batch dim, so both operands are gathered,
  with small K (1024) per tile. The search rejected it and kept f16
  storage instead (1.15×).
- **ConvNeXt: fragments apply to one of the two pointwise matmuls.** The
  first reads the materialized LayerNorm output (made f16), the second
  reads GELU(h + b) through a substituted map, which `fragment_plan`
  refuses (operands must be f16 buffers). At 0.3 GFLOP per matmul the
  block is launch-bound anyway (8 kernels).
- **Much of the f32 gain is the backend, not the kernel.** The MSL f32
  kernels are the WGSL emitter's kernels, yet AdaIN (6 small kernels)
  runs 0.030 vs 0.205 ms and the iSTFT 0.018 vs 0.073. With one command
  buffer per run (wgpu's pattern) MSL is still 0.038 / 0.023 ms, so the
  gap is wgpu/naga per-dispatch cost and code generation, not batching.
  The same holds for the block-shaped work: attention's naive form
  0.216 vs 0.746 ms and conv fwd+bwd 4.1 vs 6.1 ms. Big single kernels
  (the conv) are a wash between the two.
- **Attention has no fragment lowering yet** (QKᵀ and PV under the
  online-softmax monoid). MSL's best is the materialized naive form;
  MPS's sdpa is 2–3× ahead.
- **Not measured as speedups:** f16 accumulators. The search tried every
  remaining reduction with an f16 accumulator; none was kept (over budget
  or no gain).
- A pre-existing WGSL issue showed up here: the tiler can emit staging
  larger than any device allows (iSTFT's OLA tile, 84016 floats = 328 KiB,
  because the chunk-halving loop stops at chunk 1). wgpu rejects it at
  pipeline creation (autotune catches the panic); Apple's compiler service
  crashes on it (`XPC_ERROR_CONNECTION_INTERRUPTED`). MSL kernels now
  carry `threadgroup_bytes` and the Metal autotuner skips candidates over
  the device limit.
- `kernel_only` hangs in its transformer-block section on this machine
  (also on the base commit `fd193b4`); its matmul/attention rows above are
  from the part that runs.

### Flash attention on simdgroup fragments (M4 Max, kernel-only)

`cargo run --release -p tang-bench --features metal --example attention_fragments`
vs `scripts/torch_attention.py`. Both ran interleaved in one
`gpu-lock` window (two rounds; round 2 shown, round 1 within ~5%).
d = dv = 64; q/k/v random in [−1, 1]. `f32-auto` is the derived graph
under `schedule_auto` lowered to MSL (the best f32 schedule we have for
the multi-head graph); `fragment` is the same graph with q/k/v stored
f16 and the fused kernel flagged `fragment`: S = Q·Kᵀ on half
fragments (f32 acc), online softmax in registers (MLX lane layout), P
cast to half, O += P·V on fragments, normalizer fused. Causal runs skip
key tiles the mask covers — derived from the graph (the mask
`select(j − i, −1e30, 0)` is affine in the iota args; evaluated at the
tile box it gives a uniform skip test). TFLOP/s counts 4·h·n²·d (×½ causal).

| heads | causal | n | f32-auto | fragment | vs f32 | TFLOP/s | SDPA f32 | SDPA f16 |
|---|---|---|---|---|---|---|---|---|
| 1 | no | 512 | 0.080 | 0.154 | 0.52× | 0.43 | 0.173 | 0.079 |
| 1 | no | 1024 | 0.250 | 0.314 | 0.80× | 0.85 | 0.077 | 0.100 |
| 1 | no | 2048 | 0.860 | 0.678 | 1.27× | 1.58 | 0.179 | 0.189 |
| 1 | no | 4096 | 3.304 | 1.506 | 2.19× | 2.85 | 0.554 | 0.516 |
| 1 | yes | 512 | 0.088 | 0.148 | 0.60× | 0.23 | 0.046 | 0.054 |
| 1 | yes | 1024 | 0.281 | 0.290 | 0.97× | 0.46 | 0.081 | 0.099 |
| 1 | yes | 2048 | 0.977 | 0.590 | 1.65× | 0.91 | 0.165 | 0.191 |
| 1 | yes | 4096 | 3.743 | 1.238 | 3.02× | 1.73 | 0.409 | 0.463 |
| 8 | no | 512 | 0.422 | 0.191 | 2.21× | 2.81 | 0.081 | 0.073 |
| 8 | no | 1024 | 1.659 | 0.780 | 2.13× | 2.75 | 0.251 | 0.233 |
| 8 | no | 2048 | 6.449 | 2.951 | 2.18× | 2.91 | 0.882 | 0.757 |
| 8 | no | 4096 | 26.50 | 12.59 | 2.11× | 2.73 | 3.654 | 2.992 |
| 8 | yes | 512 | 0.508 | 0.175 | 2.91× | 1.54 | 0.065 | 0.069 |
| 8 | yes | 1024 | 2.068 | 0.440 | 4.70× | 2.44 | 0.167 | 0.150 |
| 8 | yes | 2048 | 8.224 | 1.637 | 5.02× | 2.62 | 0.534 | 0.461 |
| 8 | yes | 4096 | 33.23 | 5.788 | 5.74× | 2.97 | 1.951 | 1.626 |

(ms.) Honest reading:

- Against our own f32 path the fragment kernel wins 2–5.7× once there is
  enough work (8 heads, or n ≥ 2048 single-head); causal gains more
  because skipped tiles are free. Max |fragment − f32| is 0.6–1.9e-3 (P
  and q/k/v in half); `tune_precision` keeps it under a 1% budget vs f64.
- Against PyTorch MPS SDPA it is **3–4× slower** at 8 heads × 4096 and
  worse on small single-head problems (grid of n/32 threadgroups is too
  small to fill the GPU: 16 groups at n = 512). ~3 TFLOP/s against
  SDPA's ~10. Known gaps, in likely order of payoff: K/V staged by a
  generic `arg_read` gather each tile (scalar loads, two barriers, no
  double buffering, no direct device fragment loads); BK = 32 keys and
  8 rows per SIMD group (MLX uses larger query tiles per SIMD group and
  `exp2` with log2e folded into the scale); single-head small-n needs
  key-split (flash-decoding) parallelism.
- The CUDA wmma flash kernel from #34 (`flash_tile`) matches a narrower
  pattern (exact `(score, 1, v)` slots, unscaled score, d_lanes ∈ 16..64);
  the Metal `attention_plan` is a superset (literal scale, ragged d/n/dv,
  guarded views, any per-row slots, dv blocked as a grid axis, GQA via
  `[hk, g]` heads). Folding `flash_tile` onto `attention_plan` is a
  follow-up.

#### Speed pass (supersedes the fragment column above)

Same harness (`ATT_HEADS`, `ATT_CAUSAL`, `ATT_SAMPLES` select shapes;
best of 7), SDPA from the same `gpu-lock` window. The 4-head rows at
n = 128–512, non-causal, are the phoneme-encoder shape of the voice
model.

| heads | causal | n | f32-auto | fragment | vs f32 | TFLOP/s | SDPA f32 | SDPA f16 | vs SDPA f16 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | no | 512 | 0.080 | **0.029** | 2.75× | 2.32 | 0.169 | 0.084 | 2.9× faster |
| 1 | no | 1024 | 0.250 | **0.052** | 4.82× | 5.17 | 0.076 | 0.099 | 1.9× faster |
| 1 | no | 4096 | 3.311 | **0.504** | 6.57× | 8.52 | 0.555 | 0.517 | 1.03× faster |
| 1 | yes | 512 | 0.086 | **0.030** | 2.88× | 1.12 | 0.046 | 0.054 | 1.8× faster |
| 1 | yes | 1024 | 0.280 | **0.054** | 5.21× | 2.50 | 0.080 | 0.099 | 1.8× faster |
| 1 | yes | 4096 | 3.768 | **0.298** | 12.6× | 7.20 | 0.408 | 0.462 | 1.6× faster |
| 4 | no | 128 | 0.024 | **0.012** | 1.96× | 1.35 | 0.058 | 0.069 | 5.8× faster |
| 4 | no | 256 | 0.067 | **0.018** | 3.68× | 3.71 | 0.095 | 0.049 | 2.7× faster |
| 4 | no | 512 | 0.222 | **0.041** | 5.44× | 6.57 | 0.051 | 0.055 | 1.3× faster |
| 4 | no | 4096 | 13.01 | 1.967 | 6.61× | 8.73 | 1.722 | 1.496 | 1.31× slower |
| 4 | yes | 4096 | 15.03 | 0.835 | 18.0× | 10.3 | 0.993 | 0.871 | 1.04× faster |
| 8 | no | 512 | 0.422 | 0.069 | 6.09× | 7.74 | 0.080 | 0.071 | 1.03× faster |
| 8 | no | 1024 | 1.660 | **0.221** | 7.53× | 9.74 | 0.250 | 0.235 | 1.06× faster |
| 8 | no | 4096 | 26.15 | 3.411 | 7.67× | 10.1 | 3.459 | 2.696 | 1.27× slower |
| 8 | yes | 512 | 0.482 | **0.047** | 10.3× | 5.72 | 0.062 | 0.066 | 1.4× faster |
| 8 | yes | 1024 | 1.925 | **0.124** | 15.5× | 8.65 | 0.166 | 0.153 | 1.23× faster |
| 8 | yes | 4096 | 29.85 | 1.669 | 17.9× | 10.3 | 1.874 | 1.506 | 1.11× slower |

(ms.) ~3 → ~10 TFLOP/s. Each change measured on its own (8 heads, d 64,
ms before → after; the GPU is shared, so ±10% run to run):

| change | 8h n1024 | 8h n4096 | 8h n4096 causal | 1h n512 | kept |
|---|---|---|---|---|---|
| baseline (PR #40) | 0.785 | 16.46 | 7.77 | 0.182 | |
| Q/K/V staged with `half4` copies when the read is a direct unit-stride f16 view (`direct_f16`, `stage_direct`) | 0.533 | 11.48 | 6.31 | 0.121 | yes |
| `exp2` with log2 e folded into the score | 0.546 | 11.88 | 6.55 | 0.111 | no (no change: fast-math `exp` already is `exp2`) |
| K/V fragments `simdgroup_load`ed straight from device memory when every key tile and value block is full — no staging, no barriers in the key loop | 0.495 | 10.69 | 4.75 | 0.100 | yes |
| epilogue from the accumulator registers (lane owns row `fm`, cols `fn`, `fn+1`): no result tile, no row-stat tile, threadgroup memory 9.6 → 4.6 KB | 0.452 | 7.85 | 4.39 | 0.104 | yes |
| 16 rows per SIMD group (RF 2) via references into the fragment arrays | 0.648 | 11.76 | 8.22 | 0.231 | no (spills) |
| **every constant-trip loop unrolled in the generated text** (`unroll_const_loops`: `{ const uint jf = 3u; … }` scopes) | **0.230** | **3.85** | **1.98** | **0.031** | yes |
| then RF 2 again (fully unrolled) | 0.279 | 4.13 | 2.11 | 0.107 | no |
| then BK 64 | 0.266 | 4.37 | 2.55 | 0.035 | no |
| then `exp2` again | 0.255 | 3.85 | 2.04 | 0.030 | no (neutral) |

What this shows:

- **The big one was the compiler, not the algorithm.** The kernel indexed
  `simdgroup_matrix` arrays and `thread_elements()` with loop variables;
  Metal left some of those loops rolled and the fragments went through
  the stack. Ablations before the fix said as much: dropping the K/V
  loads or the `exp`s changed nothing, so the MMA loop itself was
  stalled. Unrolling in the emitter (constant indices everywhere)
  doubled throughput on every shape. Any fragment kernel that indexes
  fragment arrays dynamically should get the same pass.
- Bigger register tiles (16 rows per SIMD group, BK 64) lose on M4 at
  d = 64: register pressure costs more occupancy than the extra
  fragment reuse buys. MLX's 8 rows × BK 32 is the right shape here.
- Key-split (flash-decoding) was not needed for the targets: 1 head
  n = 512 runs 0.029 ms, 2.75× under f32-auto and 2.9× under SDPA f16,
  despite only 16 threadgroups. It stays the lever for single-query /
  very short-query decode.
- Still behind SDPA f16 by 1.1–1.3× at n = 4096 (8 heads; 4 heads
  non-causal). Ragged shapes (n not a multiple of 32, dv not a multiple
  of the 64-column block) take the staged `half4`/gather path with
  barriers.

## Whole-model compilation (spike)

`examples/whole_model.rs [layers] [seq] [wgpu|cuda|cuda-compile|stats]`
builds N SmolLM2-135M-like blocks (d 576, 9 heads, 3 kv heads, head dim
64, ff 1536, rope, no biases), an MSE loss, the full backward and an
AdamW update of all 7N projection weights as **one** `TensorGraph`
(`tang_bench::ir_model::train_step`), compiles it with the block's pass
pipeline, lowers it to one program and runs a step as one submission.
f32 everywhere, seq 128. `scripts/torch_model_bench.py` is the PyTorch
reference (same model, `AdamW`, CUDA events).

**Memory planning** (`TensorGraph::plan_memory`, `tensor_memplan.rs`):
buffers get storage slots by liveness over the kernel order, and the
AdamW writes `p′, m′, v′` go into `p, m, v` when legal (point-for-point
map, every other reader of the donor already ran; update kernels are
sunk past the backward kernels that still read the old weight). wgpu
cannot bind one buffer read-only and read-write in a dispatch, so it
gets slots but no in-place updates. "Persistent" is params + m + v +
data; everything else is intermediates (activations, gradients, and the
naive plan's separate `p′, m′, v′`).

| layers | kernels | persistent | intermediates naive | planned | planned + in place | **peak** naive / planned / + in place | PyTorch peak (fused / foreach AdamW) |
|---|---|---|---|---|---|---|---|
| 1  | 79   | 41 MB   | 69 MB   | 44 MB   | 18 MB  | 110 / 85 / 59 MB | — |
| 4  | 319  | 163 MB  | 276 MB  | 172 MB  | 67 MB  | 439 / 334 / **229 MB** | 239 / 293 MB |
| 30 | 2399 | 1216 MB | 2076 MB | 1280 MB | 470 MB | 3291 / 2496 / **1685 MB** | 1673 / 2085 MB |

Planning plus in-place updates cuts the step's peak by 49% at 30 layers,
to PyTorch's fused-AdamW peak. Slots alone barely move the peak (the
live lower bound over this order is 1215 MB at 30 layers): the separate
`p′, m′, v′` outputs live to the end, so in place is where the bytes are.
Kernel order is still `to_wgsl`'s node order; a memory-aware schedule
(run each weight's update as soon as its gradient exists) is the next
lever. Graph build + passes + lowering + planning at 30 layers: 0.3 s +
0.6 s + 0.1 s + 0.03 s.

**Step time.** M4 Max (wgpu, one submission per step) and RTX 3090
(CUDA, one stream, optionally the whole step captured as one CUDA graph).
The 3090 was shared — 97% utilized by other tenants for all of these runs
— so its absolute numbers are inflated; minimum over repeats.

| | 4 layers | 30 layers |
|---|---|---|
| M4 wgpu, naive buffers | 11.6 ms | 87.6 ms |
| M4 wgpu, planned slots | 11.7 ms | 89.4 ms |
| M4 wgpu, one block's step × N | 3.0 × 4 = 12.0 ms | 3.18 × 30 = 95.4 ms |
| 3090 CUDA, naive (graph) | 14.7 (13.8) ms | 117.0 (112.5) ms |
| 3090 CUDA, planned + in place (graph) | 14.7 (13.9) ms | 108.2 (104.8) ms |
| 3090 CUDA, one block's step × N (graph) | 3.31 (3.36) × 4 = 13.2 ms | 3.44 (3.36) × 30 = 103 ms |
| 3090 PyTorch eager, AdamW fused fp32 / tf32 | 8.0 / 7.5 ms | 66.7 / 63.0 ms |

One graph per step is 8% faster than N separate block steps on the M4 at
30 layers and on par on the 3090. CUDA-graph capture saves 4–6% (~0.8 ms
at 4 layers, ~4 ms at 30 for 319 / 2399 launches): launch overhead is not
the bottleneck at seq 128; the kernels are (PyTorch is still 1.6× faster,
mostly cuBLAS GEMMs and its fused optimizer; see "Toward flash backward").
Planning does not cost time; on CUDA it is slightly faster (fewer pages
touched).

**Compile cost: canonical kernels.** Each layer's kernels used to embed
node numbers in identifiers (`b{j}`, `read_{j}`, `point_{j}`, …), so the
2399 kernels at 30 layers were 2399 distinct sources. Lowering now
renumbers those in order of first appearance (`wgsl::canonical_source`,
in `to_wgsl`, `to_cuda` and `to_msl`); bindings stay in `reads` order,
so one compiled kernel serves every layer. Every source-keyed cache
(`KernelCache`, `CudaDevice`, tuning caches) then hits across layers, and
`CudaDevice` / `PlannedCuda` share an on-disk PTX cache
(`~/.cache/tang/ptx`, `$TANG_PTX_CACHE`). wgpu's pipeline cache is
Vulkan-only, so there is no persistent wgpu cache on the M4.

| | before | after |
|---|---|---|
| distinct sources, 4 / 30 layers (wgsl) | 319 / 2399 | 92 / 92 |
| distinct sources, 4 / 30 layers (cuda) | 319 / 2399 | 90 / 90 |
| M4 wgpu first run, 30 layers (shader compiles) | 232.9 s | 8.4 s |
| M4 wgpu first run, 4 layers | 29.7 s | 8.1 s |
| 3090 nvrtc, 30 layers, cold (24 cores) | 49.0 s | 1.4 s |
| 3090 module load, 30 layers, driver JIT cache off / warm | 35.7 s / 0.62 s | 1.95 s / 0.23 s |
| 3090 nvrtc, 30 layers, PTX on disk | — | 0.02 s |

Outputs (loss and every updated tensor) are bitwise identical before and
after on both backends, and step time is unchanged (M4 30 layers naive
87.7 vs 88.1 ms; 3090 planned + in place, graph, 28.5 vs 28.0 ms).

**Cross-layer fusion.** The existing passes do fire across block
boundaries, and the result is a warning. `substitute_maps` sees the
residual stream `h₁ = h₀ + attn₀ + ffn₀, …` as a chain of maps each read
point-for-point (recompute factor 1) and splices all of it: the stacked
forward drops one kernel per boundary (481 vs 30 × 17 = 510), but every
reader of `h_N` — and of the residual gradient in the backward — now
recomputes `x + Σ` over all earlier blocks. The widest kernel reads 35
buffers at 4 layers and 269 at 30 (O(N) reads per kernel, O(N²) traffic);
wgpu rejects it from 2 layers on (16 storage buffers per stage), and on
CUDA the 30-layer step is 152 ms instead of 105 ms. `compile_with_barriers`
keeps each block's output and its gradient materialized (passed to the
passes as extra outputs); the widest kernel then reads 11 buffers at any
depth and the step is 30 × (one block's kernels) + 29 (the residual
gradient between blocks; a lone block never computes `dx`). So: no net
kernels saved across layers once the stream is materialized, and a cost
model for map substitution needs a fan-in bound, not just the recompute
factor.

## OpenCL on the Booster K1 (Adreno 740, QCS8550)

`to_opencl` (WGSL kernels transpiled to OpenCL C) exported by
`cargo run --release -p tang-bench --example opencl_export -- export ROOT`,
run on the robot by `tools/opencl-runner/tang_cl.c` (gcc, no Rust), checked
on the Mac against the f64 `eval` (`opencl_export check ROOT`). Times are the
minimum over ≤30 repeats of OpenCL profiling events (first kernel start to
last kernel end), default build options. The SoC also runs vendor services
(load average 7–17 during the runs), so treat these as ±5%.

Device peak measured with `tools/opencl-runner/peak.c`: fp32 FMA 1501
GFLOP/s, fp16 FMA 2996 GFLOP/s, device copy 49.5 GB/s. Max single
allocation 256 MiB.

| case | time | throughput | max err (rel to max \|ref\|) |
|---|---|---|---|
| matmul 1024³, best schedule (`reg8c8`) | 6.66 ms | 322 GFLOP/s (21% of fp32 peak) | 2.5e-3 (1.8e-6) |
| matmul 1024³, `schedule_auto` (`reg4`) | 10.56 ms | 203 GFLOP/s | 2.5e-3 (1.8e-6) |
| matmul 512×576×1536, best (`reg4x8`) | 3.31 ms | 274 GFLOP/s | 1.2e-3 (1.4e-6) |
| matmul 512×576×1536, `schedule_auto` | 4.78 ms | 189 GFLOP/s | 1.2e-3 (1.4e-6) |
| block forward, seq 128 (17 kernels) | 7.71 ms | 122 GFLOP/s | 1.1e0 (1.9e-6) |
| block loss + 7 grads, seq 128 (51 kernels) | 19.1 ms | 148 GFLOP/s (≈3× fwd FLOPs) | 2.0e4 (7.7e-8) |
| GRU step, batch 1, obs 64, hidden 256 | 0.205 ms | 2.4 GFLOP/s | 1.1e-7 (1.8e-7) |
| GRU step, batch 64 | 0.596 ms | 53 GFLOP/s | 1.2e-7 (2.0e-7) |

What the Adreno likes (matmul candidate sweep, both shapes): 8×8 or 4×8
register tiles are ~1.45× the 4×4 tile `schedule_auto` picks; a 8-deep k
chunk (`reg8c8`) is best at 1024³; `split` (small groups, many partials) is
pathological here (1.3 s at 1024³) and `tiled` is 6× slower than the register
tiles. `-cl-mad-enable` / `-cl-fast-relaxed-math` change nothing (the
compiler already contracts). In the block, the slowest kernels are the
projections launched as 6–48 work-groups of 256 on 6 CUs (k13: 2.3 ms, 48
groups; k15: 1.7 ms, 18 groups): occupancy, not arithmetic — the schedule
chosen for desktop GPUs underfills the Adreno. Whole-program tuning per
kernel on the device (pick the schedule per node by timing) is the next step.

### Per-kernel tuning, f16 storage and the GRU (Adreno 740)

**Tuning.** `opencl_export tune-export ROOT CASE` writes, next to the
program, every kernel's schedule candidates (tang-compile's
`schedule_candidates` plus register tiles up to 8×8, k chunks 8/16/32,
8×8-thread groups, and 64/128-thread splits). `tang_cl` times each one
after the program runs (min of 5 launches; one launch if it is >4× the base),
compares its output with the base kernel's, and checks the SoC temperature
before every candidate (pauses at 82 °C until ≤78 °C). `tune-pick` keeps the
fastest candidate within 1e-4 of the base and writes a `TuningCache`
(`tools/opencl-runner/tuning/`, keyed by `QUALCOMM Adreno(TM) 740` + the
untuned OpenCL sources); `TANG_CL_TUNING=DIR opencl_export export` applies it.

| program | `schedule_auto` | tuned per kernel | candidates timed |
|---|---|---|---|
| block forward, seq 128 (17 kernels) | 7.71 ms | **6.13 ms** (−20%) | 212 |
| loss + 7 grads, seq 128 (51 kernels) | 18.96 ms (sum of kernels) | **14.34 ms** (sum of kernels) | 689 |

The training-step figure is the sum of the chosen kernels' times from the
tuning run. The tuned program was exported but not re-run end to end,
because the robot dropped off the network first.

What won, per kernel:
- The 6- and 18-group projections (16×16 threads, 4×4 registers) went to
  8×8-thread groups with 4×4 or 4×8 registers (4× the groups): 0.436 →
  0.356 ms and 0.623 → 0.515 ms.
- The 48-group MLP matmuls kept 16×16 threads with 4×8 registers and a 16
  chunk: 2.29 → 1.60 ms and 1.72 → 1.35 ms.
- In the backward, the rows×lanes attention tiles (64×4 and 32×8) lose to
  register tiles: 0.75 → 0.16 ms and 0.42 → 0.25 ms.
- Small splits: 64 threads beat 256.

**Rule (not yet applied to `schedule_auto`).** On a 6-CU part, a register
tile launching fewer than ~4 groups per CU wants 8×8-thread groups, and
4×8 registers beat 4×4 everywhere. Desktop GPUs were tuned the other way,
so this belongs in a device-aware default, which needs a CU count that
`schedule_auto` does not take yet. Left for a follow-up.

**False rejects.** All 59 candidates rejected in the backward belong to
three kernels whose outputs are cancellation noise: the dQ/dK gradients
have an f64 magnitude of ~4e-19 and come out as f32 noise of ~20, both for
the base kernel and for every candidate. The 1e-4 rule then rejects them
correctly, but for the wrong reason. These two outputs also show that the
pooled error figure in the table above (7.7e-8) hides an output whose own
relative error is meaningless; `check` now prints the worst per-output
relative error as well.

**f16 storage** (the precision schedule enumerated, not searched: `_hops` is
every register-tile operand in f16, `_hall` is every buffer but the outputs;
arithmetic and accumulation stay f32; error is against the f64 `eval`):

| case | f32 | f16 tile operands | f16 all buffers | keep? |
|---|---|---|---|---|
| matmul 1024³ (`reg8c8`) | 6.66 ms, 1.8e-6 | 7.80 ms, 8.0e-5 | 7.80 ms, 8.0e-5 | no (slower) |
| matmul 512×576×1536 (`reg4x8`) | 3.30 ms, 1.4e-6 | 3.30 ms, 9.9e-5 | 3.30 ms, 9.9e-5 | no (same) |
| block forward (tuned) | 6.13 ms, 1.9e-6 | 6.09 ms, 7.5e-5 | 6.03 ms, **inf** (activations > 65504) | no (noise) |
| GRU step, batch 1 | 0.207 ms, 1.8e-7 | 0.181 ms, 1.8e-7 | **0.121 ms**, 4.1e-4 | yes: f16 everything |
| GRU step, batch 64 | 0.596 ms, 2.0e-7 | 0.591 ms, 4.1e-4 | 0.582 ms, 4.1e-4 | no (noise) |

The matmuls here are compute-bound and the tile already stages through
local memory, so halving the bytes saves nothing. The f16-loading tile is
slower at 1024³, where the conversions cost more than the traffic they
save. Only the batch-1 GRU, a weight-streaming GEMV, gains (−42%). f16
*arithmetic* (`half` math under `cl_khr_fp16`, the 2× FMA peak) needs a
half-typed body emitter in the lowering; tang's f16 accumulation is
emulated by rounding in f32, so it was not tried.
The f16-storage training step was exported but not run (disconnect).

**GRU latency.** `tools/opencl-runner/launch.c` gives the overhead floor
of one launch (one 64-item group, one store), with vendor services
running (load 7–11):

| | median | min | p95 |
|---|---|---|---|
| enqueue + `clFinish` | 540–606 µs | 120–200 µs | 1.05–1.57 ms |
| enqueue + `clFlush` + spin on the event | 380–423 µs | 109–111 µs | 0.90–1.34 ms |
| device time of the kernel | 3.8 µs | | |
| back-to-back, one finish | 13–59 µs per launch | | |

The fused GRU step (`grufused_b*`) concatenates the input and hidden
contractions on one reduce axis of `obs + hidden`, with guarded views
reading zero past each operand. `merge_siblings` then makes the four gate
sums one tuple reduction with the gate math as its epilogue, so the step
compiles to **one kernel** at batch 1 (7 before) and two at batch 64.

| case | kernels | device time | wall (enqueue all + finish, min) |
|---|---|---|---|
| GRU batch 1 | 7 | 0.207 ms | 0.655 ms |
| GRU batch 1, fused | 1 | 0.211 ms | 0.676 ms |
| GRU batch 1, f16 storage | 7 | 0.121 ms | 0.623 ms |
| GRU batch 1, fused, f16 | 1 | 0.131 ms | 0.681 ms |
| GRU batch 64 | 7 | 0.596 ms | 1.03 ms |
| GRU batch 64, fused | 2 | 0.844 ms | 1.30 ms |

The fused kernel uses `schedule_auto`'s 256-thread split (256 groups); its
per-kernel tuning was exported but did not run before the disconnect. For a
control loop the round trip is the limit, not the math. Each step costs at
least ~0.11 ms and typically ~0.4–0.6 ms of submit-and-wait, with a p95
above 1 ms under the vendor load. So 1 kHz is out of reach with one
synchronous step per tick, and 500 Hz works at the median but misses
deadlines at p95. To get there, enqueue several steps per submit (the
back-to-back cost is 13–59 µs per launch), keep the loop on the GPU, or run
the batch-1 GRU on the CPU.

#### After the reconnect (robot rebooted, 48–64 °C, load 7–10)

Training step at seq 128, tuned per kernel and run end to end. Error is
the worst per-output relative error, leaving out the two dQ/dK gradients:
their f64 values are ~4e-19, so their output is pure f32 noise.

| variant | program | worst output rel | keep? |
|---|---|---|---|
| f32, `schedule_auto` (#58) | 19.1 ms | 7.7e-6 | |
| f32, tuned | **14.57 ms** (−24%) | 7.7e-6 | yes |
| tuned, f16 tile operands | 14.53 ms | 3.1e-4 | no: within budget, but no gain |
| tuned, f16 all buffers | 14.27 ms | inf/NaN (overflow) | no |

GRU step after tuning the fused kernel and the unfused one alike
(time = device events, wall = enqueue all + finish, min of 20):

| case | kernels | device | wall | rel err |
|---|---|---|---|---|
| batch 1, tuned (64/128 splits) | 7 | 0.101 ms | 0.463 ms | 1.8e-7 |
| batch 1, tuned, f16 storage | 7 | **0.086 ms** | **0.267 ms** | 4.1e-4 |
| batch 1, fused, tuned (128 split) | 1 | 0.189 ms | 0.358 ms | 1.8e-7 |
| batch 1, fused, tuned, f16 | 1 | 0.108 ms | 0.420 ms | 4.1e-4 |
| batch 64, tuned (8×8 groups) | 7 | **0.421 ms** | 0.954 ms | 2.0e-7 |
| batch 64, fused, tuned | 2 | 0.693 ms | 1.061 ms | 2.0e-7 |

Fusing cuts the launches, but the fused kernel is slower on the device.
Each output point reduces 320 terms (split 128), while the unfused GEMVs
split six short reductions across more groups. Wall times are dominated
by the 0.1–0.6 ms submit-and-wait floor and vary by ±0.2 ms from run to
run, so fused versus unfused wall time is not resolved at batch 1. The
latency conclusion above still holds.

## CPU backend: `to_c` on the Booster K1's Cortex-X3 (and the M4)

`to_c` turns a program into one C file (`docs/tensor-ir.md`, "CPU backend
(C)"). `cargo run --release -p tang-bench --example cpu_export -- export
ROOT` writes the cases. On the robot, `tools/cpu-runner/run_all.sh ROOT 7`
builds each one with gcc 11.4 (`-O3 -march=armv8.6-a+fp16+fp16fml
-mtune=cortex-x1`; gcc 11 knows neither the X3 nor the A715) and runs it.
`cpu_export check ROOT` then compares the results with the f64 `eval` on
the Mac.

Each run is single-threaded, pinned with `sched_setaffinity` to cpu7, the
QCS8550's one Cortex-X3 (3.19 GHz). It is `nice -n 10` and back to back:
`tang_run()` is timed with `CLOCK_MONOTONIC` around every step, after a
warm-up of up to 500 steps / 0.5 s. A run is capped at 4 s, and the script
waits for the hottest thermal zone to be ≤ 78 °C before each one. Vendor
services kept load at 6–16 and cpu7 about 22% busy. `SCHED_FIFO` works
without root on this image (`TANG_FIFO=1`), so it was used only for short
batch-1 runs (≤ 0.35 s). In longer runs RT throttling stalls the task for
~50–100 ms once a second, and it would starve whatever else is on the
core.

Inputs are uniform in ±0.2. The GRU is ipse-world's `GruCell` (obs 64,
hidden 256, PyTorch gate convention). The MLP is a locomotion-style
policy: 64 → 256 → 256 → 12, ELU. All times are µs per step.

**Batch 1, `SCHED_FIFO`, 10 000 steps**

| case | min | median | p99 | p99.9 | max | rel err vs f64 |
|---|---|---|---|---|---|---|
| GRU step (1 kernel) | 19.5 | **22.5** | 36.6 | 48.7 | 62 | 1.8e-7 |
| GRU, f16 storage | 28.4 | 30.9 | 40.7 | 61.3 | 89 | 4.1e-4 |
| GRU, `grufused` graph | 25.3 | 30.9 | 56.8 | 68.3 | 132 | 1.8e-7 |
| MLP policy (3 kernels) | 5.8 | **6.7** | 12.7 | 25.7 | 57 | 5.5e-7 |
| MLP, f16 storage | 10.1 | 10.5 | 16.5 | 30.9 | 58 | 3.7e-5 |

A second FIFO pass under heavier vendor load (load 16) gave GRU 20.2 /
23.9 / 36.8 / 49.8 and MLP 5.9 / 7.0 / 10.8 / 17.3 (min / median / p99 /
p99.9).

**Batch 1, `SCHED_OTHER` (niced), 20 000 steps, load 6–11**

| case | min | median | p99 | p99.9 | max |
|---|---|---|---|---|---|
| GRU step | 19.3 | 22.8 | 81.5 | 318 | 11 209 |
| MLP policy | 5.8 | 6.5 | 35.3 | 83 | 455 |

The niced tail is scheduling: the vendor processes preempt a nice-10 task
for up to 11 ms. The FIFO rows are what a real-time control thread sees.

**Against the hand-written loop and the other devices (GRU, batch 1)**

| | min | median | p99 | p99.9 |
|---|---|---|---|---|
| `to_c`, X3, FIFO | 19.5 | **22.5** | 36.6 | 48.7 |
| naive C, dot per output (strided `W` column), X3 | 226 | 263 | 503 | 772 |
| naive C, k outside j (row of `W` inner, vectorized), X3 | 25.5 | 30.8 | 79.7 | 287 |
| `to_c`, M4 (P-core, no pinning), f32 / f16 storage | 10 / 8 | 15 / 9 | 20 / 12 | 28 / 21 |
| Adreno 740, tuned, f16 storage (#59): device time | | 86 | | |
| Adreno 740, same: wall (enqueue + finish), min of 20 | 267 | | | |
| Adreno 740 submit-and-wait floor (`launch.c`) | 109–200 | 380–606 | p95 900–1570 | |

The M4 GRU numbers are from a quiet run. Later runs on the loaded Mac
were 1.5–2× slower (see the host notes). The naive loops are checked too:
1.8e-7, the same as `to_c`.

**Batch 64 and the block (single core)**

| case | `to_c`, X3 | `to_c`, M4 | Adreno 740 (#59) |
|---|---|---|---|
| GRU step, batch 64 | 1.34 ms median (1.06 min, FIFO); 1.8–2.8 ms niced at load 7–16 | 0.46 ms | 0.42 ms device, 0.95 ms wall |
| MLP policy, batch 64 | 0.43 ms median (FIFO); 0.54–0.84 ms niced | 0.32 ms | — |
| block forward, seq 128 (no flash; 20 kernels) | 50–66 ms | 30 ms | **6.13 ms** (tuned) |
| block forward, seq 128, GPU pass order (flash) | 84–113 ms | 50 ms | 6.13 ms |

All cases agree with the f64 `eval`: 2.0e-7 (GRU b64), 2.9e-7 (MLP b64),
8.0e-7 (block), and 4e-4 / 8e-4 with f16 storage.

What the numbers say:
- **Batch-1 control belongs on the CPU.** One X3 core runs the GRU
  world-model step in 22 µs and the policy in 7 µs, with a FIFO p99.9 of
  49 µs and 26 µs. A 1 kHz tick (1000 µs) has a 20× margin for both
  together. The Adreno spends 86 µs of device time on the same GRU step,
  and its submit-and-wait alone has a median of 380–606 µs, with a p95
  above 1 ms.
- **The lowering beats the hand-written loop.** It is 12× faster than
  the textbook dot product and 1.35× faster than a cache-friendly
  hand-written loop. It comes from the IR with no GRU-specific code.
- **Batched rollouts and the transformer belong on the GPU**, off the
  control thread. GRU batch 64 takes 1.3 ms on one X3 core against 0.42
  ms of Adreno device time. The seq-128 block takes 50–66 ms against
  6.13 ms. The CPU lowering is register-blocked GEMM at ~15–20
  GFLOP/s, with no cache tiling and no threads.
- **f16 storage is slower on the X3.** With gcc 11 the `__fp16 → f32`
  widening costs more than the halved bytes save, even though the f16 GRU
  (0.5 MB) fits the X3's 1 MB L2 and the f32 one (0.98 MB) does not quite.
  On the M4 it helps (15 → 9 µs). f16 arithmetic (`fmla .8h`) was not tried.
- **Register block size is device-dependent.** The batch-64 GRU is
  1.34 ms with a 128-float accumulator block, 1.5–1.8 ms at 64 and 1.66
  ms at 32. Batch 1 is fastest at 64 floats (the defaults now). gcc 11
  spills the 64-float block when unrolling: the inner loop reloads the
  `W` pointers from the stack.
- The `grufused` graph (one guarded reduction over `obs + hidden`) is
  slower on the CPU (31 vs 22 µs at batch 1, 10–20 ms vs 1.3–2.8 ms at
  batch 64). Its guards sit in the inner loop and its 4-wide tuple state
  shrinks the vector chunk. The plain graph already fuses to one kernel
  on the CPU.

Thermals and load: idle the hottest zone sits at 73–76 °C. A 4 s run on
the X3 takes it to 80–86 °C (89 °C once, with the vendor stack also busy).
So the script cools to ≤ 78 °C before every run. Each run is one core for
≤ 4.5 s, so the 1-minute load moved only with the vendor stack: 6–11 for
most runs, and 15–16 near the end, when vendor processes (`motion`,
`hippocampus`, `optic`, …) were busier. `~/tang-probe/cpu/` was 66 MB
during the runs. The cases were deleted afterwards, and only the runner
sources remain.

## OpenCL backend: Qwen3 decode and prefill on the Booster K1 (Adreno 740)

`tang-gpu` feature `opencl` (`src/opencl.rs`, `Runtime::OpenCl`) and `to_opencl_decode`
(`tensor_opencl_gemv.rs`). Run with `TANG_BACKEND=opencl`. MLX 4-bit checkpoints, a 49-token chat
prompt, greedy. The host thread is pinned to an A510 at nice 10, with vendor load 7–15 and the GPU
at 57–77 °C. Times are device times from `--bench` / `--time-prefill`.

| | decode step at context 64 / 1024 | end to end | 49-token prefill |
|---|---|---|---|
| Qwen3-0.6B, Vulkan (rnshim, `to_glsl_decode`) | 61.9 / 63.4 ms | 13.6 tok/s | 1716 ms |
| Qwen3-0.6B, OpenCL | **29.5 / 36.5 ms** | **31.9 tok/s** | 2168 ms (warp) → 1094 ms (tiled) |
| Qwen3-1.7B, OpenCL, warps 4 × rows 2 | 79.2 / 86.2 ms | 12.2 tok/s | 6762 → 3451 ms |
| Qwen3-1.7B, OpenCL, warps 4 × rows 4 | 55.5 ms | 18.0 tok/s | |
| Qwen3-1.7B, warps 8 × rows 4 / 4 × 1 | 71.6 / 135 ms | | |
| Qwen3-8B, OpenCL (vocab in 2 blocks) | 290 ms | 3.4 tok/s | |

**Correctness**
- Greedy ids are identical to Metal for 0.6B and 1.7B, and `qwen_decode tiny` gives 2.7e-6 (decode)
  and 1.0e-6 (prefill).
- On the Mac's OpenCL (local-memory shuffles), logits against the reference agree to 2.2e-2 (0.6B)
  and 4.5e-2 (1.7B), argmax 20/20.

**Adreno findings**
- **Vector elements by index.** `(&v.x)[i]` written as `((T*)&v)[i]` put the register arrays in
  private memory: 0.95 ms per GEMV and 298 ms per 0.6B step. A select chain (`TANG_EL4`) folds
  once the loops unroll.
- **Subgroup shuffle.** `cl_qcom_subgroup_shuffle` compiles only under `-cl-std=CL3.0`. The
  `cl_khr_subgroup_shuffle` pragma asserts in Qualcomm's compiler. The local-memory shuffle is
  wrong there, because its barrier sits in a per-warp grid-stride loop, so it is host-only.
- **Memory.** `CL_DEVICE_MAX_MEM_ALLOC_SIZE` (256 MiB) is enforced per buffer, but the 1 GiB global
  size is not a total limit: 4.7 GB allocated for 8B.
- **Prefill compute.** Tiled prefill matmuls ran at about 54 GFLOP/s, against the probe's
  register-blocked sgemm at 510. `opencl_mma_kernel` (register block, `vload4` along k, no local
  stage) is the replacement: on the Mac 0.6B goes 38.6 → 29.2 ms per 49 tokens. Its K1 number is
  pending, as is the per-device choice by `qwen_decode tune`.

**Prefill over packed weights, fp16, tail chunks** (branch `mind/prefill-kmajor`; K1 numbers
pending)
- All five projections per layer already lower to `opencl_mma_kernel` (activations `[token][k]`,
  weights `[row][k]`; 140/140 on 0.6B). The LM head stays the last token's GEMV.
- `opencl_mma_kernel_q4` reads the 4-bit words and dequantizes them in registers, so the per-pass
  f32 weight maps are gone. For 1.7B those maps were ~5.6 GB of traffic per prefill. This is the
  default on OpenCL; `TANG_CL_PREFILL_Q4=0` brings the maps back. No weight copy is cached, and a
  49-token step's own buffers drop from 111 to 27 MB (1.7B).
- `TANG_CL_PREFILL_F16=1` uses half operands with 8-term half partials summed in f32
  (`cl_khr_fp16`; the Mac emulates the roundings).
- On OpenCL the Session chunk ladder is `64,32,16,8,4,2`, so a 20-token turn is 16 + 4 rather than
  8 + 8 plus 4 decode steps.
- Mac (M4 Max OpenCL), 1.7B, 49 tokens: 81 → 61–75 ms. A 20-token turn after 49 cached:
  138 → 59 ms.
- Accuracy against the f32 maps, last-token logits: q4 4–11e-3, fp16 1.6–3.3e-2 (|logit| ≤ 32),
  top-1 agrees at 20/49/512.
- Robot bench, run after `qwen_decode tune`: `scripts/k1-prefill-bench.sh
  ~/models/qwen3-1.7b-4bit`. It covers maps/q4/fp16 × prefill 20/49/512, a 20-token turn,
  decode 128, and the check.
- Expected on the K1 (1.7B, estimates): 49 tokens 3451 ms → ~500–700 ms (maps, register block),
  ~250–400 ms (q4), ~150–250 ms (fp16). A 20-token turn ~100–250 ms. 512 tokens ~2–5 s. Decode is
  unchanged at ~55 ms/token.

## Against Flashlight / EqiForge / FlexAttention (RTX 3090, attention variants)

The six presets from the post's lab: causal, causal sliding window 128, ALiBi
(slope 1/16, causal), soft cap 30·tanh(s/30) (causal), prefix LM 64 and
bidirectional. tang builds each one the way the lab does
(`tang_derive_wasm::naive_graph` + `derive_graph`: the naive `softmax(score)·v`,
and for the backward `TensorGraph::backward` of `Σ O·dO`). It lowers it with
`Program::tuned` on CUDA, which picks per kernel between TF32 `mma` tiles and
transpiled WGSL. Single head, `[n, d]`, B = H = 1, because that is the graph
tang builds and every system then runs exactly the same problem. RTX 3090
(sm_86) on `mew`, PyTorch 2.10 + cu128, Triton 3.6.

- **Harness:** [`crates/tang-bench/examples/attn_variants.rs`](crates/tang-bench/examples/attn_variants.rs)
  times tang and writes its inputs and outputs.
  [`scripts/attn_variants_bench.py`](scripts/attn_variants_bench.py) checks
  them and runs the baselines on the same inputs.
  [`scripts/attn_variants_table.py`](scripts/attn_variants_table.py) makes the
  tables. Raw CSV: [`scripts/results/attn_variants_3090.csv`](scripts/results/attn_variants_3090.csv).
- **Timing:** CUDA events, the minimum over 5 batches of 30 runs (10 at n ≥ 4096)
  for every system, after warm-up and compilation. The GPU is shared: about
  16 GB is held by resident `tang-llm` processes. The runs used
  `flock ~/tang-gpu.lock`, but `nvidia-smi` read 100 % utilization at the
  start of the baseline run, so small rows (under 0.1 ms) carry ±2× noise.
  The large rows are stable between the two runs.
- **TFLOPS:** the same FLOP count for every system, so it is only a rescaling
  of ms. The forward is 4·n²·d × the unmasked fraction; forward + backward is
  3.5× the forward (FlashAttention's convention). Masked work a system does
  anyway is not credited.
- **Correctness:** checked against a dense float64 PyTorch reference, as the
  maximum absolute error over the maximum |reference| for O, or for dq ‖ dk ‖ dv.
  Every row passes. tang is 1.1e-6 to 1.1e-3: pure fp32 where no tensor-core
  tile is kept, TF32 where one is. FlexAttention fp32 is 7.5e-4 to 3.5e-3.
  The bf16 systems are 3.3e-3 to 8.1e-3.
- **Systems:**
  - **FlexAttention** is `torch.compile(flex_attention)` with the variant as a
    `score_mod` plus a `block_mask`. It runs in fp32 (TF32 matmuls allowed,
    like tang) and in bf16. The fp32 build fails at d = 128 on the 3090
    (`No valid triton configs … out of resource`: shared memory).
  - **FA2** is FlashAttention-2 in bf16. The `flash_attn` package can't be
    built on `mew` (no `nvcc`; no official wheel for torch 2.10), and I didn't
    install third-party wheels. So this is PyTorch's bundled FA2 kernels
    through SDPA's `FLASH_ATTENTION` backend, which supports causal and
    bidirectional only. Sliding window, ALiBi and soft cap need the
    `flash_attn` package. Prefix LM is supported by no FA2 build.
  - **Flashlight** (arXiv 2511.02043) and **EqiForge** (arXiv 2609.12330) have
    **no public code**: neither paper links a repository and no package exists.
    They can't be run here; their published numbers are summarized below.

### Results

**d = 64, forward** — ms (TFLOPS); best per row in bold

| variant | n | tang (fp32, TF32 mma) | Flex fp32/TF32 | Flex bf16 | FA2 bf16 |
|---|---:|---:|---:|---:|---:|
| causal | 1024 | 0.0315 (4.3) | 0.0835 (1.6) | 0.0442 (3.0) | **0.0131 (10.2)** |
| causal | 2048 | 0.0602 (8.9) | 0.171 (3.1) | 0.0896 (6.0) | **0.0233 (23.0)** |
| causal | 4096 | 0.227 (9.5) | 0.34 (6.3) | 0.177 (12.1) | **0.065 (33.0)** |
| causal | 8192 | 0.888 (9.7) | 0.635 (13.5) | 0.326 (26.3) | **0.177 (48.5)** |
| sliding128 | 1024 | 0.0322 (1.0) | 0.0245 (1.3) | **0.0145 (2.2)** | n/a |
| sliding128 | 2048 | 0.0616 (1.1) | 0.0324 (2.0) | **0.0321 (2.0)** | n/a |
| sliding128 | 4096 | 0.234 (0.6) | **0.0343 (3.9)** | 0.0347 (3.8) | n/a |
| sliding128 | 8192 | 0.911 (0.3) | 0.0365 (7.3) | **0.0343 (7.8)** | n/a |
| alibi | 1024 | **0.0315 (4.3)** | 0.4 (0.3) | 0.0464 (2.9) | n/a |
| alibi | 2048 | **0.0603 (8.9)** | 0.171 (3.1) | 0.0936 (5.7) | n/a |
| alibi | 4096 | 0.228 (9.4) | 0.34 (6.3) | **0.185 (11.6)** | n/a |
| alibi | 8192 | 0.889 (9.7) | 0.677 (12.7) | **0.389 (22.1)** | n/a |
| softcap | 1024 | **0.039 (3.4)** | 0.124 (1.1) | 0.0891 (1.5) | n/a |
| softcap | 2048 | **0.0748 (7.2)** | 0.254 (2.1) | 0.172 (3.1) | n/a |
| softcap | 4096 | **0.287 (7.5)** | 0.503 (4.3) | 0.341 (6.3) | n/a |
| softcap | 8192 | 1.12 (7.6) | 0.949 (9.1) | **0.7 (12.3)** | n/a |
| prefix64 | 1024 | **0.0329 (4.1)** | 0.0882 (1.5) | 0.0479 (2.8) | n/a |
| prefix64 | 2048 | **0.0627 (8.6)** | 0.171 (3.1) | 0.0894 (6.0) | n/a |
| prefix64 | 4096 | 0.238 (9.0) | 0.338 (6.3) | **0.178 (12.0)** | n/a |
| prefix64 | 8192 | 0.928 (9.3) | 0.657 (13.1) | **0.353 (24.4)** | n/a |
| bidirectional | 1024 | 0.0318 (8.4) | 0.0881 (3.0) | 0.0468 (5.7) | **0.0229 (11.7)** |
| bidirectional | 2048 | 0.0609 (17.6) | 0.168 (6.4) | 0.0885 (12.1) | **0.0337 (31.9)** |
| bidirectional | 4096 | 0.231 (18.6) | 0.333 (12.9) | 0.172 (24.9) | **0.0973 (44.1)** |
| bidirectional | 8192 | 0.9 (19.1) | 0.618 (27.8) | 0.314 (54.7) | **0.296 (58.0)** |

**d = 64, forward + backward** — ms (TFLOPS); best per row in bold

| variant | n | tang (fp32, TF32 mma) | Flex fp32/TF32 | Flex bf16 | FA2 bf16 |
|---|---:|---:|---:|---:|---:|
| causal | 1024 | 0.224 (2.1) | 0.668 (0.7) | 0.296 (1.6) | **0.126 (3.7)** |
| causal | 2048 | 0.554 (3.4) | 0.414 (4.5) | **0.202 (9.3)** | 0.228 (8.2) |
| causal | 4096 | 1.81 (4.2) | 0.968 (7.8) | **0.42 (17.9)** | 0.469 (16.0) |
| causal | 8192 | 6.76 (4.5) | 2.54 (11.8) | 0.965 (31.2) | **0.926 (32.5)** |
| sliding128 | 1024 | 0.234 (0.5) | 0.049 (2.2) | **0.0331 (3.3)** | n/a |
| sliding128 | 2048 | 0.58 (0.4) | **0.146 (1.6)** | 0.15 (1.5) | n/a |
| sliding128 | 4096 | 1.9 (0.2) | 0.161 (2.9) | **0.148 (3.1)** | n/a |
| sliding128 | 8192 | 7.34 (0.1) | 0.167 (5.6) | **0.148 (6.3)** | n/a |
| alibi | 1024 | 0.23 (2.0) | 0.672 (0.7) | **0.146 (3.2)** | n/a |
| alibi | 2048 | 0.55 (3.4) | 0.415 (4.5) | **0.207 (9.1)** | n/a |
| alibi | 4096 | 1.81 (4.2) | 0.965 (7.8) | **0.441 (17.1)** | n/a |
| alibi | 8192 | 6.83 (4.4) | 2.57 (11.7) | **1.11 (27.0)** | n/a |
| softcap | 1024 | 0.285 (1.6) | 0.217 (2.2) | **0.196 (2.4)** | n/a |
| softcap | 2048 | 0.802 (2.3) | 0.511 (3.7) | **0.324 (5.8)** | n/a |
| softcap | 4096 | 2.88 (2.6) | 1.17 (6.4) | **0.665 (11.3)** | n/a |
| softcap | 8192 | 11.3 (2.7) | 2.97 (10.1) | **1.56 (19.3)** | n/a |
| prefix64 | 1024 | 0.227 (2.1) | 0.162 (2.9) | **0.145 (3.2)** | n/a |
| prefix64 | 2048 | 0.556 (3.4) | 0.415 (4.5) | **0.2 (9.4)** | n/a |
| prefix64 | 4096 | 1.81 (4.2) | 0.963 (7.8) | **0.423 (17.8)** | n/a |
| prefix64 | 8192 | 7.01 (4.3) | 2.54 (11.8) | **0.98 (30.7)** | n/a |
| bidirectional | 1024 | 0.213 (4.4) | 0.18 (5.2) | 0.17 (5.5) | **0.122 (7.7)** |
| bidirectional | 2048 | 0.498 (7.5) | 0.447 (8.4) | **0.199 (18.9)** | 0.241 (15.6) |
| bidirectional | 4096 | 1.58 (9.5) | 1.24 (12.1) | **0.498 (30.2)** | 0.505 (29.7) |
| bidirectional | 8192 | 6.72 (8.9) | 3.99 (15.1) | 1.39 (43.4) | **1.07 (56.4)** |

**d = 128, forward** — ms (TFLOPS); best per row in bold

| variant | n | tang (fp32, TF32 mma) | Flex fp32/TF32 | Flex bf16 | FA2 bf16 |
|---|---:|---:|---:|---:|---:|
| causal | 1024 | 1.28 (0.2) | fails | 0.0839 (3.2) | **0.0233 (11.5)** |
| causal | 2048 | 4.46 (0.2) | fails | 0.163 (6.6) | **0.0421 (25.5)** |
| causal | 4096 | 17.1 (0.2) | fails | 0.318 (13.5) | **0.112 (38.5)** |
| causal | 8192 | 68.5 (0.2) | fails | 0.592 (29.0) | **0.328 (52.5)** |
| sliding128 | 1024 | 1.27 (0.1) | fails | **0.141 (0.5)** | n/a |
| sliding128 | 2048 | 4.52 (0.0) | fails | **0.0244 (5.3)** | n/a |
| sliding128 | 4096 | 17.3 (0.0) | fails | **0.0345 (7.7)** | n/a |
| sliding128 | 8192 | 69 (0.0) | fails | **0.0351 (15.2)** | n/a |
| alibi | 1024 | 1.27 (0.2) | fails | **0.0914 (2.9)** | n/a |
| alibi | 2048 | 4.51 (0.2) | fails | **0.513 (2.1)** | n/a |
| alibi | 4096 | 17.3 (0.2) | fails | **0.329 (13.1)** | n/a |
| alibi | 8192 | 68.9 (0.2) | fails | **0.654 (26.3)** | n/a |
| softcap | 1024 | 1.34 (0.2) | fails | **0.101 (2.7)** | n/a |
| softcap | 2048 | 4.69 (0.2) | fails | **0.206 (5.2)** | n/a |
| softcap | 4096 | 18 (0.2) | fails | **0.405 (10.6)** | n/a |
| softcap | 8192 | 72.4 (0.2) | fails | **0.819 (21.0)** | n/a |
| prefix64 | 1024 | 1.27 (0.2) | fails | **0.0848 (3.2)** | n/a |
| prefix64 | 2048 | 4.51 (0.2) | fails | **0.151 (7.1)** | n/a |
| prefix64 | 4096 | 17.3 (0.2) | fails | **0.299 (14.4)** | n/a |
| prefix64 | 8192 | 69.1 (0.2) | fails | **0.628 (27.3)** | n/a |
| bidirectional | 1024 | 1.28 (0.4) | fails | 0.0796 (6.8) | **0.025 (21.5)** |
| bidirectional | 2048 | 4.53 (0.5) | fails | 0.159 (13.5) | **0.0568 (37.8)** |
| bidirectional | 4096 | 17.3 (0.5) | fails | 0.297 (28.9) | **0.167 (51.5)** |
| bidirectional | 8192 | 69 (0.5) | fails | 0.582 (59.1) | **0.545 (63.0)** |

**d = 128, forward + backward** — ms (TFLOPS); best per row in bold

| variant | n | tang (fp32, TF32 mma) | Flex fp32/TF32 | Flex bf16 | FA2 bf16 |
|---|---:|---:|---:|---:|---:|
| causal | 1024 | 0.822 (1.1) | fails | 0.358 (2.6) | **0.177 (5.3)** |
| causal | 2048 | 1.75 (2.1) | fails | **0.355 (10.6)** | 0.489 (7.7) |
| causal | 4096 | 5.65 (2.7) | fails | 0.784 (19.2) | **0.527 (28.5)** |
| causal | 8192 | 21.8 (2.8) | fails | 2.09 (28.8) | **1.1 (54.8)** |
| sliding128 | 1024 | 0.805 (0.3) | fails | **0.743 (0.3)** | n/a |
| sliding128 | 2048 | 1.72 (0.3) | fails | **0.0578 (7.9)** | n/a |
| sliding128 | 4096 | 5.89 (0.2) | fails | **0.151 (6.1)** | n/a |
| sliding128 | 8192 | 22.4 (0.1) | fails | **0.209 (8.9)** | n/a |
| alibi | 1024 | 0.813 (1.2) | fails | **0.519 (1.8)** | n/a |
| alibi | 2048 | 1.74 (2.1) | fails | **0.717 (5.2)** | n/a |
| alibi | 4096 | 5.84 (2.6) | fails | **0.806 (18.6)** | n/a |
| alibi | 8192 | 22.4 (2.7) | fails | **2.17 (27.7)** | n/a |
| softcap | 1024 | 1.09 (0.9) | fails | **0.258 (3.6)** | n/a |
| softcap | 2048 | 2.35 (1.6) | fails | **0.484 (7.8)** | n/a |
| softcap | 4096 | 7.54 (2.0) | fails | **1.01 (14.9)** | n/a |
| softcap | 8192 | 28.9 (2.1) | fails | **2.71 (22.2)** | n/a |
| prefix64 | 1024 | 0.756 (1.2) | fails | **0.528 (1.8)** | n/a |
| prefix64 | 2048 | 1.64 (2.3) | fails | **0.374 (10.1)** | n/a |
| prefix64 | 4096 | 5.52 (2.7) | fails | **0.786 (19.1)** | n/a |
| prefix64 | 8192 | 21.2 (2.8) | fails | **2.09 (28.8)** | n/a |
| bidirectional | 1024 | 0.717 (2.6) | fails | 0.306 (6.2) | **0.14 (13.4)** |
| bidirectional | 2048 | 1.58 (4.8) | fails | 0.368 (20.4) | **0.263 (28.6)** |
| bidirectional | 4096 | 5.23 (5.8) | fails | 1 (30.0) | **0.579 (52.0)** |
| bidirectional | 8192 | 20.1 (6.0) | fails | 3.09 (38.9) | **2 (60.0)** |

Geometric-mean speedup of tang over each baseline across the variant × n rows
(> 1 means tang is faster):

| d | pass | vs Flex fp32 | vs Flex bf16 | vs FA2 bf16 (causal, bidi) |
|---|---|---:|---:|---:|
| 64 | fwd | 1.31× (wins 15/24) | 0.74× (11/24) | 0.39× (0/8) |
| 64 | fwd+bwd | 0.49× (2/24) | 0.26× (1/24) | 0.32× (0/8) |
| 128 | fwd | – (Flex fp32 fails) | 0.02× (0/24) | 0.01× (0/8) |
| 128 | fwd+bwd | – (Flex fp32 fails) | 0.16× (0/24) | 0.13× (0/8) |

### Where tang wins and loses, and why

- **d = 64 forward: competitive with FlexAttention, behind FA2.** At the same
  precision (fp32/TF32), tang's derived single kernel beats FlexAttention
  fp32 on causal, ALiBi, soft cap, prefix and bidirectional up to n = 4096,
  by 1.4–2.8×, leaving out one noisy row. At n = 8192 it falls behind by 0.69–0.84×. Against Flex bf16
  it wins only at n ≤ 2048. FA2 bf16 is 1.4–5× faster everywhere. Two reasons:
  bf16 `mma` has twice the TF32 rate on the 3090, and FA2 is a hand-tuned
  kernel. Both forward rows hold the property the post claims: one kernel,
  no n×n buffer, the same code for every variant.
- **Masks cost tang full price.** Sliding window and prefix LM take exactly
  as long as bidirectional. The derived kernel evaluates the mask as an
  additive −1e30 bias on every tile, and nothing in the rewrite skips a tile
  that is entirely masked. FlexAttention's `block_mask` does skip them, so
  sliding window 128 at n = 8192 is 25× faster in Flex (0.036 ms against
  0.91 ms forward, 0.17 ms against 7.3 ms forward + backward). Causal skipping
  is the same effect at 2×. This is the clearest missing rewrite: a
  comprehension whose mask is a known affine predicate of (i, j) could carry
  the block-sparsity forward as a loop bound.
- **d = 128 forward is a cliff.** No tensor-core version is generated for the
  derived d = 128 forward (`mma 0/0` in the CSV). The transpiled kernel spills
  (fp32, error 1e-6) and runs 15–120× slower than Flex bf16 (sliding window aside): 69 ms at
  n = 8192, against 0.59 ms for Flex bf16. The d = 128 forward + backward
  (21.8 ms) is *faster* than the forward alone (68.5 ms), because the backward
  graph recomputes O through tiled kernels with tensor cores. That points at
  the forward's schedule choice, not at the IR. FlexAttention has its own
  d = 128 limit on this chip: its fp32 build fails to compile.
- **Backward: tang derives it but loses 1.3–7× (sliding window aside).** tang's backward is the
  reverse-mode derivative of the naive graph, rewritten by the same passes.
  Nobody wrote a backward kernel for any variant. It comes out as 9 kernels
  with **2 n×n buffers** (P and dP are materialized) and no block skipping.
  Against Flex bf16 that is 0.26× at d = 64 and 0.16× at d = 128. The one
  win is the smallest row, causal n = 1024 (noise-level). At n ≥ 2048 the
  n×n traffic dominates. The nested-contraction lowering being worked on in a
  parallel branch removes those buffers on CUDA. This table is the "before"
  number.

### Who derives the backward

| system | forward kernel | backward |
|---|---|---|
| **tang** | derived from the naive graph by rewrites (monoid-keyed `stabilize_softmax` / `substitute_maps` / `schedule_auto`) | **derived**: `TensorGraph::backward` of the naive graph, then the same passes. Any variant the lab can type gets one, with no per-variant code. Today 9 kernels, 2 n×n buffers |
| FlexAttention | a fixed hand-written Triton template, with `score_mod` / `mask_mod` inlined | a **hand-written backward template**. `score_mod` is differentiated by autograd and inlined into it. Works for these variants, but only within the template's shape |
| FA2 (bundled / `flash_attn`) | hand-written CUDA | **hand-written** backward per supported feature (causal, window, ALiBi, softcap). Prefix LM and arbitrary scores have no kernel and fall back to SDPA math |
| Flashlight | Inductor graph rewrites to fused flash-style kernels | the paper describes forward fusion only. As far as the text says, the backward is not fused; it is whatever Inductor's autograd produces |
| EqiForge | equality saturation over a tiled IR, emitting Triton | not described. Its evaluation covers inference (prefill and decode) only |

### Flashlight and EqiForge: published numbers (not run here)

Neither system has public code, so these are the papers' own numbers, on
other GPUs, and not comparable row for row with the table above.

- **Flashlight** (A100 and H100 at a locked 1290 MHz; PyTorch 2.5, Triton 3.1):
  head dim 64, 16 heads, sequence 512–16k at 16k tokens per batch; sliding
  window and prefix 256. The paper reports score_mod variants up to 1.48×
  faster than FlexAttention. FlexAttention is "marginally faster" on vanilla
  attention and on ALiBi at batch 1 on H100. For block-mask variants (sliding
  window, prefix), FlexAttention's kernel is always faster and Flashlight wins
  only once block-mask creation is counted. The paper reports no comparison
  with FlashAttention and no backward numbers.
- **EqiForge** (A100 80GB PCIe, RTX 5090; Triton 3.6): causal MHA. The paper
  reports up to 1.87× faster than FlashAttention in decode and close to it in
  prefill (a 3–6 % gap, as far as the HTML text could be read). Whole layers
  against torch.compile: sliding-window GQA 1.06×, differential attention
  1.51×, attention sinks 1.48×, QK-norm MLA 3.16×. There is no backward and
  no FlexAttention comparison.

What tang can claim against them on this evidence:

- tang is the only one of the four that derives a backward from the forward
  for an arbitrary typed variant and runs it on six backends.
- On the 3090 its derived d = 64 forward matches template-level FlexAttention
  at equal precision for n ≤ 4096.
- What it can't claim is speed parity on the backward, at d = 128, or on
  block-sparse masks. All three trace to missing rewrites and schedules (block
  skipping, a d = 128 forward tile, nested contractions for the backward), not
  to the two-primitive IR.

Reproduce (on mew; takes the GPU lock):

```
cargo build --release -p tang-bench --features cuda --example attn_variants
flock ~/tang-gpu.lock ./target/release/examples/attn_variants /tmp/attnvar 1024,2048,4096,8192 64,128 > tang.csv
flock ~/tang-gpu.lock python3 scripts/attn_variants_bench.py /tmp/attnvar tang.csv > scripts/results/attn_variants_3090.csv
python3 scripts/attn_variants_table.py scripts/results/attn_variants_3090.csv
```

### Flash backward without n×n on WGSL and MSL

`to_wgsl` and `to_msl` now nest S = Q·Kᵀ and dP = dO·Vᵀ in the dQ, dK and dV tiles, as `to_cuda` already did (`schedule_nested_contractions_scalar`; see `docs/tensor-ir.md`, "Flash backward is nesting"). The derived attention forward + backward of `tang-derive-wasm` (the research post's lab) writes no n×n buffer on any backend. `cargo run -p tang-derive-wasm --example gallery` now gives 7 kernels and 0 n×n buffers in the fwd+bwd column for all six presets. Before, it gave 9 kernels and 2 n×n buffers.

Gradients match the f64 interpreter. The test is `derived_attention_backward_nested_on_gpu`, at n = 256, d = 32: causal, soft-cap + prefix-LM, and bidirectional, max error ≤ 1.7e-5 at gradient scale 15–36. It passes on the M4 (Metal through wgpu) and on the 3090 (Vulkan). At n ≤ 1024 the bench's max relative error is the same with and without nesting.

The cost is time. The scalar tiles evaluate each dS element's S and dP as dots on one thread, once per chunk in workgroup memory, which is more work than reading them back. `cargo run --release -p tang-bench [--features metal] --example attention_backward` times the whole program: d = 64, mean of 20 launches after warm-up, best of 3. "Materialized" is `to_wgsl_with(…, false)` / `to_msl_with(…, false)`, the schedule before this change. Each cell gives ms, with the number of n×n buffers in parentheses.

**Apple M4 Max**, 2026-11-06 09:00 EST. Load average 18.9, from other sessions' builds; the GPU was otherwise idle.

| preset | n | wgpu (Metal) before | after | MSL before | after |
|---|---|---|---|---|---|
| causal | 512 | 0.651 (2) | 1.848 (0) | 0.462 (2) | 0.644 (0) |
| bidirectional | 512 | 0.622 (2) | 1.840 (0) | 0.357 (2) | 0.519 (0) |
| causal | 1024 | 1.624 (2) | 3.886 (0) | 1.102 (2) | 1.420 (0) |
| bidirectional | 1024 | 1.571 (2) | 3.863 (0) | 0.923 (2) | 1.180 (0) |
| causal | 2048 | 5.430 (2) | 11.839 (0) | 3.014 (2) | 4.560 (0) |
| bidirectional | 2048 | 5.174 (2) | 11.635 (0) | 2.607 (2) | 4.099 (0) |
| causal | 4096 | 19.634 (2) | 36.831 (0) | 10.506 (2) | 14.916 (0) |
| bidirectional | 4096 | 20.112 (2) | 37.894 (0) | 9.561 (2) | 14.113 (0) |

**RTX 3090** (`mew`, Vulkan through wgpu), 2026-11-06 14:00 UTC. The machine is shared: load average 18.8, 29 users, about 16.5 GB of VRAM held by other processes. GPU utilization was 1% at the start of the run and 100% at the end, from another tenant. An earlier run on the same build gave the same ratios (0.23–0.25× at n ≤ 1024).

| preset | n | before | after |
|---|---|---|---|
| causal | 512 | 0.629 (2) | 2.837 (0) |
| bidirectional | 512 | 0.609 (2) | 2.678 (0) |
| causal | 1024 | 1.281 (2) | 5.136 (0) |
| bidirectional | 1024 | 1.326 (2) | 5.244 (0) |
| causal | 2048 | 3.360 (2) | 12.396 (0) |
| bidirectional | 2048 | 3.350 (2) | 12.621 (0) |
| causal | 4096 | 9.765 (2) | 35.957 (0) |
| bidirectional | 4096 | 9.868 (2) | 36.158 (0) |

Per kernel on the M4 (MSL, causal, n = 1024, before → after): dQ 0.13 → 0.37 ms, dK 0.13 → 0.35 ms, dV 0.22 → 0.25 ms. The forward tile goes from 0.55 to 0.93 ms because it now recomputes S, and the S and dP kernels (0.04 ms each) are gone.

Three things were tried and dropped:
- Keeping the 4-row × 64-lane tile: dQ/dK at 0.36 ms. A chunk had 128 dS elements across 256 threads.
- Staging the dots' K/V rows in workgroup memory per chunk: 1.9 ms vs 1.4 ms (MSL) and 45 vs 36 ms (3090, n = 4096). It adds a barrier, and the 16 KiB budget halves the chunk.
- Larger 4×4 and 4×2 register tiles: 2.3–2.6 ms.

Matching the materialized time needs the nested dots register-blocked (k-chunked) as a small GEMM, as `cuda_mma_kernel` does on `mma`, or on simdgroup matrices on Metal.

### Flash backward: dK and dV in one tile, S recomputed once

`merge_siblings` now also merges same-shape reductions that recompute a common read through their inlinable map operands, even when their readers differ or one is a program output. The read is a `(source, view)` larger than the reduction's points. Outputs read their slot through a copy. In the derived attention backward, dV = Σᵢ P̃ᵀ·dO and dK = Σᵢ dSᵀ·Q both evaluate S = Q·Kᵀ at (j, i). They become one tile. The tiled emitter runs the cooperative loads of its shared comps (P̃, dS) in one loop and memoizes nested producers by (node, coords), so S is a single dot per element (plus dP). This is the structure of FA2's dK/dV kernel. dQ stays its own tile.

Gallery fwd+bwd: 8 kernels, 0 n×n. Heavy (n²) kernels go from 4 to 3: fwd, dK+dV, dQ. Two kernels are 32K-element slot copies (dK·scale and dV, ~0.01 ms each), and 3 are O(n·d) preprocess. Nested dots per (i, j) go from 5 to 4. Gradients still match the f64 interpreter (`derived_attention_backward_nested_on_gpu`, 3 variants).

Whole fwd+bwd, d = 64, best of 3 (M4) or 2 (3090) interleaved A/B rounds. "#150" is that PR's nested schedule. "Materialized" is #150's `nested = false`.

**Apple M4 Max, MSL**, 2026-11-06 ~13:00 EST. Load average 30–440 from other sessions, so treat these as rough.

| preset | n | materialized | #150 nested | this | vs #150 |
|---|---|---|---|---|---|
| causal | 512 | 0.480 | 0.662 | 0.603 | 1.10× |
| bidirectional | 512 | 0.359 | 0.540 | 0.465 | 1.16× |
| causal | 1024 | 1.116 | 1.446 | 1.311 | 1.10× |
| bidirectional | 1024 | 0.926 | 1.205 | 1.045 | 1.15× |
| causal | 2048 | 3.117 | 4.668 | 4.299 | 1.09× |
| bidirectional | 2048 | 2.694 | 4.177 | 3.952 | 1.06× |
| causal | 4096 | 12.937 | 19.895 | 13.863 | 1.44× |
| bidirectional | 4096 | 10.671 | 15.932 | 12.935 | 1.23× |

wgpu (Metal) on the M4: 0.93–1.50× vs #150. It is slower at n = 512 and faster from n = 2048 up (4096: 44.9 → 29.9 ms causal).

**RTX 3090, Vulkan through wgpu** (`mew`, under `flock`). PyTorch 2.10 SDPA fwd+bwd is f32, one head, TF32 off, on the same GPU.

| preset | n | materialized | #150 nested | this | vs #150 | SDPA efficient | SDPA math |
|---|---|---|---|---|---|---|---|
| causal | 512 | 0.587 | 2.822 | 2.253 | 1.25× | 0.294 | 0.228 |
| bidirectional | 512 | 0.590 | 2.853 | 2.334 | 1.22× | 0.303 | 0.194 |
| causal | 1024 | 1.318 | 5.207 | 4.319 | 1.21× | 0.573 | 0.228 |
| bidirectional | 1024 | 1.336 | 5.232 | 4.374 | 1.20× | 0.588 | 0.197 |
| causal | 2048 | 3.332 | 12.523 | 10.265 | 1.22× | 1.138 | 0.646 |
| bidirectional | 2048 | 3.374 | 12.625 | 10.375 | 1.22× | 1.167 | 0.513 |
| causal | 4096 | 9.811 | 36.171 | 28.729 | 1.26× | 2.322 | 2.203 |
| bidirectional | 4096 | 9.927 | 36.448 | 28.801 | 1.27× | 2.462 | 1.767 |

The structure now matches FA2, but the per-element scalar dot inside the nested tiles still dominates. It is 0.25–0.34× the materialized schedule on the 3090 and about 12× behind SDPA there. Closing that needs the nested S/dP computed as a register-blocked GEMM per chunk (mma / simdgroup matrices), which this change makes a single site per tile.

## MoE through gather views (M4 Max and RTX 3090, kernel-only)

**Date:** 2026-11-06. **Branch:** `claude/focused-elgamal-3af3c7` (gather views, `docs/tensor-ir.md`
"Gather views"). **Run:** `cargo run --release -p tang-bench [--features cuda] --example moe_gather`
(`MOE_DIMS=T,D,E,K,F` for other sizes). Times are per kernel, mean of 50 dispatches
(`Program::time_kernel`); f32 storage everywhere.

- **M4 Max** (Metal via wgpu), on AC power (battery charging at 11%), desktop session otherwise idle.
  Absolute M4 times drift up to ~2× with power state; compare columns within a run.
- **RTX 3090** (`ssh mew`, CUDA sm_86 via `to_cuda`), shared host: 1% GPU utilization and 16.1 of
  24 GB in use by other processes (a resident `tang-llm`, ffmpeg) before and after the run.

**What runs.** A top-k MoE FFN layer as one IR graph: router GEMM, top-k as k rounds of argmax over
the logits with earlier picks masked, softmax over the selected logits, SwiGLU experts reading
`W1/W3[sel[t,k], f, d]` and `W2[sel[t,k], d, f]` through gather views, weighted combine. Token-major
(decode-style); the host does no routing. `substitute_maps` + `schedule_auto`: 16 comps → 11 kernels
(small config), 17 kernels at k = 10. The down projection is inlined into the combine (one kernel).

**Correctness.** Small config (T 4, D 64, E 16, K 4, F 32): interpreter vs a plain-Rust f64
reference 1.1e-13, interpreter before vs after the passes 0; GPU vs reference 4.3e-7 (M4),
1.4e-4 (3090: the router GEMM is a TF32 `mma.sync` tile). Top-k indices match the reference
exactly on both chips at both sizes.

**Timed config:** T 8, D 2048, E 128, K 10, F 512 (Qwen3-Next-80B-A3B's hidden size, expert FFN
width and top-k, with 128 of its 512 experts to fit the 3090's free memory). The expert half reads
3 matrices × 80 (token, slot) pairs = 1007 MB of weights per layer.
The baseline is the same expert math over weights the host gathered into contiguous `[T, K, …]`
buffers (affine views): same FLOPs, same bytes, no data-dependent address. It runs under its own
`schedule_auto` choice (a 16×16 tile) and again with every node forced to one thread per point
(the gathered kernels' schedule).

| expert GEMMs + combine | M4 Max | RTX 3090 |
|---|---|---|
| **gathered (`W[sel[t,k]]`)** | **2.17 ms** (464 GB/s) | **2.66 ms** (378 GB/s) |
| pre-gathered, `schedule_auto` (tile) | 2.89 ms (348 GB/s) | 3.55 ms (283 GB/s) |
| pre-gathered, one thread per point | 2.91 ms (346 GB/s) | 3.77 ms (267 GB/s) |
| whole layer (router, top-k, experts) | 2.95 ms | 2.82 ms |

Per kernel (gathered layer): gate 0.55 / 0.80 ms, up 0.62 / 0.77 ms, combine with the inlined
down projection 0.95 / 1.09 ms (M4 / 3090). On the 3090 router + top-k are 0.07 ms in all (12
kernels of 3–12 µs); on the M4 they are ~1.2 ms, ~0.08 ms per dispatch — launch overhead.

M4 at T 32 (4.0 GB of weight reads): gathered 9.53 ms (423 GB/s), pre-gathered 11.67 ms tiled /
11.55 ms per point.

**Reading.** The data-dependent address costs nothing measurable: the gathered layer is *faster*
than the affine baseline on both chips, under either baseline schedule. Not explained yet — the
inner loop and the bytes are the same; the gathered kernels index 3 matrices of 64 MB per expert
instead of 1 GB of per-(token, slot) copies, which may treat the TLB and page mapping better. As an
absolute number, 378 GB/s is 40% of the 3090's 936 GB/s: one thread per output point walks its
8 KB weight row alone, so adjacent threads' reads are 8 KB apart (uncoalesced). The gathered comp
gets no tile (tiles stage affine regions) and no split at this size (40960 points); a
warp-per-row GEMV schedule for gathered contractions is the obvious next step before comparing
against tang-llm's hand-written int8 MoE kernel.

## Coder-Next MoE layer derived from the IR vs the hand kernels (H200, kernel-only)

**Date:** 2026-11-06. **Branch:** `claude/moe-ir-derive` (on `claude/focused-elgamal-3af3c7`, gather views).
**GPU:** 1× H200 SXM, RunPod secure (pod `29rjl4y2rn3fyk`, US-NC-1), idle: 0 MiB / 0% before the runs.
**Run:** `cargo run --release -p tang-bench --features cuda --example coder_moe_ir` with
`CODER_MOE_DUMP=dir`, then `cargo run --release -p tang-llm --features cuda --example coder_moe_hand -- dir`
(the engine's own kernels from `coder_kernels.rs`, compiled and launched as `coder.rs` does, on the same bytes).

**Layer.** Qwen3-Coder-Next 80B-A3B shapes: hidden 2048, 512 routed experts + 1 shared, top-10, expert
FFN 512. Gate|up stored GGUF Q4_K, down Q5_K (random valid super-blocks; ~975 MB a layer), router f32.
One IR graph: router GEMM → top-k (10 argmax rounds) → softmax weights + sigmoid shared gate → pairs
sorted by expert (rank + inverse permutation, ordinary comps) → `gu[i] = Wgu[key[i]] · xq[tok[i]]` →
SwiGLU → `dn[i] = Wd[key[i]] · h[i]` → combine reading `dn[rank[t, j]]`. No new op: the int8 path is
schedule fields — `Format::Q4K/Q5K` (input storage), `Format::Q8x32` (int8 a 32, quantized by the
writer) on `xq` and `h`, `IntMma { stage: Fragment, ksplit: (2, 1) }` on the two expert GEMMs
(`docs/tensor-ir.md`, "Integer MMA and block formats").

**Correctness.** Interpreter (`eval_emulated`, same int8 rounding) vs plain-Rust reference (small
config): y 2.7e-7. GPU vs reference at B = 1/8/64: ≤ 2.8e-7 (gu, dn, y; top-k exact). Hand kernels vs
derived on the same bytes: gate|up ≤ 2.7e-7, down ≤ 3.0e-7, combine ≤ 2.9e-7 (max abs / max |ref|).

**Times** (ms a launch; median of 100 with the L2 flushed by a 256 MB memset before each — weights cold,
as in the engine's 48-layer cycle. Warm minima within ~10% and in the same order.)

| B | | derived (IR) | hand (engine) |
|---|---|---|---|
| 1 | gate\|up | 0.0174 (int8 MMA) | 0.0145 `cx_moe_gu_d2` (per pair, dp4a) |
| | down | 0.0129 + SwiGLU→Q8 0.0062 | 0.0189 `cx_moe_down_d2f` (SiLU fused) |
| | x→Q8 / combine | 0.0055 / 0.0063 | — (fused in norm) / 0.0113 `cx_moe_add_norm` |
| | **expert half** | **0.0484** | **0.0447** |
| 8 | gate\|up | 0.0481 | 0.0535 `cx_moe_gu_d4` |
| | down | 0.0312 + 0.0065 | 0.0607 `cx_moe_down_d4f` |
| | **expert half** | **0.0981** | **0.1256** |
| 64 | gate\|up | **0.158** | 0.180 `cx_moe_gu_q` (the §8 int8 MMA) |
| | down | **0.0885** + 0.0085 | 0.124 `cx_moe_down_q` + 0.0126 `cx_silu_q` |
| | plan / x→Q8 / combine | — (sort in routing) / 0.0060 / 0.0084 | 0.0064 / — / 0.0125 |
| | **expert half** | **0.270** | **0.336** |

Stage and split at B=64 (gate|up / down, cold): Fragment (2,1) 0.158 / 0.089; Fragment (1,1) 0.165 /
0.088; (4,2) 0.165 / 0.101; (8,2) 0.177 / 0.101; MMA k order (2,1) 0.199 / 0.097 — fragment-order
staging is worth ~20% on gate|up.

**Reading.** The derived expert GEMMs match or beat the hand kernels at B = 8 and 64 (B=64 gate|up −12%,
down −29%) and trail at B = 1 (+20% gate|up: one pair a tile, where the hand per-pair dp4a GEMV with
more warps a pair wins). Likely sources of the B=64 win: mins folded through the stored `dₓ·Σc` (no
second MMA), groups cut at 8-position tiles with no plan kernel, and ksplit 1 on down.

**What is missing (the gap that remains).**
- *Routing.* The derived router + top-k + sort is 27 small kernels (0.35 ms at B=1, 0.6 ms at B=64);
  the engine's is one router GEMV + `cx_route` (not timed here). Top-k as k argmax rounds, one kernel
  each, is the cost; a warp-level top-k schedule (or a fused reduction) is the next field.
- *Fusion.* The engine fuses x's int8 into the previous RMSnorm, SiLU into the B≤8 down kernel, and the
  combine into residual + next norm; the derived layer keeps SwiGLU→Q8 and x→Q8 as their own kernels
  (~0.012 ms a layer).
- *B=1.* A narrow-window schedule (one pair over more warps, dp4a instead of MMA) is not expressible yet.
- Synthetic weights (random valid k-quant blocks, gate/up Q4_K, down Q5_K); the real UD-Q4_K_XL mixes
  types per layer. Kernel-only times; no CUDA graph, no end-to-end step.

## Persistent megakernel: Qwen3-8B decode with no kernel boundaries (RTX 3090)

`tang_compile::tensor::cuda_mega` lowers any CUDA program from the decode lowering (the
510 kernels of a Qwen3-8B MLX-4-bit step, `to_cuda_decode`) to persistent kernels: each kernel
becomes a stage over its own grid as virtual blocks, stages are levelled over buffer hazards into
phases, and a grid barrier separates phases. `Program::megakernel` fuses the whole step (1 launch,
437 phases) or only the runs of small kernels between the big GEMVs (`max_blocks`: the boundary is
a per-edge choice, launch or grid barrier). Nothing in it is Qwen-specific.
`qwen_decode model ... TANG_MEGA=1 [TANG_MEGA_MAX_BLOCKS=64 TANG_MEGA_PER_SM=1]`.

Correctness, 31 teacher-forced positions vs the CPU f32 reference (`qwen_decode reference`):
all three variants give **max |err| 3.18e-2, mean 1.50e-3, argmax 31/31**, the same as the
510-kernel graph. `cuda_megakernel_matches_launches` checks bit equality over repeated runs.

Device time per decode step (min of 3 × 20, shared 3090 with other tenants, so the baseline is
~4% slower than the 9.6 ms quoted above; the rows in one block below ran back to back):

| schedule | launches | phases | len 64 | len 1024 | len 4096 | % of 936 GB/s at 4k (4.86 GB/token) |
|---|---|---|---|---|---|---|
| 510-kernel CUDA graph (main) | 510 | — | 10.05 ms (99.5 tok/s) | 10.45 ms | 11.38 ms (87.9 tok/s) | 46% |
| one megakernel, `__launch_bounds__(256,2)` | 1 | 437 | 12.00 ms (83.3 tok/s) | 12.42 ms | 13.69 ms (73.1 tok/s) | 38% |
| segments of kernels ≤ 64 blocks, 1 block/SM | 364 | 146 | **10.02 ms (99.8 tok/s)** | 10.39 ms | **11.32 ms (88.3 tok/s)** | 46% |
| segments of kernels ≤ 300 blocks, 1 block/SM | 328 | 182 | 10.14 ms | 10.65 ms | 12.13 ms | 43% |

So: the persistent form is correct and generic, but on this graph it is **at parity at best**,
not a win. What the per-phase trace (`TANG_MEGA_TRACE=1`, `%globaltimer` per phase) showed:

- **A grid barrier costs what a launch costs.** 436 barriers over 164 blocks: 0.81 µs each
  (0.67 at 82 blocks, 1.51 at 328); 436 empty kernels in a CUDA graph: 0.77 µs each. Inside the
  megakernel the small stages do run in 1–3 µs instead of ~4 µs standalone, worth ~0.5 ms a step.
- **One register budget for every stage loses more than that.** The standalone kernels use 19–128
  registers; the megakernel uses the max (103–185), so it runs 2 blocks × 8 warps per SM.
  Capping lower spills the 4-bit gate/up GEMV (3/SM: 390 µs vs 98; 4/SM: 782 µs). At 2/SM the qkv
  GEMV matches standalone (51 vs 50 µs) but gate/up (116 vs 98), down (66 vs 53) and o_proj (24 vs
  20) do not: down's 512 blocks fit one wave standalone at 52 registers (9 blocks/SM) and need two
  rounds over the megakernel's 328 slots. Larger GEMV row tiles / unroll / 8 warps make both
  paths slower (rows 1: 17–18 ms).
- **Prefetching the next phase's weights into L2 during the barrier** (`TANG_MEGA_PREFETCH`, 1–4
  MB) changes nothing: DRAM is not idle at the boundaries, the GEMVs themselves are at ~58% of
  bandwidth.
- **Replicating tiny stages in every block** instead of a barrier before their readers
  (`TANG_MEGA_DUP=1`: 437 → 363 phases) is slower (12.99 ms): every block redoing a 4096-wide
  norm costs more than the barrier it saves.

Two correctness traps worth keeping: `__ldg`/`__restrict__` reads of a buffer another block wrote
earlier in the launch are not coherent (weights keep `__ldg`, everything else is a plain load); and
a named barrier with a register id makes ptxas reserve all 16 hardware barriers per block, which
caps residency below what the occupancy API reports, so a grid barrier over "fitting" blocks
deadlocks (seen at 3 blocks/SM; barrier ids are now immediates, 3 barriers used).

Where a win would have to come from: work units sized for one register budget (split-K or row
groups so every GEMV fills the persistent grid in whole rounds) and the GEMVs' own bandwidth, not
the boundaries. llama.cpp and vLLM are not installed on mew (no GGUF either) and no Hopper host
was available, so there are no H200 rows.

## WGSL/MSL lowering caps: subgroups, native f16, simdgroup fragments under wgpu

`TensorGraph::to_wgsl_caps(outputs, WgslCaps { subgroups, f16 })` lets the
WGSL lowering use what the device has (`GpuDevice::wgsl_caps()`; wgpu
`SUBGROUP`, `SHADER_F16`; `TANG_NO_SUBGROUPS` / `TANG_NO_F16` turn them off).
Plain `to_wgsl` is unchanged, portable WGSL.

- **Subgroup split combine** (`subgroup` schedule field, set by
  `schedule_auto` on its splits; `set_subgroup`): a split reduction folds
  its per-thread partials with `subgroupAdd` / `subgroupMax` (sum, max) or a
  `subgroupShuffleXor` butterfly through the monoid's combine (any monoid:
  argmax, online softmax), then one barrier and a fold of the per-subgroup
  partials, instead of a log₂(split) workgroup-memory tree. Splits that are
  a power of two of at least 128 only. MSL always has it (`simd_sum`,
  `simd_max`, `simd_shuffle_xor`), so the native backend uses it too.
- **Native f16** (`enable f16;`): f16 buffers become `array<f16>` (same bytes
  as the packed-u32 fallback), stores are plain instead of two atomics, and
  f16 accumulator rounding is a cast. Works on Metal with wgpu 25. **Not on
  the 3090:** wgpu 25's Vulkan adapter does not expose `SHADER_F16` there
  (NVIDIA lacks `storageInputOutput16`, which, as far as I can tell, wgpu
  requires for that feature), so the 3090 keeps the packed path. The
  numbers are the same either way.
- **Fragments under wgpu** (`to_msl_mma[_caps]`, Metal MSL passthrough): a
  node scheduled `fragment` that has a simdgroup-matrix plan (f16
  contraction, fused f16 attention) now runs the native backend's
  `simdgroup_matrix` 8×8 kernel inside the wgpu program. Same buffers in the
  same order, static threadgroup memory, same grid. Before this they only
  ran on the separate `metal`-feature backend. WGSL has no matrix path:
  wgpu 25 exposes no cooperative/subgroup-matrix feature.

`cargo run --release -p tang-bench --example lowering_caps` (A/B interleaved,
best of 5×30 launches, kernel-only, ms) and `scripts/torch_lowering_caps.py`
(the same shapes; f32 matmul without TF32). The M4 was shared with other
sessions during these runs, and its absolute times moved up to 2× between
runs. Compare columns within one run.

**Caps A/B (portable → caps).** M4 Max: within ±10% for split reductions
(one 1.74× outlier on `sum [512,8192]` that a rerun did not reproduce),
f16-input matmul and attention fwd and fwd+bwd. 3090 (subgroups only):
0.97–1.04× everywhere. These kernels are not limited by the combine tree
or by f16 unpacking. Both features are correct and validated, but they
are not where the gap to PyTorch comes from.

**Fragments under wgpu (M4, f16 q/k/v or a/b, f32 accumulate) vs the f32
WGSL schedule, and vs PyTorch 2.15 MPS (separate run, same afternoon):**

| workload | WGSL f32 auto | wgpu fragment | speedup | TFLOP/s | MPS f32 | MPS f16 |
|---|---|---|---|---|---|---|
| attn h1 n1024 | 0.943 | 0.122 | 7.7× | 2.2 | 0.096 | 0.117 |
| attn h8 n1024 | 12.68 | 0.874 | 14.5× | 2.5 | 0.311 | 0.288 |
| attn h8 n2048 | 34.86 | 1.648 | 21× | 5.2 | 1.062 | 0.946 |
| attn h8 n2048 causal | 35.85 | 1.332 | 27× | 3.2 | 0.654 | 0.568 |
| attn h8 n4096 | 105.6 | 3.768 | 28× | 9.1 | 4.092 | 3.783 |
| matmul 1024³ | 0.750 | 0.291 | 2.6× | 7.4 | 0.245 | 0.230 |
| matmul 2048³ | 5.237 | 2.066 | 2.5× | 8.3 | 1.564 | 1.409 |
| matmul 512×576×1536 | 0.372 | 0.125 | 3.0× | 7.2 | 0.133 | 0.116 |

(The WGSL f32 column was unusually slow in this run: the same schedule
took 5.6–11 ms at h8 n1024 in other runs. The fragment column is the
number that matters.) Through wgpu, Metal attention now ties MPS f16 at
h8 × 4096 and trails it by 1.7–2.3× at n ≤ 2048. Matmul is 1.1–1.5× behind
MPS f16. Max |fragment − f32| is 0.7–2.2e-3 for attention; for matmul it is
0.09–0.16 on outputs of magnitude ~30–45, which is what rounding the
inputs to f16 costs.

**3090 vs PyTorch 2.10 cu128 (WGSL via Vulkan, caps on):** matmul 1024³
0.350 vs 0.108 f32 / 0.041 f16; attention h8 n1024 4.31 vs 0.280 / 0.044;
fwd+bwd h8 n1024 4.81 vs 1.19 / 0.164. The 3090's gap is tensor cores,
which WGSL cannot reach in wgpu 25. That is the CUDA backend's job.

## Split-K for monoid reductions (RTX 3090 and M4 Max, kernel-only)

Batch-1 decode attention has one query row per head, so the derived kernel launched a handful of workgroups (one per head pair × value-column tile) and left most SMs idle. `TensorGraph::split_reduction(outputs, t, P)` is split-K for **any** monoid reduction, in one launch:

- the partial is the original comp over `K / P` keys, with the chunk index as a new leading point axis, so the grid is `P`× larger;
- the combine is a reduction over the chunk axis. Its body reads one partial state, and its monoid is the original's. That is legal for every monoid because partial states and elements have the same width and the combine is associative. For online softmax it is the rescale-and-add of `(m, l, acc)`, for a sum it is `+`, for argmax it keeps the first maximum. Nothing in it mentions attention: the interpreter test splits online softmax, a matmul and an argmax.

How `P` is chosen: `split_k_candidates(t, min_chunk, max_points)` lists the powers of two the autotuner times per sequence length (here crossed with the partial's tile shapes). `schedule_split_k(outputs, target_points)` is the untuned rule: the smallest `P` that brings the point count to the target. Two changes elsewhere were needed:

- `schedule_inline` no longer inlines a reduction into a consumer with the same monoid, because that undoes the split.
- The tile emitter now loads a staged producer that is itself a reduction (attention's `q·k`) cooperatively. Each staged value gets 8 lanes over its reduce axis, and their partials are folded with the producer's monoid. Before, 64 of 256 threads each ran a serial, uncoalesced 128-long dot. `TANG_LOAD_LANES=1` restores the old load.

Harness: `crates/tang-bench/examples/split_k.rs` (`attn`, `matmul`, `prefill`, `show`), `bench/split_k_sdpa.py`. Shapes: Llama-3-8B decode, 8 kv heads × 4 query heads, head dim 128, f32, one query row. Errors are max abs error relative to the largest output, against an f64 host reference: every variant is ≤ 1.1e-5 (attention) and ≤ 3.3e-4 (TF32 matmul). GB/s counts K and V bytes once.

**RTX 3090 (CUDA, `ssh mew`), µs per call:**

| KV | unsplit, old load | unsplit | rule (P=16) | autotuned | autotuned GB/s | hand `cx_attn` (f32 port, best chunk) | SDPA f32 | SDPA bf16 |
|---|---|---|---|---|---|---|---|---|
| 1k | 361 | 160 | 36.5 | **28.6** (P=8) | 293 | 30.4 | 159 | 14.3 |
| 4k | 1410 | 641 | 83.0 | **83.0** (P=16) | 404 | 50.7 | 584 | 37.7 |
| 16k | 5601 | 2581 | 273 | **273** (P=16) | 491 | 168 | 2644 | 97.1 |
| 32k | 11253 | 5160 | 523 | **523** (P=16) | 513 | 325 | 5270 | 181 |

- Split-K is 5.6–9.9x over the unsplit kernel. With the cooperative load it is 12.6–21.5x over where decode stood before this change.
- It beats PyTorch SDPA in f32 by 5.6–10x: f32 decode has no flash path and runs the math fallback.
- It matches tang-llm's hand split-K decode kernel at 1k and trails it 1.6x at 4k–32k. The hand kernel is `cx_attn_part` + `cx_attn_merge` from `flash/coder_kernels.rs`, ported to f32 head-major caches with no gate or causal offsets.
- SDPA bf16 moves half the bytes and is not a like-for-like comparison. It is listed as the bar for a bf16 storage schedule.

**What the remaining 1.6x is:** GQA reuse. The hand kernel's block runs all 4 query heads of a kv group over one read of K/V. The derived tile's row axis is chosen as the largest other point dim, which is the chunk axis or the kv heads, never the 4 query heads that share K. So K/V are read once per query-head pair. A reuse-aware row-axis choice in `tile_axes` is the follow-up.

**Causal prefill (3090, the cooperative load alone, `split_k prefill`):** n = 1024 / 2048 / 4096 takes 33.3 / 134 / 538 ms with `TANG_LOAD_LANES=1` and 19.4 / 77.8 / 311 ms with the default, 1.7x. Absolute prefill numbers are the portable f32 tile, not the tensor-core path.

**Long-K matmul `[16, K] · [K, 256]` (3090):** split-K gives nothing on CUDA: 1.06 / 1.01 / 1.03x at K = 4k / 32k / 128k, 16 / 55 / 180 µs. The tensor-core lowering already splits K itself (`tensor_cuda::split_k`, 770 GB/s at 128k). P ≥ 32 drops off the MMA path, to 0.2x. The autotuner picks P ≤ 16, but the untuned rule picks P = 32 there, so `schedule_split_k` should not be applied to CUDA matmuls. PyTorch takes 11.3 / 52.9 / 175 µs.

**M4 Max (wgpu → Metal), µs per call.** The machine was shared with other sessions' GPU jobs during the run, so single numbers move ±2x. The P=16 column and the rule (also P=16) disagree by up to 2x at 16k.

| KV | unsplit | P=16 | autotuned | speedup |
|---|---|---|---|---|
| 1k | 470 | 141 | **108** (P=8) | 4.4x |
| 4k | 1867 | 308 | **257** (P=128) | 7.3x |
| 16k | 8855 | 1230 | **1059** (P=256) | 8.4x |
| 32k | 20358 | 2960 (rule) | **2439** (P=128) | 8.3x |

Long-K matmul `[16, K] · [K, 256]` on the M4 takes 812 / 5426 / 22453 µs unsplit and 128 / 526 / 3077 µs autotuned (P = 64 / 64 / 16, 16×16 tile with a 2×2 or 4×4 register tile), **6.4 / 10.3 / 7.3x**. There is no native split in the Metal path, so here it pays. Causal prefill on the M4 shows no change from the cooperative load (n = 2048: 666 ms with `TANG_LOAD_LANES=1`, 622 ms with the default, within noise). The hand `cx_attn` port is CUDA-only and SDPA was not run on MPS.

**Reproduce:**

```
cargo run --release -p tang-bench --example split_k -- attn            # M4 (wgpu)
cargo build --release -p tang-bench --features cuda --example split_k  # mew
flock ~/tang-gpu.lock ./target/release/examples/split_k attn
flock ~/tang-gpu.lock ./target/release/examples/split_k matmul 4096 32768 131072
TANG_LOAD_LANES=1 flock ~/tang-gpu.lock ./target/release/examples/split_k prefill 1024 2048 4096
flock ~/tang-gpu.lock python3 bench/split_k_sdpa.py
```

## Flash attention and matmul on Hopper (H200 SXM, bf16, kernel-only)

GPU: one H200 SXM (141 GB HBM3e, same GH100 die and SM count as the H100 SXM, so
FA3's published H100 numbers are comparable — the H200 adds bandwidth, not
tensor throughput). RunPod community pod, idle except for the benchmark, one
process at a time. CUDA 12.x, PyTorch SDPA (cuDNN/flash backend), FlashAttention-3
built from `flash-attention/hopper` (`flash_attn_interface`).

Method: 16k tokens per config (batch = 16384/N), 2048 hidden (heads = 2048/d),
q/k/v/dO ~ N(0,1) in bf16. Each library: best of 5 samples of 20 launches (CUDA
events). Every output is checked against an f64 forward/backward of the same bf16
inputs on two heads; all three libraries land at rel_err 1.6–5e-3. TFLOP/s:
forward 4·N²·d per head (halved when causal), backward 2.5× that. tang's backward
is the whole derived fwd+bwd program (9 kernels, includes the forward recompute
of L) timed end to end, reported in the same backward-equivalent units, so it
slightly flatters tang. Scripts: `examples/hopper_attention.rs`,
`examples/hopper_matmul.rs`, `scripts/hopper_attention.py`. Raw logs:
`docs/bench/hopper-h200-*.log`.

### Forward (TFLOP/s)

| d | causal | N | tang | SDPA | FA3 | tang / FA3 |
|---|---|---|---|---|---|---|
| 64 | false | 1024 | 231 | 292 | 384 | 0.60 |
| 64 | false | 2048 | 261 | 302 | 500 | 0.52 |
| 64 | false | 4096 | 279 | 310 | 528 | 0.53 |
| 64 | false | 8192 | 289 | 313 | 574 | 0.50 |
| 64 | false | 16384 | 294 | 315 | 567 | 0.52 |
| 64 | true | 1024 | 154 | 222 | 300 | 0.51 |
| 64 | true | 2048 | 191 | 263 | 427 | 0.45 |
| 64 | true | 4096 | 216 | 283 | 488 | 0.44 |
| 64 | true | 8192 | 231 | 297 | 550 | 0.42 |
| 64 | true | 16384 | 246 | 303 | 574 | 0.43 |
| 128 | false | 1024 | 308 | 334 | 636 | 0.48 |
| 128 | false | 2048 | 361 | 347 | 692 | 0.52 |
| 128 | false | 4096 | 392 | 355 | 718 | 0.55 |
| 128 | false | 8192 | 408 | 358 | 737 | 0.55 |
| 128 | false | 16384 | 416 | 359 | 729 | 0.57 |
| 128 | true | 1024 | 212 | 251 | 489 | 0.43 |
| 128 | true | 2048 | 272 | 284 | 612 | 0.45 |
| 128 | true | 4096 | 315 | 306 | 692 | 0.46 |
| 128 | true | 8192 | 346 | 321 | 735 | 0.47 |
| 128 | true | 16384 | 378 | 327 | 750 | 0.50 |

### Backward (TFLOP/s)

| d | causal | N | tang | SDPA | FA3 | tang / FA3 |
|---|---|---|---|---|---|---|
| 64 | false | 1024 | 22 | 215 | 426 | 0.05 |
| 64 | false | 2048 | 22 | 247 | 488 | 0.05 |
| 64 | false | 4096 | 25 | 269 | 527 | 0.05 |
| 64 | false | 8192 | 24 | 280 | 538 | 0.05 |
| 64 | false | 16384 | – | 286 | 541 | – |
| 64 | true | 1024 | 17 | 154 | 299 | 0.06 |
| 64 | true | 2048 | 20 | 199 | 410 | 0.05 |
| 64 | true | 4096 | 22 | 233 | 502 | 0.04 |
| 64 | true | 8192 | 23 | 256 | 535 | 0.04 |
| 64 | true | 16384 | – | 274 | 556 | – |
| 128 | false | 1024 | 16 | 227 | 491 | 0.03 |
| 128 | false | 2048 | 17 | 264 | 574 | 0.03 |
| 128 | false | 4096 | 18 | 286 | 597 | 0.03 |
| 128 | false | 8192 | 18 | 297 | 611 | 0.03 |
| 128 | false | 16384 | – | 303 | 615 | – |
| 128 | true | 1024 | 13 | 168 | 356 | 0.04 |
| 128 | true | 2048 | 16 | 216 | 483 | 0.03 |
| 128 | true | 4096 | 19 | 253 | 548 | 0.03 |
| 128 | true | 8192 | 20 | 279 | 596 | 0.03 |
| 128 | true | 16384 | – | 307 | 607 | – |

16k backward was not run for tang (the 9-kernel program at 8k already takes 60–150 ms).
FA3's FP8 forward (in the logs) reaches 300–930 TFLOP/s at rel_err 3–11e-2.

### bf16 matmul vs cuBLAS (TFLOP/s, best variant per family, rel_err 3–4e-3)

| M×K×N | B layout | tang mma.sync | tang wgmma | cuBLAS | wgmma / cuBLAS |
|---|---|---|---|---|---|
| 1k³ | [k,n] | 112 | 148 | 223 | 0.66 |
| 2k³ | [k,n] | 212 | 332 | 696 | 0.48 |
| 4k³ | [k,n] | 230 | 401 | 803 | 0.50 |
| 8k³ | [k,n] | 240 | 434 | 760 | 0.57 |
| 16k×2k×2k | [n,k] | 234 | 416 | 675 | 0.62 |
| 16k×2k×8k | [n,k] | 237 | 403 | 686 | 0.59 |
| 16k×8k×2k | [n,k] | 247 | 500 | 723 | 0.69 |

### Where the gap is

- **Forward**: the derived flash kernel (wgmma, warp-specialized producer) is at
  0.42–0.60× FA3; it beats SDPA at d=128 from 2k up (416 vs 359 at 16k). Missing vs FA3:
  intra-warpgroup softmax/GEMM ping-pong and TMA loads.
- **Backward**: 13–25 TFLOP/s, 20–30× behind FA3. The derived backward is 9
  kernels (two flash-style tiles, two plain contraction tiles, five elementwise),
  re-materializing P/dS through global memory; per-kernel at 1k d64 causal the
  three contraction tiles are 1.7, 2.7 and 3.7 ms. `TANG_WG_SYNC` makes no
  difference (9.98 ms both). Fix: fuse dK/dV (and atomic dQ) into one kernel,
  FA3-style — a recognizer for the backward pattern, not a tile tweak.
- **Matmul**: wgmma doubled mma.sync but sits at 0.5–0.69× cuBLAS. Next: TMA
  (multicast across a cluster) instead of cp.async, two consumer warpgroups
  ping-ponging with a producer, and a persistent tile scheduler.

### Follow-up: where the 10 ms went, and llama.cpp on the same 3090

Per-kernel times showed the four big GEMVs per layer at ~222 µs (8 of the 10 ms, ~46% of 936
GB/s); launches and small kernels are ~1 ms. So the lever was GEMV bandwidth, not boundaries:

| change (CUDA graph, no megakernel) | len 64 | len 1024 | len 4096 | correctness (31 forced rows vs CPU f32) |
|---|---|---|---|---|
| main (rows 2) | 10.05 ms (99.5 tok/s) | 10.45 ms | 11.38 ms (87.9) | max err 3.18e-2, 31/31 |
| **rows 4** (now the CUDA default) | 8.02 ms (124.6) | 8.31 ms | 9.27 ms (107.9) | 3.18e-2, 31/31 |
| rows 4 + split-K the down projection ×4 (`TANG_SPLIT_GEMV=4`) | **7.80 ms (128.1)** | 8.11 ms | 9.09 ms (110.1) | 3.46e-2, 31/31 |
| rows 4 + split-K down and attention ×4 (`TANG_SPLIT_MIN_K=4352`) | 7.95 ms | 8.28 ms | **8.89 ms (112.5)** | — |
| + small-kernel segments (`TANG_MEGA_MAX_BLOCKS=64`) | 8.06 ms | 8.38 ms | 9.31 ms | 31/31 |

Rows 4 amortizes each lane's activation (and recomputed RMSNorm) loads over 4 weight rows instead
of 2: gate/up 98 → 77 µs, qkv 50 → 35 µs. Rows 8/16, 8 warps or unroll 2 are slower. `split_reduction`
now cuts the outermost of several reduce axes (the 4-bit GEMV's groups × 64), so the down
projection (K = 12288, 512 blocks) splits. Fusing the small kernels on top no longer helps.

llama.cpp (`ggml` CUDA, built on mew, `llama-bench -n 128 -fa on -ngl 99`), GGUF converted from
the same MLX checkpoint (dequantized to f16, then `llama-quantize`; no downloads):

| | tg128 | @ d1024 | @ d4096 |
|---|---|---|---|
| llama.cpp Q4_0 (4.44 GiB) | **148.9 tok/s** | 144.8 | 134.4 |
| llama.cpp Q4_K_M (4.68 GiB) | 140.5 | 136.6 | 127.4 |
| tang IR, best (device step) | 128.1 | 123.3 | 112.5 |

tang is at 86% of llama.cpp Q4_0 at short context and 84% at 4k (was 67% / 65%). The remaining
gap is the GEMV inner loop: llama.cpp's MMVQ quantizes the activation to q8_1 once and runs dp4a
int8 dot products; tang dequantizes every nibble to f32 and FMAs, and recomputes the norm per
element. That is the next schedule to derive (an int8 activation-quantization map before the
GEMV, then a dp4a body), along with per-kernel rows/split choices through the autotuner.

### Closing on llama.cpp: Qwen3-8B decode on the 3090 (CUDA defaults now 6.76 ms)

nsys (`--cuda-graph-trace=node`) per decode step showed the CUDA graph has no gaps (3.7 µs over
548 kernels); the time is the kernels. Per layer at 7.69 ms: q|k|v 33 µs (46% of 936 GB/s),
o 16.8 (60%), gate|up 73.5 (82%), down 40 (76%), ~14 tiny kernels ~22 µs, and the attention
score kernel 13.9 µs even at 50 tokens of context. Changes, each now the CUDA decode default:

| step | len 64 | len 4096 |
|---|---|---|
| #160 (rows 4, split down ×4) | 7.80 ms | 9.09 ms |
| norms materialized once instead of recomputed in every GEMV lane, rows 8, split-K every 4-bit GEMV under 16384 rows (`split_gemvs`) | 7.22 | 8.43 |
| attention score kernel stops at the runtime length (`dyn_dim` ignored extent-1 dims, so its bound `len + p0 − p3` never qualified and 2048 blocks of empty warps ran) | 6.81 | 8.36 |
| register dim chosen by a load-bytes model (P·V tiles `d` and shares the f32 probabilities instead of tiling heads and re-reading them per `d`: 30 → ~17 µs at 4k), warps 2 | **6.76** | **8.07** |

Correctness (31 forced rows vs CPU f32): max |err| 3.71e-2, mean 1.50e-3, argmax 31/31.

Back to back with llama.cpp (`llama-bench -n 128 -fa on`, Q4_0 GGUF from the same weights):

| | short | d1024 | d4096 |
|---|---|---|---|
| llama.cpp Q4_0 | 149.4 tok/s | 145.3 | 134.9 |
| tang IR, device step | 148.0 | 141.0 | 124.0 |
| tang IR, end to end (run + 8-byte readback) | 146.3–147.9 | — | — |

Tied at short context, 92% at 4k. Tried and not kept: f16 activations (no faster at rows 8;
NaN, the transpiled map path does not write f16), splitting attention (now slower), small-kernel
persistent segments (6.81 vs 6.76 ms), rows 12/16, warps 8. Left: the ~14 tiny kernels per layer
(~0.8 ms, need real fusion — a 1-block reduction recomputed in its reader), the q|k|v and o GEMVs
at ~70%, and attention at 4k (scores 17.6 µs ≈ 480 GB/s).

Update (same session, back to back): the final vocabulary argmax was one block (32.4 µs); it now splits into 128
chunks (6.3 µs; `TANG_SPLIT_WIDE=0` keeps it whole). llama.cpp Q4_0 149.4 / 145.3 / 134.9 tok/s vs tang
148.7 / 141.4 / 124.2 (device step; end to end 148.9–149.2 at short). Remaining non-GEMV time at short context:
~584 kernels under 5 µs = 1.09 ms per step (norm stats/maps, split combines, q/k-norm + rope + KV writes, softmax).
At 4k, attention is ~46 µs per layer (scores 17.9, max 3.0, sum 2.2, P·V 22.5) against ~19 µs to read K and V once:
a fused split-KV attention (one pass, online softmax) is the next step there. Splitting more warps per group
(`TANG_KS_GROUPS`) or splitting attention K is slower.

Attention experiments (all opt-in, none kept as default; 64 / 1024 / 4096, default 6.72 / 7.08 / 8.07 ms):
P·V-only split-K ×4 (`TANG_SPLIT_ATTN=4 TANG_SPLIT_ATTN_MIN_POINTS=1024`) 6.80 / 7.17 / 7.97 (P·V 22.5 → 18.4 + 1.8 µs);
16-byte f16 loads (`TANG_DECODE_VEC=8`) 6.75 / 7.10 / 8.12; max and Σexp as one online-softmax `(m, l)` reduction
(`TANG_ONLINE_ML=1`, 31/31) 6.76 / 7.07 / 7.99. The scores and P·V kernels are each near 480–500 GB/s: what is
left at long context is one pass that computes q·k once per key and shares it across the 128 output dims
(scores in shared memory, online softmax, P·V), which the warp-reduction emitter cannot express yet.

### Derived single-pass decode attention (`shared_reduction`, opt-in: `TANG_FUSED_ATTN=1 TANG_ATTN_SPLIT=P`)

The builder can write decode attention as one online-softmax reduction over the keys per output (t, kvh, r, c)
— state (m, Σp·v_c, Σp), element (s, v_c, 1), then acc / l — with the scores a sum reduction it reads. A schedule
rule inlines a sum read by an online-softmax fold, and a new decode lowering handles any reduction whose
inlined producer ignores its last point dim: per chunk of keys, the producer once per (register-dim value, key)
into shared memory (its key-invariant args — q — hoisted per block, rows as 16-byte vectors), the chunk max and
p = exp(e₀ − m) once per key, then each thread folds Σ p·g for 8 consecutive c (one 16-byte V load per key,
keys split over 8 lanes, partial sums added by shuffles) with one monoid combine per chunk. The GQA heads are the
register dim (one K/V read serves all four). Split-KV is `split_reduction` (the online-softmax combine). The V
cache is key-major under this form. Nothing in the lowering names attention.

Correct: `qwen_decode tiny` (GPU vs interpreter, prefill and decode) 4.8e-5 / 3.3e-4, caches within 1 ulp;
Qwen3-8B 31/31 argmax, max |err| 3.24e-2. Not faster yet (ms, 64 / 1024 / 4096):

| | 64 | 1024 | 4096 |
|---|---|---|---|
| default (4 attention kernels per layer) | 6.73 | 7.07 | 8.05 |
| fused, split 16 | 7.39 | 8.72 | 9.19–9.92 |
| fused, split 32 | 7.78 | 8.38–8.55 | 9.33–9.52 |
| fused, split 64 | 7.88 | 7.90 | 9.40–9.54 |

Per layer at 4k the fused kernel is 85 µs + a 7 µs combine (split 32) against ~40 µs for the four kernels; at
length 64 it is still ~50 µs with only a few live blocks: each block walks its keys in serial rounds of
dependent loads, and the split-KV combine alone (32 chunks × 4096 outputs × 3 slots) costs what the old
short-context attention did. What it needs next: chunks sized to the live length (split chosen per step, not
per capacity), more independent loads in flight per round, and the combine folded into the finalize map.

### Launch fusion as a schedule: what it buys on the 3090 (RunPod RTX 3090, Qwen3-8B decode)

Measured on a RunPod RTX 3090 (secure cloud, EU-CZ-1, driver 595) because mew's disk was full; tang main
there is 6.72 / 7.06 / 8.05 ms, the same as mew. llama.cpp (fresh `master`, `llama-bench -n 128 -fa 1 -ngl 99`,
Q4_0 requantized from Qwen's Q8_0 GGUF) is a little faster on this card than on mew.

Three new lowerings in `tensor_cuda_gemv.rs`, all generic, all derived from the graph:

- **`staged_map`** (the cooperative shared-producer lowering): a map or an in-place cache update that reads
  a small inlined Sum/Max reduction computes that producer's whole output into shared memory once per
  block, with warps per producer point and partials combined through smem. It then evaluates its points
  from there. A CUDA-decode schedule rule inlines such reductions when the recomputation is bounded:
  RMSNorm's sum of squares, and the per-head q/k-norm statistics. A map read only by cache updates (the
  roped key) is evaluated inside the update. The norm stats, the q-norm+rope map, and k-norm+rope+KV-write
  each become one kernel, taking a step from 729 to 584 kernels and from 656 to 511 dependent phases.
  `TANG_STAGED_MAP=0` turns it off.
- **Sub-warp groups** in `warp_reduction`: a reduction with few chunks (a split's 4-part combine,
  attention's 128-wide q·k) shares a warp among 32/lpg groups, with about 4 chunks per lane. GEMVs over
  4-bit weights keep a warp per group. `TANG_SUBWARP=0` turns it off.
- **A second register dim** in `warp_reduction`, picked by the load model when it cuts streamed bytes by a
  quarter. In P·V the 4 GQA heads share V and 4 output dims share the probabilities; before, either V or
  the f32 probabilities were re-streamed per tile. P·V goes from 512 groups × 8 to 256 × 16, which also
  puts it in the 8-warp block split. `TANG_REG2=0` turns it off.

Also built, but opt-in because it is slower: **`split_fused`** (`TANG_SPLIT_FUSE=1`) runs a split-K
partial and its combine as one kernel. Each warp writes its part to a module-scope scratch and bumps a
per-group arrival counter; the warp that brings in the last part sums the parts and runs the combine's
epilogue. That gives 475 kernels per step, all 109 combines gone, and the same output, but 6.86 / 7.05 /
7.70 ms against 6.71 / 6.91 / 7.55 without it. The per-warp `__threadfence` and atomic cost more than the
combine launch inside a CUDA graph.

Interleaved runs of the old and new defaults, then llama.cpp, all on this card:

| ms per step (tok/s) | 64 | 1024 | 4096 |
|---|---|---|---|
| main (`TANG_STAGED_MAP=0 TANG_SUBWARP=0 TANG_REG2=0`) | 6.77 (147.7) | 7.12 (140.4) | 8.12 (123.2) |
| this PR | 6.80 (147.0) | 7.02 (142.5) | 7.65 (130.7) |
| this PR, `TANG_REG2=0` | 6.73 (148.7) | 7.02 (142.5) | 7.89 (126.7) |
| llama.cpp Q4_0 | 6.59 (151.7) | 6.79 (147.3) | 7.37 (135.7) |

All variants: `qwen_decode tiny` 4.85e-5 (decode) / 3.31e-4 (prefill) with caches within 1 ulp; Qwen3-8B
teacher-forced on 32 positions against the CPU f32 reference, argmax 32/32, max |err| 5.9e-3.

What this says about launch fusion on sm_86: removing launches does not remove time inside a CUDA graph.
145 fewer kernels from `staged_map` is time-neutral (6.70 vs 6.70 ms). The first version, which reduced a
one-point producer on a single warp, was 60 µs slower. 109 fewer combines from `split_fused` costs 150 µs.
A dependent launch in a graph costs about what a cross-block dependency inside a kernel costs: a fence, an
atomic, a tail. The 1.09 ms "launch overhead" from the paper's count (580 kernels × ~1.9 µs) is mostly the
kernels' own ramp and tail, and fusing moves that latency without deleting it. Without programmatic
dependent launch (sm_90+) there is no overlap of one kernel's tail with the next one's head. The wins here
come from the kernels themselves: the attention re-reads (sub-warp q·k, the 2-D register tile for P·V)
are −470 µs at 4k and −100 µs at 1k.

Single-pass attention on top (`TANG_FUSED_ATTN=1 TANG_ATTN_SPLIT=4/8/16`): 7.8–7.9 / 8.7–9.7 / 9.2–10.0 ms,
still slower. On current main 36 per-layer kernels of that path fall back to WGSL (548 of 584 native, with or
without this PR's changes), so it regressed against the previous section's 7.39 / 7.90 / 9.19; that is a
follow-up.

Where the rest of the gap to llama.cpp is (profile at 4096, isolated launches): the 4-bit GEMVs run at 82%
(gate/up, 74 µs), 72% (down, 42 µs + combine), and about 60% (qkv, 25 µs + combine; o, 18 µs + combine) of
936 GB/s, which is 6.2 of the 7.6 ms. Attention is now q·k 18 µs + softmax 2 × 6 µs + P·V 19 µs per layer,
against 18 µs for the K/V bytes. The 2-D tile's block split costs about 70 µs at length 64; the right fix is
choosing the split from the live length per step. q·k could take the same 2-D tile if the key-length bound
were applied per register point rather than per group.

## Fused attention backward on Hopper (H200 SXM, bf16, kernel-only)

The derived backward as one kernel per key block (`tensor_cuda_attn_bwd.rs`).
The kernel is recognized from the graph `backward` produces, not hand-written for attention.
- **Pattern:** the tuple reduction over queries `(dV, dK)` whose operands are pointwise maps of two short contractions (S = q·kᵀ, dP = (dO/l)·vᵀ), plus the dQ reduction reading the same map.
- **Inside the kernel:** S and dP run on bf16 `mma.sync`, and the maps' own bodies run on the accumulators. dV/dK stay in registers. dQ goes into a zero-filled f32 buffer, by atomics before Hopper and by a bulk async reduce (`cp.reduce.async.bulk`) per chunk on Hopper.
- **Tuning:** the autotuner picks 64- or 128-key blocks. Query chunks are double-buffered with `cp.async`, and chunks the causal mask zeroes are skipped.

Same method, inputs and f64 check as the section above. All results are at rel_err 2–6e-3.
- **Columns:**
  - "before" is the 9-kernel derived program measured earlier.
  - "fused program" is the whole tang program. It also recomputes the forward softmax state and rowsum(dO·O), which SDPA and FA3 take from their forward pass.
  - "kernel only" is the fused kernel's own time.
- **Units:** TFLOP/s in FlashAttention's backward convention (2.5× the forward FLOPs).
- **Baselines:** SDPA and FA3 come from `docs/bench/hopper-h200-baselines.log`; SDPA was rerun on this pod type and lands within 1%.

| d | causal | N | before (9 kernels) | fused program | fused kernel only | SDPA bwd | FA3 bwd |
|---|---|---|---|---|---|---|---|
| 64 | false | 1024 | 22 | 81 | 169 | 216 | 426 |
| 64 | false | 2048 | 22 | 105 | 178 | 249 | 488 |
| 64 | false | 4096 | 25 | 123 | 182 | 269 | 527 |
| 64 | false | 8192 | 24 | 134 | 184 | 280 | 538 |
| 64 | false | 16384 | – | 141 | 184 | 287 | 541 |
| 64 | true | 1024 | 17 | 53 | 142 | 155 | 299 |
| 64 | true | 2048 | 20 | 77 | 159 | 200 | 410 |
| 64 | true | 4096 | 22 | 99 | 169 | 233 | 502 |
| 64 | true | 8192 | 23 | 118 | 180 | 256 | 535 |
| 64 | true | 16384 | – | 130 | 185 | 274 | 556 |
| 128 | false | 1024 | 16 | 84 | 174 | 227 | 491 |
| 128 | false | 2048 | 17 | 113 | 187 | 264 | 574 |
| 128 | false | 4096 | 18 | 134 | 194 | 286 | 597 |
| 128 | false | 8192 | 18 | 148 | 196 | 298 | 611 |
| 128 | false | 16384 | – | 155 | 195 | 304 | 615 |
| 128 | true | 1024 | 13 | 56 | 151 | 169 | 356 |
| 128 | true | 2048 | 16 | 85 | 172 | 217 | 483 |
| 128 | true | 4096 | 19 | 113 | 187 | 254 | 548 |
| 128 | true | 8192 | 20 | 137 | 200 | 280 | 596 |
| 128 | true | 16384 | – | 157 | 215 | 308 | 607 |

The fused program is 4–8× faster than the 9-kernel one.
- **Fused kernel vs SDPA:** 0.6–0.9× (169–215 vs 155–308 TFLOP/s). The whole program is at 0.35–0.55×.
- **Fused kernel vs FA3:** about 0.35×.
- **Why the gap:** `mma.sync` m16n8k16 tops out well below Hopper's `wgmma`. FA3's backward uses `wgmma` with warp-specialized TMA producers. The next step is moving the same recognized kernel onto `wgmma`.

Raw logs: `docs/bench/hopper-h200-attn-bwd-fused*.log`.

## d=256 attention forward on Hopper (H200 SXM, bf16, kernel-only)

At head dim 256 `schedule_auto` left the online-softmax reduction untiled: the score stayed an n×n buffer and a scalar kernel ran the softmax, at 2.8 TFLOP/s. It now tiles up to 256 lanes, so the score inlines and the Hopper flash shape with 64-key blocks takes over. That shape compiles at 168 registers with no spills.

Same method and checks as above; 16k tokens per config, 2048 hidden (8 heads); rel_err 2–3e-3 against f64. Measured on a Secure-cloud H200 SXM, idle otherwise. SDPA was run on the same pod.

| causal | N | tang (TFLOP/s) | SDPA (TFLOP/s) |
|---|---|---|---|
| false | 1024 | 318 | 306 |
| false | 4096 | 398 | 323 |
| false | 16384 | 422 | 318 |
| true | 1024 | 220 | 251 |
| true | 4096 | 310 | 285 |
| true | 16384 | 391 | 295 |

Raw log: `docs/bench/hopper-h200-d256-and-wgmma-bwd.log`. FA3 was not run at d=256.

## Attention backward on wgmma (H200 SXM, bf16, kernel-only)

This adds a `wgmma` variant of the fused backward from #170, the third kernel option the autotuner can pick on Hopper.
- **Layout:** two consumer warpgroups of 64 keys each share the staged Q and dO/l tiles. Shared tiles use the 128-byte swizzle.
- **Operands:** S, dP and dQ read both operands from shared memory. dV and dK take P and dS straight from the map's registers (wgmma's register-A form).
- **dQ:** each warpgroup adds its partial with one bulk async reduce per chunk.

The variant matches the unfused program to 4–9e-3 on every check case, and every config is within 2.4–6.1e-3 of the f64 reference.
- **Columns:** "kernel" is the variant the tuner picked. The next two are the fused kernel's own TFLOP/s before (`mma.sync`, #170) and now; "program" is the whole fwd+bwd program.
- **Units:** TFLOP/s, backward convention (2.5× the forward FLOPs).
- **Baselines:** SDPA from `docs/bench/hopper-h200-baselines.log`.

| d | causal | N | kernel | mma.sync kernel (#170) | this kernel | SDPA bwd | program |
|---|---|---|---|---|---|---|---|
| 64 | false | 1024 | mma | 169 | 172 | 216 | 82 |
| 64 | false | 4096 | wgmma | 182 | 201 | 269 | 131 |
| 64 | false | 16384 | wgmma | 184 | 205 | 287 | 152 |
| 64 | true | 1024 | mma | 142 | 144 | 155 | 54 |
| 64 | true | 4096 | wgmma | 169 | 179 | 233 | 103 |
| 64 | true | 16384 | wgmma | 185 | 197 | 274 | 136 |
| 128 | false | 1024 | wgmma | 174 | 206 | 227 | 92 |
| 128 | false | 4096 | wgmma | 194 | 239 | 286 | 154 |
| 128 | false | 16384 | wgmma | 195 | 247 | 304 | 187 |
| 128 | true | 1024 | wgmma | 151 | 163 | 169 | 58 |
| 128 | true | 4096 | wgmma | 187 | 214 | 254 | 122 |
| 128 | true | 16384 | wgmma | 215 | 258 | 308 | 180 |

The `wgmma` kernel is 1.1–1.27× the `mma.sync` one. It reaches 0.81–0.96× SDPA's backward at d=128 and 0.69–0.93× at d=64; at d=64, 1k the tuner keeps `mma.sync`. What remains vs FA3:
- a producer warpgroup with TMA (staging is still cp.async by the consumers);
- intra-warpgroup overlap of the softmax with the next chunk's GEMMs;
- 254 registers, so one block per SM.

Raw log: `docs/bench/hopper-h200-d256-and-wgmma-bwd.log`.

## Warp-specialized and d=256 attention backward (H200 SXM, bf16, kernel-only)

Same harness as above (`attn_bwd_check`, `hopper_attention`), fused kernel vs `torch.nn.functional.scaled_dot_product_attention` backward. All variants agree with the unfused program to 3e-3–1.1e-2 rel (`docs/bench/hopper-h200-attn-bwd-ws-d256.log`).

Fused kernel, ms, per variant (7 = wgmma + producer warpgroup, 8 = wgmma, 9/10 = mma.sync):

| case | ws (7) | wg (8) | mma (9) |
|---|---|---|---|
| bh=64 n=1k d=64 causal | 0.268 | 0.195 | 0.208 |
| bh=16 n=2k d=128 | 0.371 | 0.416 | 0.463 |
| bh=8 n=4k d=128 causal | 0.599 | 0.583 | 0.677 |
| bh=2 n=2k d=256 | 0.231 | 0.231 | 0.330 |

The producer warpgroup wins at d=128 non-causal (1.12×) and loses at d=64, where it spills (ptxas budgets 168 regs for 384 threads). Autotune picks per shape.

Fused d=256 backward (new; previously unfused), kernel vs SDPA:

| case | tang kernel | SDPA bwd | ratio |
|---|---|---|---|
| bh=128 n=1k | 1.97 ms | 1.73 ms | 0.88× |
| bh=32 n=4k | 7.04 ms | 5.68 ms | 0.81× |
| bh=8 n=16k | 27.4 ms | 21.6 ms | 0.79× |
| bh=128 n=1k causal | 1.11 ms | 1.14 ms | 1.03× |
| bh=32 n=4k causal | 3.59 ms | 3.16 ms | 0.88× |
| bh=8 n=16k causal | 13.4 ms | 10.8 ms | 0.80× |

d=128 n=16k: kernel 19.8 ms (non-causal), 10.8 ms (causal). Two blocks/SM is not reachable at 256 consumer threads (needs ≤128 regs; dV/dK accumulators alone are 128 at d=128). Softmax/GEMM overlap not done yet.

## Scans: chunked delta rule, SSD and linear attention (RTX 3090, H200 SXM; bf16, kernel-only)

`delta_scan` + `scan_readout` in tensor IR, lowered by `chunked_scan_plan`
(`tensor_cuda_scan.rs`): per-chunk WY/UT transform, sequential state scan,
parallel readout; backward = the derived reverse scan at chunk granularity +
one gradient kernel per chunk. `examples/scan_bench.rs` (`--bwd`) checks the
output and all gradients against the f64 interpreter (rel. err 2–5e-3) and
times back-to-back launches; references from `scripts/scan_ref_bench.py`
(CUDA events, median of 20): fla 0.3.2 `chunk_gated_delta_rule` /
`chunk_simple_gla` (g = 0), mamba_ssm 2.3.2 `mamba_chunk_scan_combined`
(chunk 64). Batch 1, H = 32, dk = 128, dv = 128 (SSD: dstate 128, headdim 64).
Times in ms.

**RTX 3090**

| layer | T | tang fwd | ref fwd | tang fwd+bwd | ref fwd+bwd |
|---|---|---|---|---|---|
| gated delta rule (fla) | 4k | **1.12** | 1.19 | 4.44 | **4.30** |
| | 16k | 4.28 | **4.21** | 17.65 | **16.68** |
| | 64k | 17.08 | **16.24** | | |
| linear attention (fla) | 4k | 0.69 | **0.63** | 3.23 | **2.81** |
| | 16k | 2.67 | **2.49** | 12.75 | **11.60** |
| | 64k | **10.55** | 12.23 | | |
| Mamba-2 SSD (mamba_ssm) | 4k | **0.47** | 0.83 | — | 4.12 |
| | 16k | **1.74** | 2.40 | — | 13.12 |
| | 64k | **6.75** | 8.72 | | |

**H200 SXM** (the same `wmma` kernels; no `wgmma` variant yet)

| layer | T | tang fwd | ref fwd | tang fwd+bwd | ref fwd+bwd |
|---|---|---|---|---|---|
| gated delta rule (fla) | 4k | 0.62 | **0.52** | 2.40 | **1.43** |
| | 16k | 2.33 | **1.52** | 9.23 | **4.64** |
| | 64k | 9.14 | **5.69** | | |
| linear attention (fla) | 4k | 0.38 | **0.28** | 1.65 | **0.92** |
| | 16k | 1.45 | **0.67** | 6.35 | **2.75** |
| | 64k | 5.71 | **2.33** | | |
| Mamba-2 SSD (mamba_ssm) | 4k | **0.30** | 0.53 | — | 2.54 |
| | 16k | 1.14 | **0.74** | — | 3.73 |
| | 64k | 4.48 | **2.33** | | |

The backward needs dk = dv = 128 (SSD at headdim 64 runs forward only).
On the 3090 (half-rate fp32-accumulate MMA on GeForce Ampere) the derived
kernels match fla within ±6% forward and 3–10% fwd+bwd, and beat mamba_ssm's
SSD forward 1.3–1.8×. On the H200 fla's Triton kernels are 1.2–2.4× ahead at
long T: the sequential state scan (`H · dv/32` = 128 blocks, ~3.8 µs a chunk)
is latency-bound there. Next: a two-level state scan (segments in parallel,
combined through the chunk maps — the affine monoid is associative at any
granularity) and `wgmma` tiles.

**vs tang-llm's hand prefill recurrence** (`fl_gdn_wide`, a warp per state
column, token by token; Qwen3-Coder-Next GDN: 32 v heads, 16 k heads, d 128;
`scripts/gdn_hand_bench.cu`), recurrence only:

| GPU | T | `fl_gdn_wide` | chunked scan (32 heads) |
|---|---|---|---|
| RTX 3090 | 4k | 2.39 | **1.12** |
| | 16k | 9.48 | **4.28** |
| | 64k | 35.38 | **17.08** |
| H200 | 4k | 2.49 | **0.62** |
| | 16k | 9.91 | **2.33** |
| | 64k | 39.69 | **9.14** |

## Coder-Next: per-op hand vs derived (RTX 3090, kernel-only)

First step toward `TANG_CODER_DERIVED=all` (plan and inventory: `crates/tang-llm/docs/coder-derived.md`).
Ops written as naive IR graphs in `crates/tang-llm/src/flash/derived_ops.rs`, lowered by tang-compile,
NVRTC-compiled and launched on raw device buffers (the engine's calling convention). Engine shapes:
hidden 2048, 512 experts, top-10. `cargo run --release -p tang-llm --features cuda --example coder_derived_ops 1 2 8`
on mew (RTX 3090, shared GPU, `flock`). Time = min µs per launch over 50 × 20 warm launches.
Error = max |Δ| / max |want| against the hand kernel (route: weights; ids compared exactly).

| op | hand kernel | T | hand µs | derived µs | derived kernels | max rel err |
|---|---|---|---|---|---|---|
| residual add + RMSNorm | `cx_norm_q8` | 1 | 5.99 | 5.89 | 3 | 0 |
| | | 8 | 6.20 | 6.50 | 3 | 1.4e-7 |
| MoE combine + residual + RMSNorm | `cx_moe_add_norm` | 1 | 5.68 | 7.88 | 4 | 1.2e-7 |
| softmax top-10 routing | `cx_route` | 1 | 10.60 | 12.29 | 2 | 1.5e-7, ids equal |
| | | 8 | 11.01 | 12.54 | 2 | 2.2e-7, ids equal |

The hand kernels also write the int8 activations, which the derived ones do not yet (that output
is in the IR's `Q8x32` layout, not the engine's), so these rows compare unequal work in the hand
kernel's favour. Derived `add_norm` at T=64 equals a CPU reference exactly. At T ≥ 8 the hand
`cx_moe_add_norm` / `cx_norm_q8` results in this harness were not reproducible (my launch of the
hand kernel, not the derived op), so those rows are left out.

Dense Q8_0 GEMV (new `Format::Q8_0` in the IR, `Stage::Gemv`, x → int8 quantized in the prologue at
T=1 and by a writer kernel past that; `IntMma::pos_tile` = T shares one weight read), against a CPU
reference on the same int8-rounded activations (err ≤ 1.3e-7 everywhere):

| rows × k | T=1 µs (GB/s) | T=2 | T=8 |
|---|---|---|---|
| 4096 × 2048 | 17.7 (503) | 20.3 (438) | 44.9 (199) |
| 2048 × 4096 | 21.0 (424) | 20.7 (430) | 47.8 (186) |
| 151936 × 2048 (LM head) | 383 (862) | 392 (844) | 1189 (278) |

T=1/2 on the LM head is 92% of the 3090's 936 GB/s. T=8 is compute/register-bound (next step in
the plan). No H200 or end-to-end numbers yet: nothing here is wired into the engine.

Update (same day): prod decodes at T≈8–45 (`serve --batch 45` + MTP), so T ≥ 2 now runs on int8
tensor cores. `Format::Q8_0` on the `IntMma` MMA stage: a block holds 16 rows × `pos_tile` positions
(all T up to 64, one weight read), each warp stages its 16 rows × 136-byte unit through shared memory
with coalesced 8-byte loads, ksplit 2. Same 3090, same reference check (err ≤ 3.8e-7):

| rows × k | T=1 (dp4a) | T=2 | T=8 | T=16 | T=48 |
|---|---|---|---|---|---|
| 4096 × 2048 | 17.7 µs | 18.2 | 18.4 (485 GB/s) | 23.0 | 45.2 |
| 2048 × 4096 | 21.0 | 25.8 | 26.2 (340) | 37.6 | 76.8 |
| 151936 × 2048 (LM head) | 383 (862) | 487 (679) | 459 (720) | 426 (775) | 834 (396) |

Before this, T=8 on the LM head took 1189 µs (278 GB/s); T=48 took 26.5 ms on the GEMV path. At T=48
the B fragments (one global load a tile a block step) are now the limit — next: stage x per unit too.

## Coder-Next: `TANG_CODER_DERIVED=moe` on the model (H200 SXM, RunPod secure, 2026-11-07)

Qwen3-Coder-Next UD-Q4_K_XL. 47 of 48 MoE layers run the derived block (`derived_ops::moe_block`):
routing, gathered Q4_K/Q5_K experts, Q8_0 shared expert, combine, residual and next norm, plus the
int8 re-layout for the hand attention/GDN kernels. The router GEMV is still hand, and so is one
layer (its down stack is Q6_K, which the IR has no format for yet; it falls back per shape).
Prompt: the first 4.2 KB of `coder_kernels.rs` with a refactor instruction, 1,380 chat tokens, cycled
to 3k/8k by wide-check (the gates' `refactor.ids` was not available on this pod; on a 50k-token
non-repeating prompt, **hand fails the wide-check bars too** (KL 3.0e-2 at 3k), so the bars assume a
cycled prompt).

Gates (all PASS):

| gate | hand | derived MoE |
|---|---|---|
| wide-check 3000, int8 KV (KL bar 2.0e-4) | 6.74e-5, greedy equal | 4.06e-5, greedy equal |
| wide-check 8000, int8 KV (bar 3.2e-5) | 9.08e-6 | 2.70e-5 |
| wide-check 3000 / 8000, bf16 KV | — | 5.59e-5 / 1.63e-5, greedy equal |
| batch-check N=8 | PASS bitwise | PASS bitwise |
| continuation (`serve --batch 8`, int8 KV) | — | warm 1,380-token prefix + 4,663-token extension: 48-token greedy reply equal to a second server's (which reused 1,377 tokens from the persisted prefix cache, not 0) |

Decode step (`flash-batch-check`, context ~1,380, 64 steps):

| streams | hand ms | derived ms (first) | derived ms (after fixes) |
|---|---|---|---|
| 1 | 4.04 | 6.35 | 5.04 |
| 2 | 4.74 | 6.79 | 5.84 |
| 4 | 6.53 | 8.76 | 7.54 |
| 8 | 9.82 | 12.71 | 11.27 |
| 16 | 15.88 | — | 16.71 |
| 32 | 23.49 | — | 27.21 |
| 48 | 29.99 | — | 37.89 |

16–48 streams are the batch module (64 rows), where the hand experts run on int8 tensor cores
(`cx_moe_*_q`) and the derived routed experts are still one dp4a GEMV per (token, expert) pair. That
is the gap at 32–48 (−16% / −21% throughput); the IntMma stage with gathered weights (sorted pairs,
as `coder_moe_ir` does for wide windows) is the fix. batch-check N=48 tolerance: derived 99.27% /
mean 0.150 (PASS); hand 99.00% / 0.142 on this prompt (FAIL by the bar's strict inequality). The batch
shapes (T=16/32/48) built lazily outside capture in 1.2 s each.

The fixes: the RMSNorm sum of squares ran as one thread per row (27 µs a layer), and every GEMV
block re-quantized x in its prologue (x is now written once). Per layer on the H200 at T=1 (512 experts,
top-10, `examples/coder_derived_moe.rs`): 90 → 60 µs. What is left at T=1: the top-k reduction is 13 µs
in one block (the hand `cx_route` is one warp), and 14 kernels against the hand path's ~4.
Startup: the derived shapes build in 6.3 s at load.
Pod time: ~1.4 h at $5.29/hr (≈ $7.50), pod terminated.

### Round 2: routed experts sorted by expert on int8 tensor cores (H200, second pod)

From 16 rows the (token, expert) pairs are sorted by expert (IR comps) and gate/up/down run on the
`IntMma` MMA stage with gathered weights; the k-quant MMA lowering stages each warp's 16-row
super-block tile through shared memory (coalesced 16-byte loads). Same prompt and command as above,
a different H200 host (hand re-measured on it):

| streams | hand ms | derived ms (round 1) | derived ms (round 2) |
|---|---|---|---|
| 1 | 4.08 | 5.04 | 5.11 |
| 8 | 9.91 | 11.27 | 11.33 |
| 16 | 15.96 | 16.71 | **15.65** |
| 32 | 23.64 | 27.21 | **23.30** |
| 48 | 30.21 | 37.89 | 31.53 |

batch-check N=48 tolerance: derived 99.24% / mean 0.153 PASS (hand 99.00% / 0.142 on this prompt).
Batch shapes build in 1.6–1.9 s each (21 + 2 kernels).

Profile (`TANG_CODER_PROF=1 --eager`, 32 steps, logs in `crates/tang-llm/docs/bench/derived-moe/`): the
MoE stages, summed over 32 steps (hand: route + moe_gu + moe_down + moe_add_norm on 48 layers;
derived: `moe_derived` on 47 layers + the hand stages on the Q6_K layer):

| streams | hand MoE ms | derived MoE ms | per step |
|---|---|---|---|
| 1 | 84.0 | 117.6 | +1.05 ms |
| 8 | 205.4 | 257.5 | +1.63 ms |

Everything outside the MoE layer matches (same kernels). So the N=1 gap is the derived layer itself:
~77 µs a layer vs ~55 hand in eager mode. The derived shapes build at load or on first use outside a capture (the log shows each build
once), so the graphed steps run the derived kernels; I did not inspect the captured graphs node by node.
No nsys on the image, so per-kernel attribution inside the derived layer comes from
`examples/coder_derived_moe.rs` (`PER_KERNEL=1`): top-k 13 µs, gate and up GEMVs, 14 kernels.
Pod time this round ≈ 45 min ($4), terminated.

### Round 3 (third H200, `crates/tang-llm/docs/bench/derived-moe/r3/`)

Changes: `y` not materialized unless kept (one kernel a layer fewer); a parallel rank-count top-k
was tried and left opt-in (`TANG_DMOE_TOPK=rank`: no faster at T=1, slower at T=48).

| gate | result |
|---|---|
| batch-check N=8 | PASS bitwise (checksum 601bcc0313fe017a, same as round 1's last) |
| wide-check 3000, int8 KV | **FAIL**: KL 2.81e-4 vs bar 2.0e-4; greedy equal (32 tokens) |
| wide-check 8000, int8 KV | PASS: KL 1.98e-5 (bar 3.2e-5), greedy equal |
| batch-check N=48 tolerance | derived PASS 99.24% / mean 0.153; hand 99.00% / 0.142 |

| streams | hand ms | derived ms |
|---|---|---|
| 1 | 4.11 | 5.17 |
| 8 | 9.92 | 11.41 |
| 16 | 15.91 | 15.71 |
| 32 | 23.60 | 23.37 |
| 48 | 30.15 | 32.18 |

The 3000 KL regression (4.06e-5 on the round-1 build) is new since the first gate run; the narrow
path changed since then in its reduction orders (the norm's sum of squares split across a block,
x quantized by a writer kernel). Not bisected yet. The 8000 KL improved. Decode is unchanged within noise.
Pod ≈ 45 min ($4), terminated.

### Round 4: wide-check regression bisected and fixed (fourth H200, `crates/tang-llm/docs/bench/r4/`)

Each narrow-path change since round 1 was undone one at a time (wide-check 3000, int8 KV). Only one mattered: the rmsnorm sum of squares split into 256-wide blocks.

| variant | wide-check 3000 KL |
|---|---|
| round-3 build | 2.81e-4 (FAIL) |
| shared expert back on MMA | 1.95e-4 |
| norm sum serial (`SS_SPLIT=0`) | 4.06e-5 |
| x quantized inline | 2.81e-4 |
| y kept | 2.81e-4 |
| all four undone | 9.62e-5 |

KL by sum split width: 0 → 4.06e-5, 64 → 1.84e-4, 128 → 5.86e-5, 256 → 2.81e-4, 512 → 4.40e-4, 1024 → 2.30e-5. KL does not fall steadily with width; it moves with summation order. The new default is 1024, which matches the hand norm's thread count.

Gates with split 1024:

| gate | result |
|---|---|
| wide-check 3000 (int8) | PASS, KL 2.30e-5 (bar 2.0e-4; round 1: 4.06e-5) |
| wide-check 8000 (int8) | PASS, KL 1.28e-5 (bar 3.2e-5) |
| batch-check N=8 | PASS, bitwise (checksum 0e4e4af3f0bb966d) |
| batch-check N=48 | 98.58% token agreement, mean \|dlogit\| 0.151: just under the 99% bar |

The N=48 gate is borderline for the hand engine too: in the same run it scored 99.00% and also printed FAIL.

Decode ms a step (context ~1380):

| N | hand | derived |
|---|---|---|
| 1 | 4.11 | 5.18 |
| 8 | 9.91 | 11.42 |
| 16 | 16.05 | 15.90 |
| 48 | 30.18 | 31.71 |

Fusing gate|up+SiLU into one weight pass was not attempted this round.

### Round 5: gate|up in one launch, fewer kernels (fifth H200, `crates/tang-llm/docs/bench/r5/`)

Changes, all on the unsorted path (windows under 16 rows):
- the top-k (id, logit) pairs are read in place, with no column kernels;
- the routing weights and the expert combine are inlined;
- gate and up rows come from one gate‖up buffer in one launch (the engine now uploads gate and up contiguously);
- the shared expert's gate|up is also one launch at T=1.

On the RTX 3090 example, kernels per layer drop from 16 to 10 at T=1 (73.7 → 63.0 µs) and from 18 to 13 at T=8 (286 → 268 µs).

| gate | result |
|---|---|
| wide-check 3000 (int8) | PASS, KL 2.30e-5 (same as round 4) |
| wide-check 8000 (int8) | PASS, KL 1.28e-5 |
| batch-check N=8 | PASS, bitwise (checksum 0e4e4af3f0bb966d, same as round 4) |
| batch-check N=48 | derived 98.58% / mean \|dlogit\| 0.151 (FAIL, checksum unchanged from round 4); hand in the same run 99.00% / 0.142 (also FAIL) |

Decode ms a step, from the N=48 runs in the same pod session (context ~1380):

| N | hand | derived r5 | derived r4 | gap r4 → r5 |
|---|---|---|---|---|
| 1 | 4.05 | 4.48 | 5.18 | 1.07 → 0.43 |
| 8 | 9.81 | 11.03 | 11.42 | 1.51 → 1.22 |
| 16 | 15.87 | 15.58 | 15.90 | derived 0.29 faster |
| 48 | 30.01 | 31.88 | 31.71 | 1.53 → 1.87 (sorted path unchanged; run noise) |

The b8 run measured derived N=8 at 10.69 ms, a gap of 0.88 ms. Windows of 16 rows and up (the sorted path) still run separate gate and up passes.

### Round 6: sorted path fused, engine int8 folded in, shared expert retiled (sixth H200, `crates/tang-llm/docs/bench/r6/`)

Changes:
- **Sorted path (T ≥ 16): gate|up in one launch.** The space is `[half, pair, row | col]`, with half outermost. The int8 MMA's same-weight runs now compare the whole weight offset rather than only the gather key, because a position dim can move the offset too.
- **The next layer's int8 input is written by the MoE op itself.** A new storage format, `Format::Q8x32F` (codes, then one f32 scale per 32, the layout the hand kernels read), takes one kernel. That replaces the two separate `engine_q8` launches per layer.
- **Shared-expert MMA tile is 8 positions** (it was T). At T=48 the old tile ran 8 blocks; the new one runs 48 (3090: 941 → 887 µs per layer).
- SiLU stays a separate kernel. Gate and up land in different MMA tiles, so a register epilogue would need a row-interleaved weight view, which affine forms can't express.

Hand engine, this branch vs main (contiguous gate‖up upload), same pod:

| | main | this branch |
|---|---|---|
| N=1 checksum | 58a49b7dcb916b00 | 58a49b7dcb916b00 |
| N=8 checksum | 24a2aee70897bb74 | 24a2aee70897bb74 |

Bitwise unchanged.

Gates:

| gate | result |
|---|---|
| wide-check 3000 (int8) | PASS, KL 3.44e-5 |
| wide-check 8000 (int8) | PASS, KL 2.03e-5 |
| batch-check N=8 | PASS, bitwise (checksum 796c8f3f0fe0a52b) |
| batch-check N=48 | derived **PASS**, 99.28%, mean \|dlogit\| 0.145; hand in the same run 99.00%, 0.142 (FAIL) |

Decode ms per step (context ~1380). The derived column is from the N=48 run; the N=1 and N=8 numbers from the b8 run are in brackets.

| N | hand | derived |
|---|---|---|
| 1 | 4.15 | 4.48 (b8 run: 4.13) |
| 8 | 9.92 | 10.98 (b8 run: 10.74) |
| 16 | 15.95 | **14.39** |
| 32 | 23.66 | **21.67** |
| 48 | 30.26 | **28.78** |

Derived beats hand from N=16 up; at N=48 it is 1.5 ms per step faster (round 5: 1.9 ms slower). The pod run was stopped before its N=48 profiles, since the target was met.

### Round 7: hybrid cutoff, `TANG_DMOE_MIN_ROWS=16` (seventh H200, `crates/tang-llm/docs/bench/r7/`)

With `TANG_CODER_DERIVED=moe`, windows of 16 rows or more take the derived MoE. Narrower windows run exactly the hand path, router included, and so do wide prefill windows. The cutoff is read once per process, so a shape takes the same path inside and outside CUDA graph capture. `TANG_DMOE_MIN_ROWS` overrides it (`1` is the round-6 behaviour).

| gate | result |
|---|---|
| wide-check 3000 (int8) | PASS, KL 6.74e-5 |
| wide-check 8000 (int8) | PASS, KL 9.08e-6 |
| batch-check N=8, derived switch on | PASS, bitwise; checksum 24a2aee70897bb74, equal to hand in this run and to main in round 6 |
| batch-check N=48 | derived 98.93%, mean \|dlogit\| 0.141 (FAIL by 0.07 points); hand in the same run 99.00%, 0.142 (FAIL) |

Decode ms per step (context ~1380):

| N | hand | hybrid |
|---|---|---|
| 1 | 4.05 | 4.05 (b8 run; 4.29 in the N=48 run) |
| 8 | 9.81 | 9.81 (b8 run; 9.99 in the N=48 run) |
| 16 | 15.87 | **14.06** |
| 32 | 23.48 | **21.40** |
| 48 | 30.01 | **28.45** |

The N=48 token-agreement figure moves with the mix of narrow and wide windows: 98.58% in rounds 4–5, 99.28% in round 6 (derived at every width) and 98.93% here. The hand engine itself scores exactly at the bar, and derived's mean \|dlogit\| is at or below hand's in every round.

## Idle-GPU measurements (2026-11-09/10)

All runs are from branch `claude/review-measurements`; the commit is recorded in each raw `machine.txt`. Every number below has its raw output under `crates/tang-llm/docs/bench/review/`:
- `3090/`: idle rented RTX 3090 (RunPod secure EU-CZ-1, driver 595.91.07, torch 2.8.0+cu128, commit 6ebfccd8, 2026-11-10 00:36 UTC). `idle.txt` holds `nvidia-smi` samples taken before each step: 1 MiB used, no other process.
- `mew-ncu/`: ncu bytes on mew. mew is a shared 3090, so it is used only for counters, never for times; runs under `flock ~/tang-gpu.lock` at 1% background load.
- `h200/`: idle rented H200 SXM (RunPod secure US-GA-2, driver 595.91.07, torch 2.8.0+cu128).

### 1. Figure 1 on the CUDA path (causal attention, n = 4096, d = 64, f32, idle 3090)

`N=4096 D=64 OPS=fwd,fwdbwd REF_DIR=… cargo run --release -p tang-bench --features cuda --example figure1_cuda`

**Method.** Each schedule is `TensorGraph::place` of one graph, lowered by the new `to_cuda_placed`. That lowering keeps the placement's `nest` decision: before this change, `to_cuda` nested every short contraction into a tile, so on CUDA "naive" was not naive. Each program is tuned per kernel (`Program::tuned_placed`). "searched" keeps the fastest correct role-level placement, then each kernel's thread mappings.

**Checking.** *Every* point, flash included, is compared at n = 4096 against the f64 interpreter (`TensorGraph::eval`, computed once per op and cached). The metric is max |error| / max |reference| per output, with one tolerance for the experiment: 2e-3. Times are the median of 7 samples of 5 runs, with the range in brackets.

| schedule | fwd ms | fwd model traffic | kernels | fwd max rel err | fwd+bwd ms | fwd+bwd err |
|---|---|---|---|---|---|---|
| naive | 4.206 [4.176–4.650] | 816 MB | 11 | 2.2e-6 | 23.86 | 9.8e-6 |
| checkpoint | 9.334 [9.334–9.408] | 275 MB | 5 | 2.2e-6 | 33.56 | 9.5e-6 |
| flash (tuned: TF32 mma) | 0.242 [0.241–0.245] | 4.2 MB | 1 | 5.2e-4 | 0.744 | **1.5e-2 FAIL** |
| flash, no tensor cores (f32) | 3.664 [3.362–3.665] | 4.2 MB | 1 | 2.0e-6 | 7.64 | **1.5e-2 FAIL** |
| flash, fused backward off (`TANG_NO_ATTN_BWD=1`) | — | — | 8 | — | 1.652 | 1.2e-3 |
| searched | **0.233** [0.232–0.238] | 4.2 MB | 1 | 5.2e-4 | 1.907 (fused bwd on) / 1.675 (off) | 1.2e-3 |

- **The forward figure stands, on CUDA and checked.** The searched forward is the flash placement (Smem / Recompute / Reg / Fuse). It is 18× faster than naive and 40× faster than checkpoint, and every point passes.
- **New finding: flash's forward+backward fails the f32 check.** The fused attention-backward kernel (`tensor_cuda_attn_bwd`) computes in bf16 tensor cores even for an f32 graph. Its error is 1.5e-2 (dQ), 9.7e-3 (dK) and 9.0e-3 (dV), and it is the same with every other kernel on f32 (`flash_fp32` row). With the fused backward disabled, the same flash placement passes at 1.2e-3 and runs 1.65 ms instead of 0.74 ms. The search correctly rejected the fused one, so the "searched" fwd+bwd point is a slower, correct schedule. The earlier figure never checked flash; this run shows the fused backward is not f32-accurate.
- **The search caught a wrong placement.** Smem / Recompute / Hbm / Fuse produced output with error 7.0 (simply wrong) at 14.5 ms (`fig1.err`). The check rejected it. Its cause is not yet investigated.
- **Why the lowest-traffic schedule doesn't always win.** Checkpoint moves a third of naive's model traffic (275 vs 816 MB) yet is 2.2× slower. Almost all of the difference is one kernel, the score contraction S = QKᵀ: 7.12 ms in checkpoint against 1.51 ms in naive, with the same arithmetic and the same output.
  - Naive materializes Kᵀ in its own transpose kernel (8 µs), so in S the 32 lanes of a warp read 32 adjacent floats.
  - Checkpoint's `substitute_maps` folds the transpose into the view, so each lane reads its own K row.
  - ncu on mew (`mew-ncu/naive_fwd.csv`, `ckpt_fwd.csv`) confirms it: the same 67.6 M L1 requests carry 5.4 GB in naive and 35.5 GB in checkpoint (6.5×).
  - **So it is not a wrong lowering:** the output is exact to 2e-6. It is a lowering that loses coalescing when a transpose is recomputed into its reader. The traffic model counts DRAM bytes once per buffer and cannot see this; the L1 bytes can.
  - Flash, the lowest-traffic schedule (4.2 MB), does win.

### 2. PyTorch baselines for the d = 576 block (idle 3090)

`python3 scripts/review/torch_block_compile.py` (eager, `torch.compile`, CUDA graph via `torch.cuda.graph`; fp32 and TF32) and `cargo run --release -p tang-bench --features cuda --example cuda_block`, interleaved for 6 rounds. Values are best [median] of 6, in ms.

| block | tang (CUDA) | torch eager fp32 / TF32 | torch.compile fp32 / TF32 | torch CUDA graph fp32 / TF32 |
|---|---|---|---|---|
| fwd 128 | 0.196 [0.197] | 0.788 / 0.820 | 0.396 / 0.388 | 0.269 / **0.162** [0.162] |
| fwd 512 | **0.331** [0.332] | 0.793 / 0.841 | 0.434 / 0.407 | 0.560 / 0.396 |
| fwd+bwd 128 | 0.482 [0.503] | 3.774 / 3.127 | 2.148 / 1.553 | 0.663 / 0.484 [0.484] |
| fwd+bwd 512 | 1.127 [1.132] | 4.209 / 2.947 | 1.524 / 1.724 | 1.621 / 1.142 [1.144] |

- **The fair baseline is closer.** With a CUDA graph and TF32, PyTorch's forward at seq 128 (0.162 ms) beats tang's (0.196 ms) by 1.2×. fwd+bwd at seq 128 is a tie (0.484 vs 0.482 best, 0.503 median), and so is seq 512 (1.142 vs 1.127).
- tang still wins the seq-512 forward against every PyTorch mode: 0.331 ms vs 0.396 (graph TF32) and 0.407 (compile TF32).
- Eager PyTorch on this pod is slower than the earlier shared-GPU numbers (0.79 vs 0.306 ms at fwd 128) because the eager path is CPU-launch bound and this pod's CPU differs. The CUDA-graph rows remove that.
- The CUDA-graph TF32 column is the baseline to compare against.

### 6. Floors beyond GEMVs: flash attention and matmul tiles (3090)

Bytes come from ncu on mew (`scripts/ncu/ncu_kernels.sh … --profile-from-start off -- floors_cuda <w>`). Times come from the idle rented 3090 (`floors_cuda <w>`, same tuned program). The traffic floor is bytes / 936 GB/s. The compute floor is FLOPs / 35.6 TFLOP/s, the 3090's dense TF32 tensor peak.

| kernel | idle time | DRAM bytes | traffic floor (light) | FLOPs | compute floor (light) |
|---|---|---|---|---|---|
| flash fwd, causal 4096×64 (1 kernel) | 0.243 ms | 5.5 MB | 5.9 µs (0.02) | 2.15 G | 60 µs (**0.25**) |
| flash fwd+bwd, causal 4096×64 (8 kernels) | 0.743 ms | 29 MB | 31 µs (0.04) | 7.5 G | 211 µs (0.28) |
| matmul tile 1024³ TF32 | 0.098 ms | 12.5 MB | 13.4 µs (0.14) | 2.15 G | 60 µs (**0.62**) |
| matmul tile 512×576×1536 TF32 | 0.054 ms | 8.9 MB | 9.6 µs (0.18) | 0.91 G | 25 µs (**0.47**) |

These kernels are compute-shaped: their traffic floors are 2–18% of their time, so the GEMV-style "light" says nothing about them. Against the TF32 roof, the matmul tile reaches 0.47–0.62 and flash 0.25–0.28. Flash's fused backward kernel alone takes 0.476 ms of its 0.743 ms. Full ncu tables, including occupancy, L1 requests and stalls, are in `mew-ncu/*.md`.

### 7. Greedy equivalence, Qwen3-8B, 256 tokens (idle 3090)

`qwen_decode model <mlx-community/Qwen3-8B-4bit> ids.txt --gen 256`, then the 277 ids (21-token prompt + 256 generated) are teacher-forced through `--force`. They are compared against `qwen_decode reference` (CPU f32 with f64 accumulation, the checkpoint dequantized exactly) and `qwen_decode compare`.

**Tolerance for the experiment: argmax equal at every position.**

| check | result |
|---|---|
| argmax agreement, positions 20…276 | **257/257** |
| on-device argmax vs the logits' argmax | 257/257 |
| logit error | max \|err\| 0.98 at max \|logit\| 55.7 (1.8% of scale), mean 6.5e-3 |

The greedy text is the reference's for all 256 tokens. The worst logit error, 0.98, is larger than the 3.3e-2 recorded for 64 tokens. The device caches are f16, and per-position error grows with context; it never flipped an argmax here.

### 4. MoE layer with equal work (idle H200)

`CODER_MOE_B=1,4,8,64 CODER_MOE_DUMP=d coder_moe_ir`, then `coder_moe_hand d 1 4 8 64` on the same bytes. The fragment and GEMV rows add `CODER_MOE_STAGE=frag|gemv`. There were 3 rounds; values are medians of the cold (L2-flushed) medians, in ms, with the round spread in brackets. All outputs agree to ≤ 3e-7.

The hand `cx_moe_add_norm` also does the residual add, the next RMSNorm and the int8 activations. The derived half stops at the combine. For equal work, the same three steps are timed as derived ops on the window's own output (`add_norm` + `engine_q8`, 5 kernels), in the new block at the end of `coder_moe_hand`, and added to the derived half.

| B | derived expert half (stage) | + residual, norm, int8 | **derived, equal work** | **hand** | derived / hand |
|---|---|---|---|---|---|
| 1 | 0.0356 [0.0356–0.0356] (Gemv) | 0.0162 | **0.0518** | 0.0439 | 1.18 (slower) |
| 4 | 0.0763 (Gemv) | 0.0164 | **0.0927** | 0.0868 | 1.07 (slower) |
| 8 | 0.1062 (Fragment) | 0.0168 | **0.1230** | 0.1248 | 0.99 |
| 64 | 0.2957 (Fragment) | 0.0222 | **0.3179** | 0.3357 | 0.95 |

- **Which B=1 number is right:** both, for different stages.
  - 0.036 is the `Stage::Gemv` schedule (fused producers): 0.0356 here, 0.0354 when forced.
  - BENCHMARKS.md:2810's 0.0484 is the Fragment (int8 MMA) stage at B=1, before `Stage::Gemv` existed: 0.0504 here with `CODER_MOE_STAGE=frag`.
  - The MoE table in the paper uses the Gemv number for B=1/4 and states it.
- **But with equal work the derived layer loses at B = 1 and 4,** by 18% and 7%. An earlier "beats the hand kernels at batch 1" held only for the unequal comparison. At B = 8 it is a tie and at B = 64 a 5% win.
- Gemv at B=8: 0.1167, slower than Fragment's 0.1062, as the default chooses.

### 3. Attention at d = 256 on the H200: tang against FlashAttention-3 and SDPA

`python3 scripts/hopper_attention.py gen DIR N 256 CAUSAL`, then `… bench DIR` (FA3 and SDPA) and `hopper_attention DIR` (tang). 3 rounds each, medians in ms; the round spread is under 2% everywhere (raw: `h200/attn_*`).

- FA3 was built from `flash-attention/hopper` at HEAD with only head dim 256 in bf16 enabled (`flash_attn_3` 3.0.1, `flash_attn_interface`).
- 16k tokens per configuration and 2048 hidden (8 heads), bf16.
- Every library is checked on two heads against the f64 reference, and all land at relative error 2–5e-3.
- tang's backward time is its forward+backward program minus its forward.

| N | causal | tang fwd | FA3 fwd | SDPA fwd | tang / FA3 (fwd) | tang bwd | FA3 bwd | SDPA bwd | tang / FA3 (bwd) |
|---|---|---|---|---|---|---|---|---|---|
| 1024 | no | 0.433 | 0.199 | 0.450 | 2.18× slower | 3.624 | 0.914 | 1.742 | 3.96× slower |
| 1024 | yes | 0.315 | 0.137 | 0.274 | 2.30× | 2.666 | 0.574 | 1.141 | 4.64× |
| 4096 | no | 1.379 | 0.703 | 1.712 | 1.96× | 8.748 | 3.079 | 5.671 | 2.84× |
| 4096 | yes | 0.885 | 0.377 | 0.963 | 2.35× | 5.075 | 1.620 | 3.154 | 3.13× |
| 16384 | no | 5.177 | 2.783 | 6.785 | 1.86× | 29.30 | 11.79 | 21.60 | 2.49× |

- At d = 256, tang's forward runs at 0.43–0.54 of FA3's speed, inside the earlier 0.42–0.60.
- Its backward runs at 0.22–0.40 of FA3's, the low end of the earlier "about 0.4×". The backward is below 0.3 at N ≤ 4096.
- Against SDPA, tang's forward wins from N = 4096 up (1.24×, 1.09×, 1.31×) and loses at N = 1024 causal. Its backward loses to SDPA everywhere.
- The FA3 fp8 path was not built.

### 5. In-model decode, five interleaved rounds (H200)

`TANG_BATCH_N=N TANG_BATCH_ONLY=N [TANG_CODER_DERIVED=moe TANG_DMOE_MIN_ROWS=16] tang-llm flash-batch-check <UD-Q4_K_XL> --prompt-file refactor_short.txt -n 64`

- One idle H200 for all 30 runs, each a fresh process.
- Hand and derived alternate, and their order flips each round.
- Context ~1380, 64 timed steps after 4 warm-up steps.

| N | hand ms: 5 rounds (median, range) | derived ms: 5 rounds (median, range) | derived gain per round |
|---|---|---|---|
| 16 | 15.83 15.84 15.84 15.84 15.83 (15.84, 0.01) | 13.99 13.52 13.99 13.99 13.53 (13.99, 0.47) | 11.6–14.6% |
| 32 | 23.45 23.43 23.44 23.43 23.44 (23.44, 0.02) | 21.35 21.35 21.36 21.36 21.36 (21.36, 0.01) | 8.8–9.0% |
| 48 | 30.00 30.00 30.08 30.00 30.02 (30.00, 0.08) | 28.43 28.43 28.43 28.43 28.46 (28.43, 0.03) | 5.2–5.5% |

- **On one machine the round-to-round swing (at most 0.47 ms, 3%) is far below the gain (5–15%), in every round.**
- Earlier single runs disagreed because they compared different pods: hand N=48 has read 29.67, 30.01, 30.20 and 30.26 ms on four different H200 pods in earlier rounds.
- Paired comparisons need one machine. These medians are the in-model numbers.
- Batch-check tolerance at each N is the same every round. Hand: 99.16 / 99.23 / 99.00%. Derived: 99.02 / 99.06 / 98.93%; at N=48 derived sits 0.07 points under the 99% bar and hand exactly at it.

### 8. TTFT against vLLM (H200)

vLLM 0.33.0 ran on `Qwen/Qwen3-Coder-Next-FP8`, the official FP8 checkpoint (80 GB). The bf16 checkpoint is 159 GB and does not fit one H200. The command was `VLLM_USE_DEEP_GEMM=0 python scripts/review/vllm_ttft.py`:
- an offline `LLM` with no prefix reuse
- three prompts per length, each a different rotation of the same text
- one output token, after one warm-up.

The first attempt failed: vLLM's DeepGEMM needs nvcc ≥ 12.9 and the image ships 12.8, so DeepGEMM is off.

tang ran `flash-batch-check` with `TANG_BATCH_N=1 TANG_BATCH_CTX=N TANG_CODER_KV=int8 TANG_CODER_WIDE=2048` on the UD-Q4_K_XL GGUF: the time to prefill one stream, three runs.

| prompt | vLLM FP8 (3 runs) | tang hand kernels (3 runs) | tang + `TANG_CODER_ATTN=derived` (2 runs) |
|---|---|---|---|
| 8,000 tokens | **0.167–0.173 s** | 2.1 s | — |
| 44,000 tokens | **1.082–1.088 s** | 13.8 s | 12.9 s |

- **vLLM is 12.4× faster to first token at 8k and 12.7× at 44k.** These are different weight formats (FP8 vs a 4.5-bit GGUF), so the comparison is not precision-matched. But the gap is an order of magnitude and does not come from the format.
- tang's 13.8 s here is also slower than the warm-server 8.33 s (hand) / 5.54 s (derived attention + scan) TTFT. That table came from a warm server, and batch-check's prefill path may include work the server path skips. This was not reconciled.
- The prefill gains are relative to tang's own engine. Against vLLM they do not hold.
- SGLang was not tried.

### What this costs and what was not done

- FA3 fp8 was not built, and SGLang was not run.
- The flash backward's bf16 kernel is reported, not fixed.
- The wrong Smem/Recompute/Hbm/Fuse placement is caught by the check but not root-caused.
- The 13.8 s vs 8.33 s TTFT gap between batch-check and the warm-server measurement is not reconciled.

### Launch, latency and the 3090 attention tile

**Empty kernel and DRAM latency, H200 SXM** (`scripts/review/latency.cu`, `nvcc -O2 -arch=sm_90a`, idle RunPod secure H200, 2026-11-10; raw: `review/prove/latency_h200.txt`). Three runs agree to within 0.5 ns.

| quantity | value |
|---|---|
| empty kernel inside a CUDA graph (2000 nodes, best of 10 replays): 1 / 132 / 528 blocks × 256 | **0.48 / 0.54 / 0.78 µs** each |
| same, launched on a stream | 2.34 / 1.79 / 1.80 µs |
| pointer chase, one thread, random single cycle with 64 B slots, 1 MB (L2-resident) | 145 ns (286 cycles at 1.98 GHz) |
| same over 32 MB | 191 ns |
| same over 4 GB (DRAM, including TLB misses) | **340 ns** (672 cycles) |

A first version re-walked the warm-up run's path, so the timed chase hit L2 (151 ns at 4 GB). It is kept in the raw file and superseded.

**3090 attention autotuner pick** (`TUNE=3090 io_dual` on branch `claude/paper-theory-fixes` fb1cb207). It ran on an idle rented RTX 3090; raw: `review/prove/io_dual_3090_cuda.txt`. The pod has no Vulkan driver, so `Runtime::select` ran with `--features cuda`: the tuner timed CUDA lowerings, not wgpu.
- matmul 1024³: autotuned [p0=64 p1=64 r0=32], 1.95× bound.
- attention fwd, 8 heads, N = 1024 and N = 4096, d = 64 causal: autotuned [p2=16 p3=64 r0=16], 24× bound. That is the same as `schedule_auto`; the dual tile is [p2=48 r0=48] and the 2-level dual [p2=128 p3=32 r0=32].
- Per-tile kernel times were not measured: `io_dual` prints none.

**3090 attention race** (`TUNE=3090 RACE=1 io_dual --features cuda`, PR #195 head 24eb7f7c, 2026-11-10 08:27 UTC; raw: `review/prove/io_dual_race_3090.txt`).
- **Machine:** RunPod had no RTX 3090 in stock in any region or CUDA version, so this ran on mew under `flock ~/tang-gpu.lock`. mew's other GPU processes (listed at the top of the raw file) were idle: utilization was 1% before the run, and the 2 s samples in `io_dual_race_3090_util.txt` show 100% for our process throughout.
- **Candidates:** the race times every candidate of the main kernel's schedule space, 12 per workload.

| workload | candidates | fastest | slowest | spread | traffic range of candidates |
|---|---|---|---|---|---|
| matmul 1024³ | 12 | 0.100 ms [p0=64 p1=64 r0=32] | 0.101 ms | 1% | 138–541 MB |
| matmul 4096³ | 12 (2 failed to launch: invalid argument) | 5.511 ms [p0=32 p1=16 r0=32] | 5.566 ms | 1% | 8.7–25.8 GB |
| attention fwd 8×1024×64 causal | 12 | 0.072 ms (all) | 0.072 ms | <1% | 107–409 MB |
| attention fwd 8×4096×64 causal | 12 | 0.663 ms [p2=16 p3=64 r0=16] | 0.678 ms | 2% | 1.6–10.8 GB |

Per tile (queries p2 × keys r0, value columns p3):
- N = 1024: 16×16 (p3=64) 0.072 ms, 64×16 (p3=32) 0.072 ms, 16×32 0.072 ms.
- N = 4096: 16×16 (p3=64) **0.663 ms**, 64×16 (p3=16) 0.677, 64×32 (p3=32) 0.677, 16×32 (p3=32) 0.678.
- 64×64 is not in the candidate space io_dual races.

**Reading.** Candidate times differ by at most 2% while their LP traffic differs by 2.5–4×. On this CUDA path, matmul and attention lower to the native mma kernels (TF32 tile, flash on mma), and those take their block shape from the lowering, not from the thread-schedule tile being raced. So on CUDA the race measures the same kernel 12 times. It cannot test whether the dual's tile beats the autotuner's. The wgpu path (Vulkan), where the thread tile is the kernel's tile, would; it needs a 3090 with a Vulkan driver (mew has one).
