"use client";

import { useEffect, useRef } from "react";
import { installOgClock, seeded } from "./ogClock";
import { VCAD_TORUS as T } from "./vcadData";

// The vcad cover, live: the paper's torus gate, make_torus(8, 3), as a plasma toroid.
// The BRep surface is a hairline mesh (back faces faint); inside it, helical field
// lines on nested flux surfaces glow and particles stream along them. The two CAD
// parameters take turns: the minor radius r, then the major radius R, each breathing
// a little while its design velocity dx/dθ grows out of the mesh nodes as needles,
// red where the wall moves outward and pale where it moves in (dx/dR on the inner
// equator points into the solid). The readouts are the paper's measured gradients.
const C = {
  bg: "#0b0907",
  line: "#2a2119",
  lineHi: "#4a3a2a",
  label: "#a08d70",
  text: "#e8e1d2",
  vcad: "#ff2052",
  hot: "#ffe0e6",
  ice: "#ffd9c7",
};

const NU = 64; // toroidal lines
const NV = 28; // poloidal lines
const T_TURN = 5.2; // seconds per parameter
const T_LOOP = 2 * T_TURN;

// flux surfaces: fraction of the minor radius and safety factor q (poloidal turns per toroidal turn)
const SURF = [
  { rho: 0.0, q: 1 },
  { rho: 0.28, q: 1.15 },
  { rho: 0.5, q: 1.6 },
  { rho: 0.7, q: 2.3 },
  { rho: 0.86, q: 3.2 },
];
const rnd = seeded(7);
const PARTICLES = Array.from({ length: 340 }, () => {
  const s = 1 + Math.floor(rnd() * (SURF.length - 1));
  return { s, u0: rnd() * Math.PI * 2, v0: rnd() * Math.PI * 2, w: 0.35 + rnd() * 0.5, b: 0.4 + rnd() * 0.6 };
});

function smooth(t: number) {
  const k = Math.min(1, Math.max(0, t));
  return k * k * (3 - 2 * k);
}
const sci = (x: number) => {
  const e = Math.floor(Math.log10(Math.abs(x)));
  return `${(x / Math.pow(10, e)).toFixed(1)}e${e}`;
};

export function PlasmaTorus({ og = false }: { og?: boolean }) {
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
      ctx.globalCompositeOperation = "source-over";
      ctx.fillStyle = C.bg;
      ctx.fillRect(0, 0, w, h);

      const time = reduce ? 1.9 : (now - start) / 1000;
      const lt = time % T_LOOP;
      pointer.x += (pointer.tx - pointer.x) * 0.04;
      pointer.y += (pointer.ty - pointer.y) * 0.04;
      const narrow = w < 640;

      // whose turn: 0 = minor r, 1 = major R; the active one breathes, its needles swell mid-turn
      const active = lt < T_TURN ? 0 : 1;
      const turn = (lt % T_TURN) / T_TURN;
      const swell = reduce ? 1 : Math.sin(Math.PI * turn) ** 0.7;
      const breathe = reduce ? 0 : Math.sin(2 * Math.PI * turn);
      const r = T.r + (active === 0 ? 0.32 * breathe : 0);
      const R = T.R + (active === 1 ? 0.7 * breathe : 0);

      // camera: from above, slow yaw, a little pointer parallax
      const yaw = (reduce ? 0.6 : time * 0.07) + pointer.x * 0.1;
      const pitch = 0.5 + pointer.y * 0.05;
      const cy0 = Math.cos(yaw), sy0 = Math.sin(yaw), cp = Math.cos(pitch), sp = Math.sin(pitch);
      const scale = narrow ? Math.min(w * 0.032, h * 0.017) : Math.min(w * 0.022, h * 0.0175);
      const ox = w * 0.5;
      const oy = h * (narrow ? 0.73 : og ? 0.7 : 0.71);
      const camD = 70;
      const proj = (x: number, y: number, z: number): [number, number, number] => {
        const x1 = x * cy0 - y * sy0;
        const y1 = x * sy0 + y * cy0;
        const y2 = y1 * cp - z * sp;
        const z2 = y1 * sp + z * cp;
        const k = camD / (camD + y2);
        return [ox + x1 * scale * k, oy - z2 * scale * k, y2];
      };
      // depth of a direction, to cull back faces of the surface
      const toward = (nx: number, ny: number, nz: number) => (nx * sy0 + ny * cy0) * cp - nz * sp < 0.02;
      const pt = (u: number, v: number, rr: number) => {
        const c = R + rr * Math.cos(v);
        return proj(c * Math.cos(u), c * Math.sin(u), rr * Math.sin(v));
      };

      // floor: concentric rings under the toroid, the machine's footprint
      {
        const zf = -r - 2.2;
        ctx.lineWidth = 0.6;
        for (let k = 1; k <= 7; k++) {
          const rad = k * 2.4;
          ctx.strokeStyle = C.line;
          ctx.globalAlpha = 0.6 * (1 - k / 8.5);
          ctx.beginPath();
          for (let i = 0; i <= 72; i++) {
            const a = (2 * Math.PI * i) / 72;
            const s = proj(rad * Math.cos(a), rad * Math.sin(a), zf);
            if (i) ctx.lineTo(s[0], s[1]);
            else ctx.moveTo(s[0], s[1]);
          }
          ctx.stroke();
        }
        ctx.globalAlpha = 1;
      }

      // the BRep wall's back half, faint, then the plasma, then the front half over it
      const back = new Path2D();
      const front = new Path2D();
      for (let i = 0; i < NU; i++) {
        const u = (2 * Math.PI * i) / NU;
        for (let j = 0; j < NV; j++) {
          const v = (2 * Math.PI * j) / NV;
          const vis = toward(Math.cos(v) * Math.cos(u), Math.cos(v) * Math.sin(u), Math.sin(v));
          const p = pt(u, v, r);
          const a = pt(u + (2 * Math.PI) / NU, v, r);
          const b = pt(u, v + (2 * Math.PI) / NV, r);
          const path = vis ? front : back;
          path.moveTo(p[0], p[1]);
          path.lineTo(a[0], a[1]);
          path.moveTo(p[0], p[1]);
          path.lineTo(b[0], b[1]);
        }
      }
      ctx.lineWidth = 0.7;
      ctx.strokeStyle = C.lineHi;
      ctx.globalAlpha = 0.3;
      ctx.stroke(back);
      ctx.globalAlpha = 1;

      // plasma: additive light. field lines on each flux surface, then particles with trails
      ctx.globalCompositeOperation = "lighter";
      SURF.forEach((sf, si) => {
        const rr = sf.rho * r;
        const lines = si === 0 ? 1 : 3;
        for (let l = 0; l < lines; l++) {
          const v0 = (2 * Math.PI * l) / lines + si;
          for (const [width, alpha] of [[5, 0.05], [2.2, 0.1], [1, 0.38]] as const) {
            ctx.lineWidth = width;
            ctx.strokeStyle = si === 0 ? C.hot : C.vcad;
            ctx.globalAlpha = alpha * (si === 0 ? 1.4 : 1);
            ctx.beginPath();
            const M = 260;
            for (let k = 0; k <= M; k++) {
              const u = (2 * Math.PI * k) / M + time * 0.15;
              const s = pt(u, v0 + u / sf.q, rr);
              if (k) ctx.lineTo(s[0], s[1]);
              else ctx.moveTo(s[0], s[1]);
            }
            ctx.stroke();
          }
        }
      });
      for (const p of PARTICLES) {
        const sf = SURF[p.s];
        const rr = sf.rho * r;
        const u = p.u0 + time * p.w;
        ctx.strokeStyle = C.hot;
        ctx.lineWidth = 1.4;
        ctx.globalAlpha = 0.85 * p.b;
        ctx.beginPath();
        for (let k = 0; k < 6; k++) {
          const uu = u - k * 0.035;
          const s = pt(uu, p.v0 + uu / sf.q, rr);
          if (k) ctx.lineTo(s[0], s[1]);
          else ctx.moveTo(s[0], s[1]);
        }
        ctx.stroke();
      }
      ctx.globalCompositeOperation = "source-over";
      ctx.globalAlpha = 1;

      ctx.lineWidth = 0.7;
      ctx.strokeStyle = C.label;
      ctx.globalAlpha = 0.72;
      ctx.stroke(front);
      ctx.globalAlpha = 1;

      // needles: dx/dr = the tube normal; dx/dR = the radial direction from the axis
      if (swell > 0.02) {
        const len = (narrow ? 1.1 : 1.4) * swell;
        ctx.lineWidth = 1.2;
        for (let i = 0; i < NU; i += 2) {
          const u = (2 * Math.PI * i) / NU;
          for (let j = 0; j < NV; j += 2) {
            const v = (2 * Math.PI * j) / NV;
            const n = [Math.cos(v) * Math.cos(u), Math.cos(v) * Math.sin(u), Math.sin(v)];
            if (!toward(n[0], n[1], n[2])) continue;
            const d = active === 0 ? n : [Math.cos(u), Math.sin(u), 0];
            const outward = d[0] * n[0] + d[1] * n[1] + d[2] * n[2]; // the wall's normal speed
            const c = R + r * Math.cos(v);
            const x = c * Math.cos(u), y = c * Math.sin(u), z = r * Math.sin(v);
            const s0 = proj(x, y, z);
            const s1 = proj(x + d[0] * len, y + d[1] * len, z + d[2] * len);
            if (Math.hypot(s1[0] - s0[0], s1[1] - s0[1]) < 3) continue;
            ctx.strokeStyle = outward > 0 ? C.vcad : C.ice;
            ctx.globalAlpha = 0.25 + 0.75 * Math.abs(outward);
            ctx.beginPath();
            ctx.moveTo(s0[0], s0[1]);
            ctx.lineTo(s1[0], s1[1]);
            ctx.stroke();
          }
        }
        ctx.globalAlpha = 1;
      }

      // HUD: the two parameters and their measured gradients; the active one in vcad red
      const hudY = h - (narrow ? 64 : 34);
      const lx = narrow ? 16 : 40;
      ctx.textBaseline = "alphabetic";
      const rows: [string, number, string, string][] = [
        ["minor r", r, `dV/dr ${T.dVdr.toFixed(3)}`, `vs FD ${sci(T.dVdrFdRel)}`],
        ["major R", R, `dV/dR ${T.dVdR.toFixed(3)}`, `vs FD ${sci(T.dVdRFdRel)}`],
      ];
      ctx.font = `500 10px ${mono}`;
      ctx.fillStyle = C.label;
      ctx.globalAlpha = 0.8;
      ctx.fillText("make_torus(8, 3)  ·  mm, mm³", lx, hudY - 2 * 16 - 8);
      rows.forEach(([name, val, grad, fd], k) => {
        const y = hudY - (1 - k) * 16;
        const on = k === active;
        ctx.font = `${on ? 500 : 400} 11px ${mono}`;
        ctx.fillStyle = on ? C.vcad : C.label;
        ctx.globalAlpha = on ? 1 : 0.7;
        ctx.fillText(`${on ? "▸" : " "} ${name}  ${val.toFixed(3)}`, lx, y);
        if (!narrow) {
          ctx.font = `400 11px ${mono}`;
          ctx.globalAlpha = on ? 0.95 : 0.6;
          ctx.fillText(grad, lx + 150, y);
          ctx.fillStyle = C.label;
          ctx.globalAlpha = 0.6;
          ctx.font = `400 10px ${mono}`;
          ctx.fillText(fd, lx + 250, y);
        }
      });
      if (!narrow) {
        ctx.font = `400 10px ${mono}`;
        ctx.textAlign = "right";
        ctx.fillStyle = C.label;
        ctx.globalAlpha = 0.75;
        ctx.fillText(`d²V/dr² ${T.d2Vdr2.toFixed(3)} · vs FD ${sci(T.d2Vdr2FdRel)}`, w - 40, hudY);
        ctx.fillStyle = C.vcad;
        ctx.globalAlpha = 0.9 * (0.4 + 0.6 * swell);
        ctx.fillText(`dx/d${active === 0 ? "r" : "R"} · exact on the frozen mesh`, w - 40, hudY - 16);
        ctx.textAlign = "left";
      }
      ctx.globalAlpha = 1;

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
