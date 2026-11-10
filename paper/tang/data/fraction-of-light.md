# Fraction of light: measured kernels against a traffic floor (v0)

This document compares each kernel's measured time with the time its HBM traffic would take
at peak bandwidth (the *floor*): **light = floor / measured**. A light of 1.0 means the kernel
moves its bytes at peak; 0.2 means it runs five times slower than its traffic requires.

This is v0: the floor counts the bytes the kernel actually moved (ncu `dram__bytes_*`), or,
for whole decode steps, the analytic weight, state and KV bytes a step has to read. The
derived lower bound from the Prove session replaces both later.

## Harness (`scripts/ncu/`)

| script | what it does |
|---|---|
| `ncu_kernels.sh OUT.csv [ncu opts] -- cmd` | per launch: `dram__bytes_read.sum`, `dram__bytes_write.sum`, `gpu__time_duration.sum`, `sm__throughput` and `dram__throughput` (% of peak), grid and block. Warm cache, boost clocks (`--cache-control none --clock-control none`). |
| `table.py CSV --bw B` | per kernel: launches, µs each, MB each, floor, light, SM %, DRAM %, and a bound class (below); `--step-ms` adds the launch/idle gap |
| `nsys_kernels.sh` / `nsys_table.py` | for GPUs whose counters ncu can't read (RunPod containers return `ERR_NVGPUCTRPERM`): kernel durations and inter-kernel idle time from an nsys trace (CUDA graph nodes included), with bytes joined from an ncu run of the same workload on another GPU |
| `step_groups.py` | one decode step grouped into moe / dense / gdn / attn / small, each against its analytic floor |
| `step_floor.py MODEL.gguf N…` | the step's weight bytes from the GGUF: non-expert tensors once, plus the distinct experts touched, E·(1 − (1 − k/E)^N) per layer |
| `run_all.sh` / `run_nsys.sh` | the whole sweep (ncu or nsys) |
| `cudarc_stubs.c` | `LD_PRELOAD` stubs for driver/NVRTC symbols that cudarc resolves up front and some ncu injections lack |

Engine hooks added for profiling:
- `TANG_BATCH_ONLY=b` runs only that batch size in `flash-batch-check`.
- `TANG_PROFILE_STEPS=k` runs k steps inside `cuProfilerStart`/`Stop` (ncu `--profile-from-start off`, nsys `--capture-range=cudaProfilerApi`).
- `ONCE=1` in `coder_derived_moe` / `coder_derived_ops` launches three times, with no timing loops.
- Derived kernels are named after their graph node (`dop08_ex_gate_up`), not `main0`.

**ncu version matters.** cudarc 0.16 resolves every symbol when it loads. Nsight Compute
2025.1 lacks `cuTensorMapEncodeIm2colWide`, and 2026.4's NVRTC interception lacks
`nvrtcGetNVVM`. **2025.2.1 works** (installed on mew under `/opt/nvidia/nsight-compute/`).

**Bound classes**, per kernel's mean launch:

| class | condition | meaning |
|---|---|---|
| launch | under 5 µs | fixed launch, ramp and tail cost dominates |
| traffic | DRAM ≥ 50% of peak, or light ≥ 0.5 | limited by bytes moved |
| compute | SM ≥ 60% of peak | limited by arithmetic |
| latency | none of the above | fills neither DRAM nor the SMs: too few bytes in flight (too few CTAs, dependent loads, serial reductions) |

## Hardware runs

- **RTX 3090** (mew, `flock ~/tang-gpu.lock`): ncu counters, 936 GB/s. Tables in `docs/bench/ncu/3090/`.
- **H200 SXM** (RunPod secure, 4.8 TB/s): no counter access in the container, so the nsys path was used, with bytes from the 3090 ncu run for the same kernels and shapes. Tables in `docs/bench/ncu/h200/`; raw traces in `h200-raw/`. The pod ran about 50 minutes (roughly $4.4).

## The decode step (H200, Coder-Next UD-Q4_K_XL, context ~1380, CUDA graphs)

Group times come from one profiled step and are expressed as a share of that run's wall time per step.

| config | wall ms | moe light | dense light | gdn light | attn light | small (<5 µs) | idle between kernels | **step light** |
|---|---|---|---|---|---|---|---|---|
| hand N=1 | 4.04 | 0.14 (40%) | 0.37 (31%) | 0.13 | 0.02 | 15% | 1% | **0.18** |
| hand N=8 | 9.83 | 0.27 (55%) | 0.18 (26%) | 0.43 | 0.08 | 7% | 0% | **0.23** |
| hand N=48 | 29.67 | 0.36 (56%) | 0.08 (21%) | 0.46 | 0.13 | 4% | 0% | **0.28** |
| derived N=1 | 4.39 | 0.17 (30%) | 0.40 (26%) | 0.14 | 0.02 | 25% | 8% | **0.16** |
| derived N=8 | 10.91 | 0.25 (54%) | 0.18 (23%) | 0.48 | 0.08 | 9% | 4% | **0.20** |
| derived N=48 | 28.40 | 0.42 (51%) | 0.08 (21%) | 0.49 | 0.13 | 7% | 2% | **0.29** |

The analytic floors behind the light column:

| N | step floor | weights | GDN state | KV | distinct experts per layer |
|---|---|---|---|---|---|
| 1 | 3.46 GB, 0.72 ms | 3.28 GB | 0.15 GB | 0.03 GB | 10 |
| 8 | 10.7 GB, 2.23 ms | 9.21 GB | | | 75 |
| 48 | 39.9 GB, 8.32 ms | 31.1 GB | 7.2 GB | 1.6 GB | 313 |

Weights are 2.36 GB of non-expert tensors plus 1.909 MB per expert. GDN state is 36 layers × 2 MiB f32 per stream, read and written. Per-config tables are in `docs/bench/ncu/h200/step_*.md`.

**Inside a CUDA graph the step is not bound by launch gaps.** Idle time between kernels is 0–1% for the hand engine and 2–8% for derived (which runs more, smaller kernels). The ~0.5–1 ms of kernels under 5 µs at N=1 is real kernel time (norms, quantizers, routing), not gaps.

## Per kernel: the same code on two GPUs

| kernel (derived) | 3090: µs / light / DRAM % | H200: µs / light | class on H200 |
|---|---|---|---|
| MoE `ex_gate_up`, T=1 (320 CTAs) | 21.8 / 0.72 / 74% | 10.7 / 0.29 | latency |
| MoE `ex_down`, T=1 (160 CTAs) | 14.8 / 0.68 / 70% | 5.4 / 0.36 | latency |
| MoE `ex_gate_up`, T=48 | 506 / 0.88 / 90% | 182 / 0.48 | latency |
| MoE `ex_down`, T=48 | 273 / 0.89 / 92% | 125 / 0.38 | latency |
| Q8_0 GEMV, 2048 → 4096 rows (256 CTAs) | 144 / 0.88 / 70% | 63.5 / 0.39 | latency |
| GDN chunked scan, H=32, T=4096 (2 kernels) | 690 / 0.63 / 61–66% | 434 / ≈0.2 | latency (one kernel tuned to 4 CTAs) |
| shared expert GEMVs, T=8 | 13 / 0.10 / 11% | 12 / 0.03 | latency |
| top-k, norms, quantizers | 2–12 / under 0.05 | 1–9 | launch / latency |

The H200 light figures assume the kernel moves the same bytes on both GPUs (the 3090's ncu bytes). That holds up to L2 effects: the H200's L2 is 50 MB against the 3090's 6 MB.

On the 3090 the big derived kernels reach 0.7–0.9 of light: there they are traffic-bound and close to done. On the H200 the same kernels reach only 0.3–0.5. The H200 has 5.1× the bandwidth but the kernels run just 2–3× faster. They keep too few bytes in flight to cover the H200's bandwidth-delay product, which is about 5× larger. So the same code changes class, from traffic-bound to latency-bound (memory-level parallelism).

Flash attention fwd/bwd on the H200: `hopper_attention` autotunes inside the run, so the trace mixes candidate variants. Its printed best-of times were not kept, so this run gives no clean H200 number. On the 3090, the fused attention backward's two main kernels run at 24–32% SM and 4–6% DRAM, classed latency. Attention is compute-shaped (4·N²·D FLOPs against 4·N·D·2 bytes), so its floor should be the FLOP roof, not traffic. Rerunning with `TANG_VARIANT` fixed is the follow-up.

## What it implies for the 1–8 stream gap

1. **The gap isn't launches; it's bytes in flight.** At N=1 the MoE group is 40% of the hand step at light 0.14, and dense GEMVs are 31% at 0.37. The expert GEMVs run 64–320 CTAs per call on 132 SMs, each making one pass over a row slice. Each call is too short to ramp to full bandwidth before its tail, and 10 experts × 3 matrices per layer pay that ramp and tail every time.
2. **GEMV split / more parallelism per byte.** Splitting K across CTAs (or more rows per warp with deeper `cp.async` / TMA prefetch) raises outstanding loads per SM. The 3090 numbers show the inner loop is already right at 0.88 of light, so the missing piece is occupancy and pipelining on the H200, not the arithmetic. This alone targets the 0.14 → ~0.5 range for the MoE group.
3. **Persistent fused MoE kernel.** One resident kernel per layer that streams gate|up, then down, for every (token, expert) pair keeps loads in flight across expert and kernel boundaries. It removes the per-call ramp and tail (the main cost at N=1–8) and absorbs the ~15–25% of step time spent in sub-5 µs kernels (route, norms, quantize, combine). That is where derived is behind hand at N=1–8 (more small kernels, 8% idle against 1%).
4. **Dense projections at N≥8** are the other large lever: light 0.18 at N=8 and 0.08 at N=48. `cx_mma_q8x` takes 4 ms per step at N=48 against a 0.46 ms weight floor, with only 192 CTAs. Same disease, same cure.
5. **GDN state traffic is real at N=48:** 7.2 GB per step, about 1.5 ms of floor, at light 0.46–0.49. State in bf16 (`TANG_CODER_GDN_STATE=bf16`) would halve that floor.

## Round 2: raising bytes in flight (H200)

Pod time this round was about 1.7 H200-hours, roughly $8, across four short pods. Every change is behind a flag that defaults off. The default engine is unchanged: on the same pod, the hand engine at N=8 produced main's checksum (24a2aee70897bb74).

### Flash attention, clean (bf16, bh=64, N=4096, D=128, non-causal)

| | measured | FLOP roof (989 TFLOP/s) | compute light | traffic floor | traffic light |
|---|---|---|---|---|---|
| fwd, tuned (1 kernel) | 1.413 ms (389 TFLOP/s) | 0.556 ms | **0.39** | 0.056 ms | 0.04 |
| fwd + bwd, tuned (9 kernels) | 8.325 ms (165 TFLOP/s bwd-equiv.) | 1.95 ms | **0.23** | 0.17 ms | 0.02 |
| fixed variant 0 / 1 / 2 | fwd 3.65 / 2.74 / 3.57 ms; fwd+bwd 15.3 / 14.3 / 15.2 ms | | 0.15–0.20 | | |

Attention is compute-bound: its gap to light is FLOP throughput, not traffic. The tuner's per-kernel choice beats every single fixed variant by 1.9–2.6×. Logs: `docs/bench/ncu/bif-s1/attn_*.log`.

### GEMV / MMA knob sweep on the derived MoE layer

New knobs in the lowering: `TANG_GEMV_WARPS`, `TANG_GEMV_UNROLL` (all of a lane's loads issued before its math), `TANG_GEMV_Q8_UPL`, plus the existing `TANG_GEMV_UPL`, `TANG_DMOE_KSPLIT`, `TANG_DMOE_FRAG` and `TANG_INT8_NOSTAGE`.

| µs per layer | T=1 | T=8 | T=16 | T=48 |
|---|---|---|---|---|
| base | 50.1 | 155.1 | 236.2 | 430.6 |
| best knob | 48.2 (`WARPS=2/4`) | 143.2 (`UPL=4`) | 230.1 (`KSPLIT=1`) | 413.0 (`KSPLIT=1`) |

The best knob gains 2–8%. Unrolling alone does nothing. The derived Q8_0 GEMV on GGUF blocks reaches 812–2181 GB/s (0.17–0.45 of peak) at any knob setting. Logs: `docs/bench/ncu/bif-s1/`.

### What a GEMV can reach on the H200: `examples/gemv_bif.rs`

| kernel | 3090: GB/s (fraction of 936) | H200: GB/s (fraction of 4800) |
|---|---|---|
| streaming read, 512 MB, uint4 ×4 unrolled | 919 (0.98) | 4610 (0.96) |
| derived Q8_0 GEMV, GGUF 34-byte blocks, 4096×2048 | 495 (0.53) | 1023 (0.21) |
| repacked (aligned codes, separate scales), R=2 rows per warp, 4096×2048 | 680 (0.73) | 2185 (0.46) |
| derived, 20480×2048 | 762 (0.81) | 1586 (0.33) |
| repacked R=4, 20480×2048 (fits in the 50 MB L2) | 823 (0.88) | 4905 (1.02) |
| derived, 151936×2048 (vocab head) | 864 (0.92) | 1921 (0.40) |
| repacked R=2, 151936×2048 | 874 (0.93) | 4282 (**0.89**) |

On the H200 the GGUF Q8_0 layout itself is the cap. Its 34-byte blocks force halfword loads and funnel shifts: the instruction cost per byte stays the same while the bytes needed per SM-cycle are 2.7× the 3090's. A 16-byte-aligned repack, where each lane issues 4·R uint4 loads before any math, reaches 0.89 of peak on the large GEMV. The engine already stores dense Q8_0 in this aligned form (Q8X, type 108). The derived lowering still reads GGUF blocks; porting the repack to the derived Q8_0 path is a straightforward follow-up.

### On the model: no change

| hand engine, decode ms (N=1 / 2 / 4 / 8) | |
|---|---|
| baseline K-split Q8X GEMV | 4.03–4.05 / 4.74 / 6.51 / 9.80 |
| `TANG_CODER_Q8XW=1` (gemv_bif's structure on the engine's Q8X: a warp owns R rows, every load up front) | 4.04 / 4.81 / 6.64 / 10.03 |
| `Q8XW=2` / `Q8XW=4` | 4.18 / 4.91 / 6.81 / 10.21 (R=4 run did not finish) |
| `Q8XW=1` + `TANG_CODER_PDL=1` (programmatic dependent launch: next GEMV streams its weights before `griddepcontrol.wait`) | 4.09 / 4.82 / 6.66 / 10.04 (bitwise equal to `Q8XW=1`) |

The microbench's 2.2× doesn't reach the decode step. The model's dense GEMVs are small (4–10 µs each, 145 a step at N=1): their cost is the fixed fill-and-drain of a dependent kernel, not the inner loop. PDL only overlaps a GEMV with its predecessor when that predecessor also triggers early, and most predecessors are norms, routing or attention.

Together with #160's result (a grid barrier costs what an empty launch costs in a graph), this argues against the persistent fused MoE kernel as specified. Fusing route, top-k, gate|up, down and combine into one persistent kernel replaces launches with barriers at the same price, unless the phases overlap. The levers left for N=1–8:
- **Concurrency of independent work inside a layer:** the shared expert alongside routed experts, and the router GEMV alongside the next norm. This fills the SMs during the many sub-wave kernels (waves 0.13–0.65 on the 3090 runs; fewer SMs filled still on the 132-SM H200).
- **Cross-kernel L2 prefetch:** a layer's dense and expert weights (46 + ~19 MB) fit the H200's 50 MB L2. Prefetching the next kernel's weights during the current one (`prefetch.global.L2`, or an access-policy window on a side stream) removes the first DRAM round trip that dominates a 5 µs kernel.
- **Fewer dependent steps:** cross-layer fusion of norm → GEMV prologues (the derived path already inlines quantization).

### For Prove (Little's law)

`docs/bench/ncu/3090-occ/` has ncu achieved occupancy, registers per thread, waves per SM and long-scoreboard stall cycles per warp for every derived MoE kernel at T=1/8. For example, `ex_gate_up` at T=1 runs at 60% occupancy, 40 registers and 0.65 waves on the 3090. The microbench table above gives bytes in flight per thread (16·4·R) against achieved GB/s on both GPUs. The H200 container doesn't expose counters, so its occupancy has to come from the launch shapes plus these 3090 measurements.

## Round 3: fill/drain, L2 prefetch, concurrency (H200)

All flags default off. One pod, about 70 minutes, roughly $6. Logs are in `docs/bench/ncu/fill-drain/`.

### Fill/drain per kernel (`gemv_bif`, cold L2, repacked Q8 GEMV)

| rows × 2048 | MB | µs |
|---|---|---|
| 128 | 0.28 | 7.39 |
| 1024 | 2.23 | 7.39 |
| 4096 | 8.91 | 8.67 |
| 16384 | 35.7 | 14.4 |
| 131072 | 285 | 69.0 |

Fitting t = τ + bytes/BW gives **τ = 6.9 µs** and BW = 4.62 TB/s (0.96 of peak); this τ includes the stream launch and event overhead. The same fit on the 3090 gives τ = 5.0 µs and 0.94 of peak.

In the round-1 decode traces, near-zero-byte elementwise kernels last 1.2–2.5 µs (kernel duration only), so roughly 4–5 µs of τ is launch plus the first DRAM round trip. Either way, a dependent kernel moving under ~2 MB costs about τ whatever its size. At N=1 the step runs ~550–830 kernels, so the critical path is dominated by τ, not bytes.

### L2 prefetch (`cp.async.bulk.prefetch.L2`, `TANG_CODER_L2PF=1`)

The pair microbench runs GEMV A, which prefetches B into L2, then GEMV B. B speeds up by 0.4–0.6 µs, but A slows by 0.6–4 µs from issuing the prefetch, so the pair is net slower (4096 rows: 17.2 → 20.7 µs). On the engine, the wide Q8X GEMV prefetches the next dense matrix, with the call order learned at prefill: N=1 / N=8 go 4.08 / 10.13 → 4.10 / 10.19 ms. Adding PDL: 4.16 / 10.22.

**Prefetch issued inside a short kernel costs more than it saves.** It would have to run off the critical path: in a kernel with spare issue slots and bandwidth (attention, GDN conv), or on a side branch.

### Concurrency inside a layer

The only independent work inside a layer is the shared expert, alongside the router and top-k. Attention/GDN → MoE is a data dependency. The existing `TANG_CODER_SHPAR=1` puts the shared expert on a parallel graph branch. With it, the derived MoE switch is ignored and the path is hand, bitwise identical to hand.

| decode ms | N=1 | N=8 | N=16 | N=32 | N=48 |
|---|---|---|---|---|---|
| hand (same pod) | 4.11 | 9.92 | 15.96 | 23.62 | 30.20 |
| hand + `SHPAR=1` | **4.04** | **9.70** | **14.34** | **20.53** | **28.29** |
| derived hybrid, round 7 (for reference) | 4.05 | 9.81 | 14.06 | 21.40 | 28.45 |

`SHPAR` is about 2% faster at N=1–8 and 6–13% faster at N=16–48. At N=1–8 that is within this pod's run-to-run noise: the same baseline measured 4.03–4.12 ms across rounds. An earlier H200 log recorded −2% at N=1. The large-N gain is new: the shared expert's dense GEMVs overlap the routed experts' sorted GEMMs.

Gates with `SHPAR=1`:

| gate | result |
|---|---|
| wide-check 3000 (int8) | PASS, KL 6.74e-5 |
| wide-check 8000 (int8) | PASS, KL 9.08e-6 |
| batch-check N=8 | PASS, bitwise; checksum 24a2aee70897bb74, main's |
| batch-check N=48 | 99.00%, mean \|dlogit\| 0.142, checksum 4c1cc97f3193e028: identical to the hand engine, which sits exactly at the 99% bar (prints FAIL, as it has every round) |

### Where this leaves the 1–8 stream gap

- Per kernel the cost is τ ≈ 7 µs; per step it is the number of dependent kernels. Neither in-kernel tricks (wide loads, PDL, L2 prefetch) nor the one available branch move N=1–8 beyond noise.
- What remains is fewer dependent steps: fusing the per-layer chains (norm → GEMV → conv/attention prep, route → experts → combine → norm) into fewer kernels without adding grid barriers. #160 showed a barrier costs as much as a launch, so the fused pieces must run their phases inside blocks (block-local dependencies), not across the grid.
- For Prove's critical-path term: at N=1 the hand step has 548 kernels on one stream (one path) and 4.04 ms of wall time, about 7.4 µs per kernel — close to the measured τ.
