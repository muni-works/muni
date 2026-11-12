"use client";

import { useEffect, useMemo, useState } from "react";
import { installOgClock } from "./ogClock";
import { SIM_COVER } from "./simCoverData";

// The Seeing Is Measuring cover. One test part in the view of one of its photographs, with every
// loose hole and counterbore undecided between a plain hole and a counterbore, an amplitude for
// each. The picture is the paper's blend, I = I0 + Σ a_k (I_k − I0), of irys renders of the part
// without the feature (I0) and with each alternative alone (I_k); beside each feature, the residual
// against the photograph blends the same way, so it drains to grey as the photograph is explained.
// The amplitudes are the recorded steps of the fit on the part's three photographs, replayed on a
// loop, and as each feature decides, its line of the CAD program is written out. Every frame, place
// and number comes from simCoverData.ts; nothing is drawn by hand.
const HOLD_START = 2200; // ms at the level start
const STEP = 620; // ms per recorded step
const HOLD_END = 6500; // ms on the decided part
const REWIND = 1200; // ms back to the start
const TYPE = 26; // ms per character of a program line

type Group = (typeof SIM_COVER.groups)[number];
type Opt = Group["options"][number];
const NAME: Record<string, string> = { hole: "HOLE", counterbore: "COUNTERBORE" };
const ease = (t: number) => t * t * (3 - 2 * t);
const clamp01 = (x: number) => Math.min(Math.max(x, 0), 1);
const steps = SIM_COVER.steps;
const LAST = steps.length - 1;
const TOTAL = HOLD_START + LAST * STEP + HOLD_END + REWIND;

/** Amplitudes `ms` into the loop, the step, and the phase. */
function at(ms: number) {
  const t = ((ms % TOTAL) + TOTAL) % TOTAL;
  if (t < HOLD_START) return { t, a: [...steps[0].a] as number[], step: 0, phase: "start" as const };
  const u = (t - HOLD_START) / STEP;
  if (u < LAST) {
    const i = Math.floor(u);
    const f = ease(u - i);
    return { t, a: steps[i].a.map((x, k) => x + (steps[i + 1].a[k] - x) * f), step: i + 1, phase: "fit" as const };
  }
  const r = t - HOLD_START - LAST * STEP;
  if (r < HOLD_END) return { t, a: [...steps[LAST].a] as number[], step: LAST, phase: "end" as const };
  const f = ease((r - HOLD_END) / REWIND);
  return { t, a: steps[LAST].a.map((x, k) => x + (steps[0].a[k] - x) * f), step: 0, phase: "rewind" as const };
}

/** The loop time at which group `g` decides: from the first step after which its leading amplitude stays above 0.97. */
function decidedAt(g: Group): number | null {
  for (let i = 0; i <= LAST; i++) {
    if (steps.slice(i).every((s) => Math.max(...g.options.map((o) => s.a[o.k])) > 0.97)) return HOLD_START + i * STEP;
  }
  return null;
}

/** Opacity for alternative `i` so that, drawn in order over the base, each ends with weight a_k. */
function layerOpacity(opts: readonly Opt[], i: number, a: number[]) {
  const ai = clamp01(a[opts[i].k]);
  const after = opts.slice(i + 1).reduce((acc, q) => acc + clamp01(a[q.k]), 0);
  return 1 - after > 1e-6 ? Math.min(ai / (1 - after), 1) : 0;
}

const src = (n: string) => `/research/sim-cover/${n}`;

export function Deciding({ og = false }: { og?: boolean }) {
  const [w, h] = SIM_COVER.size;
  const groups = SIM_COVER.groups as readonly Group[];
  const [ms, setMs] = useState(0);

  useEffect(() => {
    if (og) return installOgClock(() => setMs(0), (m) => setMs(m));
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setMs(HOLD_START + LAST * STEP + HOLD_END - 1);
      return;
    }
    let raf = 0;
    let t0: number | null = null;
    const tick = (now: number) => {
      if (t0 === null) t0 = now;
      setMs(now - t0);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [og]);

  const s = at(ms);
  const beta = steps[Math.min(s.step, LAST)].beta;
  const order = useMemo(() => groups.map((_, i) => i).sort((i, j) => groups[i].centre[0] - groups[j].centre[0]), [groups]);
  const decideT = useMemo(() => groups.map(decidedAt), [groups]);
  const typed = (gi: number) => {
    const d = decideT[gi];
    if (d === null || s.phase === "start" || s.phase === "rewind" || s.t < d) return 0;
    return Math.floor((s.t - d) / TYPE);
  };

  // callout geometry, in frame pixels
  const BLOCK = 380;
  const INSET = 150;
  const blockX = (row: number) => w * (0.47 + 0.235 * row);
  const ly = h * 0.15;
  const insetY = ly + 168;
  const winners = groups.map((g) => {
    const as = g.options.map((o) => clamp01(steps[LAST].a[o.k]));
    return g.options[as[0] >= as[1] ? 0 : 1];
  });

  return (
    <div className="post-cover-canvas sim-cover">
      <div className="sim-cover-art">
        <svg viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="xMidYMid slice" role="img" aria-label="A test part whose holes are decided, one by one, between a plain hole and a counterbore">
          <defs>
            {order.map((gi, row) => (
              <clipPath key={gi} id={`sim-inset-${gi}`}>
                <rect x={blockX(row)} y={insetY} width={INSET} height={INSET} rx={2} />
              </clipPath>
            ))}
          </defs>
          <image href={src("base.jpg")} x={0} y={0} width={w} height={h} />
          {groups.map((g, gi) => (
            <g key={gi}>
              {g.options.map((o, i) => (
                <image key={o.k} href={src(`opt${o.k}.png`)} x={g.box[0]} y={g.box[1]} width={g.box[2]} height={g.box[3]} opacity={layerOpacity(g.options, i, s.a)} />
              ))}
            </g>
          ))}
          <rect x={0} y={0} width={w} height={h} className="sim-cover-dim" />
          {order.map((gi, row) => {
            const g = groups[gi];
            const [cx, cy] = g.centre;
            const bx = blockX(row);
            const as = g.options.map((o) => clamp01(s.a[o.k]));
            const win = as[0] >= as[1] ? 0 : 1;
            const leaning = Math.abs(as[0] - as[1]) > 0.08;
            const decided = Math.max(...as) > 0.97;
            const dim = g.options[win].dim as { d: number; depth?: number };
            const sc = INSET / Math.max(g.box[2], g.box[3]);
            const ix = bx + (INSET - g.box[2] * sc) / 2;
            const iy = insetY + (INSET - g.box[3] * sc) / 2;
            return (
              <g key={gi} className={`sim-feature${leaning ? " is-leaning" : ""}${decided ? " is-decided" : ""}`}>
                <polyline className="sim-rim" points={g.rim.map((p) => p.join(",")).join(" ") + ` ${g.rim[0].join(",")}`} />
                <polyline className="sim-leader" points={`${cx},${cy} ${bx + INSET / 2},${insetY + INSET + 12}`} />
                <circle className="sim-dot" cx={cx} cy={cy} r={5} />
                {g.options.map((o, i) => {
                  const y = ly + 26 + i * 44;
                  return (
                    <g key={o.k} className={`sim-row${i === win && leaning ? " is-win" : ""}`} opacity={0.32 + 0.68 * Math.min(1, as[i] * 2)}>
                      <text x={bx} y={y}>{NAME[o.kind]}</text>
                      <text className="sim-num" x={bx + 262} y={y}>{as[i].toFixed(2)}</text>
                      <line className="sim-meter-bg" x1={bx + 276} y1={y - 8} x2={bx + BLOCK} y2={y - 8} />
                      <line className="sim-meter" x1={bx + 276} y1={y - 8} x2={bx + 276 + (BLOCK - 276) * as[i]} y2={y - 8} />
                    </g>
                  );
                })}
                <text className="sim-cap" x={bx} y={insetY - 16}>RESIDUAL</text>
                <g clipPath={`url(#sim-inset-${gi})`}>
                  <image href={src(`res-base-${gi}.png`)} x={ix} y={iy} width={g.box[2] * sc} height={g.box[3] * sc} />
                  {g.options.map((o, i) => (
                    <image key={o.k} href={src(`res-opt${o.k}.png`)} x={ix} y={iy} width={g.box[2] * sc} height={g.box[3] * sc} opacity={layerOpacity(g.options, i, s.a)} />
                  ))}
                </g>
                <rect className="sim-inset-frame" x={bx} y={insetY} width={INSET} height={INSET} rx={2} />
                <text className="sim-dim-text" x={bx + INSET + 20} y={insetY + 26}>{`DIA ${dim.d.toFixed(2)}`}</text>
                <text className="sim-dim-text" x={bx + INSET + 20} y={insetY + 56}>{dim.depth !== undefined ? `DEPTH ${dim.depth.toFixed(2)}` : "THROUGH"}</text>
              </g>
            );
          })}
        </svg>
      </div>
      <div className="sim-cover-scrim" />
      <div className="sim-program" aria-hidden="true">
        {SIM_COVER.base.map((l, i) => (
          <div key={`b${i}`} className="sim-prog-base">{l}</div>
        ))}
        {order.map((gi) => {
          const line = winners[gi].line;
          const n = Math.min(typed(gi), line.length);
          return (
            <div key={gi}>
              {line.slice(0, n)}
              {n > 0 && n < line.length ? <span className="sim-caret">▍</span> : null}
              {"\u00a0"}
            </div>
          );
        })}
      </div>
      <div className="sim-cover-count" aria-hidden="true">
        {s.phase === "end"
          ? `DECIDED · ${SIM_COVER.nSteps} STEPS · ${SIM_COVER.evals} RENDERS`
          : s.phase === "fit"
            ? `STEP ${String(s.step).padStart(2, "0")} / ${String(LAST).padStart(2, "0")} · β = ${beta}`
            : "EVERY FEATURE AT 0.50"}
        <span>{`TEST PART ${SIM_COVER.seed} · IRYS RENDERS BLENDED BY AMPLITUDE · A RECORDED FIT, REPLAYED`}</span>
      </div>
    </div>
  );
}
