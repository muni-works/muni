"use client";

import { useEffect, useRef } from "react";
import { installOgClock } from "./ogClock";

// The tang cover, live: one training step of causal attention (n = 1024, d = 64) as the
// derived kernels run it. One cell per (32-query, 32-key) tile, laid in perspective.
//
// FORWARD. Each row block is a workgroup. Its online-softmax state (m, l, acc) sweeps the
// key tiles left to right in registers: the tile under the head flares orange and fades
// behind it, because no score is ever written. Diagonal tiles are half-masked and drawn as
// triangles; tiles above them are skipped by the affine mask and never launched (dots).
// Heaviest rows start first, as the CUDA lowering launches them. When a row block finishes,
// its output rows O (n × d, the only thing written) land in the strip on the left.
//
// BACKWARD. The same grid swept the other way: each key block (dK, dV) walks down its
// queries, recomputing S and P̃ inside the tile (cyan), so the backward writes nothing
// n × n either. Then the step repeats. The HUD counts what reached memory.
const C = {
  bg: "#0b0907",
  surface: "#15110d",
  line: "#2a2119",
  lineHi: "#4a3a2a",
  label: "#a08d70",
  text: "#e8e1d2",
  sel: "#ff5f00",
  ok: "#39ff14",
  info: "#00f0ff",
};

const N = 32; // tiles per side
const TILE = 0.06; // seconds per staged tile
const FADE = 1.1; // seconds for a staged tile's glow to fade
const STAGGER = 1.4; // spread of row-block start times
const K = 1.45; // perspective: the far edge is 1 / (1 + K) the width of the near one

const FWD = STAGGER + N * TILE + FADE; // forward phase length
const GAP = 0.9;
const BWD = STAGGER + N * TILE + FADE;
const PASS = FWD + GAP + BWD + GAP * 1.5;

function rgb(hex: string) {
  return [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
}
const RGB = Object.fromEntries(Object.entries(C).map(([k, v]) => [k, rgb(v)])) as Record<keyof typeof C, number[]>;
function mix(a: number[], b: number[], t: number, alpha = 1) {
  const k = Math.min(1, Math.max(0, t));
  const c = [0, 1, 2].map((i) => Math.round(a[i] + (b[i] - a[i]) * k));
  return alpha < 1 ? `rgba(${c[0]},${c[1]},${c[2]},${alpha})` : `rgb(${c[0]},${c[1]},${c[2]})`;
}

// forward: row block i starts heaviest-first (long rows first)
const fStart = (i: number) => ((N - 1 - i) / (N - 1)) * STAGGER;
// backward: key block j walks queries j..N-1; the longest (j = 0) starts first
const bStart = (j: number) => (j / (N - 1)) * STAGGER;

export function FlashTiles({ og = false }: { og?: boolean }) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const reduce = !og && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const mono = "'IBM Plex Mono', ui-monospace, monospace";

    let start = performance.now();
    let raf = 0;
    let running = false;
    let onScreen = true;
    let tabOn = true;
    const pointer = { x: 0, y: 0, tx: 0, ty: 0 };
    const onMove = (e: PointerEvent) => {
      pointer.tx = e.clientX / window.innerWidth - 0.5;
      pointer.ty = e.clientY / window.innerHeight - 0.5;
    };
    window.addEventListener("pointermove", onMove);

    function draw(now: number) {
      if (!canvas || !ctx) return;
      const dpr = window.devicePixelRatio || 1;
      const w = canvas.clientWidth;
      const h = canvas.clientHeight;
      if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
        canvas.width = Math.round(w * dpr);
        canvas.height = Math.round(h * dpr);
      }
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.globalCompositeOperation = "source-over";
      ctx.fillStyle = C.bg;
      ctx.fillRect(0, 0, w, h);

      pointer.x += (pointer.tx - pointer.x) * 0.05;
      pointer.y += (pointer.ty - pointer.y) * 0.05;
      const narrow = w < 640;
      const t = reduce ? FWD * 0.62 : ((now - start) / 1000) % PASS;
      const tb = t - FWD - GAP; // backward clock
      const inBwd = tb >= 0;

      // ---- geometry: a floor plane receding to the top, with a little pointer parallax
      const yTop = h * (narrow ? 0.6 : og ? 0.58 : 0.53);
      const yBot = h * 1.05;
      const halfW = w * (narrow ? 0.5 : 0.36);
      const cx = w * 0.5 + pointer.x * 24;
      const skew = pointer.x * 30; // the far edge shifts against the near one
      const s0 = 1 / (1 + K);
      const rowY = (r: number) => {
        const s = 1 / (1 + K * (1 - r / N));
        return { y: yTop + (yBot - yTop) * ((s - s0) / (1 - s0)) + pointer.y * 10 * s, s };
      };
      const X = (c: number, r: { s: number }) => cx - skew * (1 - r.s) + (-1 + (2 * c) / N) * halfW * r.s;

      // per-tile glow from either sweep
      const glow = (i: number, j: number) => {
        let f = 0;
        let b = 0;
        if (!inBwd) {
          const since = t - fStart(i) - j * TILE;
          if (since >= 0) f = Math.max(0, 1 - since / FADE);
        } else {
          const since = tb - bStart(j) - (i - j) * TILE;
          if (since >= 0) b = Math.max(0, 1 - since / FADE);
        }
        return { f, b };
      };

      // ---- the grid, far rows first
      let liveF = 0;
      let liveB = 0;
      for (let i = 0; i < N; i++) {
        const a = rowY(i);
        const b = rowY(i + 1);
        const gy = (b.y - a.y) * 0.14;
        for (let j = 0; j < N; j++) {
          const x0 = X(j, a);
          const x1 = X(j + 1, a);
          const xb0 = X(j, b);
          const xb1 = X(j + 1, b);
          const gx = (x1 - x0) * 0.14;
          if (j > i) {
            // masked: never launched. A faint shimmer so the void reads as a place.
            if ((i + j) % 2 === 0) {
              const tw = 0.5 + 0.5 * Math.sin(now / 900 + i * 1.7 + j * 0.9);
              ctx.fillStyle = mix(RGB.bg, RGB.lineHi, 0.35 + 0.35 * tw);
              ctx.beginPath();
              ctx.arc((x0 + x1 + xb0 + xb1) / 4, (a.y + b.y) / 2, Math.max(0.6, (x1 - x0) * 0.045), 0, Math.PI * 2);
              ctx.fill();
            }
            continue;
          }
          const { f, b: bk } = glow(i, j);
          const depth = (i - j) / N;
          ctx.beginPath();
          if (j === i) {
            // half-masked diagonal tile: the lower-left triangle runs
            ctx.moveTo(x0 + gx, a.y + gy);
            ctx.lineTo(xb1 - gx, b.y - gy);
            ctx.lineTo(xb0 + gx, b.y - gy);
          } else {
            ctx.moveTo(x0 + gx, a.y + gy);
            ctx.lineTo(x1 - gx, a.y + gy);
            ctx.lineTo(xb1 - gx, b.y - gy);
            ctx.lineTo(xb0 + gx, b.y - gy);
          }
          ctx.closePath();
          const heat = Math.max(f, bk);
          if (j === i) {
            ctx.fillStyle = bk > f ? mix(RGB.lineHi, RGB.info, 0.55 + 0.45 * bk) : mix(RGB.lineHi, RGB.sel, 0.6 + 0.4 * f);
            ctx.fill();
          } else if (heat > 0.02) {
            ctx.fillStyle = bk > f ? mix(RGB.bg, RGB.info, bk * 0.8) : mix(RGB.bg, RGB.sel, f * 0.88);
            ctx.fill();
          }
          if (j !== i) {
            ctx.strokeStyle = mix(RGB.line, RGB.label, 0.2 + 0.45 * (1 - depth) + 0.35 * heat);
            ctx.lineWidth = 0.6;
            ctx.stroke();
          }
        }
      }

      // ---- the sweep heads: a bloom on each live tile, additive
      if (!reduce) {
        ctx.globalCompositeOperation = "lighter";
        for (let i = 0; i < N; i++) {
          const a = rowY(i);
          const b = rowY(i + 1);
          let j = -1;
          let col = RGB.sel;
          if (!inBwd) {
            const k = (t - fStart(i)) / TILE;
            if (k >= 0 && k < i + 1) j = Math.floor(k);
          } else {
            col = RGB.info;
            // which key block is at query row i right now
            for (let jj = 0; jj <= i; jj++) {
              const k = (tb - bStart(jj)) / TILE;
              if (Math.floor(k) === i - jj) {
                j = jj;
                break;
              }
            }
          }
          if (j < 0) continue;
          if (inBwd) liveB++;
          else liveF++;
          const px = (X(j + 0.5, a) + X(j + 0.5, b)) / 2;
          const py = (a.y + b.y) / 2;
          const r = (X(j + 1, b) - X(j, b)) * 2.2;
          const g = ctx.createRadialGradient(px, py, 0, px, py, r);
          g.addColorStop(0, mix(RGB.bg, col, 1, 0.7));
          g.addColorStop(1, mix(RGB.bg, col, 1, 0));
          ctx.fillStyle = g;
          ctx.fillRect(px - r, py - r, 2 * r, 2 * r);
        }
        ctx.globalCompositeOperation = "source-over";
      }

      // ---- the output strip: O rows land as their row block finishes (forward), then dK/dV (backward)
      const stripW = Math.max(4, halfW * 0.035);
      for (let i = 0; i < N; i++) {
        const a = rowY(i);
        const b = rowY(i + 1);
        const done = inBwd ? true : t >= fStart(i) + (i + 1) * TILE;
        const justF = !inBwd ? Math.max(0, 1 - (t - fStart(i) - (i + 1) * TILE) / FADE) : 0;
        const gap = halfW * 0.06;
        const xr0 = X(0, a) - gap * a.s - stripW * a.s;
        const xr1 = X(0, a) - gap * a.s;
        const xb0 = X(0, b) - gap * b.s - stripW * b.s;
        const xb1 = X(0, b) - gap * b.s;
        ctx.beginPath();
        ctx.moveTo(xr0, a.y + 1);
        ctx.lineTo(xr1, a.y + 1);
        ctx.lineTo(xb1, b.y - 1);
        ctx.lineTo(xb0, b.y - 1);
        ctx.closePath();
        ctx.fillStyle = done ? mix(RGB.label, RGB.text, justF) : C.line;
        if (inBwd) {
          // dK / dV for key block i are done once its column sweep has passed the last query
          const bdone = tb >= bStart(i) + (N - i) * TILE;
          ctx.fillStyle = bdone ? mix(RGB.label, RGB.info, 0.7) : C.label;
        }
        ctx.fill();
      }

      // ---- HUD
      if (!narrow) {
        const hx = cx + halfW * 0.98;
        const hy = rowY(N * 0.18).y;
        const rows: [string, string][] = inBwd
          ? [
              ["BACKWARD", C.info],
              ["dK, dV · Σ over queries", C.text],
              ["S, P̃ recomputed in the tile", C.label],
              [`live tiles ${String(liveB).padStart(2, "0")}`, C.label],
            ]
          : [
              ["FORWARD", C.sel],
              ["O = ⊕ (m, l, acc)", C.text],
              ["state in registers", C.label],
              [`live tiles ${String(liveF).padStart(2, "0")}`, C.label],
            ];
        ctx.font = `10px ${mono}`;
        ctx.textAlign = "right";
        rows.forEach(([s, c], k) => {
          ctx.fillStyle = c;
          ctx.fillText(s, hx, hy + k * 15);
        });
        ctx.fillStyle = C.label;
        ctx.fillText("n × n bytes written", hx, hy + 5 * 15);
        ctx.fillStyle = C.ok;
        ctx.font = `600 18px ${mono}`;
        ctx.fillText("0", hx, hy + 5 * 15 + 22);
        ctx.textAlign = "left";
        // the strip's label
        const a = rowY(N * 0.5);
        ctx.font = `10px ${mono}`;
        ctx.fillStyle = C.label;
        ctx.textAlign = "right";
        ctx.fillText(inBwd ? "dK dV" : "O · n × d", X(0, a) - halfW * 0.12 * a.s, a.y);
        ctx.textAlign = "left";
      }

      if (!og && !reduce && onScreen && tabOn) raf = requestAnimationFrame(draw);
      else running = false;
    }

    const resume = () => {
      if (og || reduce || running || !onScreen || !tabOn) return;
      running = true;
      raf = requestAnimationFrame(draw);
    };
    const io = new IntersectionObserver(([e]) => {
      onScreen = e.isIntersecting;
      resume();
    });
    io.observe(canvas);
    const onVis = () => {
      tabOn = document.visibilityState === "visible";
      resume();
    };
    document.addEventListener("visibilitychange", onVis);
    const onResize = () => reduce && requestAnimationFrame(draw);
    window.addEventListener("resize", onResize);

    const uninstall = og
      ? installOgClock(
          () => {
            start = 0;
          },
          (ms) => draw(start + ms),
        )
      : null;
    if (!og) {
      running = true;
      raf = requestAnimationFrame(draw);
    }
    return () => {
      uninstall?.();
      cancelAnimationFrame(raf);
      io.disconnect();
      document.removeEventListener("visibilitychange", onVis);
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("resize", onResize);
    };
  }, [og]);

  return <canvas ref={ref} className="post-cover-canvas" aria-hidden="true" />;
}
