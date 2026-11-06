"use client";

import { useEffect, useMemo, useState } from "react";

// The memory dial in the tang post. One attention graph; the only thing that changes is where the
// n×n scores live and where kernel boundaries fall. Each stop is a schedule tang derives and runs;
// the numbers come from `paper/tang/data/memory-axis.json` (copied to /derive/), measured, never
// typed in. A stop without a measurement says so.

type Row = {
  point: string;
  device: string;
  op: string;
  n: number;
  d: number;
  ms: number | null;
  hbm_bytes: number | null;
  kernels: number | null;
  nxn_buffers: number | null;
  correct: boolean | null;
  reason?: string;
};

const STOPS: { key: string; name: string; where: string; what: string }[] = [
  { key: "naive", name: "As written", where: "HBM", what: "Scores and probabilities written out as n×n buffers." },
  { key: "checkpoint", name: "Checkpointing", where: "HBM, recomputed", what: "Probabilities dropped after the forward and recomputed in the backward." },
  { key: "fa2", name: "FlashAttention-2", where: "SMEM + registers", what: "Scores tiled through shared memory; online-softmax state in registers. Nothing n×n leaves the chip." },
  { key: "fa3", name: "FlashAttention-3", where: "SMEM, pipelined", what: "Same placement, with asynchronous tile loads overlapping the matrix units." },
  { key: "megakernel", name: "Megakernel", where: "On chip, no boundaries", what: "The whole layer as one persistent kernel; activations never return to HBM." },
];

const fmtBytes = (b: number) => (b >= 1e9 ? `${(b / 1e9).toFixed(2)} GB` : `${(b / 1e6).toFixed(1)} MB`);

export function MemoryDial() {
  const [rows, setRows] = useState<Row[] | null>(null);
  const [stop, setStop] = useState(0);
  const [device, setDevice] = useState<string>("");
  const [op, setOp] = useState("fwd");
  const [n, setN] = useState(4096);

  useEffect(() => {
    fetch("/derive/memory-axis.json")
      .then((r) => (r.ok ? r.json() : []))
      .then((d: Row[]) => {
        setRows(d);
        if (d.length) setDevice(d[0].device);
      })
      .catch(() => setRows([]));
  }, []);

  const devices = useMemo(() => [...new Set((rows ?? []).map((r) => r.device))], [rows]);
  const ns = useMemo(() => [...new Set((rows ?? []).map((r) => r.n))].sort((a, b) => a - b), [rows]);
  const pick = (key: string) => rows?.find((r) => r.point === key && r.device === device && r.op === op && r.n === n && r.d === 64);
  const cur = pick(STOPS[stop].key);
  const base = pick("naive");
  const s = STOPS[stop];
  const speedup = cur?.ms && base?.ms ? base.ms / cur.ms : null;

  return (
    <div className="memory-dial">
      <div className="md-track" role="radiogroup" aria-label="Where the scores live">
        {STOPS.map((t, i) => (
          <button key={t.key} role="radio" aria-checked={i === stop} className={i === stop ? "on" : ""} onClick={() => setStop(i)}>
            <span className="dot" />
            <span className="nm">{t.name}</span>
          </button>
        ))}
      </div>
      <input type="range" min={0} max={STOPS.length - 1} value={stop} onChange={(e) => setStop(+e.target.value)} aria-label="Memory placement" />
      <div className="md-card">
        <div className="md-where">{s.where}</div>
        <div className="md-what">{s.what}</div>
        {rows === null ? (
          <div className="md-stat">loading measurements…</div>
        ) : rows.length === 0 ? (
          <div className="md-stat">Measurements pending.</div>
        ) : !cur || cur.ms === null ? (
          <div className="md-stat">Not measured yet{cur?.reason ? `: ${cur.reason}` : ""}.</div>
        ) : (
          <div className="md-stats">
            <div><b>{cur.ms.toFixed(3)} ms</b><span>time</span></div>
            {speedup && <div><b>{speedup.toFixed(1)}×</b><span>vs as written</span></div>}
            {cur.hbm_bytes !== null && <div><b>{fmtBytes(cur.hbm_bytes)}</b><span>HBM traffic</span></div>}
            {cur.kernels !== null && <div><b>{cur.kernels}</b><span>kernels</span></div>}
            {cur.nxn_buffers !== null && <div><b>{cur.nxn_buffers}</b><span>n×n buffers</span></div>}
          </div>
        )}
      </div>
      {devices.length > 0 && (
        <div className="md-controls">
          <select value={device} onChange={(e) => setDevice(e.target.value)}>{devices.map((d) => <option key={d}>{d}</option>)}</select>
          <select value={op} onChange={(e) => setOp(e.target.value)}><option value="fwd">forward</option><option value="fwd+bwd">forward + backward</option></select>
          <select value={n} onChange={(e) => setN(+e.target.value)}>{ns.map((v) => <option key={v} value={v}>n = {v}</option>)}</select>
        </div>
      )}
    </div>
  );
}
