"""docs §27 listening set: before/after renders of the oov_fun.tsv sentences (Mac, after scp from mew).

    python3 scripts/oov/listen.py RENDER_DIR OUT_DIR

One wav per sentence: 1 beep + before (main lilt: unknown words dropped), 2 beeps + after (OOV ladder).
Every take is validated and loudness-levelled by scripts/listen.py. No duration check: dropping a word
changes the length, which is the point. README.txt lists word, category, whether main lilt dropped it
(from before.log) and what Whisper heard in each take (from eval.tsv).
"""
import os, sys

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from listen import SR, Rejected, Report, beeps  # noqa: E402

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
here = os.path.dirname(os.path.abspath(__file__))
rows = [l.rstrip("\n").split("\t") for l in open(os.path.join(here, "../../data/lilt/oov_fun.tsv")) if l.strip() and not l.startswith("#")]
ev = {}
if os.path.exists(os.path.join(src, "eval.tsv")):
    for l in list(open(os.path.join(src, "eval.tsv")))[1:]:
        c = l.rstrip("\n").split("\t")
        ev[(c[0], c[1])] = c
dropped = {}
for l in open(os.path.join(src, "before.log")):
    if ": OOV (dropped by lilt): " in l:
        u, rest = l.split(": OOV (dropped by lilt): ", 1)
        dropped[u.strip()] = rest.strip()
rep = Report(f"listening set {out}")
lines = []
for i, (w, reading, cat, sent) in enumerate(rows):
    u = f"f{i:02d}"
    parts = []
    for k, arm in enumerate(["before", "after"], 1):
        p = [f for f in os.listdir(os.path.join(src, arm)) if f.startswith(u + "_") and f.endswith(".wav")][0]
        x, sr = sf.read(os.path.join(src, arm, p), dtype="float64")
        assert sr == SR
        try:
            y = rep.prepare(x, f"{u} {w} [{k}:{arm}]")
        except Rejected:
            continue
        parts += [beeps(k), y, np.zeros(int(0.5 * SR))]
    name = f"{u}_{''.join(c for c in w if c.isalnum())}.wav"
    sf.write(os.path.join(out, name), np.concatenate(parts), SR, subtype="PCM_16")
    hb, ha = (ev.get((a, u), [""] * 7)[6] for a in ("before", "after"))
    d = f"dropped by main lilt: {dropped[u]}" if u in dropped else "spoken by main lilt too"
    lines.append(f"{name}\t{w}\t{cat}\t{reading}\t{sent}\n    {d}\n    before heard: {hb}\n    after  heard: {ha}\n")
with open(os.path.join(out, "README.txt"), "w") as f:
    f.write("RIBT af_heart (ribt-2-afheart, research-only), docs/voice-model.md §27: unknown words.\n")
    f.write("Each file: 1 beep = before (main lilt, unknown words silently dropped), 2 beeps = after (OOV ladder).\n")
    f.write("Takes levelled to -23 LUFS, -1 dBFS true peak (report.txt). 'heard' = Whisper small.en, unprompted.\n\n")
    f.write("file\tword\tcategory\texpected-ish\tsentence\n")
    f.writelines(lines)
    if rep.rejects:
        f.write("REJECTED (not in the set):\n" + "".join(f"  {n}: {', '.join(b)}\n" for n, b in rep.rejects))
rep.write(out)
