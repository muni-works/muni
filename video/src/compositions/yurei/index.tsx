// 幽霊 Yūrei — vcad Mac app launch film, v2.
// Cinematic shots: Higgsfield (Seedance 2.5). App shots: real captures from vcad
// (public/yurei/cap). Every caption speaks to the viewer. 30 fps.
import React from "react";
import {
  AbsoluteFill, Audio, Img, OffthreadVideo, Sequence, interpolate, random,
  spring, staticFile, useCurrentFrame, useVideoConfig, Easing,
} from "remotion";

export const YUREI = { fps: 30, frames: 1140 };

const RED = "#ff2052", TEAL = "#3ef0d8", TEXT = "#e8f6f3";
const JP = '"Hiragino Sans","Hiragino Kaku Gothic ProN",sans-serif';
const f = (p: string) => staticFile(`yurei/${p}`);
const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

const Fonts: React.FC = () => (
  <style>{`
    @font-face{font-family:Plex;src:url(${f("IBMPlexSans-Regular.otf")});font-weight:400}
    @font-face{font-family:Plex;src:url(${f("IBMPlexSans-SemiBold.otf")});font-weight:600}
    @font-face{font-family:PlexMono;src:url(${f("IBMPlexMono-Regular.otf")});font-weight:400}
    @font-face{font-family:PlexMono;src:url(${f("IBMPlexMono-Medium.otf")});font-weight:500}
  `}</style>
);

const useU = () => {
  const { width, height } = useVideoConfig();
  return Math.min(width, height) / 1080;
};

/* ---------- post ---------- */
const Post: React.FC = () => {
  const frame = useCurrentFrame();
  const gx = Math.floor(random(`g${frame}`) * 200), gy = Math.floor(random(`h${frame}`) * 200);
  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      <AbsoluteFill style={{ background: "linear-gradient(180deg,rgba(0,60,70,.16),rgba(80,40,0,.12))", mixBlendMode: "soft-light" }} />
      <AbsoluteFill style={{ background: "repeating-linear-gradient(0deg,rgba(0,0,0,.18) 0 2px,transparent 2px 4px)" }} />
      <AbsoluteFill style={{ opacity: 0.07, backgroundImage: "repeating-radial-gradient(circle at 31% 47%,#fff 0 1px,transparent 1px 3px)", backgroundPosition: `${gx}px ${gy}px` }} />
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 50%,transparent 50%,rgba(0,0,0,.85) 100%)" }} />
    </AbsoluteFill>
  );
};

/** White flash + tiny shake at the head of every cut. */
const Hit: React.FC<{ len?: number; color?: string }> = ({ len = 4, color = "#fff" }) => {
  const frame = useCurrentFrame();
  return <AbsoluteFill style={{ background: color, opacity: interpolate(frame, [0, len], [0.85, 0], clamp), pointerEvents: "none" }} />;
};
const useShake = (amp = 14, len = 6) => {
  const frame = useCurrentFrame();
  const k = Math.max(0, 1 - frame / len);
  return `translate(${(random(`sx${frame}`) - 0.5) * amp * k}px, ${(random(`sy${frame}`) - 0.5) * amp * k}px)`;
};

/* ---------- type ---------- */
const Glitch: React.FC<{ children: React.ReactNode; size: number; font?: string; color?: string; seed: string }> = ({ children, size, font = JP, color = TEXT, seed }) => {
  const frame = useCurrentFrame();
  const burst = frame < 8 || random(`${seed}${Math.floor(frame / 3)}`) > 0.92;
  const dx = burst ? (random(`${seed}x${frame}`) - 0.5) * 26 : 0;
  return (
    <div style={{ fontFamily: font, fontWeight: 700, fontSize: size, color, letterSpacing: ".03em", whiteSpace: "nowrap", textAlign: "center",
      transform: `translateX(${dx}px)`,
      textShadow: `${-4 - Math.abs(dx) / 2}px 0 rgba(255,32,82,.85), ${4 + Math.abs(dx) / 2}px 0 rgba(62,240,216,.85), 0 0 40px rgba(62,240,216,.35)` }}>
      {children}
    </div>
  );
};

/** Big punchy caption: slams in, holds. */
const Cap: React.FC<{ jp?: string; en: string; pos?: "low" | "mid" }> = ({ jp, en, pos = "low" }) => {
  const frame = useCurrentFrame(); const u = useU(); const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 12, mass: 0.5 } });
  return (
    <AbsoluteFill style={{ justifyContent: pos === "low" ? "flex-end" : "center", alignItems: "center", paddingBottom: pos === "low" ? 80 * u : 0 }}>
      <div style={{ textAlign: "center", transform: `scale(${interpolate(s, [0, 1], [1.25, 1])})`, opacity: Math.min(1, s * 1.5), maxWidth: "90%" }}>
        {jp && <div style={{ fontFamily: JP, fontWeight: 700, fontSize: 38 * u, color: TEAL, marginBottom: 4 * u, textShadow: "0 3px 20px #000" }}>{jp}</div>}
        <div style={{ fontFamily: "Plex", fontWeight: 600, fontSize: 64 * u, color: TEXT, letterSpacing: "-.01em", textShadow: "0 4px 30px #000, 0 0 2px #000" }}>{en}</div>
      </div>
    </AbsoluteFill>
  );
};

/* ---------- media ---------- */
const Clip: React.FC<{ src: string; from?: number; rate?: number; zoom?: [number, number]; dur: number; filter?: string }> = ({ src, from = 0, rate = 1, zoom = [1, 1.06], dur, filter }) => {
  const frame = useCurrentFrame(); const shake = useShake();
  return (
    <AbsoluteFill style={{ transform: `${shake} scale(${interpolate(frame, [0, dur], zoom)})`, filter }}>
      <OffthreadVideo src={f(src)} startFrom={from} playbackRate={rate} muted style={{ width: "100%", height: "100%", objectFit: "cover" }} />
    </AbsoluteFill>
  );
};

/** A real vcad capture, framed on the model (cx, cy in capture pixels, 1372×887). */
const Cap2: React.FC<{ src: string; cx: number; cy: number; zoom: [number, number]; dur: number; grade?: string }> = ({ src, cx, cy, zoom, dur, grade = "saturate(.9) contrast(1.08)" }) => {
  const frame = useCurrentFrame(); const shake = useShake(10);
  const s = interpolate(frame, [0, dur], zoom, { easing: Easing.out(Easing.cubic) });
  return (
    <AbsoluteFill style={{ background: "#000", overflow: "hidden" }}>
      <Img src={f(`cap/${src}`)} style={{ position: "absolute", width: "100%", height: "100%", objectFit: "cover",
        objectPosition: `${(cx / 1372) * 100}% ${(cy / 887) * 100}%`,
        transformOrigin: `${(cx / 1372) * 100}% ${(cy / 887) * 100}%`, transform: `${shake} scale(${s})`, filter: grade }} />
    </AbsoluteFill>
  );
};

/** Stop-motion through capture frames (the real Explode slider). */
const Flip: React.FC<{ frames: string[]; each: number; cx: number; cy: number; zoom: [number, number] }> = ({ frames, each, cx, cy, zoom }) => {
  const frame = useCurrentFrame();
  const i = Math.min(frames.length - 1, Math.floor(frame / each));
  return <Cap2 src={frames[i]} cx={cx} cy={cy} zoom={zoom} dur={frames.length * each} />;
};

const Cursor: React.FC<{ x: number; y: number; label?: string }> = ({ x, y, label }) => {
  const u = useU();
  return (
    <div style={{ position: "absolute", left: `${x}%`, top: `${y}%` }}>
      <svg width={46 * u} height={46 * u} viewBox="0 0 24 24" style={{ filter: "drop-shadow(0 0 10px rgba(255,32,82,.8))" }}>
        <path d="M3 2l7.5 19 2.6-7.9L21 10.5z" fill="#fff" stroke="#000" strokeWidth="1" />
      </svg>
      {label && <div style={{ marginLeft: 36 * u, marginTop: -6 * u, fontFamily: "PlexMono", fontSize: 26 * u, background: RED, color: "#fff", padding: `${4 * u}px ${12 * u}px`, borderRadius: 8 * u, display: "inline-block" }}>{label}</div>}
    </div>
  );
};

const Terminal: React.FC<{ text: string; start?: number }> = ({ text, start = 0 }) => {
  const frame = useCurrentFrame(); const u = useU();
  const shown = text.slice(0, Math.max(0, Math.floor((frame - start) * 2.2)));
  return (
    <div style={{ position: "absolute", left: "5%", top: "8%", background: "rgba(4,12,14,.92)", border: "1px solid #145", borderRadius: 14 * u, fontFamily: "PlexMono", fontSize: 42 * u, padding: `${20 * u}px ${30 * u}px`, color: TEXT, boxShadow: "0 30px 90px #000" }}>
      <span style={{ color: TEAL }}>&gt; </span>{shown}<span style={{ opacity: frame % 16 < 8 ? 1 : 0 }}>▍</span>
    </div>
  );
};

/* receipts lock-on */
const Receipts: React.FC = () => {
  const frame = useCurrentFrame(); const u = useU(); const { fps } = useVideoConfig();
  const rows: [string, string][] = [["clearance ≥ 3 mm", "4.00 mm"], ["mass ≤ 900 g", "804 g"], ["fits printer bed", "120 × 80"]];
  const stamp = spring({ frame: frame - 54, fps, config: { damping: 9, mass: 0.6 } });
  return (
    <AbsoluteFill>
      <Cap2 src="stirling-0.jpg" cx={690} cy={470} zoom={[1.5, 1.75]} dur={90} grade="brightness(.55) saturate(.6)" />
      <div style={{ position: "absolute", left: "50%", top: "46%", transform: "translate(-50%,-50%)", width: "62%", display: "flex", flexDirection: "column", gap: 16 * u, fontFamily: "PlexMono", fontSize: 34 * u }}>
        {rows.map(([k, v], i) => {
          const t = frame - i * 12;
          const on = t > 6;
          const s = spring({ frame: t, fps, config: { damping: 14 } });
          return (
            <div key={k} style={{ display: "flex", justifyContent: "space-between", background: "rgba(2,10,12,.94)", border: `2px solid ${on ? TEAL : "#145"}`, boxShadow: on ? "0 0 30px rgba(62,240,216,.3)" : "none", padding: `${16 * u}px ${24 * u}px`, color: TEXT, opacity: t > 0 ? 1 : 0, transform: `translateX(${interpolate(s, [0, 1], [80, 0])}px) scale(${on && t < 10 ? 1.04 : 1})` }}>
              <span>{k}</span><span style={{ color: on ? TEAL : "#4a7a74" }}>{on ? `${v} · HOLDS` : "checking…"}</span>
            </div>
          );
        })}
      </div>
      {frame > 54 && (
        <div style={{ position: "absolute", left: "70%", top: "70%", transform: `translate(-50%,-50%) rotate(-8deg) scale(${interpolate(stamp, [0, 1], [2.4, 1])})`, opacity: Math.min(1, stamp * 1.4), border: `${10 * u}px solid ${RED}`, padding: `0 ${36 * u}px`, fontFamily: JP, fontWeight: 900, fontSize: 150 * u, color: RED, textShadow: "0 0 40px rgba(255,32,82,.5)" }}>確認</div>
      )}
    </AbsoluteFill>
  );
};

const Keys: React.FC = () => {
  const u = useU(); const frame = useCurrentFrame();
  const press = frame < 6 ? 0.9 : 1;
  return (
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center" }}>
      <div style={{ display: "flex", gap: 24 * u, transform: `scale(${press})` }}>
        {["⌘", "Z"].map((k) => (
          <div key={k} style={{ width: 140 * u, height: 140 * u, borderRadius: 26 * u, background: "linear-gradient(#1d2a2c,#0d1416)", border: "1px solid #2a4446", boxShadow: "0 10px 0 #050909, 0 30px 60px #000", display: "flex", alignItems: "center", justifyContent: "center", fontFamily: "Plex", fontWeight: 600, fontSize: 66 * u, color: TEXT }}>{k}</div>
        ))}
      </div>
    </AbsoluteFill>
  );
};

const Word: React.FC<{ text: string; bg?: string }> = ({ text, bg = "#05090a" }) => {
  const u = useU(); const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ background: bg, alignItems: "center", justifyContent: "center" }}>
      <div style={{ transform: `scale(${interpolate(frame, [0, 30], [1.15, 1], clamp)})` }}>
        <Glitch size={150 * u} font="Plex" seed={text}>{text}</Glitch>
      </div>
    </AbsoluteFill>
  );
};

const End: React.FC<{ dur: number }> = ({ dur }) => {
  const frame = useCurrentFrame(); const u = useU();
  const a = (s: number) => interpolate(frame, [s, s + 10], [0, 1], clamp);
  return (
    <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 45%,#0a1d22,#010304 70%)", alignItems: "center", justifyContent: "center", opacity: interpolate(frame, [dur - 15, dur], [1, 0], clamp) }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 16 * u }}>
        <Img src={f("icon.png")} style={{ width: 170 * u, opacity: a(0), transform: `scale(${interpolate(frame, [0, 12], [1.4, 1], clamp)})` }} />
        <div style={{ opacity: a(3) }}><Glitch size={170 * u} font="Plex" seed="end">vcad</Glitch></div>
        <div style={{ opacity: a(12), fontFamily: JP, fontWeight: 700, fontSize: 44 * u, color: TEAL, textAlign: "center" }}>あなたのCADに、あなたのエージェントを。</div>
        <div style={{ opacity: a(18), fontFamily: "Plex", fontSize: 46 * u, color: "#cfdedb" }}>Your agent, in your CAD.</div>
        <div style={{ opacity: a(30), fontFamily: "PlexMono", fontSize: 36 * u, color: RED, letterSpacing: ".1em", marginTop: 26 * u }}>FREE FOR MAC · VCAD.IO</div>
      </div>
    </AbsoluteFill>
  );
};

const Title: React.FC = () => {
  const u = useU();
  return <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", paddingBottom: 140 * u }}><Glitch size={110 * u} seed="t1">CADに、誰かいる。</Glitch></AbsoluteFill>;
};

/* ---------- timeline ---------- */
const ST = ["stirling-0.jpg", "stirling-1.jpg", "stirling-2.jpg", "stirling-3.jpg", "stirling-4.jpg", "stirling-5.jpg"];
type Cut = { at: number; len: number; el: React.ReactNode; hit?: boolean; sfx?: string };
const CUTS: Cut[] = [
  { at: 0, len: 96, el: <><Clip src="C1.mp4" dur={96} rate={1.5} zoom={[1, 1.08]} /><Title /><Cap en="Someone's in your CAD." /></> },
  { at: 96, len: 30, el: <Clip src="H2.mp4" from={45} rate={2.2} dur={30} zoom={[1, 1.3]} filter="hue-rotate(-18deg) saturate(1.3)" />, hit: true, sfx: "whoosh.wav" },
  { at: 126, len: 84, el: <><Clip src="G4.mp4" rate={1.6} dur={84} /><Sequence from={20}><Cap en="It's your agent." /></Sequence></>, hit: true, sfx: "glitch.wav" },
  { at: 210, len: 120, el: <><Clip src="X1.mp4" dur={120} zoom={[1, 1.08]} /><Terminal text="make a stirling engine with a flywheel" /><Sequence from={70}><Cursor x={58} y={44} label="claude" /></Sequence><Sequence from={40}><Cap en="Ask for a part. Watch it get built." /></Sequence></>, hit: true },
  { at: 330, len: 90, el: <><Receipts /><Cap en="Every claim, checked." /></>, hit: true, sfx: "glitch.wav" },
  { at: 420, len: 60, el: <><Flip frames={ST} each={6} cx={690} cy={430} zoom={[1.6, 1.5]} /><Sequence durationInFrames={18}><Keys /></Sequence><Sequence from={10}><Cap en="Undo anything." /></Sequence></>, hit: true, sfx: "rewind.wav" },
  { at: 480, len: 140, el: <><Clip src="R6.mp4" rate={1.6} dur={140} zoom={[1, 1.05]} /><Sequence from={30}><Cap en="Design robots." /></Sequence></>, hit: true, sfx: "whoosh.wav" },
  { at: 620, len: 70, el: <><Clip src="X6.mp4" rate={1.7} dur={70} zoom={[1.02, 1.1]} /><Cap en="Pose every joint." /></>, hit: true },
  { at: 690, len: 46, el: <><Clip src="X2.mp4" rate={2.6} dur={46} zoom={[1, 1.1]} /><Cap en="Motors." pos="mid" /></>, hit: true },
  { at: 736, len: 46, el: <><Clip src="X3.mp4" rate={2.6} dur={46} zoom={[1, 1.1]} /><Cap en="Circuit boards." pos="mid" /></>, hit: true },
  { at: 782, len: 46, el: <><Clip src="X4.mp4" rate={2.6} dur={46} zoom={[1, 1.1]} /><Cap en="Machined parts." pos="mid" /></>, hit: true },
  { at: 828, len: 46, el: <><Clip src="X5.mp4" rate={2.6} dur={46} zoom={[1, 1.1]} /><Cap en="Brackets." pos="mid" /></>, hit: true },
  { at: 874, len: 28, el: <Word text="Free." />, hit: true, sfx: "stamp.wav" },
  { at: 902, len: 28, el: <Word text="Native." />, hit: true, sfx: "stamp.wav" },
  { at: 930, len: 30, el: <Word text="No account." />, hit: true, sfx: "stamp.wav" },
  { at: 960, len: 180, el: <End dur={180} />, hit: true, sfx: "taiko.wav" },
];

export const Yurei: React.FC = () => {
  const { fps } = useVideoConfig();
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <Fonts />
      {CUTS.map((c, i) => (
        <Sequence key={i} from={c.at} durationInFrames={c.len}>
          {c.el}
          {c.hit && <Sequence durationInFrames={5}><Hit /></Sequence>}
        </Sequence>
      ))}
      <Post />
      {/* sound */}
      <Audio src={f("score.m4a")} volume={(fr) => interpolate(fr, [0, 6, YUREI.frames - 45, YUREI.frames], [0.9, 0.85, 0.85, 0], clamp)} />
      <Audio src={f("taiko.wav")} volume={1} />
      {CUTS.filter((c) => c.sfx).map((c, i) => (
        <Sequence key={`s${i}`} from={Math.max(0, c.at - (c.sfx === "whoosh.wav" ? 6 : 0))}>
          <Audio src={f(c.sfx!)} volume={c.sfx === "stamp.wav" ? 0.7 : 0.75} />
        </Sequence>
      ))}
      {void fps}
    </AbsoluteFill>
  );
};
