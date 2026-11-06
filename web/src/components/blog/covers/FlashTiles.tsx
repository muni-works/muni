"use client";

import { useEffect, useRef } from "react";
import { installOgClock } from "./ogClock";

// The tang cover, live: causal attention at n = 1024 as the derived flash kernel runs it
// (the PDF's title illustration, set in perspective). One cell per (32-query, 32-key) tile.
// Tiles above the diagonal are masked by an affine condition and never launched: faint dots.
// Each row block is one workgroup; its online-softmax state (m, l, acc) sweeps its key tiles
// left to right, lighting each tile as it is staged and letting it fade behind, because
// nothing n × n is ever written. The diagonal tile runs masked, in orange. Row blocks start
// heaviest-first, as the CUDA lowering launches them.
const C = {
  bg: "#0b0907",
  line: "#2a2119",
  lineHi: "#4a3a2a",
  label: "#a08d70",
  text: "#e8e1d2",
  sel: "#ff5f00",
};

const N = 32; // tiles per side
const TILE_S = 0.055; // seconds per staged key tile
const FADE = 0.9; // seconds for a staged tile to fade
const K = 1.4; // perspective: the far edge is 1 / (1 + K) the width of the near one

function mix(a: string, b: string, t: number) {
  const p = (s: string, i: number) => parseInt(s.slice(1 + i * 2, 3 + i * 2), 16);
  const c = [0, 1, 2].map((i) => Math.round(p(a, i) + (p(b, i) - p(a, i)) * Math.min(1, Math.max(0, t))));
  return `rgb(${c[0]},${c[1]},${c[2]})`;
}

// when row block i starts: heaviest (longest) rows first, staggered
function startOf(i: number) {
  return ((N - 1 - i) / N) * 1.6;
}
// one full pass of the kernel, then it runs again
const PASS = startOf(0) + N * TILE_S + FADE + 1.2;

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
      ctx.fillStyle = C.bg;
      ctx.fillRect(0, 0, w, h);

      const narrow = w < 640;
      const t = reduce ? PASS * 0.6 : ((now - start) / 1000) % PASS;
      const yTop = h * (narrow ? 0.62 : og ? 0.6 : 0.55);
      const yBot = h * 1.04;
      const halfW = w * (narrow ? 0.48 : 0.34);
      const cx = w * 0.5;
      const s0 = 1 / (1 + K);
      // row r of the grid, 0 = far (first query block), N = near edge
      const rowY = (r: number) => {
        const z = r / N;
        const s = 1 / (1 + K * (1 - z));
        return { y: yTop + (yBot - yTop) * ((s - s0) / (1 - s0)), s };
      };
      const colX = (c: number, s: number) => cx + (-1 + (2 * c) / N) * halfW * s;

      for (let i = 0; i < N; i++) {
        const a = rowY(i);
        const b = rowY(i + 1);
        const gy = (b.y - a.y) * 0.16;
        const head = (t - startOf(i)) / TILE_S; // the key tile row block i is staging now
        for (let j = 0; j < N; j++) {
          const x0 = colX(j, a.s);
          const x1 = colX(j + 1, a.s);
          const xb0 = colX(j, b.s);
          const xb1 = colX(j + 1, b.s);
          const gx = (x1 - x0) * 0.16;
          if (j > i) {
            if ((i + j) % 2 === 0) {
              ctx.fillStyle = C.line;
              ctx.beginPath();
              ctx.arc((x0 + x1 + xb0 + xb1) / 4, (a.y + b.y) / 2, Math.max(0.6, (x1 - x0) * 0.05), 0, Math.PI * 2);
              ctx.fill();
            }
            continue;
          }
          // how recently this tile was staged: 1 just now, fading to 0
          const since = (head - j) * TILE_S;
          const lit = since >= 0 ? Math.max(0, 1 - since / FADE) : 0;
          const diag = j === i;
          const depth = (i - j) / N;
          const quad = () => {
            ctx.beginPath();
            ctx.moveTo(x0 + gx, a.y + gy);
            ctx.lineTo(x1 - gx, a.y + gy);
            ctx.lineTo(xb1 - gx, b.y - gy);
            ctx.lineTo(xb0 + gx, b.y - gy);
            ctx.closePath();
          };
          quad();
          if (diag) {
            ctx.fillStyle = mix(C.lineHi, C.sel, 0.75 + 0.25 * lit);
            ctx.fill();
          } else {
            if (lit > 0) {
              ctx.fillStyle = mix(C.bg, C.sel, lit * 0.85);
              ctx.fill();
            }
            ctx.strokeStyle = mix(C.lineHi, C.label, 0.15 + 0.5 * (1 - depth) + 0.35 * lit);
            ctx.lineWidth = 0.6;
            ctx.stroke();
          }
        }
        // the row block's state readout, at its live head, for a few rows on wide screens
        if (!narrow && !reduce && i % 8 === 5 && head >= 0 && head <= i + 1) {
          const j = Math.min(i, Math.floor(head));
          const rx = colX(i + 1, a.s) + 14; // right of the diagonal, over the masked half
          const ry = (a.y + b.y) / 2;
          ctx.font = `10px ${mono}`;
          ctx.fillStyle = C.bg;
          ctx.fillRect(rx - 4, ry - 8, ctx.measureText(`ROWS ${i * 32}–${i * 32 + 31} · (m, l, acc) · KEY TILE ${j}`).width + 8, 15);
          ctx.fillStyle = C.label;
          ctx.globalAlpha = 0.85;
          ctx.fillText(`ROWS ${i * 32}–${i * 32 + 31} · (m, l, acc) · KEY TILE ${j}`, rx, ry + 3);
          ctx.globalAlpha = 1;
        }
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
      window.removeEventListener("resize", onResize);
    };
  }, [og]);

  return <canvas ref={ref} className="post-cover-canvas" aria-hidden="true" />;
}
