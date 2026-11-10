# Speed log

Decode speed of `main` after each performance change, measured on rented GPUs. One row per
(change, GPU, model, streams). `bench_batch --q4` (greedy, no speculation, 256 tokens for 8B
and 128 for 32B, `mlx-community/Qwen3-*-4bit`) unless the row says zest-harness. tok/s is
total across streams. Speed of light is the weight bytes a step over HBM bandwidth (8B ~4.26 GB,
32B ~18.4 GB; H200 4.8 TB/s, H100 SXM 3.35 TB/s): 8B 1120 tok/s on an H200 and 790 on an
H100, 32B 260 and 182. % is of that, for one stream. Rows compare against the previous row
for the same GPU, model and streams; GPUs differ run to run (±5%), so treat changes under
~5% as noise unless the same pod measured both.

| date | commit | change | GPU | model | streams | tok/s | % SoL | vs prev |
|---|---|---|---|---|---|---|---|---|
| 2026-10-20 | bfcb90f | baseline | H200 | 8B | 1 | 121 | 10.8% | |
| 2026-10-20 | bfcb90f | baseline | H200 | 8B | 8 | 603 | | |
| 2026-10-20 | bfcb90f | baseline | H200 | 32B | 1 | 42.9 | 16.5% | |
| 2026-10-20 | bfcb90f | baseline | H200 | 32B | 8 | 172 | | |
| 2026-10-20 | c623ce1 | #80 GEMV fill, #81 pool, #82 attention splits, #83 rms_norm | H200 | 8B | 1 | 208 | 18.5% | +72% |
| 2026-10-20 | c623ce1 | (same) | H200 | 8B | 8 | 709 | | +18% |
| 2026-10-20 | c623ce1 | (same) | H200 | 32B | 1 | 69.5 | 26.7% | +62% |
| 2026-10-20 | c623ce1 | (same) | H200 | 32B | 8 | 215 | | +25% |
| 2026-10-20 | c623ce1 | (same, new pod) | H100 | 8B | 1 | 197 | 24.9% | |
| 2026-10-20 | c623ce1 | (same) | H100 | 8B | 8 | 700 | | |
| 2026-10-20 | c623ce1 | (same) | H100 | 8B | 16 | 846 | | |
| 2026-10-20 | c623ce1 | (same) | H100 | 32B | 1 | 67.6 | 37.1% | |
| 2026-10-20 | c623ce1 | (same) | H100 | 32B | 8 | 213 | | |
| 2026-10-20 | c623ce1 | (same) | H100 | 32B | 16 | 232 | | |
| 2026-10-21 | 701af6c | #87 speculation ≤2 streams, #89 tensor-core GEMM (no change at 1/8 rows in bench_batch, as expected) | H200 | 8B | 1 | 207 | 18.5% | −0.5% |
| 2026-10-21 | 701af6c | (same) | H200 | 8B | 8 | 711 | | +0.3% |
| 2026-10-21 | 701af6c | (same) | H200 | 32B | 1 | 70.7 | 27.2% | +1.7% |
| 2026-10-21 | 701af6c | (same) | H200 | 32B | 8 | 219 | | +1.9% |

AA-style single stream (`tang-llm serve`, speculation on as deployed, ~850-token prompt, 500
output tokens, temperature 0.7, streamed; output tok/s from first token to last, median of 3;
the probe is `docs/bench/speed_bench.py`):

| date | commit | GPU | model | AA output tok/s | bar (fastest public API) |
|---|---|---|---|---|---|
| 2026-10-21 | 701af6c | H200 | 8B | 200.5 | Eigen 303 |

Measured on the same H100 pod, waiting to merge (each on top of c623ce1):

| change | model | streams | tok/s | vs c623ce1 |
|---|---|---|---|---|
| draft only at ≤2 streams (zest-harness, speculation on) | 8B | 4 / 8 / 16 | 408 / 542 / 600 | +38% / +61% / +91% |
| (same) | 32B | 8 / 16 | 149 / 160 (≤4) | +58% / +86% |
| device top-64 sampling | 8B | 8 / 16 | 785 / 1002 | +12% / +18% |
| (same) | 32B | 8 / 16 | 221 / 243 | +4% / +5% |
| tensor-core 4-bit GEMM, 9-32 rows | 8B | 16 | 895 | +6% |
| (same) | 32B | 16 | 282 | +21% |
| all three | 8B / 32B | 16 | 1051 / 298 | +24% / +28% |

## gpt-oss-20b

Single stream, AA-style (a ~1k-token chat prompt, output tok/s; `scripts/gpt_oss_speed.sh`).
The bar is Groq's claimed ~1,200 tok/s.

**Bytes per decoded token** (what a step must read; gpt-oss-20b, 24 layers):

| part | format | per token |
|---|---|---:|
| experts: 4 of 32 per layer, gate/up 5760×2880 + down 2880×2880 | MXFP4 (4.25 bits) | 1.27 GB |
| attention Q/K/V/O, 26.5M a layer | bf16 | 1.27 GB |
| output head 201088×2880 | bf16 | 1.16 GB |
| KV at ~1.3k context (12 full layers ~1.3k keys, 12 sliding 128), f32 | | ~0.05 GB |
| router, norms, biases | f32 | ~0.01 GB |
| **total** | | **~3.75 GB** |

Speed of light at that size: 1280 tok/s on an H200 (4.8 TB/s), 890 on an H100, 270 on a 4090.
Groq's 1,200 is ~94% of the H200's. **To pass it, the weights have to shrink:** attention and
the head at 4 bits (Q4, as the Qwen rows run) would take a token to ~1.95 GB, a 2460 tok/s ceiling
on the H200. The experts are already 4-bit.

**Per kernel** (4090 nsys, 256 decoded tokens, before the 4-rows-a-warp GEMV): the expert GEMV
was 48% of GPU time at ~350 GB/s (a third of peak) and the bf16 GEMVs 36% at ~0.94 TB/s (at
peak). Sink attention was 6%, rms_norm 4%. Host side: ~460 launches a token, with a
host-to-device upload (ids, block tables) and a logits download every step.

| kernel | bytes/token | at 4.8 TB/s | measured | what's left |
|---|---:|---:|---|---|
| `moe_gemv_mxfp4` (48 calls) | 1.27 GB | 0.26 ms | 4090: 3.6 ms → ~2.2 ms after 4 rows a warp | input staged in smem (new, A/B below); more columns a block |
| `gemv_bf16` attention (48 calls) | 1.27 GB | 0.26 ms | at bandwidth | 4-bit attention weights |
| `gemv_bf16` head (1 call) | 1.16 GB | 0.24 ms | at bandwidth | 4-bit head, or device top-k so only the argmax comes back |
| `attn_sink_partial` + combine | ~0.05 GB | 0.01 ms | 6% (launch-bound) | fold into fewer launches |
| everything else (~360 launches) | | | ~1.5 ms on H100 | CUDA graphs |

Measured so far (before the rebase onto #88/#89):

| date | commit | change | GPU | model | streams | tok/s | % SoL | vs prev |
|---|---|---|---|---|---|---|---|---|
| 2026-10-20 | 29221a7 | #95, 13-token prompt | RTX 4090 | gpt-oss-20b | 1 | 157 | 58% | |
| 2026-10-20 | 1b8474c | #95, 13-token prompt | H100 | gpt-oss-20b | 1 | 182 | 20% | |
| 2026-10-20 | 1b8474c | #95, 13-token prompt | H100 | gpt-oss-120b | 1 | 119 | | |

**Plan for when gpt-oss is back in focus** (on hold since 2026-10-21; 30% of zest goes to
speed, all of it on Coder-Next and tang-pro for now). In order, each with what's ready:

1. **Q4 attention and head**, the path past Groq: 3.75 → ~1.95 GB a token, H200 ceiling
   1280 → ~2460 tok/s. `--q4` already quantizes attention, the embedding and the head at load
   (affine 4-bit, group 64) and the 4-bit GEMV serves them. Correctness checked offline:
   `scripts/gpt_oss_q4_check.py` applies the same rounding to transformers' weights, and tang
   `--q4` matches it at max KL 1.1e-4 (tiny model, CPU). Still unmeasured: what Q4 costs the
   real 20b. `gpt_oss_speed.sh` measures it (`--q4` vs bf16 KL, 256 positions) beside the speed.
   If the head costs too much, keep the head bf16 and quantize attention only (1.27 GB saved of
   the 1.8), or try group 32.
2. **The MXFP4 GEMV A/B** (input via L1, the default, vs staged in shared memory,
   `TANG_MOE_GEMV=smem`), in the same script. The smem kernel has not run on a GPU yet.
3. **CUDA graphs over the decode step**: the H100 step is launch-bound (~460 launches a token).
4. **Speculation**: already exact for gpt-oss (`tests/speculate.rs` passes on CUDA).

One H200 hour covers 1 and 2 (`scripts/gpt_oss_speed.sh <gpt-oss-20b dir>`; it prints these
rows and an nsys summary).

## Dead ends

Tried and measured at under 3% (or worse):

- **4-bit GEMV, a warp a column, x read through L1 (no shared-memory stage):** 30% slower at one
  row, worse with more rows (L1 traffic is 8x the weight bytes per extra row).
- **GEMV with the next stage's weights double-buffered in registers:** 5-15% slower; register
  pressure cut occupancy.
- **GEMV, 2 columns a warp instead of 4:** 2-10% slower.
- **GEMV K-split sizing, 1 / 4 / 8 / 16 blocks an SM:** within 3% of each other once the
  128-bit loads are in; 4 kept.
- **GEMV with the whole K slice of x resident in shared memory and every weight load issued up
  front (`gemv_q4_xr`, 2026-10-21, H200):** 8B solo 207 → 130 tok/s, 32B 71 → 36. Registers
  (16 uint4 of weights a lane) leave one 8-warp block an SM, and a block loads everything,
  then computes: no overlap between one block's math and the next one's loads. The fix has to
  keep several blocks (or a load pipeline) per SM.
- **Device top-k for a lone stream:** 1.5% slower than sampling its one row on the host;
  only batches cut on the device.
- **The VRAM-pressure check on pool misses only (#81)** measured +1.5% alone. It's kept because
  it takes ~2.6 ms of CPU off each step, which matters once kernels stop hiding host time.

## Qwen3-Coder-Next (qwen3next Flash engine)

`Qwen3-Coder-Next-UD-Q4_K_XL.gguf` (unsloth, 49.6 GB), the Flash engine's qwen3next path
(`src/flash/coder.rs`), one stream, greedy. A step reads 3.42 GB at a 1.3k context (3.52 GB at
4k): dense weights, 10 routed + 1 shared expert a layer, head, K/V. Speed of light is that over
HBM bandwidth: 1,400 tok/s on an H200, 970 on an H100 SXM.

AA rows are `flash-aa`, Artificial Analysis-style: a ~1.24k-token chat prompt (one of
`explain` / `refactor` / `write`, the same 140-line Rust file with a different task), 512
output tokens, tok/s after the first token. The fastest public API for this model is Novita at
174 tok/s.

| date | commit | change | GPU | prompt | drafts | tok/s | % SoL | vs prev |
|---|---|---|---|---|---|---|---|---|
| 2026-10-20 | c33c4df | engine (#84), flash-bench 4k ctx | H100 | code ×4k | none | 156 | 16.1% | |
| 2026-10-20 | b9fbcad | fusions, K-split GEMV, 1024-thread norms (#90) | H100 | code ×4k | none | 198 | 20.4% | +27% |
| 2026-10-21 | d9f1d29 | (same kernels) AA | H200 | explain | none | 205.5 | 14.7% | |
| 2026-10-21 | d9f1d29 | | H200 | refactor | none | 205.3 | 14.7% | |
| 2026-10-21 | d9f1d29 | | H200 | write | none | 205.3 | 14.7% | |
| 2026-10-21 | d9f1d29 | | H200 | explain | suffix | 205.1 | | 1.15 tok/window |
| 2026-10-21 | d9f1d29 | | H200 | refactor | suffix | 340.5 | | 2.71 tok/window |
| 2026-10-21 | d9f1d29 | | H200 | write | suffix | 218.7 | | 1.28 tok/window |
| 2026-10-21 | d9f1d29 | separate SiLU launch (now the default) | H200 | explain | none | 217.4 | 15.5% | +2% (noise) |
| 2026-10-21 | 4ac3171 | K-split GEMV, 2 warps a row (was 4) | H200 | explain | none | 227.2 | 16.2% | +4.4% |
| 2026-10-21 | 4ac3171 | (same pod, 2 warps for 4k+-row matrices only) | H200 | explain | none | 226.9 | 16.2% | +4.3% |
| 2026-10-21 | 4ac3171 | (same build, AA) | H200 | refactor | suffix | 370.2 | | 2.71 tok/window |
| 2026-10-21 | 4ac3171 | | H200 | write | suffix | 229.0 | | 1.25 tok/window |
| 2026-10-21 | 4ac3171 | | H200 | explain | suffix | 222.3 | | 1.16 tok/window |
| 2026-10-21 | 2a723ae | (round-3 pod, defaults of 4ac3171) | H200 | explain | none | 222.3 | 15.9% | pod baseline |
| 2026-10-21 | 2a723ae | fast Q4_K/Q5_K expert dot (32 weights a lane) | H200 | explain | none | 230.9 | 16.5% | +3.9% |
| 2026-10-21 | 2a723ae | Q8X dense repack (aligned codes, separate scales) | H200 | explain | none | 231.8 | 16.6% | +4.3% |
| 2026-10-21 | 8fdfd13 | Q8X + fast expert dot (the defaults now) | H200 | explain | none | 240.8 | 17.2% | +8.3% |
| 2026-10-21 | 2a723ae | + bf16 router (opt-in) | H200 | explain | none | 243.1 | 17.4% | +1% |
| 2026-10-21 | 2a723ae | (Q8X + bf16 router, AA) | H200 | refactor | suffix | 403.5 | | 2.71 tok/window |
| 2026-10-21 | 2a723ae | | H200 | write | suffix | 252.0 | | 1.25 tok/window |
| 2026-10-21 | eed9069 | (round-4 pod, defaults) | H200 | explain | none | 242.0 | 17.3% | same as round 3 |
| 2026-10-21 | 625db0d | (round-5 pod, defaults: Q8X loads two steps ahead) | H200 | explain | none | 241.5 | 17.2% | 0% |
| 2026-10-21 | c4aad43 | two expert-down rows a warp (fastk=2, now the default) | H200 | explain | none | 246.7 | 17.6% | +2.2% |
| 2026-10-21 | 625db0d | (same pod, AA) | H200 | write | suffix | 247.2 | | 1.25 tok/window |

Stage sweep on that H200 pod (`TANG_CODER_STAGES=1`: each stage alone in a CUDA graph, replayed;
µs a step at a 1.3k context, window 4,856 µs): routed+shared gate|up 876 (771 GB/s), down 801
(501 GB/s), GDN input GEMV 618 (1.6 TB/s), GDN output 301, top-k 286, GDN conv+step 238,
moe combine+norm 214, attention split-K 207 (154 GB/s), router 176, head 174, post-mixer norm
166, attention in/out 260. The stages sum to 4,461 µs, so launch gaps are ~8% of the window.

### Batch decode past 8 rows (2026-11-03, b957a2a9+, H200, explain prompt, ~1.2k context)

`TANG_BATCH_N=64 flash-batch-check`: bitwise PASS at 64 sequences (tokens and logits equal to
each sequence alone). Graphs, 16 steps:

| B | ms a step | tok/s aggregate | tok/s a stream |
|---|---|---|---|
| 1 | 4.03 | 248 | 248 |
| 2 | 4.73 | 423 | 211 |
| 4 | 6.49 | 616 | 154 |
| 8 | 9.86 | 812 | 101 |
| 16 | 21.99 | 728 | 45 |
| 32 | 40.53 | 790 | 25 |
| 64 | 73.90 | 866 | 14 |

Past 8 rows the step grows linearly with B. Eager profile at B=64 (ms a step): expert gate|up
23.6 (~0.46 GB a layer of distinct experts in 0.49 ms: ~0.94 TB/s), expert down 24.3 (~0.46
TB/s), GDN in 6.8, GDN conv+step 4.3, GDN out 4.1, attention split-K 2.6, head 1.9, attention
in 1.7, router 1.6, attention out 1.3. The grouped expert kernels (`cx_moe_gu_g` /
`cx_moe_down_g`, ~1.75 tokens an expert) and the 32-row K-split GEMVs (`cx_gemvkb`, L2-bound
re-reading activations per weight row) are the walls.

- **Tensor-core GEMMs for batch windows** (`TANG_CODER_BGEMM=1`: `cx_gemm_dense` +
  `cx_moe_gemm_*`, the prefill kernels): slower at every B past 8 (B=64: 132.5 vs 78.3 ms
  eager) and not bitwise. They're tiled for 64 tokens an expert; decode has ~2.

### Streaming grouped experts for batch windows (2026-11-03, H200, explain, ~1.2k context)

`cx_moe_gu_s` / `cx_moe_down_s`: grid (row tiles of 64 / 128 rows, groups of at most 8 pairs),
each warp walking its rows of one expert with cp.async staging, the group's activations staged
once a block, and `cx_dotq_m` decoding each Q4_K/Q5_K weight block once for all the group's rows
(each row's arithmetic the single-row dot's). Bitwise PASS at 64. Graphs, 16 steps:

| B | ms a step | tok/s aggregate | tok/s a stream |
|---|---|---|---|
| 1 | 4.03 | 248 | 248 |
| 2 | 4.74 | 422 | 211 |
| 4 | 6.51 | 615 | 154 |
| 8 | 9.86 | 812 | 101 |
| 16 | 20.01 | 800 | 50 |
| 32 | 31.04 | 1031 | 32 |
| 64 | 51.16 | 1251 | 20 |

Eager, B=64 (ms a layer, GB/s from ~367 distinct experts + shared): gate|up 0.57 → 0.29
(~1.5 TB/s; 0.22 ms / ~2 TB/s on 64-token prompts), down 0.50 → 0.23 (~0.95 TB/s; 0.18 /
~1.2 TB/s). Ring depth barely matters (gate|up best at 1 stage — occupancy wins; down 2).

- **Plain code sums precomputed per 16 bytes** (dropping 8 of 16 dp4a a row-token, exact): slower
  (gate|up 0.22 → 0.26 ms), the extra prologue pass costs more than it saves.
- **Deeper rings / more rows a warp for down** (4/8 stages, 32 rows): flat or worse.

### Tensor-core batch windows, tolerance-gated (2026-11-03, H200, explain, ~1.2k context)

Past 8 rows, batch windows may drop bitwise equality: `flash-batch-check` then gates on
**greedy agreement given the same history ≥ 99%** (each sequence's steps up to and including
its first divergence from the sequence alone) and **mean |Δlogit| ≤ 0.2** over those steps
(`TANG_BATCH_TOL`); max |Δlogit| is reported. Narrow windows (T ≤ 8) stay bitwise.

Measured noise floor at B=64 (16 steps): agreement 99.50% (986/991), mean |Δlogit| 0.122,
max 11.9. The int8 MMA down kernel matches the per-pair dot to ~1e-6 relative
(`TANG_CODER_MMA_CHECK=1`), so the spread isn't the kernel: a reordered fp32 sum flips the int8
rounding of some activation downstream, and the flips compound over 48 layers. A 0.05 max bar
is unreachable for any change of summation order in this pipeline.

| commit | change | B=16 | B=32 | B=64 ms | B=64 tok/s |
|---|---|---|---|---|---|
| 34c91db3 | streaming experts (bitwise) | 20.01 | 31.04 | 51.16 | 1251 |
| 90a132d9 | + MMA down experts (`cx_moe_down_m`) | 19.32 | 29.75 | 48.64 | 1316 |
| 90a132d9 | + Q8X dense MMA (`cx_mma_q8x`) | 18.60 | 27.24 | 43.02 | 1488 |
| 94c1b95b | + mixed matrices (GDN in on MMA) | 18.48 | 25.79 | 40.01 | 1600 |

Eager B=64 at 94c1b95b, ms a step: gate|up (streaming) 10.7, down (MMA) 5.8 (~1.8 TB/s), GDN in
4.1, GDN conv+step 4.3 (≈ the f32 state's bandwidth at 64 sequences), router 1.6, route+plan
1.6, GDN out 1.35, attention in/out + head ~2.

- **Gate|up on MMA** (`TANG_CODER_MOE_MMA=all`): no faster than streaming (10.2–11 vs 10.7 ms).
- **Narrow streaming experts** (`TANG_CODER_NSTREAM=1`, T = 2..8, bitwise, spec-test PASS):
  slower. T=8 oracle window 10.0 → 13.5 ms, forced-wrong windows 7.2 → 9.3 ms; T=1 unchanged
  (4.6 ms). One sequence gives ~1 token an expert, so grouping saves no bytes, and the
  streaming kernels stage activations per block with fewer warps than per-pair `_d4`.

### Batch windows: plan prefix, router, expert MMA retries (2026-11-04, H200, new pod)

| commit | change | B=16 | B=32 | B=64 ms | B=64 tok/s |
|---|---|---|---|---|---|
| 5bbaee5c | parallel prefix in `cx_moe_plan_w` (route+plan 1.6 → 0.8 ms) | 17.41 | 24.74 | 38.78 | 1650 |

Tolerance PASS (99.50%, mean |Δlogit| 0.122). Eager B=64, ms a step: gate|up 10.6, down 5.6,
GDN conv+step 4.35, GDN in 4.06, router 1.64, GDN out 1.35, route+plan 0.79, head 0.76.

- **Expert MMA with precomputed code sums + a superblock's scales unpacked once** (68896d53):
  slower, down 5.8 → 7.5 ms, gate|up unchanged. Reverted.
- **Two 16-row tiles a warp in the expert MMA** (B fragment and scales shared): gate|up 10.9 →
  12.5 ms. Dropped.
- **Router with the activations in shared memory** (`cx_router_b`, `TANG_CODER_ROUTERB=1`):
  1.64 → 1.89 ms. Off.
- Gate|up stays ~0.22 ms a layer on all three kernels (per-pair-dot streaming, MMA, MMA with
  two tiles): ~2 TB/s for ~400 distinct experts × 1.18 MB. Down is ~1.9 TB/s on MMA.

### Persistent weight-major experts (2026-11-04, H200 h8zep5lcaascxj, explain)

`cx_moe_gu_p` / `cx_moe_down_p` (`TANG_CODER_MOE_PERSIST=gu|down|all`): a grid of SMs × k
blocks, each pulling the next (group, row slice) off an atomic counter (two slots at the end
of the plan region; the last block out zeroes them, so graphs replay) and streaming the slice
through `moe_stream_body` (same dots, bitwise). Shape: `TANG_CODER_PSST` ring stages,
`TANG_CODER_PCTA` blocks an SM, `TANG_CODER_PSPLIT` slices an expert. `TANG_BATCH_QUICK=1`,
B=64, 64-token prompts, graph replay (the quick path prints no profile):

| kernel | shape | B=64 ms a step | gate|up ms a layer (Δ from 0.22) |
|---|---|---|---|
| `cx_moe_gu_s` (default) | SST 1, 8 rows a warp | 30.32 | ~0.22 (~2 TB/s) |
| `cx_moe_gu_p` | PSST 3, 2 a SM, whole expert | 61.07 | ~0.86 (~0.5 TB/s) |
| `cx_moe_gu_p` | PSST 2, 3 a SM, whole expert | 63.54 | ~0.91 |
| `cx_moe_gu_p` | PSST 2, 3 a SM, 1/4 expert | 35.97 | ~0.34 |
| `cx_moe_gu_p` | PSST 1, 6 a SM, 1/4 expert | 34.92 | ~0.32 |
| `cx_moe_gu_p` | PSST 1, 6 a SM, 1/8 expert | 33.73 | ~0.29 (~1.6 TB/s) |
| `cx_moe_gu_p` | PSST 1, 6 a SM, 1/16 expert | 30.61 | ~0.23 |
| `cx_moe_gu_p` | PSST 2, 4 a SM, 1/16 expert | 31.29 | ~0.24 |

Whole experts per block are 4× slower: 16 warps an SM (vs ~48 for the streaming grid) and
~1.4 waves of 375 items over 264 blocks, each item a serial 64-step walk per warp.
Time falls monotonically as slices shrink and converges on `cx_moe_gu_s` at 1/16 (8 rows a
warp, the streaming grid's own shape) without passing it. Tolerance at 1/8 (B=64, full check):
99.37% agreement, mean |Δlogit| 0.122, the streaming kernel's numbers (same dots). So the
~2 TB/s ceiling is not the grid fragmenting an expert's rows over 8-16 blocks: giving one
block the whole expert's contiguous 1.2 MB is strictly worse, because a block's 8 warps walk
their rows serially (load latency + dp4a per 2-row step) and only many resident warps hide
that. The limit is per-warp latency × resident warps, not the memory-side layout. Off by
default; kept behind the switch.

### ILP sweep on `cx_moe_gu_s` (2026-11-04, H200 h8zep5lcaascxj, explain)

More independent loads in flight a warp: ring depth D (`TANG_CODER_SST`) and rows staged a
step (`TANG_CODER_SRP`, new: 2 or 4, dots still two rows at a time with `cx_dotq_m`, bitwise).
B=64 quick, ms a step (gate|up ms a layer ≈ 0.22 + Δ/48). Resident warps an SM estimated from
dynamic smem (8 warps a block; Q5_K rows, 18 KB activations):

| SRP | D | rows a warp | ms a step | ≈ gate\|up ms a layer | warps an SM |
|---|---|---|---|---|---|
| 2 | 1 | 8 | **30.32** | 0.22 | ~40 |
| 2 | 2 | 8 | 31.19 | 0.24 | ~24 |
| 2 | 4 | 8 | 33.73 | 0.29 | ~16 |
| 2 | 1 | 16 | 32.49 | 0.27 | ~40 |
| 2 | 2 | 16 | 33.03 | 0.28 | ~24 |
| 2 | 4 | 16 | 35.38 | 0.33 | ~16 |
| 2 | 8 | 16 | launch fails (smem) | | |
| 4 | 1 | 8 | 31.65 | 0.25 | ~24 |
| 4 | 2 | 8 | 33.75 | 0.29 | ~16 |
| 4 | 2 | 16 | 35.48 | 0.33 | ~16 |

Every extra outstanding step costs resident warps one-for-one (the ring lives in smem), and
the trade is never positive: bytes in flight an SM stay about constant while the per-step
fixed cost grows. Stopping rule met (best variant 0% faster than 0.22 ms a layer): this layout
is at its floor of ~2 TB/s, set by the instruction work per byte (dp4a decode and scale math on
Q4_K/Q5_K super-blocks for ~1.75 tokens), not by load latency or grid shape. The remaining
lever is fewer instructions a byte (a different quant layout or tensor-core decode), a
decision for Cam. The T=8 narrow run was skipped: the best variant is the default shape, and
narrow streaming (`TANG_CODER_NSTREAM=1`) is already recorded as slower.

### TCX: experts repacked into tensor-core tiles (2026-11-04, H200 srznguhpkj2lqo, explain)

`TANG_CODER_TCX=1` (`flash::tcx`, `cx_moe_gu_t` / `cx_moe_down_t`): at load each Q4_K / Q5_K
expert matrix is also stored as 16-row × 256-column tiles whose 4-bit codes are the
m16n8k32 A fragments as they are (one shift and mask a register; Q5's fifth bits a separate
plane), with d / dmin f16 and the 6-bit sub-block scales and mins unpacked to bytes
(repack → dequant is bit-exact vs GGUF, unit-tested). A 32-column step is two MMAs: the
codes, and the mins replicated (gives m_j · Σx); the 6-bit scale is one IMAD a value, and the
activations are int8 with one scale a token a 256 (Q8_K-style, `cx_q8k` / `cx_silu_q8k`), so
float math happens once a superblock. 4 (gate|up) / 2 (down) warps split a tile's K. Runs in
every grouped window, narrow and batch. Repack: +156 s load (weights 116 → 272 s); both copies
held for now (49.6 → 97.3 GB).

| B | default ms | TCX ms | Δ |
|---|---|---|---|
| 1 | 4.07 | 4.40 | +8% |
| 8 | 9.97 | 11.30 | +13% |
| 16 | 17.50 | 14.55 | −17% |
| 32 | 24.81 | 21.30 | −14% |
| 64 | 38.94 | 35.67 | −8% |

Tolerance at B=64 (alone vs batch, both TCX): 99.17% agreement, mean |Δlogit| 0.144 (default
99.50% / 0.122). flash-aa explain no drafts: 245.5 → 226.8 tok/s.

Iteration 2 (3e0d5405+): the per-block activation staging was the cost, not the math.
`TANG_BATCH_QUICK=1 TANG_CODER_PROF=1`, B=64, ms a step (gate|up / down; default 10.6 / 5.65):

| change | gate\|up | down | quick ms |
|---|---|---|---|
| staged activations, K split 4 / 2 | 10.1 | 5.25 | 34.96 |
| staged, split 8 / 2 | 15.1 | 5.26 | 39.97 |
| staged, split 2 / 1 | 7.0 | 4.92 | 31.49 |
| activations from global in B order (no staging, no barrier), split 2 / 1 | **6.2** | **4.96** | 30.72 |
| same, split 1 / 1 | 8.6 | 4.93 | 33.11 |
| same, split 4 / 2 | 8.6 | 5.4 | 33.66 |
| same, per-32 activations (`TANG_CODER_TCX32=1`, float math a step) | 6.7 | 5.7 | — |

Gate|up at 6.2 ms ≈ 0.13 ms a layer ≈ 3.7 TB/s of distinct expert bytes; down ~2.9 TB/s.
The default kernels at the same instruction count per byte as before sat at ~2 TB/s and so
did TCX while it staged activations: the per-block prologue (stage, barrier) was the limit.

Full `flash-batch-check` N=64 (explain, graphs), ms a step:

| B | default | TCX (Q8_K acts) | TCX32 (per-32 acts) |
|---|---|---|---|
| 1–8 | 4.07 / 4.79 / 6.57 / 9.97 | same (narrow stays per-pair) | same |
| 16 | 17.46 | 16.43 | 16.33 |
| 32 | 24.78 | 21.98 | 22.31 |
| 64 | 38.91 | **32.30** (1982 tok/s) | **33.87** (1890 tok/s) |
| tolerance | 99.50% / 0.122 | **98.96% / 0.134: FAIL** | 99.29% / 0.121 PASS |

Per-256 activations cost ~0.5% agreement: under the 99% bar. TCX32 passes at the noise floor.
Narrow windows on TCX (`TANG_CODER_TCX_NARROW=1`) lose: flash-aa explain no drafts 233.9 →
203.7 tok/s (split 2/1), mtp windows 6.66 → 8.1 ms (2.13 → 2.23 tok/window at 319.8 → 273.9
tok/s). One token an expert has too few warps a tile, and the per-pair `_d4` path wins there.
Repack: +156 s serial, threaded now; both copies held (97 GB).

### TCX tiles as the only expert copy; TCX32 the batch default (2026-11-04, H200 srznguhpkj2lqo)

Routed + shared Q4_K / Q5_K experts are now uploaded only as TCX tiles (`TANG_CODER_TCX=0`
for the GGUF rows). Tile v3: codes `[q][row][32 B]` = each row's GGUF `qs` slices as they
are, Q5 `qh` per row as is, scales unpacked. Every reader takes them: narrow per-pair dots
(`cx_dotq_tile`, cx_dotq_fast / _half's lane loads and arithmetic on the tile: bitwise), wide
GEMMs (`sbk_load_t`: the same SbK, scale bytes re-packed: bitwise), batch windows
(`cx_moe_*_t32`, per-32 activations). Layer 46's Q8_0 shared expert unchanged.

VRAM after load: 50.8 GB (52.6 with the MTP head), was 97.3 with both copies and 49.6 GGUF only.
Gates: flash-aa outputs (explain / refactor / write × none / suffix / mtp, 512 tokens) identical
to TCX=0; flash-tcheck t1 = t8 = t8-verify bitwise; flash-spec-test PASS (step-3200 head);
batch-check N=8 bitwise; wide-check KL 8.61e-5 (3000) / 4.43e-6 (8000), afa748e7's values;
batch-check N=64 tolerance 99.29% / 0.121 PASS.

| B | TCX=0 ms | tiles ms | Δ |
|---|---|---|---|
| 1 | 4.07 | 4.27 | +4.9% |
| 2 | 4.79 | 5.08 | +6% |
| 4 | 6.57 | 7.00 | +6.5% |
| 8 | 9.97 | 10.53 | +5.6% |
| 16 | 17.46 | 16.56 | −5% |
| 32 | 24.78 | 22.61 | −9% |
| 64 | 38.91 | 34.17 | −12% (1873 tok/s) |

flash-aa (--bw 4800, step-3200 head), TCX=0 → tiles: none 233.9 → 222.7; mtp explain 319.8 →
304.4, refactor 401.8 → 382.0, write 351.7 → 334.7. The narrow per-pair dots lose ~5% on the
tile layout (a lane's qs / scales / qh for a row are in three regions of the tile instead of
one 144 / 176-byte block). Tile v2 (codes in MMA-lane order) was worse: none 219.3.

### GGUF-native batch experts (`cx_moe_*_q`), GGUF rows the only copy again (2026-11-05, H200 srznguhpkj2lqo)

Tiles reverted to opt-in (`TANG_CODER_TCX_TILES=1`). Batch windows take `cx_moe_gu_q` /
`cx_moe_down_q` (default; `TANG_CODER_TCX=0` for the previous streaming / `_m` kernels): the
TCX32 kernel on GGUF Q4_K / Q5_K rows. A lane loads 8 contiguous qs bytes a 32-byte chunk
(and 8 qh bytes), so the m16n8k32 k order inside a step is a permutation of the columns; the B
fragment (x at 8 tig, one uint2 from global, no staging) takes the same one. Scales and mins
unpacked once a superblock with bit ops on the three scale words; mins as a second MMA; per-32
activation scales. K split 2 / 1.

- The ~5% narrow loss blamed on the tile layout was the tile branch inside `cx_dot` and the
  narrow bodies (code size / registers in `_d4`), not the layout: with the branch compiled out
  (only under TANG_CODER_TCX_TILES) narrow is back to 4.07 ms at B=1.
- First version with sbk_load's 4-byte qs words: gate|up 8.5 / down 6.0 ms a step (quick +
  profile), B=64 37.45 ms. With 8-byte lane loads: 7.2 / 5.7, B=64 35.34.

Gates: flash-aa outputs identical to TCX=0 (9 runs), tok/s none 234.6 / 234.8 / 234.7, mtp
320.1 / 402.0 / 351.9 (explain / refactor / write); tcheck bitwise; spec-test PASS;
batch-check N=8 bitwise; wide-check KL 8.61e-5 / 4.43e-6; N=64 tolerance 99.29% / 0.121.
VRAM 49.6 GB (51.4 with the MTP head).

| B | TCX=0 ms | `_q` ms | Δ |
|---|---|---|---|
| 1 | 4.28* | 4.07 | |
| 8 | 10.46* | 9.98 | |
| 16 | 17.57 | 16.95 | −3.5% |
| 32 | 24.85 | 23.41 | −5.8% |
| 64 | 39.00 | **35.34** (1811 tok/s) | −9.4% |

(*TCX=0 on the build that still had the tile branch compiled in; B ≤ 8 is the same code either way.)

### Dead ends (Coder-Next)

- **22 → 12 launches a layer with no faster kernels:** +2% (156 → 159 on H100). The step is
  kernel-latency-bound, not launch-bound.
- **Expert GEMVs, 4 rows a warp** (all staged before decoding): −4% vs 2.
- **K-split GEMV with 8 warps a row** instead of 4: −7%. Both together: −10%.
- **SiLU + int8 of h fused into the down kernel:** −2% vs a separate launch (each down block
  recomputes its pair's 512 values; the extra latency outweighs the saved launch).
- **The eager event profiler** (`TANG_CODER_PROF`) put about 2× the graph's time on small
  kernels. Use the stage sweep for decisions.
- **Top-k in the router GEMV's last block** (atomic counter, one launch fewer): −2% (217 → 213).
  The last block's serial top-k costs more than the launch it saves.
- **K-split routed experts** (Q warps a row, unstaged, like `cx_gemvk`): gate|up −4% / −6% /
  −16% at Q = 1 / 2 / 4, down +0.5% / −6% / −18%. Experts want the staged rows; the dense
  matrices want the split.
- **K-split GEMV, 1 warp a row** (no split): −1.5% vs 4, −6% vs 2.
- **A Qwen3 drafter** (estimate, not built): teacher-forced top-1 agreement with the engine's
  greedy output is 58 / 88 / 71% for Qwen3-0.6B and 62 / 90 / 77% for 1.7B
  (explain / refactor / write). A verify window of 8 costs ~3× a T=1 step here (each token
  routes to its own experts), so a drafter only pays on refactor-like text, which the free
  suffix drafter already covers (2.7 tokens a window). Expected gain on fresh text ≤10%, for a
  second model engine. Not worth building yet.
- **First rows of a `flash-aa` run** read ~4% low (205 vs 213–217 for the same kernels later in
  the run). Compare variants inside the A/B block, which warms up first.
- **bf16 router weights** (`TANG_CODER_ROUTER16=1`): +1% (240.8 → 243.1), under the bar. The
  router is 4.2 MB a layer of F32 but reads at ~1.1 TB/s either way. Kept opt-in.
- **Top-k in the expert gate|up kernel's prologue** (every block of a token reruns it; no
  `route` launch): −9% (242 → 220, eed9069). The top-k latency now sits in front of every
  expert block.
- **Norm kernels at 512 / 256 threads** instead of 1024: −4% / −11%.
- **Attention split-K chunks of 32 / 16 positions** (from 64): 0% / −3%. At 16 the merge
  costs more (218 µs) than the split saves (153 vs 224 µs).
- **The shared expert on a parallel graph branch** (forked before the router, joined before
  the combine, so it overlaps the router and the one-warp top-k): −2% (241.5 → 236.9). The
  fork/join costs more than the overlap gives.
- **Q8X GEMV with both 512-wide steps' loads issued first:** 0% (241.5 vs 242). Left in (harmless).
- **Running `flash-ref` while benchmarking:** flash-ref uses the GPU too, and halved every
  kernel's speed for the length of the overlap. Run references before or after, never during.
- **nsys / ncu on the RunPod image:** ncu's injection lacks `cuTensorMapEncodeIm2colWide`,
  which cudarc resolves at load, and nsys isn't installed (apt fails).

### 2026-11-03: verify-window experts at T=8, grouped vs per-pair (negative result)

Stage sweep (`TANG_CODER_STAGES=1 TANG_CODER_STAGES_T=1,8`, explain, ctx 1,299), H100 SXM
(3.35 TB/s), all variants the same box and build. GB/s is the sweep's own byte count.

| variant | T=1 window | T=8 window | T=8 moe_gu | T=8 moe_down |
|---|---|---|---|---|
| per-pair `_d4` / `_d4f` (default) | 4,405 µs | 9,884 µs | 2,105 µs, 321 GB/s (10%) | 2,672 µs, 150 GB/s (4%) |
| `TANG_CODER_FUSE_SILU=0` (`silu_q` + `_d4`) | **4,355** | **9,604** | 2,101 | **2,237, 179 GB/s** (+102 µs silu_q) |
| leader-grouped `_x2` (WGROUP=2) | 4,415 | 12,048 | 3,290, 205 GB/s | 3,205, 125 GB/s |
| leader-grouped `_x4` (WGROUP=4) | 4,413 | 11,623 | 2,677, 252 GB/s | 2,815, 142 GB/s |
| in-block-scan `_w` / `_wf` (WGROUP=1, H200, iteration 1) | 4,079 | 14,450 (main 9,409) | 2,805 | 6,702, 60 GB/s |

What this says about why grouping lost:
- **The per-pair path is latency-bound, not byte-bound.** At T=8 the 88 pairs × 2048 rows read
  about 2× the distinct bytes (mean 43 of 80 routed experts distinct a layer) and still sit at
  4–10% of peak. Halving the bytes can't help while each block has a few KB in flight.
- **Iteration 1 (`_w`/`_wf`) put serial work in front of the loads.** Every block rebuilt the
  group: an O(n²) smem duplicate scan over 80 ids plus 5 `__syncthreads`. The down kernel then
  quantized h for all M members before issuing a single weight load, and group 0 (shared expert,
  8 tokens) did 8× the work. down fell to 60 GB/s.
- **Iteration 2 (`_x`) took out the scan and prologue and it still lost.** Here a warp finds
  its group with 3 ballots: per-pair grids, non-leaders exit, shared expert in groups of 4. Each
  warp loads its rows into registers once and loops over the members, reading h from `silu_q`.
  Bitwise per pair. The loss comes from how the work spreads: about half the blocks exit, so the
  surviving ~45 groups × 64–128 blocks carry the same per-block bytes as before but each runs M
  members serially from registers. There are fewer bytes in flight per SM and a longer critical
  path per block. R=4 (more rows of loads a warp) beats R=2, so it is bytes in flight that
  matter. A grid y of T·(K+1) with half the blocks dead is the wrong shape.
- **The fused SiLU prologue in `_d4f` costs at T=8** (and on H100 at T=1 too): 64 blocks a pair
  each redo the pair's 512 SiLU + int8 then hit a `__syncthreads` before any weight load.
  Separate `silu_q` + `_d4` saves 435 µs of down for 102 µs of silu_q (−2.8% window at T=8,
  −1.1% at T=1). This contradicts the H200 dead-end entry above; re-check on H200 before
  flipping the default.
- No crossover: the leader kernels match per-pair at T=1 (they aren't used there) and lose at T=8.

For the weight-major streaming rewrite (B=1..64): keep loads independent of any prologue
(precomputed activations, plan built once in `cx_route` or a tiny kernel, never per block). Size
the grid by distinct-expert row tiles × enough splits to keep ≥8 blocks/SM resident, not by
pairs. Software-pipeline the weight loads (cp.async or register double-buffer) so a warp keeps
loads in flight while it decodes the previous tile. Split the shared expert and any hot expert
by rows so no block carries 8× the members. nsys works on the RunPod image
(`/opt/nvidia/nsight-compute/2025.1.1/host/target-linux-x64/nsys`) but gives no stall reasons, and
ncu still can't inject. Occupancy and stall data were not measured here.

### Wide prefill: k32 expert/dense GEMM tile, warp-per-column GDN, f32 router GEMM (2026-11-04, H200)

`flash-wide-check --ctx 3000` (refactor ids, `TANG_CODER_WIDE=2048`, the serve width), GPU time
of the two wide prefills by stage (`TANG_CODER_PROF=1`; the narrow prefill is now excluded):

| stage | before ms | after ms |
|---|---|---|
| moe_gu (`cx_moe_gemm_gu`) | 1107 | 568 |
| GDN recurrence | 441 (`fl_gdn_conv_step_seg`, 32 blocks) | 190 (`fl_gdn_wide` + norm) |
| moe_down | 427 | 227 |
| gdn_in (`cx_gemm_dense` + GEMV fallback) | 408 | 243 |
| router (F32: 256 eight-row GEMVs a layer) | 393 | 89 (`cx_sgemm_wide`) |
| gdn_out / attn_in / attn_out | 137 / 92 / 46 | 91 / 59 / 30 |
| wide prefill, 3000 tokens | 1.63 s, **1,844 tok/s** | 0.80 s, **3,741 tok/s** |

1000 / 8000 tokens: 3,428 / 3,980 tok/s. Narrow prefill (`prefill_slot`, what `flash-aa` and
`--batch`-less paths use) is unchanged at ~810 tok/s.

- `gemm_tile32` (every k32-scaled type: Q4_K/Q5_K/Q8_0/Q8X/Q4_0/Q5_0/IQ4): one m16n8k32 MMA a
  32 columns, scales and mins once a 32 instead of per 16, the tokens' scales and per-32 code
  sums staged in shared memory (no shuffles in the loop), and the 32 columns permuted so each
  8-weight decode is used whole (half the decodes). Q3_K/Q6_K keep the k16 tile.
- `fl_gdn_wide`: 8 lanes per state column (columns are independent given k, q, g, b), 3-step
  shuffle reductions, no block barrier a token; gated norm in `fl_gdn_wide_norm`.
  `TANG_CODER_GDNW=0` for the old kernel.
- Router: F32 GEMM (`TANG_CODER_SGEMM=0` off); other non-GEMM matrices take the batched K-split
  GEMV (32 rows a launch) instead of 8-row GEMVs.

Serve, `/workspace/load.py 64 <port> 3` after `serve --batch 64 --ctx 32768`, same H200, HEAD
4133d39a vs this: aggregate **302 → 421 tok/s**, TTFT p50 25.6 → 16.5 s, p95 108 → 69 s, wall
406 → 292 s, 192/192 ok. Gates: `flash-wide-check` 3000/8000 PASS (KL 9e-7 / 3e-6); 1000 fails
the 1e-3 bar on both (base 1.15e-2, this 7.9e-3: pre-existing, FA2 at short context);
`flash-tcheck` t1 vs t8 bitwise; `flash-spec-test` PASS.

### Single-stream prefill takes the wide windows (2026-11-04, H200)

`Coder::prefill` (flash-aa, single-request serve) used only the narrow path (~850 tok/s) even
when wide windows existed. It now takes `prefill_wide` on slot 0 for prompts of at least
`TANG_CODER_WIDE_MIN` (128) tokens when wide windows are built, no MTP head is loaded and no
per-window logits are wanted. `flash-aa` builds 2048-row windows (`TANG_CODER_AUTO_WIDE`, 0 off;
+~50 s load); `serve` without `--batch` builds them too (`TANG_SERVE_WIDE`). Check tools keep
narrow references (auto-wide off by default in `load_coder`).

flash-aa explain (1235 tokens): prefill **1.49 → 0.35 s** (830 → 3,530 tok/s); decode unchanged.
Crossover (flash-wide-check): 32 tok 785 vs 472, 64: 856 vs 671, 128: 851 vs 1,141, 256: 849 vs
1,770, 512: 842 vs 2,589 tok/s (narrow vs wide).

### Wide expert GEMM: Q4_K / Q5_K superblock operands loaded once (2026-11-04, H200)

`gemm_tile_sbk`: for the experts (gate/up Q4_K, down Q5_K in UD-Q4_K_XL) a lane loads a
superblock's d, dmin, scales and qs words once per 256 columns (`sbk_load`, as the batch MMA
kernels), next superblock's loads in flight, instead of 4–5 scattered loads per 8 weights.
Two 3k wide prefills: moe_gu 568 → 411 ms, moe_down 227 → 198 ms. wide-check 3000: 3,741 →
**4,276 tok/s**; 8000: 3,980 → 4,414. Serve C=64 x3: 421 → **447 tok/s** aggregate, TTFT p50
16.5 → 15.2 s, p95 69 → 61 s, wall 292 → 275 s. Gates: wide-check 3000/8000 KL 9e-7 / 3e-6,
spec-test PASS, tcheck t1/t8 bitwise, batch-check N=8 bitwise.

Tried and reverted: software-pipelining the generic k32 tile (decode the next 32 columns before
this step's MMAs): dense GEMMs got slower (gdn_in 242 → 406 ms), likely registers.
`__launch_bounds__(256, 3)` on the expert GEMMs: slightly slower.
- Q8X dense tile with a lane's 128 columns of codes + scales loaded as one batch: gdn_in 242 →
  231 ms, wide 4,276 → 4,285 tok/s (noise level); not kept. Weight-load latency isn't what holds
  the dense GEMMs at ~45 TOPS; next suspects are the token-operand loads (8 bytes a lane a chunk
  from global, 8 rows) and 2 blocks an SM. Needs a profiler (ncu doesn't run on these pods).

### 16-bit GDN state (`TANG_CODER_GDN_STATE`, 2026-11-04, H200 ru6a6zybgtu80q, explain)

The recurrent state is stored as bf16 or f16, rounded every token in registers, so windows stay
bitwise. Quick ms/step f32 → bf16: B=8 9.06 → 8.94, B=32 19.15 → 18.78, B=64 30.24 → 29.63
(f16 29.43). GDN conv+step per step (eager prof): B=32 2.19 → 1.89, B=64 4.29 → 3.68. No change
single-stream (T=1 window 7.47 → 7.53 ms). The f32 step wasn't at the state-bandwidth floor
(≈2 ms of its 4.29 at B=64), so halving the bytes saves 0.6 ms, not the predicted 2.1.
Quality and gates are in `qwen3next-batching.md` ("bf16 GDN state"). Default stays f32: any
non-bitwise state lands at a ~2–3e-3 KL floor (RBITS=2 does too), f16 matches that floor, and
bf16 is 1.5× it.

### FA2 wide attention on fp16 tensor cores (2026-11-04)

`cx_attn_fa2` runs Q, P and its K/V tiles (converted in shared memory once a tile) as fp16
instead of bf16: attention outputs 8x closer to split-K (rel L2 0.9-3.2e-3 → 1.1-4.2e-4).
flash-wide-check warm tok/s, bf16 → fp16, H200: 1000 4,005 → 3,997, 3000 4,284 → 4,265, 8000
4,436 → 4,390 (−1%); H100: 1000 3,989 → 4,046, 3000 4,318 → 4,313, 8000 4,463 → 4,417.
Short-context KL unchanged (see qwen3next-batching.md Known issues: a 1e-7 jitter fails it too).

### Wide prefill under ncu: what held the GEMMs and GDN (2026-11-04, RTX 3090 on mew)

First profiler data for the wide path. ncu can't inject on the RunPod images. On mew it runs as
root (`RmProfilingAdminOnly=1`) against a build with cudarc `cuda-12060`, because ncu
2025.1.1's injection library lacks `cuTensorMapEncodeIm2colWide`. Other jobs held 20 GB of the
3090, so `TANG_CODER_MAX_LAYERS=1` (new debug knob) loads one layer of
Qwen3-Coder-Next UD-Q4_K_XL. `flash-wide-check --ctx 2048`, `TANG_CODER_WIDE=2048`. Reports
are in `artifacts/` (`prof_base` = afa748e7, `psd` = after).

| kernel (afa748e7) | time | occ. | regs | issue | tensor | L1 / L2 hit | top stalls (cycles/issue) | smem conflicts |
|---|---|---|---|---|---|---|---|---|
| cx_gemm_dense gdn_in (97×32) | 5.43 ms | 34% | 128 (2 blk/SM) | 18% | 8.5% | 76 / 54% | long_sb 18.0, wait 1.6 | 0 |
| cx_gemm_dense gdn_out (16×32) | 1.75 ms | 33% | 128 | 21% | 10.4% | 76 / 90% | long_sb 14.1, wait 1.6 | 0 |
| cx_moe_gemm_gu (8×513×32) | 6.63 ms | 32% | 128 | 25% | 6.8% | 84 / 82% | long_sb 9.9, lg_throttle 1.5 | 0 |
| cx_moe_gemm_down (16×513×32) | 3.00 ms | 32% | 128 | 29% | 7.7% | 78 / 59% | long_sb 8.1, wait 1.6 | 642k st |
| fl_gdn_wide (32×2, 512 thr) | 3.03 ms | 33% (66% theor.) | 64 | 45% | – | 82 / 77% | mio 2.0, short_sb 1.8, long_sb 1.2 | 0 |

Root causes, from the SASS-level samples:
- GEMMs: IMMA waiting on its B operand. Every warp loads its own copy of the tokens straight
  from global (generic `LD`, 8 B a lane a chunk) and uses it at once.
- Expert GEMMs: the grid's z gave 32 tiles an expert, about 96% of the 131k blocks empty. Each
  of them copied the four `ExW` param structs to local memory (`const ExW& m = ...`) before it
  exited.
- My first staged Q4_K tile indexed `SbK.q[j]` with a runtime superblock half, which sent the
  operands through local memory (37M LDL). Fixed by templating the half.
- fl_gdn_wide: the per-chunk conv + SiLU + l2 norm staging (global-latency FFMAs, index math)
  ran serially in only 64 blocks. The recurrence's smem reads were 4× redundant, with four
  columns a warp reading the same k / q.

Fixes (all GEMM outputs bitwise equal to afa748e7; the GDN summation order changed, so the KL
vs narrow went from 2.3e-6 to 2e-13 at 3000):
- Token tiles staged in shared memory: 128-column slabs, cp.async double buffer, row strides
  160 / 144 B (conflict-free). Tokens' scale and code sum interleaved into one 16-byte read.
  Dense, gate|up and down GEMMs.
- Wide modules group an expert's pairs by 64 (`CX_GCHUNK`), so the grid is (rows, groups, 1).
  Batch modules also launch z = 1 (their groups are ≤ 8). ExW read field by field.
- Q4_K/Q5_K expert tiles called directly. Through `gemm_tile_any`'s switch the compiler emits a
  CALL.
- `fl_gdn_wide_prep`: conv, SiLU, norms, g and b for every token in parallel, written into the
  free `egu` buffer. The recurrence streams them, holds two state columns a lane, and reads k / q
  as float4.

| kernel (ncu, 3090, 1 layer, 2048 rows) | before | after |
|---|---|---|
| moe_gu | 6.63 ms | 2.74 ms (tensor 16%, issue 46%) |
| moe_down | 3.00 | 1.48 |
| gdn_in (dense) | 5.43 | 2.99 |
| gdn_out (dense) | 1.75 | 0.83 |
| gdn recurrence | 3.03 | 1.43 + 0.26 prep |

Per-stage GPU time with `TANG_CODER_PROF`, two 3000-token wide prefills on one layer
(per-layer stages only): 57.6 → 31.9 ms (1.8×).

What's left: the dense Q8X tile is now MIO-bound. Each MMA needs about 3 smem wavefronts
(B 2, scales 1), close to the MMA's own rate. The next step is 32 rows a warp so each B
fragment feeds two MMAs.

Tried and reverted: GDN at one column a lane with 32 columns a block (128 blocks): 3.9 ms.
Four columns a lane: 1.86 ms. Token staging with the runtime-half bug: slower.

H200 results, pod o7lpawaxjvnm9b. afa748e7 and this branch were run back to back with the same
settings: `flash-wide-check --ids-file refactor.ids -n 32`, `TANG_CODER_WIDE=2048`. Logs are in
`artifacts/h200/`.

| | afa748e7 | this branch |
|---|---|---|
| wide prefill, 1000 tokens | 3,967 tok/s | **5,829 tok/s** |
| wide prefill, 3000 tokens | 4,263 tok/s | **6,679 tok/s** |
| wide prefill, 8000 tokens | 4,391 tok/s | **7,172 tok/s** |
| 3000: moe_gu / moe_down | 410 / 197 ms | 201 / 114 ms |
| 3000: gdn_in / gdn_out | 240 / 92 ms | 144 / 53 ms |
| 3000: GDN recurrence | 181 ms | 132 + 11 ms prep |
| 3000: attn_in / attn_out | 57 / 30 ms | 26 / 18 ms |
| 3000: router (unchanged) | 87 ms | 87 ms |
| serve C=64 ×3, aggregate | 443 tok/s | **543 tok/s** |
| serve C=64: TTFT p50 / p95 | 15.5 / 63.3 s | 7.2 / 42.0 s |
| serve C=64: wall | 277 s | 226 s |

Gates:
- **tcheck:** t1 / t8 / t8-verify bitwise on both.
- **spec-test:** PASS on both.
- **batch-check:** N=8 PASS bitwise and N=64 PASS within tolerance. The logits checksums are
  identical to afa748e7, so the batch path is unchanged.
- **wide-check KL vs narrow, -n 32:**

| | afa748e7 | this branch |
|---|---|---|
| 3000 | 8.6e-5 | 1.1e-4 |
| 8000 | 4.4e-6 | 1.1e-5 |
| 1000 | 3.1e-2 | 8.7e-2 |

  At 3000 and 8000 the greedy output is equal on both builds. Both builds miss the 1e-5 bar at
  3000 with these settings. 1000 fails on both (the known FA2 short-context issue). The GEMMs
  are bitwise, so the KL change comes from the GDN summation order.

`TANG_CODER_DENSE32=1` (Q8X at 32 rows a warp) is slower on the H200 too: gdn_in 144 → 191 ms,
3000 tokens 6,675 → 6,392 tok/s, KL 5.5e-4. It stays off by default.

### Wide prefill: router SGEMM re-tiled, wide GDN bitwise to afa748e7 again (2026-11-04, H200)

Follow-up on the same branch. Runs used `flash-wide-check --ids-file refactor.ids -n 32` with
`TANG_CODER_WIDE=2048` on pod o7lpawaxjvnm9b, shared with the serving agent under
`/workspace/gpu.lock`. Logs are in `artifacts/h200/r3`.

- **Router:** `cx_sgemm_wide2` replaces `cx_sgemm_wide`. It uses 64-row tiles, float4 k slabs
  prefetched in registers, conflict-free float4 smem reads, and finds each row's segment once a
  block. Every output is the same `fmaf` chain over k ascending, so the result is bitwise equal
  and top-10 expert selection is unchanged (no tf32 or bf16 needed). Router time, two 3k
  prefills:

| tile | router ms |
|---|---|
| old `cx_sgemm_wide` | 87.3 |
| 64 x 128 (`TANG_CODER_SGEMM2=1`) | 40.7 |
| 64 x 64, block 128 (default) | 34.2 |

  The 25 ms target isn't met. The rest would take tf32 or bf16 tensor cores, which would change
  routing.
- **GDN KL:** q and k are now staged permuted, so each lane's float4 reads give afa748e7's rows
  (`sub + 8 i`) in order. The wide GDN is bitwise equal to afa748e7 again. KL vs narrow is back
  to 8.61e-5 at 3000 and 4.43e-6 at 8000, and gdn_wide is not slower: 132 → 120 ms.

| | afa748e7 | branch |
|---|---|---|
| wide prefill, 1000 tokens | 3,967 tok/s | 6,424 tok/s |
| wide prefill, 3000 tokens | 4,263 tok/s | 7,143 tok/s (7,223 with the 64-token router tile) |
| wide prefill, 8000 tokens | 4,391 tok/s | 7,534 tok/s |
| serve C=64 ×3, aggregate | 443 tok/s | **583 tok/s** |
| serve C=64: TTFT p50 / p95 | 15.5 / 63.3 s | 2.9 / 37.2 s |
| serve C=64: wall | 277 s | 210 s |

The load test ran with the 128-token router tile, before the 64-token tile became the default.

Gates: tcheck t1 / t8 / t8-verify bitwise; batch-check N=8 bitwise, checksum unchanged
(2066e91aa9110ab5); wide-check 3000 and 8000 PASS. spec-test was not re-run here; it passed
earlier on this branch.

## 2026-11-05: serve3 — `--mtp` at no cost with spec off, and a shorter TTFT tail

Branch `frog/coder-serve3` from `frog/integrate-2026-11-03` @ 99f8c6f9. H200 8utiorjlxzui34,
`serve --batch 64 --ctx 32768 --mtp mtp.gguf` (step 3200), `TANG_SERVE_SPEC` default (off), port
8911. Mix = `load.py` (prompts 200–6000, out 256–1024, 10 % sampled), decode-heavy =
`load_dec.py` (prompts 200–800, out 512–1024). The scripts now also report TTFT p99 and ITL
(gaps between streamed chunks). 0 errors in every run.

**What `--mtp` cost.** serve2's MTP K/V fill ran over every wide-prefilled prompt as 8-row
MTP passes, each a full MTP layer (MoE, 152k-vocab head, pick) plus a sync: 256 passes per
2048-row window. With spec off nothing drafts from it. `TANG_SERVE_WIDE_MTP=0` on the base:
482 → 600 tok/s (no `--mtp`: 610).

**What set the TTFT tail.** The slow requests are all the cold burst's long prompts
(t0 ≈ 0). Their prefill isn't slow (~7k tok/s in wide windows of 25 ms + 0.12 ms a token), but
every request pinned its prompt's state to disk (`marks`: the second `<|im_start|>`, which for
a one-turn chat is the whole prompt), and that serialized ~100 MB per value-by-value and took a
second device copy of the positions on the serve thread: 70–180 ms per request, 31 % of the
burst's prefill time.

Changes:
- **MTP fill.** Passes nothing drafts from (no chain, no training dump) stop after the MTP
  mixer, which writes the K/V: no MoE, head or pick. The serve loop fills only when spec is on
  and a decode window has spare rows (`Coder::mtp_fill`, `TANG_SERVE_WIDE_MTP=0|1` pins it); a
  slot prefilled without it drafts from stale K/V there, verification keeps the output exact.
- **Scheduler.** Prefill gets `fill_share` (0.85) once a prompt has waited
  `TANG_SERVE_PREFILL_URGENT_S` (4 s), even with decode rows full (was `share`, 0.5, which is
  how a burst's last long prompts drained); a leftover chunk below a slice waits for the next
  step unless it finishes its prompt; the wide slice is 1024 (was 512; a wide window's fixed
  ~25 ms).
- **Disk pins.** The state file is serialized and written on the writer thread from the host
  copies the snapshot already made (its position segments cover the prompt), not a second
  device read. Round trip checked: a pinned system prompt read back after a restart, same
  greedy reply.

| | before (99f8c6f9, `--mtp`) | before, no `--mtp` | after (`--mtp`) |
|---|---|---|---|
| mix C=64: aggregate | 482 tok/s | 610 | **725** |
| mix C=64: TTFT p50 / p95 / p99 | 14.2 / 56.6 / 74.7 s | 3.3 / 36.7 / 50.0 s | **1.0 / 26.5 / 32.4 s** |
| mix C=64: ITL p50 / p95 / p99 | 38 / 360 / 494 ms | 41 / 308 / 419 ms | 42 / 250 / 323 ms |
| mix C=64: stream p50 | 9.7 tok/s | 11.0 | 12.9 |
| mix C=8: aggregate | 358 tok/s | 420 | **464** |
| mix C=8: TTFT p50 / p95 / p99 | 1.32 / 7.42 / 9.08 s | 0.93 / 5.21 / 6.35 s | 0.67 / 3.74 / 4.63 s |
| mix C=8: ITL p50 / p95 / p99 | 11.2 / 12.6 / 282 ms | 11.2 / 11.6 / 243 ms | 11.2 / 11.7 / 160 ms |
| decode-heavy C=64: aggregate | 1,056 tok/s | 1,153 | **1,287** |
| decode-heavy C=64: TTFT p50 / p95 / p99 | 1.59 / 17.1 / 19.6 s | 1.19 / 13.0 / 15.0 s | 0.76 / 7.2 / 8.0 s |
| decode-heavy C=64: ITL p50 / p95 / p99 | 36 / 226 / 324 ms | 36 / 178 / 274 ms | 36 / 50 / 252 ms |

Steps (mix C=64, `--mtp` unless noted): base 482 → fill gated 606 (p95 37.1 s) → + urgent share
630 (34.2 s) → + slice 1024 642 (33.0 s) → + disk pins off-thread 725 (26.5 s). Without `--mtp`,
slice 2048 alone gave 654 / 33.2 s but ITL p99 580 ms.

The burst floor is now prefill work: the first 64 prompts are ~172k tokens, ~25 s of wide
prefill at 85 % of the GPU, which is the p95. Lower takes faster prefill or packing several
prompts into one wide window.

Gates (this build): flash-tcheck bitwise (0 of 151936); batch-check N=8 bitwise, checksum
2066e91aa9110ab5; N=64 tolerance 99.36 %, mean 0.123; spec-batch-check 16 streams k=2 every
budget 16/16 identical (budget 16 990 tok/s, 1.21×); sample-check N=64 PASS; `cargo test -p
tang-llm` 208 passed.

## 2026-11-07: chunked GDN recurrence for wide prefill (`TANG_CODER_GDN=chunked`, H200)

`TANG_CODER_GDN=chunked` (off by default; f32 GDN state only) replaces `fl_gdn_wide` in wide
windows with tang-compile's chunked scan (`ChunkedScan::coder`, tang#179). It runs on 64-token
chunks:
- a glue kernel turns `fl_gdn_wide_prep`'s rows into head-major fp16 operands, each v head reading
  k head `h / 2`, with the window's tail padded by identity steps (α = 1, β = 0)
- a per-chunk WY/UT transform on fp16 tensor cores
- a sequential scan of the slot's f32 state over chunks (read at the start, written back at the end)
- a parallel readout into the same `Y` rows; `fl_gdn_wide_norm` is unchanged

`log α` is floored at −60, because steps where `α` underflows to 0 (full forgets) would make the
running sum −∞. Pod csjujaaoh9npv7 (secure H200 SXM, driver 595.91),
`Qwen3-Coder-Next-UD-Q4_K_XL.gguf`.

Recurrence alone (`scripts/gdn_hand_bench.cu`, synthetic rows, 32 v heads):

| window rows | `fl_gdn_wide` | chunked |
|---|---|---|
| 4096 | 2.49 ms | 0.62 ms |
| 16384 | 9.91 ms | 2.33 ms |
| 65536 | 39.69 ms | 9.14 ms |

Gates (`flash-wide-check --ids-file refactor.ids -n 32`, `TANG_CODER_WIDE=2048`,
`TANG_WIDE_CTXS=3000,8000`). Teacher-forced max KL vs narrow; greedy output equal in every run.

| KV | GDN | KL 3000 (bar 2.0e-4) | KL 8000 (bar 3.2e-5) | wide tok/s 3000 / 8000 |
|---|---|---|---|---|
| int8 | `fl_gdn_wide` | 1.33e-4 | 8.93e-6 | 7,156 / 7,332 |
| int8 | chunked | 1.67e-4 | 1.25e-5 | 7,783 / 8,204 |
| bf16 | `fl_gdn_wide` | 1.81e-4 | 2.88e-5 | 7,268 / 7,653 |
| bf16 | chunked | 1.28e-4 | 1.94e-5 | 7,899 / 8,474 |

- **batch-check N=8** (chunked, `TANG_BATCH_CTX=8192`): PASS bitwise, checksum
  5324c706f111df45.
- **Continuation:** on a fresh server, `/v1/prefill` of a 2,970-token first turn, then the
  6,020-token conversation (reused 2,970, the 3,050-token extension wide-prefilled from the cached
  state). Its 48-token greedy reply equals a cold chunked run (reused 0) and the `fl_gdn_wide` run.
- **TTFT** through `serve --batch 8 --ctx 65536`, `TANG_CODER_KV=int8`, a 44,172-token prompt
  (median of 3, prompt cache defeated):

| build | TTFT | prefill tok/s |
|---|---|---|
| main (fl_gdn_wide) | 8.33 s | 5,300 |
| `TANG_CODER_GDN=chunked` | 7.70 s | 5,740 |
| tang#176 `TANG_CODER_ATTN=derived` | 6.17 s | 7,160 |
| tang#176 + `TANG_CODER_GDN=chunked` | **5.54 s** | **7,980** |

The GDN saving is about 0.63 s at 45k: ~1.9 ms per 4096-row window × 36 layers × 11 windows.
The rest of the 45k TTFT is attention (tang#176) and MoE.
Note: wide prefill windows only run under `serve --batch N` (the batched scheduler calls
`prefill_slot_wide`). The single-stream server prefills 44k tokens at ~470 tok/s (94 s).
