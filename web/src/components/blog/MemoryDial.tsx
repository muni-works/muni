"use client";

import { useEffect, useMemo, useState } from "react";

// The memory-placement figure in the tang post. One attention graph (q·k → softmax → ·v); the only
// thing that changes between stops is where the intermediates S and P live and where kernel
// boundaries fall. The schematic is drawn from that placement; the table holds measurements from
// `paper/tang/data/figure1-cuda.json` (the paper's Figure 1) and `memory-axis.json` (earlier WGSL
// runs), both served at /derive/, never typed in. Unmeasured cells say "—".

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
  schedule?: string; // autotune rows: picked placement, e.g. "Smem/Recompute/Hbm/Fuse" (S/P/…)
};

type Level = 0 | 1 | 2 | 3; // HBM, L2, SMEM, registers
type Stop = {
  key: string;
  name: string;
  short: string;
  s: Level; // where S = q·kᵀ lives
  p: Level; // where P = softmax(S) lives
  cuts: number[]; // kernel boundaries between the three ops (after op i)
  recompute?: boolean;
  pipelined?: boolean;
  layer?: boolean;
  tuned?: boolean; // placement chosen by search per device; the table shows what it picked
  kernels?: number; // measured kernel count, when the drawing is derived from a row
};

// The autotuned stop is drawn from what the search picked on the selected device and size.
const LEVEL: Record<string, Level> = { Hbm: 0, Smem: 2, Reg: 3, Recompute: 3 };
function tunedStop(base: Stop, row: Row | undefined): Stop {
  const [s, p] = (row?.schedule ?? "").split("/");
  if (!(s in LEVEL) || !(p in LEVEL)) return base;
  const sl = LEVEL[s];
  const pl = LEVEL[p];
  const cuts = [...(sl === 0 ? [0] : []), ...(pl === 0 ? [1] : [])];
  return { ...base, s: sl, p: pl, cuts, recompute: p === "Recompute", kernels: row?.kernels ?? undefined };
}

const STOPS: Stop[] = [
  { key: "naive", name: "As written", short: "Written", s: 0, p: 0, cuts: [0, 1] },
  { key: "checkpoint", name: "Checkpointing", short: "Ckpt", s: 0, p: 0, cuts: [0, 1], recompute: true },
  { key: "flash", name: "FlashAttention-2", short: "FA2", s: 2, p: 3, cuts: [] },
  { key: "fa3", name: "FlashAttention-3", short: "FA3", s: 2, p: 3, cuts: [], pipelined: true },
  { key: "megakernel", name: "Megakernel", short: "Mega", s: 2, p: 3, cuts: [], layer: true },
  { key: "autotune", name: "Autotuned", short: "Tuned", s: 2, p: 3, cuts: [], tuned: true },
];

const DEVICE_NAME: Record<string, string> = {
  cuda3090: "RTX 3090, CUDA, idle",
  rtx3090: "RTX 3090, WGSL, shared",
  m4: "M4 Max, WGSL",
};
const LEVELS = ["HBM", "L2", "SMEM", "Registers"];
const OPS = ["S = q·kᵀ", "P = softmax(S)", "O = P·v"];

// schematic geometry
const W = 640;
const LX = 92; // lane label column
const LANE_H = 34;
const TOP = 30;
const colX = (i: number) => LX + 30 + i * 180;
const COL_W = 150;
const laneY = (l: Level) => TOP + (3 - l) * LANE_H; // registers on top, HBM at the bottom

const fmtBytes = (b: number) => (b >= 1e9 ? `${(b / 1e9).toFixed(2)} GB` : `${(b / 1e6).toFixed(1)} MB`);

function Schematic({ stop }: { stop: Stop }) {
  const h = TOP + 4 * LANE_H + 34;
  const tensor = (op: number, name: string, lvl: Level, nxn: boolean) => {
    const x = colX(op) + 18;
    const y = laneY(lvl) + 6;
    return (
      <g style={{ transition: "transform .45s ease", transform: `translate(${x}px, ${y}px)` }}>
        <rect width={COL_W - 36} height={LANE_H - 12} rx={2} className={nxn && lvl === 0 ? "md-t hot" : "md-t"} />
        <text x={(COL_W - 36) / 2} y={(LANE_H - 12) / 2 + 1} className="md-tl">
          {name}
          {nxn && lvl === 0 ? " · n×n" : ""}
        </text>
      </g>
    );
  };
  return (
    <svg viewBox={`0 0 ${W} ${h}`} className="md-svg" role="img" aria-label={`${stop.name}: where S and P live`}>
      {LEVELS.map((name, l) => (
        <g key={name}>
          <line x1={LX} x2={W - 8} y1={laneY(l as Level) + LANE_H} y2={laneY(l as Level) + LANE_H} className="md-lane" />
          <text x={LX - 10} y={laneY(l as Level) + LANE_H / 2 + 1} className="md-ll">
            {name}
          </text>
        </g>
      ))}
      <line x1={LX} x2={W - 8} y1={TOP} y2={TOP} className="md-lane" />
      <text x={W - 8} y={TOP + 4 * LANE_H + 22} className="md-name">
        {stop.name}
      </text>
      {OPS.map((op, i) => (
        <text key={op} x={colX(i) + COL_W / 2} y={TOP - 12} className="md-op">
          {op}
        </text>
      ))}
      {/* q, k, v and O always live in HBM */}
      {[0, 2].map((i) => (
        <text key={i} x={colX(i) + COL_W / 2} y={laneY(0) + LANE_H / 2 + 1} className="md-io">
          {i === 0 ? "q, k" : "v, O"}
        </text>
      ))}
      {tensor(0, "S", stop.s, true)}
      {tensor(1, "P", stop.p, true)}
      {/* kernel boundaries */}
      {[0, 1].map((c) => (
        <line
          key={c}
          x1={colX(c) + COL_W + 15}
          x2={colX(c) + COL_W + 15}
          y1={TOP - 4}
          y2={TOP + 4 * LANE_H + 4}
          className="md-cut"
          style={{ opacity: stop.cuts.includes(c) ? 1 : 0 }}
        />
      ))}
      <text x={LX} y={h - 8} className="md-note">
        {stop.kernels != null ? `${stop.kernels} kernel${stop.kernels === 1 ? "" : "s"} measured${stop.cuts.length ? " · dashed = kernel boundary" : ""}` : stop.cuts.length ? `${stop.cuts.length + 1} kernels · dashed = kernel boundary` : stop.layer ? "one persistent kernel for the whole layer" : "one kernel"}
        {stop.recompute ? (stop.tuned ? " · P recomputed, not stored" : " · P recomputed in backward") : ""}
        {stop.pipelined ? " · async loads overlap MMA" : ""}
        {stop.tuned ? " · picked by search" : ""}
      </text>
    </svg>
  );
}

export function MemoryDial() {
  const [rows, setRows] = useState<Row[] | null>(null);
  const [stop, setStop] = useState(0);
  const [device, setDevice] = useState("");
  const [op, setOp] = useState("fwd");
  const [n, setN] = useState(4096);

  useEffect(() => {
    const get = (f: string) =>
      fetch(`/derive/${f}`)
        .then((r) => (r.ok ? r.json() : []))
        .catch(() => []);
    // Figure 1's CUDA rows come first so the dial opens on the same numbers as the paper's figure.
    Promise.all([get("figure1-cuda.json"), get("memory-axis.json")]).then(([cuda, wgsl]: [Row[], Row[]]) => {
      const d = [
        ...cuda
          .filter((r) => r.point !== "flash_fp32")
          .map((r) => ({ ...r, device: "cuda3090", point: r.point === "searched" ? "autotune" : r.point })),
        ...wgsl,
      ];
      setRows(d);
      if (d.length) {
        setDevice(d[0].device);
        setN(d[0].n);
      }
    });
  }, []);

  const devices = useMemo(() => [...new Set((rows ?? []).map((r) => r.device))], [rows]);
  const ns = useMemo(
    () => [...new Set((rows ?? []).filter((r) => r.device === device).map((r) => r.n))].sort((a, b) => a - b),
    [rows, device],
  );
  useEffect(() => {
    if (ns.length && !ns.includes(n)) setN(ns.includes(4096) ? 4096 : ns[0]);
  }, [ns, n]);
  const cell = (key: string) => rows?.find((r) => r.point === key && r.device === device && r.op === op && r.n === n && r.d === 64);
  const base = cell("naive")?.ms ?? null;
  const metrics: { label: string; v: (r: Row | undefined) => string }[] = [
    { label: "ms", v: (r) => (r?.ms != null ? r.ms.toFixed(3) : "—") },
    { label: "speedup", v: (r) => (r?.ms != null && base ? `${(base / r.ms).toFixed(2)}×` : "—") },
    { label: "HBM bytes", v: (r) => (r?.hbm_bytes != null ? fmtBytes(r.hbm_bytes) : "—") },
    { label: "kernels", v: (r) => (r?.kernels != null ? String(r.kernels) : "—") },
    { label: "n×n bufs", v: (r) => (r?.nxn_buffers != null ? String(r.nxn_buffers) : "—") },
    { label: "f64 check", v: (r) => (r?.correct == null ? "—" : r.correct ? "pass" : "fail") },
  ];

  return (
    <figure className="memory-dial">
      <Schematic stop={STOPS[stop].tuned ? tunedStop(STOPS[stop], cell("autotune")) : STOPS[stop]} />
      <div className="md-axis" role="radiogroup" aria-label="Schedule">
        {STOPS.map((t, i) => (
          <button key={t.key} role="radio" aria-checked={i === stop} className={i === stop ? "on" : ""} onClick={() => setStop(i)} title={t.name}>
            {t.short}
          </button>
        ))}
      </div>
      <table className="md-table">
        <thead>
          <tr>
            <th />
            {STOPS.map((t, i) => (
              <th key={t.key} className={i === stop ? "on" : ""} onClick={() => setStop(i)} title={t.name}>
                {t.short}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {metrics.map((m) => (
            <tr key={m.label}>
              <td>{m.label}</td>
              {STOPS.map((t, i) => (
                <td key={t.key} className={i === stop ? "on" : ""}>
                  {m.v(cell(t.key))}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
      <figcaption>
        <span className="fig-label">Interactive</span> Causal attention, d = 64, one graph under six schedules. Only the placement of S and P and the
        kernel boundaries change.{" "}
        {rows === null ? "Loading measurements." : rows.length === 0 ? "Measurements pending; cells fill in as runs complete." : null}
        {devices.length > 0 && (
          <span className="md-controls">
            <select value={device} onChange={(e) => setDevice(e.target.value)} aria-label="Device">
              {devices.map((d) => (
                <option key={d} value={d}>
                  {DEVICE_NAME[d] ?? d}
                </option>
              ))}
            </select>
            <select value={op} onChange={(e) => setOp(e.target.value)} aria-label="Pass">
              <option value="fwd">forward</option>
              <option value="fwdbwd">forward + backward</option>
            </select>
            <select value={n} onChange={(e) => setN(+e.target.value)} aria-label="Sequence length">
              {ns.map((v) => (
                <option key={v} value={v}>
                  n = {v}
                </option>
              ))}
            </select>
          </span>
        )}
      </figcaption>
    </figure>
  );
}
