"use client";

import { useCallback, useEffect, useRef, useState } from "react";

// The derivation lab in the tang post. The reader types an attention variant; tang's compiler,
// built to wasm from the same crates as the paper (tang-derive-wasm), builds the naive graph,
// runs its real pass pipeline, and hands back two WGSL programs: the graph as written, and the
// derived one. Both run here on the reader's GPU through WebGPU, timed, and checked against
// tang's f64 interpreter. Nothing in this file knows about attention beyond the preset strings.

/* eslint-disable @typescript-eslint/no-explicit-any */
// WebGPU types without a dependency on @webgpu/types: the lab only touches a small surface.
type GPUDevice = any;
type GPUBuffer = any;
type GPUCommandEncoder = any;
type GPUComputePipeline = any;
type GPUBindGroup = any;
type GPUBindGroupEntry = any;
declare const GPUBufferUsage: any;
declare const GPUMapMode: any;
declare const GPUShaderStage: any;
const gpuApi = () => (typeof navigator !== "undefined" ? (navigator as any).gpu : undefined);

type Kernel = { source: string; node: number; reads: number[]; points: number; count: number; workgroup_size: number };
type Program = { kernels: Kernel[]; buffers: { node: number; len: number; input: number | null }[]; outputs: number[]; nxn_buffers: number };
type Derived = { naive: Program; derived: Program; candidates: { name: string; program: Program }[] } | { error: string };
type Wasm = {
  default: (url?: string) => Promise<unknown>;
  derive: (score: string, mask: string, n: number, d: number, backward: boolean) => string;
  reference: (score: string, mask: string, n: number, d: number, backward: boolean, inputs: Float32Array) => Float32Array;
};

const PRESETS: { name: string; score: string; mask: string }[] = [
  { name: "Causal", score: "s", mask: "j <= i" },
  { name: "Sliding window", score: "s", mask: "j <= i && i - j < 128" },
  { name: "ALiBi", score: "s - 0.0625*(i - j)", mask: "j <= i" },
  { name: "Soft cap", score: "30*tanh(s/30)", mask: "j <= i" },
  { name: "Prefix LM", score: "s", mask: "j <= i || j < 64" },
  { name: "Bidirectional", score: "s", mask: "" },
];
const D = 64;
const CHECK_N = 128;

let wasmP: Promise<Wasm> | null = null;
function loadWasm() {
  wasmP ??= (async () => {
    const m = (await import(/* webpackIgnore: true */ "/derive/tang_derive.js" as string)) as Wasm;
    await m.default("/derive/tang_derive_bg.wasm");
    return m;
  })();
  return wasmP;
}

function rand(len: number, seed: number) {
  let a = seed >>> 0;
  const out = new Float32Array(len);
  for (let i = 0; i < len; i++) {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = Math.imul(a ^ (a >>> 15), a | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    out[i] = (((t ^ (t >>> 14)) >>> 0) / 4294967296) * 2 - 1;
  }
  return out;
}

type Compiled = { run: (enc: GPUCommandEncoder) => void; read: () => Promise<Float32Array>; destroy: () => void; kernels: number };

async function compile(dev: GPUDevice, p: Program, inputs: Float32Array[]): Promise<Compiled> {
  const bufs = new Map<number, GPUBuffer>();
  for (const b of p.buffers) {
    const buf = dev.createBuffer({ size: Math.max(16, b.len * 4), usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST });
    if (b.input !== null) dev.queue.writeBuffer(buf, 0, inputs[b.input]);
    bufs.set(b.node, buf);
  }
  const passes: { pipe: GPUComputePipeline; bind: GPUBindGroup; x: number; y: number }[] = [];
  const uniforms: GPUBuffer[] = [];
  for (const k of p.kernels) {
    const mod = dev.createShaderModule({ code: k.source });
    // an explicit layout: a kernel that never reads its uniform (a tile with a fixed point
    // count) would have it dropped from an "auto" layout, and the bind group would not match
    const layoutEntries = [
      ...k.reads.map((_, i) => ({ binding: i, visibility: GPUShaderStage.COMPUTE, buffer: { type: "read-only-storage" } })),
      { binding: k.reads.length, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } },
      { binding: k.reads.length + 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "uniform" } },
    ];
    const bgl = dev.createBindGroupLayout({ entries: layoutEntries });
    const layout = dev.createPipelineLayout({ bindGroupLayouts: [bgl] });
    const pipe = await dev.createComputePipelineAsync({ layout, compute: { module: mod, entryPoint: "main" } });
    const u = dev.createBuffer({ size: 16, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
    dev.queue.writeBuffer(u, 0, new Uint32Array([k.points, 0, 0, 0]));
    uniforms.push(u);
    const entries: GPUBindGroupEntry[] = k.reads.map((r, i) => ({ binding: i, resource: { buffer: bufs.get(r)! } }));
    entries.push({ binding: k.reads.length, resource: { buffer: bufs.get(k.node)! } });
    entries.push({ binding: k.reads.length + 1, resource: { buffer: u } });
    const bind = dev.createBindGroup({ layout: bgl, entries });
    const groups = Math.ceil(k.count / k.workgroup_size);
    passes.push({ pipe, bind, x: Math.min(groups, 65535), y: Math.ceil(groups / 65535) });
  }
  const outLen = p.outputs.reduce((s, o) => s + p.buffers.find((b) => b.node === o)!.len, 0);
  const staging = dev.createBuffer({ size: outLen * 4, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST });
  return {
    kernels: p.kernels.length,
    run(enc) {
      const pass = enc.beginComputePass();
      for (const s of passes) {
        pass.setPipeline(s.pipe);
        pass.setBindGroup(0, s.bind);
        pass.dispatchWorkgroups(s.x, s.y);
      }
      pass.end();
    },
    async read() {
      const enc = dev.createCommandEncoder();
      let off = 0;
      for (const o of p.outputs) {
        const len = p.buffers.find((b) => b.node === o)!.len * 4;
        enc.copyBufferToBuffer(bufs.get(o)!, 0, staging, off, len);
        off += len;
      }
      dev.queue.submit([enc.finish()]);
      await staging.mapAsync(GPUMapMode.READ);
      const out = new Float32Array(staging.getMappedRange().slice(0));
      staging.unmap();
      return out;
    },
    destroy() {
      bufs.forEach((b) => b.destroy());
      uniforms.forEach((b) => b.destroy());
      staging.destroy();
    },
  };
}

async function timeIt(dev: GPUDevice, c: Compiled) {
  const once = async (reps: number) => {
    const enc = dev.createCommandEncoder();
    for (let r = 0; r < reps; r++) c.run(enc);
    const t0 = performance.now();
    dev.queue.submit([enc.finish()]);
    await dev.queue.onSubmittedWorkDone();
    return (performance.now() - t0) / reps;
  };
  await once(2); // warm
  let best = Infinity;
  for (let i = 0; i < 5; i++) best = Math.min(best, await once(10));
  return best;
}

function relErr(a: Float32Array, ref: Float32Array) {
  let num = 0;
  let den = 0;
  for (let i = 0; i < ref.length; i++) {
    const e = a[i] - ref[i];
    num += e * e;
    den += ref[i] * ref[i];
  }
  return Math.sqrt(num / Math.max(den, 1e-30));
}

type Result = {
  naive: { kernels: number; nxn: number; ms: number; err: number };
  derived: { kernels: number; nxn: number; ms: number; err: number; name: string };
  tried: { name: string; ms: number; derived: boolean }[];
  sources: string[];
};

export function DeriveLab() {
  const [preset, setPreset] = useState(0);
  const [score, setScore] = useState(PRESETS[0].score);
  const [mask, setMask] = useState(PRESETS[0].mask);
  const [n, setN] = useState(1024);
  const [backward, setBackward] = useState(false);
  const [status, setStatus] = useState<string>("");
  const [error, setError] = useState<string>("");
  const [res, setRes] = useState<Result | null>(null);
  const [gpu, setGpu] = useState<"unknown" | "yes" | "no">("unknown");
  const [open, setOpen] = useState(-1);
  const devRef = useRef<GPUDevice | null>(null);
  const busy = useRef(false);

  useEffect(() => {
    setGpu(gpuApi() ? "yes" : "no");
    loadWasm().catch(() => setError("could not load the compiler"));
  }, []);

  const go = useCallback(async () => {
    if (busy.current) return;
    busy.current = true;
    setError("");
    setOpen(-1);
    try {
      setStatus("deriving…");
      const w = await loadWasm();
      const t0 = performance.now();
      const out = JSON.parse(w.derive(score, mask, n, D, backward)) as Derived;
      const tDerive = performance.now() - t0;
      if ("error" in out) {
        setError(out.error);
        setRes(null);
        return;
      }
      const ins = [rand(n * D, 1), rand(n * D, 2), rand(n * D, 3)];
      if (backward) ins.push(rand(n * D, 4));
      let naiveR = { kernels: out.naive.kernels.length, nxn: out.naive.nxn_buffers, ms: NaN, err: NaN };
      let derR = { kernels: out.derived.kernels.length, nxn: out.derived.nxn_buffers, ms: NaN, err: NaN, name: "schedule_auto" };
      const tried: Result["tried"] = [];
      let bestSrc = out.derived.kernels.map((k) => k.source);
      if (gpu === "yes") {
        setStatus(`derived in ${tDerive.toFixed(0)} ms · running on your GPU…`);
        if (!devRef.current) {
          const ad = await gpuApi().requestAdapter({ powerPreference: "high-performance" });
          if (!ad) throw new Error("no WebGPU adapter");
          devRef.current = await ad.requestDevice({
            requiredLimits: {
              maxStorageBuffersPerShaderStage: Math.min(10, ad.limits.maxStorageBuffersPerShaderStage),
              maxStorageBufferBindingSize: ad.limits.maxStorageBufferBindingSize,
              maxBufferSize: ad.limits.maxBufferSize,
            },
          });
        }
        const dev = devRef.current;
        const a = await compile(dev, out.naive, ins);
        const b = await compile(dev, out.derived, ins);
        naiveR.ms = await timeIt(dev, a);
        derR.ms = await timeIt(dev, b);
        a.destroy();
        b.destroy();
        tried.push({ name: "as written · scores materialized", ms: naiveR.ms, derived: false });
        tried.push({ name: "derived · schedule_auto", ms: derR.ms, derived: true });
        // the autotuner's other thread mappings, timed here; keep the fastest derived one
        for (const c of out.candidates) {
          setStatus(`timing ${c.name}…`);
          try {
            const x = await compile(dev, c.program, ins);
            const ms = await timeIt(dev, x);
            x.destroy();
            tried.push({ name: `derived · ${c.name}`, ms, derived: true });
            if (ms < derR.ms) {
              derR = { ...derR, ms, name: c.name };
              bestSrc = c.program.kernels.map((k) => k.source);
            }
          } catch {
            /* a mapping this device cannot run is simply not a candidate */
          }
        }
        // the check: the same variant derived at a small n, run on the GPU, and compared with
        // tang's f64 interpreter (which is too slow in wasm at full size)
        setStatus("checking against the f64 interpreter at n = 128…");
        await new Promise((r) => setTimeout(r, 20));
        const cn = Math.min(n, CHECK_N);
        const small = JSON.parse(w.derive(score, mask, cn, D, backward)) as Derived;
        if ("error" in small) throw new Error(small.error);
        const cins = [rand(cn * D, 11), rand(cn * D, 12), rand(cn * D, 13)];
        if (backward) cins.push(rand(cn * D, 14));
        const ca = await compile(dev, small.naive, cins);
        const cb = await compile(dev, small.derived, cins);
        const enc = dev.createCommandEncoder();
        ca.run(enc);
        cb.run(enc);
        dev.queue.submit([enc.finish()]);
        const [ya, yb] = [await ca.read(), await cb.read()];
        ca.destroy();
        cb.destroy();
        const all = new Float32Array(cins.length * cn * D);
        cins.forEach((x, k) => all.set(x, k * cn * D));
        const ref = w.reference(score, mask, cn, D, backward, all);
        naiveR = { ...naiveR, err: relErr(ya, ref) };
        derR = { ...derR, err: relErr(yb, ref) };
      }
      setRes({ naive: naiveR, derived: derR, tried, sources: bestSrc });
      setStatus(`derived in ${tDerive.toFixed(0)} ms, in your browser`);
    } catch (e) {
      setError(String(e instanceof Error ? e.message : e));
    } finally {
      busy.current = false;
    }
  }, [score, mask, n, backward, gpu]);

  // first run once the compiler is in
  useEffect(() => {
    if (gpu !== "unknown") go();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [gpu]);

  const pick = (k: number) => {
    setPreset(k);
    setScore(PRESETS[k].score);
    setMask(PRESETS[k].mask);
  };
  const fmt = (ms: number) => (Number.isFinite(ms) ? `${ms < 1 ? ms.toFixed(3) : ms.toFixed(2)} ms` : "—");
  const fmtE = (e: number) => (Number.isFinite(e) ? e.toExponential(1) : "—");

  return (
    <div className="derive-lab">
      <div className="dl-head">
        <span className="dl-tag">Live</span>
        <span>Derive an attention kernel on your own GPU</span>
      </div>
      <div className="dl-presets">
        {PRESETS.map((p, k) => (
          <button key={p.name} className={k === preset && p.score === score && p.mask === mask ? "on" : ""} onClick={() => pick(k)}>
            {p.name}
          </button>
        ))}
      </div>
      <label className="dl-field">
        <span>score</span>
        <input value={score} spellCheck={false} onChange={(e) => setScore(e.target.value)} onKeyDown={(e) => e.key === "Enter" && go()} />
        <em>in s = q·k/√d, i, j, n, d · exp log tanh sigmoid sqrt abs min max</em>
      </label>
      <label className="dl-field">
        <span>mask</span>
        <input value={mask} spellCheck={false} placeholder="(none)" onChange={(e) => setMask(e.target.value)} onKeyDown={(e) => e.key === "Enter" && go()} />
        <em>comparisons in i, j joined by &amp;&amp; and ||</em>
      </label>
      <div className="dl-row">
        <div className="dl-seg">
          {[256, 512, 1024, 2048].map((v) => (
            <button key={v} className={v === n ? "on" : ""} onClick={() => setN(v)}>
              n = {v}
            </button>
          ))}
        </div>
        <div className="dl-seg">
          <button className={!backward ? "on" : ""} onClick={() => setBackward(false)}>forward</button>
          <button className={backward ? "on" : ""} onClick={() => setBackward(true)}>+ backward</button>
        </div>
        <button className="dl-go" onClick={go}>Derive →</button>
      </div>

      {error && <div className="dl-error">{error}</div>}

      {res && !error && (
        <div className="dl-out">
          <div className="dl-col naive">
            <div className="dl-k">As written</div>
            <div className="dl-big">{fmt(res.naive.ms)}</div>
            <div className="dl-meta">{res.naive.kernels} kernels · <b className="bad">{res.naive.nxn} n × n buffers</b></div>
            <div className="dl-meta">error vs f64 (n = 128) {fmtE(res.naive.err)}</div>
          </div>
          <div className="dl-arrow">
            <span>stabilize_softmax</span>
            <span>substitute_maps</span>
            <span>schedule_auto</span>
            <i>→</i>
          </div>
          <div className="dl-col derived">
            <div className="dl-k">Derived · {res.derived.name}</div>
            <div className="dl-big">{fmt(res.derived.ms)}</div>
            <div className="dl-meta">
              {res.derived.kernels} kernels · <b className={res.derived.nxn ? "bad" : "good"}>{res.derived.nxn} n × n buffers</b>
            </div>
            <div className="dl-meta">error vs f64 (n = 128) {fmtE(res.derived.err)}</div>
          </div>
        </div>
      )}
      {res && !error && Number.isFinite(res.naive.ms) && (
        <div className="dl-speed">
          {res.derived.ms <= res.naive.ms ? (
            <>
              <b>{(res.naive.ms / res.derived.ms).toFixed(1)}×</b> faster than the graph as written, on this GPU. Nobody wrote this kernel.
            </>
          ) : (
            <>
              On this GPU at this size the graph as written is <b>{(res.derived.ms / res.naive.ms).toFixed(1)}×</b> faster: its scores fit in cache, and parallelism, not memory, is the bottleneck. That is §1's point: the right schedule belongs to the chip and the size, so tang measures rather than assumes.
            </>
          )}
          {backward && res.derived.nxn > 0 && (
            <span className="dl-note"> The WebGPU backward still writes {res.derived.nxn} n × n buffers; on CUDA, nested contractions remove them (§4).</span>
          )}
        </div>
      )}
      {res && !error && res.tried.length > 0 && (
        <div className="dl-tried">
          <div className="dl-k">Schedules timed on your GPU</div>
          {[...res.tried].sort((x, y) => x.ms - y.ms).map((t, k, arr) => (
            <div key={t.name} className={`dl-bar${k === 0 ? " best" : ""}${t.derived ? "" : " naive"}`}>
              <span className="nm">{t.name}</span>
              <span className="track"><i style={{ width: `${Math.max(2, (100 * arr[0].ms) / t.ms)}%` }} /></span>
              <span className="ms">{fmt(t.ms)}</span>
            </div>
          ))}
        </div>
      )}
      {gpu === "no" && <div className="dl-note">This browser has no WebGPU, so the kernels were derived but not run. Try Chrome, Edge or Safari 26.</div>}

      {res && !error && (
        <div className="dl-src">
          <div className="dl-k">The derived WGSL · {res.sources.length} kernels</div>
          {res.sources.map((s, k) => (
            <div key={k}>
              <button onClick={() => setOpen(open === k ? -1 : k)}>
                {open === k ? "▾" : "▸"} kernel {k} · {s.split("\n").length} lines
              </button>
              {open === k && <pre>{s}</pre>}
            </div>
          ))}
        </div>
      )}
      <div className="dl-status">{status}</div>
    </div>
  );
}
