"use client";

import { useEffect, useRef } from "react";
import { installOgClock } from "./ogClock";
import { VCAD_RUN } from "./vcadData";

// The vcad cover, live: the paper's five-parameter part (a box with every edge filleted
// and a through-hole) drawn as its tessellation, in hairlines. It walks from θ₀ to θ*
// at the pace of the real L-BFGS run (J per iterate from the paper's data), and the
// design velocities dx/dθ of one parameter at a time grow out of the mesh nodes as
// red needles: the field the seam computes exactly. Then it settles at θ* and loops.
const C = {
  bg: "#0b0907",
  line: "#2a2119",
  lineHi: "#4a3a2a",
  label: "#a08d70",
  text: "#e8e1d2",
  vcad: "#ff2052",
  hot: "#ffe0e6",
};

const R = VCAD_RUN;
const NAMES = ["sx", "sy", "sz", "fillet r", "hole r"];
const NI = R.lbfgs.length; // accepted iterates + 1
const LJ0 = Math.log10(R.lbfgs[0]);
const LJ1 = Math.log10(R.lbfgs[NI - 1]);
// progress along θ₀ → θ*, monotone in log J (0 at the start, 1 at convergence)
const W = R.lbfgs.map((j) => (LJ0 - Math.log10(j)) / (LJ0 - LJ1));

// timeline, seconds
const T_WALK = 10.5; // L-BFGS, all 30 iterates
const T_HOLD = 3.5;
const T_LOOP = T_WALK + T_HOLD;
const T_PARAM = T_WALK / 5; // each parameter's field gets an equal share of the walk

type V3 = [number, number, number];
const N = 22; // grid lines per face side

function smooth(t: number) {
  const k = Math.min(1, Math.max(0, t));
  return k * k * (3 - 2 * k);
}

// a rounded box (every edge filleted at r) as six warped face grids; the warp puts more
// lines near the edges so the blends read. Points within the hole radius of the z faces
// are null, which breaks the grid lines there.
function surface(th: readonly number[]): (V3 | null)[][][] {
  const [sx, sy, sz, r, rh] = th;
  const h: V3 = [sx / 2, sy / 2, sz / 2];
  const faces: (V3 | null)[][][] = [];
  const warp = (g: number) => Math.sign(g) * (1 - Math.pow(1 - Math.abs(g), 1.7));
  for (let axis = 0; axis < 3; axis++) {
    for (const s of [-1, 1]) {
      const a1 = (axis + 1) % 3;
      const a2 = (axis + 2) % 3;
      const grid: (V3 | null)[][] = [];
      for (let i = 0; i <= N; i++) {
        const row: (V3 | null)[] = [];
        for (let j = 0; j <= N; j++) {
          const q: V3 = [0, 0, 0];
          q[axis] = s * h[axis];
          q[a1] = warp((2 * i) / N - 1) * h[a1];
          q[a2] = warp((2 * j) / N - 1) * h[a2];
          const inner = q.map((v, k) => Math.max(-(h[k] - r), Math.min(h[k] - r, v))) as V3;
          const d = q.map((v, k) => v - inner[k]) as V3;
          const len = Math.hypot(d[0], d[1], d[2]) || 1;
          const nrm = d.map((v) => v / len);
          const p = [...inner.map((v, k) => v + r * nrm[k]), ...nrm] as unknown as V3; // xyz, then the outward normal
          row.push(axis === 2 && Math.hypot(p[0], p[1]) < rh ? null : p);
        }
        grid.push(row);
      }
      faces.push(grid);
    }
  }
  return faces;
}

// the hole wall: rings at a few heights and straight rulings between the caps
function holeWall(th: readonly number[]): V3[][] {
  const [, , sz, , rh] = th;
  const lines: V3[][] = [];
  const NS = 36;
  for (let k = 0; k <= 4; k++) {
    const z = -sz / 2 + (sz * k) / 4;
    const ring: V3[] = [];
    for (let i = 0; i <= NS; i++) ring.push([rh * Math.cos((2 * Math.PI * i) / NS), rh * Math.sin((2 * Math.PI * i) / NS), z]);
    lines.push(ring);
  }
  for (let i = 0; i < NS; i += 3) {
    const a = (2 * Math.PI * i) / NS;
    lines.push([[rh * Math.cos(a), rh * Math.sin(a), -sz / 2], [rh * Math.cos(a), rh * Math.sin(a), sz / 2]]);
  }
  return lines;
}

const lerp = (a: readonly number[], b: readonly number[], t: number) => a.map((v, k) => v + (b[k] - v) * t);

export function SeamField({ og = false }: { og?: boolean }) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const reduce = !og && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const mono = "'IBM Plex Mono', ui-monospace, monospace";

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

      const time = reduce ? T_WALK * 0.62 : (now - start) / 1000;
      const lt = time % T_LOOP;
      pointer.x += (pointer.tx - pointer.x) * 0.04;
      pointer.y += (pointer.ty - pointer.y) * 0.04;
      const narrow = w < 640;

      // where the optimizer is: a fractional iterate, eased between accepted steps
      const walk = Math.min(1, lt / T_WALK);
      const fi = walk * (NI - 1);
      const i0 = Math.floor(fi);
      const i1 = Math.min(NI - 1, i0 + 1);
      const wt = W[i0] + (W[i1] - W[i0]) * smooth(fi - i0);
      const theta = lerp(R.theta0, R.thetaStar, wt);
      const jNow = Math.pow(10, Math.log10(R.lbfgs[i0]) + (Math.log10(R.lbfgs[i1]) - Math.log10(R.lbfgs[i0])) * smooth(fi - i0));
      const active = Math.min(4, Math.floor(lt / T_PARAM));
      const inWalk = lt < T_WALK;
      // needles swell in the middle of each parameter's turn and fade across the hand-off
      const turn = (lt % T_PARAM) / T_PARAM;
      const needle = reduce ? 1 : inWalk ? Math.sin(Math.PI * Math.min(1, Math.max(0, turn))) ** 0.6 : 0;

      // camera: slow yaw, fixed pitch, a little parallax from the pointer
      const yaw = (reduce ? 0.7 : 0.55 + time * 0.12) + pointer.x * 0.12;
      const pitch = 0.62 + pointer.y * 0.06;
      const cy0 = Math.cos(yaw), sy0 = Math.sin(yaw), cp = Math.cos(pitch), sp = Math.sin(pitch);
      const scale = (narrow ? Math.min(w * 0.036, h * 0.026) : Math.min(w * 0.022, h * 0.029));
      const ox = w * 0.5;
      const oy = h * (narrow ? 0.76 : og ? 0.74 : 0.73);
      const camD = 60;
      // a normal faces the camera when its screen depth component is negative
      const facing = (n: readonly number[]) => {
        const y1 = n[3] * sy0 + n[4] * cy0;
        return y1 * cp - n[5] * sp < 0.02;
      };
      // z is up in the part; the screen's y grows downward
      const proj = (p: readonly number[]): [number, number, number] => {
        const x1 = p[0] * cy0 - p[1] * sy0;
        const y1 = p[0] * sy0 + p[1] * cy0;
        const z1 = p[2];
        const y2 = y1 * cp - z1 * sp;
        const z2 = y1 * sp + z1 * cp;
        const k = camD / (camD + y2);
        return [ox + x1 * scale * k, oy - z2 * scale * k, y2];
      };

      // the ground: a perspective grid fading into the dark, the part's shadow plane
      {
        const zg = -theta[2] / 2 - 0.4;
        ctx.lineWidth = 0.6;
        for (let g = -12; g <= 12; g += 2) {
          for (const along of [0, 1]) {
            const a = proj(along ? [g, -12, zg] : [-12, g, zg]);
            const b = proj(along ? [g, 12, zg] : [12, g, zg]);
            ctx.strokeStyle = C.line;
            ctx.globalAlpha = 0.55 * (1 - Math.abs(g) / 14);
            ctx.beginPath();
            ctx.moveTo(a[0], a[1]);
            ctx.lineTo(b[0], b[1]);
            ctx.stroke();
          }
        }
        ctx.globalAlpha = 1;
      }

      // the mesh, and its velocity field for the active parameter (central difference of the
      // generator, standing in for the seam's exact dx/dθ; the shape of the field is the point)
      const faces = surface(theta);
      const hstep = 0.02;
      const tp = theta.slice();
      const tm = theta.slice();
      tp[active] += hstep;
      tm[active] -= hstep;
      const fp = surface(tp);
      const fm = surface(tm);
      const depthAlpha = (d: number) => 0.18 + 0.62 * smooth((14 - d) / 22);

      ctx.lineWidth = 0.75;
      const front = new Path2D();
      const back = new Path2D();
      for (const grid of faces) {
        for (let dir = 0; dir < 2; dir++) {
          for (let a = 0; a <= N; a++) {
            for (let b = 0; b < N; b++) {
              const p = dir ? grid[a][b] : grid[b][a];
              const q = dir ? grid[a][b + 1] : grid[b + 1][a];
              if (!p || !q) continue;
              const s0 = proj(p);
              const s1 = proj(q);
              const path = facing(p) ? front : back;
              path.moveTo(s0[0], s0[1]);
              path.lineTo(s1[0], s1[1]);
            }
          }
        }
      }
      ctx.strokeStyle = C.lineHi;
      ctx.globalAlpha = 0.35;
      ctx.stroke(back);
      ctx.strokeStyle = C.label;
      ctx.globalAlpha = 0.8;
      ctx.stroke(front);
      ctx.globalAlpha = 1;
      for (const ln of holeWall(theta)) {
        ctx.beginPath();
        let dsum = 0;
        ln.forEach((p, k) => {
          const s = proj(p);
          dsum += s[2];
          if (k) ctx.lineTo(s[0], s[1]);
          else ctx.moveTo(s[0], s[1]);
        });
        ctx.strokeStyle = C.lineHi;
        ctx.globalAlpha = depthAlpha(dsum / ln.length) + 0.1;
        ctx.stroke();
      }

      // needles: dx/dθ at every other node, red, brightest where the surface moves most
      if (needle > 0.01) {
        const len = (narrow ? 3.6 : 5.6) * needle;
        ctx.lineWidth = 1.25;
        for (let f = 0; f < 6; f++) {
          for (let a = 0; a <= N; a += 2) {
            for (let b = 0; b <= N; b += 2) {
              const p = faces[f][a][b];
              const pp = fp[f][a][b];
              const pm = fm[f][a][b];
              if (!p || !pp || !pm || !facing(p)) continue;
              const v = [0, 1, 2].map((k) => (pp[k] - pm[k]) / (2 * hstep));
              const m = Math.hypot(v[0], v[1], v[2]);
              if (m < 0.05) continue;
              const s0 = proj(p);
              const s1 = proj([0, 1, 2].map((k) => p[k] + v[k] * len));
              ctx.strokeStyle = m > 0.9 ? C.hot : C.vcad;
              ctx.globalAlpha = Math.min(1, 0.3 + 0.7 * m);
              ctx.beginPath();
              ctx.moveTo(s0[0], s0[1]);
              ctx.lineTo(s1[0], s1[1]);
              ctx.stroke();
              ctx.fillStyle = ctx.strokeStyle;
              ctx.fillRect(s1[0] - 0.8, s1[1] - 0.8, 1.6, 1.6);
            }
          }
        }
        ctx.globalAlpha = 1;
      }

      // HUD, left: θ, the active parameter in vcad red with its exact reverse-mode dJ/dθ at θ₀
      const hudY = h - (narrow ? 22 : 34);
      const lx = narrow ? 16 : 40;
      ctx.textBaseline = "alphabetic";
      if (!narrow) {
        ctx.font = `500 10px ${mono}`;
        ctx.fillStyle = C.label;
        ctx.globalAlpha = 0.8;
        ctx.fillText("θ  (mm)", lx, hudY - 5 * 15 - 8);
        for (let k = 0; k < 5; k++) {
          const y = hudY - (4 - k) * 15;
          const on = inWalk && k === active;
          ctx.font = `${on ? 500 : 400} 11px ${mono}`;
          ctx.fillStyle = on ? C.vcad : C.label;
          ctx.globalAlpha = on ? 1 : 0.7;
          ctx.fillText(`${on ? "▸" : " "} ${NAMES[k].padEnd(9)}${theta[k].toFixed(3).padStart(7)}`, lx, y);
          if (on) {
            ctx.font = `400 10px ${mono}`;
            ctx.globalAlpha = 0.75 * needle + 0.25;
            ctx.fillText(`dx/dθ`, lx + 158, y);
          }
        }
      }

      // HUD, right: J per iterate on a log axis, the dot where the optimizer is
      {
        const pw = narrow ? 120 : 180;
        const ph = narrow ? 44 : 72;
        const px = w - pw - (narrow ? 16 : 40);
        const py = hudY - ph;
        const X = (i: number) => px + (pw * i) / (NI - 1);
        const Y = (j: number) => py + ph * ((LJ0 + 0.5 - Math.log10(j)) / (LJ0 + 0.5 - LJ1));
        ctx.strokeStyle = C.line;
        ctx.lineWidth = 0.6;
        ctx.globalAlpha = 1;
        ctx.beginPath();
        ctx.moveTo(px, py + ph);
        ctx.lineTo(px + pw, py + ph);
        ctx.stroke();
        // gradient descent's first iterates for scale, faint
        ctx.strokeStyle = C.lineHi;
        ctx.beginPath();
        R.gd.slice(0, NI).forEach((j, i) => (i ? ctx.lineTo(X(i), Y(j)) : ctx.moveTo(X(i), Y(j))));
        ctx.stroke();
        ctx.strokeStyle = C.vcad;
        ctx.lineWidth = 1.1;
        ctx.beginPath();
        for (let i = 0; i <= Math.min(NI - 1, Math.ceil(fi)); i++) {
          const x = i <= fi ? X(i) : X(fi);
          const j = i <= fi ? R.lbfgs[i] : jNow;
          if (i) ctx.lineTo(x, Y(j));
          else ctx.moveTo(x, Y(j));
        }
        ctx.stroke();
        ctx.fillStyle = C.hot;
        ctx.beginPath();
        ctx.arc(X(fi), Y(jNow), 2.2, 0, Math.PI * 2);
        ctx.fill();
        ctx.font = `400 10px ${mono}`;
        ctx.fillStyle = C.label;
        ctx.textAlign = "right";
        const e = Math.floor(Math.log10(jNow));
        ctx.fillText(`J ${(jNow / Math.pow(10, e)).toFixed(1)}e${e} · iter ${Math.round(fi)}/${NI - 1}`, px + pw, py - 8);
        ctx.textAlign = "left";
        if (!narrow) {
          ctx.fillStyle = C.vcad;
          ctx.globalAlpha = 0.9;
          ctx.fillText("L-BFGS", px, py - 8);
          ctx.globalAlpha = 1;
        }
      }

      // the settled state: the five numbers recovered
      if (!inWalk && !narrow) {
        const a = reduce ? 1 : smooth((lt - T_WALK) / 0.6) * (1 - smooth((lt - T_LOOP + 0.6) / 0.6));
        ctx.font = `500 11px ${mono}`;
        ctx.fillStyle = C.text;
        ctx.globalAlpha = a;
        ctx.textAlign = "center";
        ctx.fillText(`θ* recovered · max |θ − θ*| < 3e-7 mm`, w / 2, hudY - 62);
        ctx.textAlign = "left";
        ctx.globalAlpha = 1;
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
    } else if (reduce) draw(start);
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
