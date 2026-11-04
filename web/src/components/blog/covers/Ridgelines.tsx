"use client";

import { useEffect, useRef } from "react";
import { installOgClock } from "./ogClock";
import { RIBT_UTT } from "./ribtData";

// The ribt cover, live: one real RIBT utterance as a ridgeline landscape. Each ridge
// is one mel frame (frequency left to right, energy as height); the first frame is
// nearest and the sentence runs away from you into the distance. It streams the way
// ribt does: words arrive, phonemes resolve, and the terrain rises in 48-frame
// chunks, the first one hot. Then a playhead walks the ridges at speaking speed,
// lighting each word as it is said, and loops.
const C = {
  bg: "#0b0907",
  surface: "#15110d",
  line: "#2a2119",
  lineHi: "#4a3a2a",
  label: "#a08d70",
  text: "#e8e1d2",
  sel: "#ff5f00",
  warn: "#ffd400",
};

const U = RIBT_UTT;
const NF = U.frames;
const NB = U.bands;
const MEL = new Float32Array(NF * NB);
for (let i = 0; i < NF * NB; i++) MEL[i] = (U.mel.charCodeAt(i) - 48) / 63;
const STRIDE = 2; // one ridge every second frame
const F0 = 20; // the closure before "Could" and the tail after "?" are near silence: start and end there
const F1 = 232;
const NR = Math.ceil((F1 - F0) / STRIDE);
const CHUNK = U.chunk; // frames
const FRAME_S = U.hop_ms / 1000;

// timeline, seconds
const T_TEXT = 0.35; // words start arriving
const T_WORD = 0.07; // between words (the text streams from a language model)
const T_C0 = 0.95; // first chunk rises
const T_CK = 0.16; // later chunks: compute runs far ahead of playback
const T_RISE = 0.38;
const T_PLAY = T_C0 + 0.25; // playback starts as chunk 0 lands
const T_PLAYLEN = (F1 - F0) * FRAME_S;
const T_LOOP = T_PLAYLEN + 2.6;

function smooth(t: number) {
  const k = Math.min(1, Math.max(0, t));
  return k * k * (3 - 2 * k);
}
const chunkStart = (k: number) => (k === 0 ? T_C0 : T_C0 + 0.3 + (k - 1) * T_CK);

export function Ridgelines({ og = false }: { og?: boolean }) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const reduce = !og && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const mono = "'IBM Plex Mono', ui-monospace, monospace";

    // a little smoothing across bands so ridges read as terrain, not bars
    const ridge = (f: number, out: Float32Array) => {
      for (let b = 0; b < NB; b++) {
        let s = 0;
        let w = 0;
        for (let d = -1; d <= 1; d++) {
          const bb = b + d;
          if (bb < 0 || bb >= NB) continue;
          const k = d === 0 ? 2 : 1;
          s += MEL[f * NB + bb] * k;
          w += k;
        }
        out[b] = s / w;
      }
    };
    const R = Array.from({ length: NR }, (_, r) => {
      const a = new Float32Array(NB);
      ridge(Math.min(NF - 1, F0 + r * STRIDE), a);
      return a;
    });

    const pointer = { x: 0, y: 0, tx: 0, ty: 0 };
    const onMove = (e: PointerEvent) => {
      pointer.tx = (e.clientX / window.innerWidth) * 2 - 1;
      pointer.ty = (e.clientY / window.innerHeight) * 2 - 1;
    };
    if (!og) window.addEventListener("pointermove", onMove);

    let raf = 0;
    const start = performance.now();
    let onScreen = true;
    let tabOn = document.visibilityState === "visible";
    let running = false;
    const xs = new Float32Array(NB);

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

      const time = reduce ? T_C0 + 3 : (now - start) / 1000;
      pointer.x += (pointer.tx - pointer.x) * 0.04;
      pointer.y += (pointer.ty - pointer.y) * 0.04;
      const narrow = w < 640;

      // perspective: ridge r sits at depth z = r / NR; the nearest is widest and lowest
      const yNear = h * 1.0;
      const yFar = h * (narrow ? 0.62 : og ? 0.6 : 0.55);
      const halfNear = w * (narrow ? 0.62 : 0.52);
      const K = 2.2;
      const amp = h * (narrow ? 0.13 : 0.15);
      const cx = w * 0.5 - pointer.x * 12;
      const lift = -pointer.y * 6;

      const playT = time - T_PLAY;
      const playLoop = playT < 0 ? -1 : playT % T_LOOP;
      const playFrame = playLoop >= 0 && playLoop < T_PLAYLEN ? F0 + playLoop / FRAME_S : -1;

      // far ridges first; each fills down to the floor in bg, hiding what is behind it
      for (let r = NR - 1; r >= 0; r--) {
        const f = F0 + r * STRIDE;
        const k = Math.floor(f / CHUNK);
        const rise = smooth((time - chunkStart(k)) / T_RISE);
        const z = r / (NR - 1);
        const s = 1 / (1 + K * z);
        const s1 = 1 / (1 + K);
        const y0 = yFar + (yNear - yFar) * ((s - s1) / (1 - s1)) + lift * s;
        const half = halfNear * s;
        const a = amp * s * (0.15 + 0.85 * rise);
        for (let b = 0; b < NB; b++) xs[b] = cx - half + (2 * half * b) / (NB - 1);

        ctx.beginPath();
        ctx.moveTo(xs[0], y0);
        for (let b = 0; b < NB; b++) {
          // taper the edges into the floor
          const edge = Math.sin((Math.PI * (b + 0.5)) / NB);
          const v = rise > 0 ? Math.max(0, (R[r][b] - 0.12) / 0.88) : 0;
          ctx.lineTo(xs[b], y0 - a * v * v * (0.55 + 0.45 * edge) * 1.5);
        }
        ctx.lineTo(xs[NB - 1], y0);
        ctx.closePath();
        ctx.fillStyle = C.bg;
        ctx.fill();

        // colour: not yet rendered (floor line), rendered (warm grey by depth), chunk 0 hot, the playhead
        const near = playFrame >= 0 ? Math.abs(f - playFrame) : 1e9;
        const past = playFrame >= 0 && f < playFrame;
        let col = C.lineHi;
        let alpha = 0.35 + 0.65 * s;
        if (rise <= 0) {
          col = C.line;
          alpha = 0.6;
        } else if (near < 3) {
          col = "#fff4e8";
          alpha = 1;
        } else if (near < 14) {
          col = C.sel;
          alpha = 1 - near / 18;
        } else if (k === 0 && time - chunkStart(0) < 1.6 && !reduce) {
          col = C.sel;
          alpha = 0.9 * (1 - smooth((time - chunkStart(0) - 0.6) / 1.0));
          if (alpha < 0.3) {
            col = C.label;
            alpha = 0.55 + 0.45 * s;
          }
        } else {
          col = C.label;
          alpha = past ? 0.5 + 0.5 * s : 0.25 + 0.5 * s;
        }
        // the first chunk's flash as it lands
        const flash = reduce ? 0 : Math.max(0, 1 - (time - chunkStart(k) - T_RISE * 0.6) / 0.35);
        if (rise > 0 && flash > 0 && flash < 1) {
          col = k === 0 ? "#fff4e8" : C.sel;
          alpha = Math.max(alpha, flash * (k === 0 ? 1 : 0.6));
        }
        ctx.strokeStyle = col;
        ctx.globalAlpha = alpha;
        ctx.lineWidth = r % 8 === 0 ? 1.1 : 0.8;
        ctx.stroke();
        ctx.globalAlpha = 1;
      }

      // HUD: the text arriving word by word above the terrain, phonemes under each word
      ctx.textBaseline = "alphabetic";
      const words = U.words;
      const hudY = yFar - (narrow ? 34 : 46);
      ctx.font = `500 ${narrow ? 11 : 12}px ${mono}`;
      const gap = 9;
      const widths = words.map((wd) => ctx.measureText(wd.t).width);
      const total = widths.reduce((p, q) => p + q, 0) + gap * (words.length - 1);
      let x = w * 0.5 - total / 2;
      const nowFrame = playFrame;
      for (let i = 0; i < words.length; i++) {
        const wd = words[i];
        const arrive = T_TEXT + i * T_WORD;
        const a = reduce ? 1 : smooth((time - arrive) / 0.2);
        const saying = nowFrame >= wd.f0 && nowFrame < wd.f1;
        const said = nowFrame >= wd.f1;
        ctx.font = `500 ${narrow ? 11 : 12}px ${mono}`;
        ctx.fillStyle = saying ? C.sel : said ? C.text : C.label;
        ctx.globalAlpha = a * (saying || said ? 1 : 0.85);
        ctx.fillText(wd.t, x, hudY);
        if (!narrow) {
          ctx.font = `400 10px ${mono}`;
          ctx.fillStyle = saying ? C.sel : C.label;
          ctx.globalAlpha = a * (saying ? 0.95 : 0.55);
          const pw = ctx.measureText(wd.ph).width;
          ctx.fillText(wd.ph, x + widths[i] / 2 - pw / 2, hudY + 15);
        }
        x += widths[i] + gap;
      }
      ctx.globalAlpha = 1;

      // readout beside chunk 0: the number this whole model is built around
      {
        const a0 = reduce ? 1 : smooth((time - chunkStart(0) - 0.2) / 0.3);
        if (a0 > 0) {
          const z = (CHUNK - F0) / STRIDE / 2 / (NR - 1);
          const s = 1 / (1 + K * z);
          const s1 = 1 / (1 + K);
          const yy = yFar + (yNear - yFar) * ((s - s1) / (1 - s1)) + lift * s - amp * s * 0.5;
          const xr = cx - halfNear * s - 10;
          const lines: [string, string][] = [
            [`FIRST AUDIO ${U.ttfa_ms} ms`, C.sel],
            [`CHUNK 0 · ${CHUNK} FRAMES · 512 ms OF SPEECH`, C.label],
          ];
          ctx.font = `400 10px ${mono}`;
          const tw = ctx.measureText(lines[1][0]).width;
          const left = xr - 26 - tw >= 16;
          const xR = cx + halfNear * s + 10;
          const corner = narrow || (!left && xR + 26 + tw > w - 64);
          const tx = left ? xr - 26 : xR + 26;
          const xa = left ? xr : xR;
          if (!corner) {
            ctx.strokeStyle = C.sel;
            ctx.globalAlpha = 0.5 * a0;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(xa, yy);
            ctx.lineTo(left ? tx + 6 : tx - 6, yy);
            ctx.stroke();
          }
          {
            const ty = corner ? yFar - 4 : yy + 4;
            ctx.textAlign = corner || !left ? "left" : "right";
            const lx = corner ? 16 : tx;
            ctx.font = `500 11px ${mono}`;
            ctx.fillStyle = lines[0][1];
            ctx.globalAlpha = a0;
            ctx.fillText(lines[0][0], lx, ty);
            ctx.font = `400 10px ${mono}`;
            ctx.fillStyle = lines[1][1];
            ctx.globalAlpha = 0.85 * a0;
            ctx.fillText(lines[1][0], lx, ty + 14);
          }
          ctx.textAlign = "left";
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

    const uninstall = og ? installOgClock(() => {}, (ms) => draw(start + ms)) : null;
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
