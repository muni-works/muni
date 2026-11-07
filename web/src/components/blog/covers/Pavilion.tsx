"use client";

import { IRYS_COVER } from "./irysCoverData";

// The irys cover: rose full (vcad hardware/rose-full) in the Barcelona Pavilion, rendered by
// irys, with every joint axis from the robot's CAD drawn through the render's own camera.
// The art is shifted right so the centred title sits over the travertine, not the robot.
// Scene: "Barcelona Pavillion" by eMirage, CC-BY, from blender.org's demo files.
const C = { bg: "#0b0907", text: "#e8e1d2", label: "#a08d70", info: "#00f0ff" };
const CALLOUTS = ["head_pitch", "l_shoulder_pitch", "l_elbow", "waist_yaw", "l_knee_pitch", "l_ankle_pitch"];

export function Pavilion({ og = false }: { og?: boolean }) {
  const [w, h] = IRYS_COVER.size;
  const label = (n: string) => (n.startsWith("l_") ? "left " + n.slice(2) : n).replace(/_/g, " ").toUpperCase();
  const picked = CALLOUTS.map((n) => IRYS_COVER.joints.find((j) => j.name === n)).filter(Boolean) as (typeof IRYS_COVER.joints)[number][];
  picked.sort((a, b) => a.p[1] - b.p[1]);
  return (
    <div className="post-cover-canvas irys-cover" aria-hidden="true" style={{ background: C.bg }}>
      <div className="irys-cover-art">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/research/irys-cover.jpg" alt="" />
        <svg viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="xMidYMid slice">
          {IRYS_COVER.joints.map((j, i) => (
            <g key={j.name} className="irys-joint" style={{ animationDelay: og ? "0s" : `${0.6 + i * 0.045}s` }}>
              <line x1={j.a[0]} y1={j.a[1]} x2={j.b[0]} y2={j.b[1]} stroke={C.info} strokeOpacity={0.8} strokeWidth={2.2} />
              <circle cx={j.p[0]} cy={j.p[1]} r={4.5} fill={C.info} />
            </g>
          ))}
          {picked.map((j, i) => {
            const ly = h * 0.12 + i * h * 0.115;
            const lx = Math.max(...IRYS_COVER.joints.map((q) => q.p[0])) + 140;
            return (
              <g key={j.name} className="irys-callout" style={{ animationDelay: og ? "0s" : `${2.2 + i * 0.12}s` }}>
                <polyline points={`${j.p[0]},${j.p[1]} ${j.p[0] + 50},${ly} ${lx},${ly}`} fill="none" stroke={C.text} strokeOpacity={0.6} strokeWidth={1.6} />
                <circle cx={j.p[0]} cy={j.p[1]} r={9} fill="none" stroke={C.text} strokeWidth={2} />
                <text x={lx + 12} y={ly - 6} textAnchor="start" fill={C.text} fontSize={22} fontFamily="var(--p-mono)" letterSpacing={2.5}>{label(j.name)}</text>
                <text x={lx + 12} y={ly + 22} textAnchor="start" fill={C.label} fontSize={20} fontFamily="var(--p-mono)" letterSpacing={2}>{`${j.lim[0].toFixed(1)}° … ${j.lim[1].toFixed(1)}°`}</text>
              </g>
            );
          })}
        </svg>
      </div>
      <div className="irys-cover-scrim" />
      <div className="irys-cover-count">
        ROSE FULL · {IRYS_COVER.nJoints} REVOLUTE JOINTS · {IRYS_COVER.nParts} PARTS
        <span>VCAD HARDWARE/ROSE-FULL · RENDERED BY IRYS · SCENE CC-BY EMIRAGE</span>
      </div>
    </div>
  );
}
