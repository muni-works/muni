"use client";

import { useEffect, useMemo, useState } from "react";
import { IRYS_COVER } from "./irysCoverData";

// The irys cover: rose full (vcad hardware/rose-full) in the Barcelona Pavilion, rendered by
// irys, with every joint from the robot's CAD drawn through the render's own camera. Hover or
// tap a joint (or tab to it) to see its axis, its range of motion swept as an arc, and the links
// it connects; with no one touching it, the cover tours the callouts on its own.
// Scene: "Barcelona Pavillion" by eMirage, CC-BY, from blender.org's demo files.
const C = { bg: "#0b0907", text: "#e8e1d2", label: "#a08d70", info: "#00f0ff", sel: "#ff5f00" };
const CALLOUTS = ["head_pitch", "l_shoulder_pitch", "l_elbow", "waist_yaw", "l_knee_pitch", "l_ankle_pitch"];
type J = (typeof IRYS_COVER.joints)[number];

const pretty = (n: string) =>
  n.replace(/^l_/, "left ").replace(/^r_/, "right ").replace(/_/g, " ").toUpperCase();
const deg = (x: number) => `${x.toFixed(1)}°`;

export function Pavilion({ og = false }: { og?: boolean }) {
  const [w, h] = IRYS_COVER.size;
  const joints = IRYS_COVER.joints as readonly J[];
  const callouts = useMemo(
    () => CALLOUTS.map((n) => joints.find((j) => j.name === n)).filter(Boolean).sort((a, b) => a!.p[1] - b!.p[1]) as J[],
    [joints],
  );
  const labelX = Math.max(...joints.map((q) => q.p[0])) + 140;
  const [hover, setHover] = useState<string | null>(null);
  const [tour, setTour] = useState(0);
  const [touched, setTouched] = useState(false);

  // The tour: one callout at a time, until someone interacts (or prefers no motion).
  useEffect(() => {
    if (og || touched || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const t = window.setInterval(() => setTour((k) => (k + 1) % callouts.length), 2600);
    return () => window.clearInterval(t);
  }, [og, touched, callouts.length]);

  const active = hover ?? (touched || og ? null : callouts[tour]?.name ?? null);
  const aj = joints.find((j) => j.name === active);
  const enter = (n: string) => {
    setTouched(true);
    setHover(n);
  };

  return (
    <div className="post-cover-canvas irys-cover" style={{ background: C.bg }}>
      <div className="irys-cover-art">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/research/irys-cover.jpg" alt="" />
        <svg viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="xMidYMid slice" role="group" aria-label="rose full's joints, from its CAD">
          {joints.map((j, i) => {
            const on = j.name === active;
            const dim = active !== null && !on;
            return (
              <g
                key={j.name}
                className={`irys-joint${on ? " is-on" : ""}${dim ? " is-dim" : ""}`}
                style={{ animationDelay: og ? "0s" : `${0.6 + i * 0.045}s` }}
                tabIndex={0}
                role="button"
                aria-label={`${pretty(j.name)}: ${deg(j.lim[0])} to ${deg(j.lim[1])}`}
                onPointerEnter={() => enter(j.name)}
                onPointerLeave={() => setHover(null)}
                onFocus={() => enter(j.name)}
                onBlur={() => setHover(null)}
                onClick={() => enter(j.name)}
              >
                <line x1={j.a[0]} y1={j.a[1]} x2={j.b[0]} y2={j.b[1]} />
                <circle className="irys-pivot" cx={j.p[0]} cy={j.p[1]} r={4.5} />
                <circle className="irys-hit" cx={j.p[0]} cy={j.p[1]} r={22} />
              </g>
            );
          })}
          {aj && (
            <g key={`arc-${aj.name}`} className="irys-arc" pointerEvents="none">
              <polyline points={aj.arc.map((q) => q.join(",")).join(" ")} pathLength={1} />
              <circle cx={aj.arc[0][0]} cy={aj.arc[0][1]} r={5} />
              <circle cx={aj.arc[aj.arc.length - 1][0]} cy={aj.arc[aj.arc.length - 1][1]} r={5} />
            </g>
          )}
          {callouts.map((j, i) => {
            const ly = h * 0.12 + i * h * 0.115;
            const on = j.name === active;
            return (
              <g
                key={j.name}
                className={`irys-callout${on ? " is-on" : ""}`}
                style={{ animationDelay: og ? "0s" : `${2.2 + i * 0.12}s` }}
                onPointerEnter={() => enter(j.name)}
                onPointerLeave={() => setHover(null)}
              >
                <polyline points={`${j.p[0]},${j.p[1]} ${j.p[0] + 50},${ly} ${labelX},${ly}`} fill="none" />
                <circle cx={j.p[0]} cy={j.p[1]} r={9} fill="none" />
                <text x={labelX + 12} y={ly - 6}>{pretty(j.name)}</text>
                <text className="irys-sub" x={labelX + 12} y={ly + 22}>{`${deg(j.lim[0])} … ${deg(j.lim[1])}`}</text>
                {on && (
                  <text className="irys-sub" x={labelX + 12} y={ly + 48}>{`MOVES ${j.moves} PARTS`}</text>
                )}
              </g>
            );
          })}
        </svg>
      </div>
      <div className="irys-cover-scrim" />
      <div className="irys-cover-count" aria-live="polite">
        {aj ? (
          <>
            {pretty(aj.name)} · {deg(aj.lim[0])} … {deg(aj.lim[1])}
            <span>{`MOVES ${aj.moves} OF ${IRYS_COVER.nParts} PARTS · FROM ROSE-FULL.JOINTS.JSON`}</span>
          </>
        ) : (
          <>
            ROSE FULL · {IRYS_COVER.nJoints} REVOLUTE JOINTS · {IRYS_COVER.nParts} PARTS
            <span>VCAD HARDWARE/ROSE-FULL · RENDERED BY IRYS · SCENE CC-BY EMIRAGE</span>
          </>
        )}
      </div>
    </div>
  );
}
