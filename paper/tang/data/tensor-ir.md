# Tensor IR

`tang_compile::tensor` is a tensor-level IR for tang. This note is the
design argument; the code is the spec.

## The claim

Hand-written kernels are the fastest way to run one op on one chip today.
They are also forks: one per op, per backend, per fusion opportunity, each
re-deriving the same math. The claim is that if the *whole* model goes
through an IR, the compiler can run optimization passes over it and then
emit the best code for the network and chip at hand — and that past a
certain scale this beats hand kernels, because the decisions that matter
(what to fuse, where data lives, how to spread work across threads and
devices) are decisions a hand kernel has already frozen.

`BENCHMARKS.md` has the measurements. In short: every hand kernel we
compared against is matched or beaten by code derived from the IR, the
derived flash attention is 7.6× faster than the hand one at n = 1024, and
a whole transformer block derived from the IR runs 18% faster than the
hand-written path at seq 512. No op-specific code exists in the compiler.

## Two primitives

Everything is built from two ideas.

**Views.** A `View` is an affine map from an iteration space to a source
tensor's coordinates: one `Form` (`offset + Σ coef·idx`) per source dim.
Broadcast is a zero form, transpose a permutation, slice an offset, stride a
coefficient, "head `h` reads columns `64h+2i`" a form with two terms. Views
compose by substitution and never touch memory. Because they are the only
way a comprehension addresses its inputs, every layout decision is a view
and every view is analyzable.

A view can be *guarded*: a read outside the source returns 0 instead of
being a shape error. That is zero padding as a view — same-padded and
dilated convolutions, transposed (polyphase) convolutions and overlap-add
are guarded reads. The guard follows the leaf read through composition;
a map read through a guarded view stays materialized, since `f(0)` need
not be 0. The gradient of a guarded read eliminates a coordinate rather
than scattering: for `x[c, t + 3k − 9]`, `dx[c, τ]` reads `dy[o, τ − 3k + 9]`
through a guard, so padding contributions never reach `x`.

**Comprehensions.** The only compute op:

```
out[i…] = ⊕_{k…} body(x₀[view₀(i,k)], x₁[view₁(i,k)], …)
```

`body` is a scalar `tang-expr` graph (nine RISC ops), `⊕` is a `Monoid`
whose combine is also a scalar graph. A map is a comprehension with no
reduce dims; sum and max are monoids; matmul is `Σ_k a[i,k]·b[k,j]`;
attention scores, convolution and gather are the same op with different
views. A comprehension may produce several values per point — its trailing
`tuple` dims are filled by the body — so monoids can carry tuple state.

Dims are `Dim::Fixed(n)` or `Dim::Sym("seq")`. Construction, rewriting and
differentiation work with symbols; `bind` produces the concrete graph that
schedules, the interpreter and lowering need.

## What falls out

**Fusion is one rule.** A map is a pure function of its inputs, so
`substitute_maps` splices its body into every consumer and composes the
views. Map→map, map→reduce, transpose→anything: same rule. Reductions are
not substituted — they are *inlined* by a schedule decision, which is the
difference between algebra and scheduling.

**Reshape is a view, not a copy.** A row-major reshape of a map is read
through the map's own coordinates whenever the reshape only merges dims
seen from the reader (`View::through_reshape`); the reshape node
dissolves and the map inlines like any other. Only a reshape that splits
a source dim — which needs `/` and `%` — keeps its source materialized.

**Epilogues ride the reduction.** A map that reads a reduction
point-for-point — a bias, an activation, the `acc / l` that finishes an
online softmax — never gets its own kernel: the tiled and split
schedules run it on the thread that holds the final accumulator. Any
affine read of the reduction's points qualifies, and each arg picks a
constant tuple slot. A slot that cannot vary along a point dim (the
softmax row sum along its lanes, found through the monoid's combine) may
be read at any coordinate of that dim, since every thread's accumulator
agrees there.

**Siblings share a pass.** Two reductions over the same space with the
same monoid, read by the same consumers, are one reduction under the
product monoid (`merge_siblings`): the gate and up projections of a
SwiGLU MLP become one tuple-valued comp, their activation becomes its
epilogue, and the normed input is read once. Siblings that read the same
big map `schedule_auto` will recompute in each reader (dS, read by both
rope halves of dQ) merge too, so it is recomputed once; `split_reduce_dims`
runs the merge again for siblings the layout passes expose.

**Flash attention is a rewrite.** Online softmax is a monoid over
`(max, sum, acc…)`. `stabilize_softmax` finds `m = max_j s` and every
`Σ_j g·exp(s − m)` over the same `s` (compared as canonical
sub-expressions, so masks and scales are fine) and replaces them with one
reduction under that monoid. The extra out dims of the members — the value
column of `Σ_j p·v` — become point dims of the fused comp, which is what
lets a lane per column share the reduction later. Nothing n×n is ever
materialized. Logsumexp, Welford variance and top-k are the same move.

**Gradients are comprehensions.** For `y = ⊕_k body(x[v(i,k)])`, the
gradient w.r.t. `x` through a pick view is found by *renaming
coordinates*: the coords `v` picks become `x`'s out dims, the rest become
reduce dims, every other view is pushed through the same renaming, and the
body is differentiated by `tang-expr`'s symbolic `diff`. A dim read through
any other form — an offset, a stride, a diagonal, a broadcast — stays an
out dim and the body is gated by `[coord == form]` using `iota`, the
coordinates-as-values node. `Max` gates the term to the argmax with a
select. The online-softmax monoid has its own rule: with the forward's
`m` and accumulators read back, `∂accᵢ/∂s_j = gᵢ·exp(s_j−m) − accᵢ·[s_j = m]`,
so the flash-fused graph differentiates too and its gradients equal the
naive graph's. The backward graph is an ordinary graph; the same passes optimize
it. A whole transformer block (`tang-bench::ir_block`) differentiates this
way and matches finite differences.

**A stabilizing max has no gradient.** Softmax is invariant to shifting
its scores, so the `[s == m]` terms of a stabilizing max's gradient sum to
zero, but only in exact arithmetic, and while they exist the max has to be
materialized and masked tiles cannot be skipped. `backward` drops them when
it can prove the loss does not depend on `m`
(`stabilizer_maxes`). Each node downstream of `m` gets a degree in
`t = exp(−m)`: `t^k·h` or `a + κ·m`, with `h` and `a` free of `m`, and with
the row of `m` its factor comes from tracked as a view. The rules only use
identities: `t^a·t^b = t^(a+b)`, `Σ_j t·h_j = t·Σ_j h_j` when `t`'s row does not
depend on `j`, and `2^(a+κm) = 2^a·t^(−κ ln 2)`. `o/l` is then degree 0, a
function of the scores alone. If every path from `m` ends at a degree-0 node,
`∂L/∂m ≡ 0` and `m`'s gradient is not built. Any use the rules do not cover
disqualifies `m`. `stabilize_softmax` then points the max's remaining
readers (the backward's `exp(s − m)`) at the online state's slot 0, which
holds the same max bit for bit. The f64 evaluation of the training step is
unchanged (2.7e-19 absolute at gradients of 1e6).

**Sums distribute.** `hoist_invariant_factors` moves the factors of a
sum's body that do not read the reduce coords out to a map over the
reduction: `Σ_c P̃·dO·V` becomes `P̃·Σ_c dO·V`, a plain contraction. A sum
over size-1 dims becomes a map, and args that no body output reads are
dropped, since a kernel would still bind them.

**Flash backward is nesting.** A short contraction (one reduce dim, at most
128) whose every reader is a tile, or a map recomputed in tiles, is inlined
(`schedule_nested_contractions`, applied by `to_cuda`). The attention
backward then reads `S = Q·Kᵀ` and `dP = dO·Vᵀ` only through `P̃` and `dS`,
which the dQ, dK and dV tiles recompute, so nothing n×n is written.
`cuda_mma_kernel` runs each nested contraction as `mma` per staged block:
- the side along the operand's rows (K for dK) stays in A fragments for
  the whole kernel;
- the side along k is read per chunk;
- each warp evaluates the map (`dS`, `P̃`) on its accumulator registers and
  writes the stage directly.

The k slots are paired as in the flash forward, so the recomputed `S` is
the same sum the forward reduced. Chunks where a staged operand of every
term is a masked exponential, zero by an affine condition (`map_zero_cond`),
are left out of the k range. `merge_reduce_dims` leaves a map over a
contraction this big unmerged, since a reshape would pin it to memory.

**Schedules are separate from algebra.** A comprehension says *what*. The
schedule fields on a node say *how*, and can't change the answer:

- `inline` — recompute inside the consumer instead of writing a buffer.
- `split` — one workgroup per point; threads stride the reduce space and
  tree-combine through workgroup memory. Valid for any monoid because
  combine is associative — including online softmax.
- `tile` / `tile_2d` — a `bx × by` block of threads per workgroup, each
  owning an `rx × ry` register tile of points (`reg`). The emitter inlines the closure into one loop nest,
  tracks every address as an affine form over the loop variables, and
  stages anything that does not depend on the lane axis in workgroup
  memory once per reduce chunk: buffer reads (k/v tiles, the matmul `b`
  tile) and *inlined sub-computations* (the q·k scores) alike.
  Reduce-invariant per-thread reads (the q row) are hoisted to registers.
- `precision` — number formats (`set_precision(t, Precision { storage,
  accum })`): the format a materialized buffer or input is *stored* in
  (`F32 | F16 | BF16`) and the format a reduction *accumulates* in
  (`F32 | F16`). See [Precision is a schedule](#precision-is-a-schedule).
- `schedule_auto` — the rules of thumb distilled from measurement;
  `autotune` tries candidate graphs on the device and keeps the fastest.

The derived flash kernel — rows × lanes per workgroup, cooperative score
tiles, online softmax in registers — is what those rules produce from the
naive graph. No one wrote it.

**Hand kernels become lowering targets.** The remaining role for a
hand-written kernel is as an intrinsic: "this comprehension shape has a
fast implementation on this chip". The compiler picks it when it wins and
derives one when it doesn't. The existing kernels keep their speed and stop
being forks.

## Precision is a schedule

f16 is not a different program; it is a different way to run the same
one. So precision is a per-node schedule field, like `inline` and `tile`,
and the graph stays math. Everything defaults to f32, which is exactly
the old behaviour.

- **Storage** applies where a value is written to memory: graph inputs
  (weights) and materialized comps. An inlined comp has no buffer, so its
  storage is ignored. Loads widen to f32; arithmetic is f32.
- **Accum** applies to a reduction's running state: after every combine
  step the state is rounded to the format.
- **The interpreter predicts the error.** `eval` stays pure f64 and
  ignores precision. `eval_emulated` rounds every stored value and every
  accumulator step to its scheduled format (round to nearest even,
  subnormals, overflow to ∞) while body arithmetic stays f64.
  `precision_error` compares the two (`ErrorStats`: max / mean, abs /
  relative to the output's largest magnitude); `ErrorBudget { max_rel,
  max_abs }` admits or rejects a schedule. Emulation matches the GPU's
  f16 kernels to 1 f16 ulp when the reduction order is the same.
- **The reduction order is part of the error.** The interpreter folds a
  reduction sequentially. A `split` schedule tree-combines 256 partial
  sums, so the same f16 accumulator is far more accurate under it
  (AdaIN's variance over T = 2000, measured on the GPU: 2.8e-4 under a
  256-thread split, 1.3e-2 with one thread per row; the interpreter's
  sequential prediction is 7.9e-3). Emulation models the sequential
  order, the worst case.
- **WGSL lowering.** naga 24 rejects `enable f16`, so f16 storage is
  packed two per `u32` with core-WGSL `unpack2x16float` on load; a store
  merges its half into the word with two atomics on disjoint bits
  (neighbouring halves belong to different threads). No device feature
  needed. f16 accumulation is lowered as a round-trip through
  `pack2x16float` after each combine — the numerics of an f16
  accumulator, not its speed. bf16 is not available on WGSL (it has no bf16
  type; the lowering panics on it).
- **Search.** `tang_bench::ir_gpu::tune_precision` takes a scheduled
  graph and a budget, lowers buffers to f16 one at a time (largest
  first), runs each on the device against the f64 reference, and keeps a
  change only if the program stays within budget and gets faster (≥ 3%,
  re-timed at the end against f32). Accumulators are tried against the
  budget only.

- **CUDA lowering.** `to_cuda` emits the shared kernels under a CUDA
  dialect: f16 and bf16 buffers are native 16-bit arrays (`unsigned
  short`), one element per index, converted with PTX `cvt`. No headers,
  no packing, no atomics. On the host, `Program` packs and unpacks them
  two per word. The tensor-core tiles follow storage:
  - A matmul tile whose staged operands are f16 (bf16) runs on
    `mma.sync` m16n8k16 f16 (bf16) fragments with fp32 accumulation
    instead of TF32 m16n8k8. It stages halves with 16-byte `cp.async`,
    and stages twice the k per chunk, so a stage is the same bytes as a
    TF32 one.
  - An f32 operand beside a half one (fp32 master weights) is rounded to
    the half format while it is staged.
  - Flash attention with f16 (bf16) Q, K and V computes S = Q·Kᵀ and
    O += P·V on m16n8k16. P is packed from the score registers with
    `cvt.rn.f16x2`.
  - Epilogue reads and output stores are typed, so a tile may read and
    write any mix of formats.
  - An f16 accumulator (`accum`) keeps a kernel on the transpiled path.

  With no node in half precision, every CUDA source is byte-identical to
  the f32-only lowering.
- **Search on CUDA.** `tang_bench::ir_precision::tune_precision` runs
  through `Program` (CUDA or wgpu), with the Metal search's flow. Its
  moves are tried in this order:
  1. one move with every tensor-core tile's operands in half at once;
  2. each tile's operand group (`TensorGraph::cuda_tile_operands`);
  3. single buffers, largest first.

  Each move is tried in each format of a list (f16, bf16) and checked
  against the f64 reference under the budget. A move is kept if it saves
  `min_gain` (1% by default). An `exclude` set keeps a training step's
  weights and AdamW state in f32. Cost is the sum over kernels of the
  fastest single launch: on a time-sliced GPU, whole-program times swing
  by 2× between batches. `examples/cuda_precision.rs` and `whole_model
  prec-ref | prec-tune` run the phases with the f64 references and nvrtc
  outside the GPU lock.

Set precision after the rewriting passes (they rebuild the graph); the
schedule passes (`schedule_auto`, autotune) leave it alone. `backward`
appends to the same graph, so a forward input stored in f16 is read as
f16 by the gradient kernels too, and backward reductions (a snake's
`dα = Σ_t …`) take their own precision.

## Metal backend (MSL)

`TensorGraph::to_msl` lowers the same kernels as `to_wgsl` to Metal
Shading Language (`tensor_msl.rs`). The emitters are shared: the point,
split and tiled schedules, register tiles, multi-dim reductions,
windowed staging, guarded views, epilogue fusion and tuple monoids are
produced once, with a `Dialect` switch for buffer access, and the WGSL
surface syntax is rewritten to MSL. What changes:

- **Native formats.** f16 buffers are `half` (one element per index, a
  plain store; no packed words, no atomics), bf16 buffers are `bfloat`.
  f16 accumulators round through `half` after every combine.
- **Guards are lazy.** WGSL `select` evaluates both arms and relies on
  robust buffer access; MSL has none, so a guarded read is a ternary that
  never issues the out-of-range load.
- **Fragment lowering** (`set_fragment`, `fragment_plan`): a materialized
  `Σ_r A(m, r)·B(r, n)` — or an elementwise map over one, as epilogue —
  whose two operands are f16 buffers and whose accumulator is f32 runs on
  `simdgroup_half8x8` × `simdgroup_half8x8` → `simdgroup_float8x8`. `m`
  and `n` are the tile axes; other point dims are batch. The reduce dims
  are flattened, so a conv's `(c, k)` is one K and conv is implicit GEMM.
  An operand whose address is affine with unit stride along k or along
  its free axis (matmul's `a`, `b`, `bᵀ`; a conv's weight) is loaded into
  fragments straight from device memory on interior tiles; any other
  operand (a conv's guarded, dilated `x`) is gathered through its view
  into threadgroup `half` tiles, zero-padded at staging, and ragged edge
  tiles stage both. A conv-shaped operand — one reduce dim ("rows",
  channels) read through its own forms, the free axis and every other
  reduce dim ("taps") through one form `st·n + Σ coef·tap + …` — is
  instead staged once per (row chunk, n tile) as one zero-padded
  *window*, de-interleaved by stride phase, and each tap's fragments load
  from it at a shifted offset (conv `x`, a polyphase upsample's `x`, conv
  dx's `dy`). The other operand is then staged once per chunk for all
  taps as tap planes. The body may be any `v_i · v_j` with further
  unread args (gradients keep the product rule's dropped factor), and an
  operand may be an inlined elementwise map, evaluated while staging and
  rounded to f16 there (the emulator does not model that rounding).
  The result tile goes through threadgroup memory,
  where the epilogue map runs before the write-out. Fragment geometry
  (`FragmentTarget`: fragment shape, SIMD width, threadgroup memory,
  tile) is data, so a CUDA `wmma` lowering can reuse the plan.
- **Runtime.** `tang_bench::ir_msl` (feature `metal`) owns its Metal
  buffers end to end; `tune_precision` there adds the candidate
  "operands f16 + fragments" per contraction, and `autotune_kernels`
  tries fragments wherever the node's precision admits them. WGSL stays
  the portable default.

## CPU backend (C)

`to_c` lowers a program to one C file for the system compiler. It exists
for batch-1 control steps, where a GPU round trip costs more than the
math. On the Booster K1 one synchronous Adreno submit costs 0.1–0.6 ms,
while a GRU step is 0.02 ms of work on one Cortex-X3 core.

It lowers the comps directly rather than transpiling the WGSL kernels.
A WGSL kernel is written per thread: the thread mapping (`split`, `tile`,
`reg`) is baked into index arithmetic and barriers. A loop nest would
have to be recovered from thread ids, and on one core that decomposition
is pure overhead. The comprehension already *is* a loop nest: points and
reduce dims become `for` loops with constant trip counts, and every read
is an affine index into a `restrict` pointer. GPU schedule fields are
ignored. `inline` and `precision` are honoured.

- **Vector dim.** Each kernel picks the point dim that most args read
  with unit stride. Chunks of it form the innermost loop, so gcc/clang
  vectorize across output points and keep the accumulators in
  registers. The reduce loops sit outside: for `Σ_k x[i,k]·W[k,j]` the
  inner loop streams a row of `W`.
- **Lane mode.** When no point dim is contiguous but the innermost reduce
  dim is (`x·Wᵀ` with `W` stored `[out, in]`), the innermost loop instead
  runs over 4 consecutive reduce steps into 4 partial accumulators per
  point, and the monoid folds them at the end. This works for any monoid.
- **Row block.** Four points along a second dim are unrolled in the
  source, so a weight row loaded once feeds four rows.
- **Epilogues fuse.** A map that reads reductions point-for-point, and is
  their only reader, computes them in its own kernel. That holds whether
  `schedule_auto` inlined them or not. The GRU step (six contractions and
  the gate math) is one kernel.
- **No inlined reductions otherwise.** A GPU tile stages an inlined
  reduction per chunk, but a CPU loop would redo the whole sum at every
  read. Any other inlined reduction is materialized.
- **Program.** Kernels are canonical and deduplicated. Buffers are static
  arrays laid out by `plan_memory`. `tang_run()` calls the kernels in plan
  order and allocates nothing. Callers write inputs and read outputs in
  place (`tang_input(k)`, `tang_output(i)`). f16 and bf16 storage are
  `__fp16` and `uint16_t`: loads widen to f32, and arithmetic is f32.

`tang_gpu::cpu::CpuProgram` compiles the file with `$TANG_CC` (default
`cc`), `dlopen`s it, and exposes `write_input`, `run` and `read_output`.
On a target without Rust (the robot), `tools/cpu-runner/bench.c`
`#include`s the exported file and is built with gcc. Measurements are in
BENCHMARKS.md ("CPU backend").

Not done yet: the flash-attention form (online softmax with the value
column as a point dim) recomputes its exponentials for every column, so
the CPU pass order skips `stabilize_softmax`. There is also no f16
arithmetic and no multi-core split.

## Vulkan backend (GLSL)

GPUs with neither CUDA nor Metal (the Booster K1's Adreno 740, Mali, …)
run tang programs through wgpu's Vulkan backend. Generic kernels are WGSL
as everywhere else. The decode lowering's tuned kernels (warp GEMVs that
decode 4-bit weights as they load, in-place cache updates) are written in
CUDA spelling, and Vulkan cannot take CUDA or MSL. `to_glsl_decode`
transliterates them to GLSL 450. tang-gpu, with feature `glsl`, compiles
the GLSL to SPIR-V with shaderc and dispatches it through wgpu's SPIR-V
passthrough.

- **Every buffer is a `uint[]`.** GLSL has no pointers, so a cast load
  `(const float4*)(b + e)` becomes four indexed words, and float reads are
  `uintBitsToFloat`. Packed nibbles and halves are never loaded as floats
  first.
- **Warps stay 32 lanes.** Adreno subgroups are 64 wide. The butterflies
  shuffle by XOR offsets of at most 16, which stay inside an aligned run
  of 32, so `subgroupShuffleXor` gives the same sums.
  `examples/subgroup_probe` checks a device's layout.
- **f16 is converted in integer ops** with round-to-nearest-even.
  `packHalf2x16` rounds however the driver likes, and the Adreno's choice
  biased every cached value.
- **On Adreno, WGSL goes through GLSL too.** naga's SPIR-V for a Qwen
  RoPE map came out wrong on the Adreno (right on NVIDIA and Metal), and
  naga's GLSL writer plus glslang is right. That route is the default on
  Adreno; `TANG_WGSL_VIA_GLSL=0/1` forces it off or on.
- **Bindings top out at 128 MiB** on the Adreno, smaller than Qwen3-8B's
  4-bit LM head (311 MB). `QwenDims::vocab_chunks` splits the embedding
  and LM head into vocabulary blocks.

On the K1, Vulkan itself needs `tools/adreno-vulkan/rnshim.c`. The vendor
driver opens a DRM render node that the kgsl-only kernel does not have,
and the shim answers that open with `/dev/null`. Vulkan then offers
10.9 GiB of device memory, against OpenCL's 1 GiB.

`qwen_decode tiny` on the Adreno matches the interpreter to 2.8e-6 at every
decode position, which is the agreement CUDA, Metal and NVIDIA Vulkan
reach. `QWEN_KEEP_ALL=POS` checks every kernel's result at decode position
`POS`, which is how both Adreno issues were found.

Not done yet: the full Qwen3-8B on the K1 (its startup trips the thermal
limit; cooling pending), a matrix-tile prefill in GLSL (prefill uses the
warp kernels), and timings.

## Running programs: one API, wgpu or CUDA

`tang_gpu::program` runs a lowered program on whichever backend the
machine has:

```rust
let rt = Runtime::select()?;            // CUDA if present (feature `cuda`), else wgpu
let p = Program::compile(&rt, &g, &outs, &inputs);
p.run(&rt);
let y = p.read(&rt, outs[0]);
```

- `Runtime` is `Wgpu { device, cache }` or `Cuda(CudaDevice)`.
  `select` takes CUDA when tang-gpu is built with `cuda`, `libcuda` and
  nvrtc load (cudarc dynamic loading — the feature builds and runs
  without NVIDIA hardware) and a device exists; `TANG_BACKEND=wgpu|cuda`
  forces one. `rt.lower(&g, &outs)` is `to_wgsl` (or MSL tiles with
  `TANG_NATIVE`) on wgpu and `to_cuda` on CUDA.
- `Program` owns the program's buffers on that backend: `run`,
  `run_kernel`, `read`, `write`, `time`, `time_kernel`, and `copy`, a
  device-side copy of one program's tensor into another's (how the
  training step hands gradients to Adam and Adam hands weights back).
- `Program::tuned` times, per kernel, the backend-native lowering
  against the portable one and keeps the faster, caching the choice in
  a file keyed by the device and every variant's sources: on CUDA the
  tensor-core tiles (each `MMA_SHAPES` block shape) against transpiled
  WGSL, on Metal the simdgroup-matrix MSL tiles (`to_msl_mma`, what
  `TANG_NATIVE=1` forces everywhere) against WGSL; other wgpu adapters
  have one lowering, so it is `compile`. The WGSL *schedule* autotuner
  (`ir_gpu::autotune_kernels`, `TuningCache`) is a different search —
  graph rewrites before lowering — and composes with it: tune the graph,
  then `tuned` lowers it.
- Kernel sources are canonical (`wgsl::canonical_source`, applied by
  `to_program`, `to_cuda` and `to_msl`): node numbers in identifiers
  (`b{j}`, `read_{j}`, `body_{j}`, `point_{j}`, `combine_{j}`) are
  renumbered in order of first appearance, so the same kernel at other
  nodes (another layer) is the same string and binds its buffers by
  `reads` order. Source-keyed caches — `KernelCache`, `CudaDevice`,
  the tuning caches — then compile once per distinct kernel, not per
  layer. `CudaDevice` also keeps PTX on disk (`cuda::ptx`, under
  `$TANG_PTX_CACHE` or `~/.cache/tang/ptx`; empty disables it).
- Interop: a program lives on one backend. Programs on the same runtime
  pass tensors with device copies; anything else is an explicit host
  round trip (`read`/`write`). On wgpu, `wgpu_buffer(t)` hands buffers to
  tang-gpu's hand kernels as before; on CUDA the hand kernels do not run,
  so a CUDA path has to be IR end to end — the derived forward, the
  training step and Adam are (`examples/train_loop.rs`,
  `examples/cuda_block.rs`). No Vulkan/CUDA zero-copy sharing.
- Memory plans: `Program::with_plan` takes a `BufferPlan` (buffer → slot,
  slot sizes, kernel order) and allocates slots instead of one buffer per
  tensor. `Program::planned` takes `plan_memory`'s `MemoryPlan` directly.
  On CUDA a plan may update in place (AdamW's `p2` in `p`'s slot); wgpu
  cannot bind one buffer read-only and read-write in one dispatch, so it
  refuses such plans. Slot offsets are not needed: the planner gives each
  tensor a whole slot. A kernel that does not bind its donor among its
  reads (the decode lowering's in-place updates on Metal read the old
  value through `out`) is accepted on wgpu too.
- Shared buffers: `Program::with_shared` binds some inputs to another
  program's buffers (`Shared { input, from, tensor }`), with nothing
  allocated or uploaded for them; in-place writes are seen by both. A
  prefill and a decode program hold one copy of the weights and KV caches
  this way (`examples/qwen_decode.rs`).
- CUDA graphs: on `Runtime::cuda_capturable()` (its own stream, cudarc
  event tracking off) `Program::capture` records one run; later `run`s
  replay it. On wgpu, `capture` builds every kernel's pipeline, bind group
  and uniform once, so a run is one command buffer with one compute pass. `tang_gpu::cuda::precompile` fills the PTX cache on all
  cores without a GPU.
- `tang_bench::ir_gpu::Executable` is a thin wrapper over
  `Program::on_wgpu` for callers that own a `GpuDevice` and `KernelCache`.
- Exact stabilizer gradients: `backward` drops the gradient of a
  stabilizing softmax max (exact in real arithmetic). With
  `backward_with(.., BackwardOptions { exact_stabilizers: true })` or
  `TANG_EXACT_STABILIZERS=1` the `[s == m]` terms are kept, which in a
  saturated (one-hot) softmax restores the true ~0 dWq/dWk instead of
  `dP − D` rounding noise.

## What the measurements say about the claim

The winning schedule is a property of (graph, chip, size), not of the op:

- Attention at n = 1024 on an M4 Max wants the tiled flash schedule.
  At n = 512 it wants the *naive* graph with n² threads — the 1 MB scores
  buffer is free and parallelism is the bottleneck, not bandwidth.
- Rmsnorm wants a split reduction (few rows, wide axis).
- Matmul wants one thread per point; shared-memory tiling does not pay
  because the operands already sit in cache.

Then the same branch ran on an RTX 3090. The attention and matmul results
held; the transformer block *lost* until three chip-agnostic fixes landed
(cost-aware substitution, keeping reductions schedulable under their
epilogue maps, bank-conflict-free tile layout), after which the autotuned
block beat the hand path there too (2.5 vs 3.1 ms, 6.2 vs 10.4 ms). The
rules of thumb distilled on the M4 pick the wrong matmul schedule on
NVIDIA; the per-kernel tuner picks the right one on both.

That is the strong form of the claim: decomposing into IR and choosing the
schedule per target is not just as good as hand kernels, it is the only
way to be right on every chip at once. A hand kernel is one point in the
schedule space; the compiler searches it.

## Not yet

- Fragments for attention on Metal (QKᵀ and PV under the online-softmax
  schedule). A polyphase upsample still re-stages its weight per phase
  (the phase is a batch dim of the tile).
- Body arithmetic in `half`. Storage and accumulators honour f16; scalar
  body math is f32 on every path.
- #34's f32 simdgroup-matrix tile (`tensor_msl_mma.rs`, `to_msl_mma`,
  run through wgpu's MSL passthrough, opt-in with `TANG_NATIVE`) and the
  CUDA path coexist with the whole-IR MSL backend (`tensor_msl.rs`,
  `to_msl`). The f32 Metal tile does not beat the WGSL register tile on
  an M4, so `pick_backend` only weighs WGSL against the native f16
  backend.
- CUDA: `to_cuda` emits whole programs (`mma.sync` TF32 tiles plus the
  other kernels transpiled from their WGSL) that `tang_gpu::program` runs
  through cudarc (above). The matmul-shaped tiles and the fused attention
  run on tensor cores; `cuda_flash_kernel` lowers the attention from the
  comp's structure to a flash kernel with O and the softmax state in
  `mma` registers (BENCHMARKS.md, "Flash attention on `mma.sync`"). CUDA buffers do not interoperate
  with wgpu ones (host copies at the boundary), and the lowering does not
  yet read the precision schedule (f16/bf16 wmma).
- Scatter gradients reduce over the whole source coordinate they gate on;
  a stride-2 read pays 2× in the backward pass. Fine for rope, not for a
  large gather.
- Non-affine indexing — KV-cache paging, MoE routing — needs a `Gather`
  view that reads an index tensor, which blocks some fusion.
- Placement is a transform now (`shard_reduction` + `fold_partials`:
  partial reductions over slices, the all-reduce as a comprehension over
  the monoid's combine; `examples/shard_attention.rs` runs flash
  attention's key axis across two devices), but the transport is
  host-mediated. A device-to-device runtime is the missing piece.
- A real cost model. `schedule_auto` is three measured rules; `autotune`
  is the honest answer until there is one.
