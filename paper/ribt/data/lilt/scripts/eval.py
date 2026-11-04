"""docs §27: is each oov_fun.tsv target word audible in the render, per lilt arm?

    python -I eval.py oov_fun.tsv RENDER_DIR ARM [ARM ...]

Whisper small.en transcribes RENDER_DIR/ARM/fNN_*.wav twice: unprompted, and prompted with the
target vocabulary (as in bon/hardeval.py; lenient). A target is *said* if some 1-3 word span of the
transcript matches the word or its expected reading at character-similarity >= 0.6 (letters and
digits only). Writes RENDER_DIR/eval.tsv (arm, id, word, category, hit, hit_prompted, hyp).
"""
import difflib, glob, os, re, sys

import numpy as np
import soundfile as sf
import whisper
from scipy.signal import resample_poly


def key(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def said(target_forms, hyp):
    ws = hyp.split()
    best = 0.0
    for n in (1, 2, 3):
        for i in range(len(ws) - n + 1):
            span = key("".join(ws[i:i + n]))
            for t in target_forms:
                best = max(best, difflib.SequenceMatcher(None, t, span).ratio())
    return best


rows = [l.rstrip("\n").split("\t") for l in open(sys.argv[1]) if l.strip() and not l.startswith("#")]
out, arms = sys.argv[2], sys.argv[3:]
m = whisper.load_model("small.en")
prompt = "Vocabulary: " + ", ".join(r[0] for r in rows) + "."
res = []
for arm in arms:
    for i, (w, reading, cat, sent) in enumerate(rows):
        p = glob.glob(os.path.join(out, arm, f"f{i:02d}_*.wav"))[0]
        x, sr = sf.read(p, dtype="float32")
        x16 = resample_poly(x, 2, 3).astype(np.float32)
        h = m.transcribe(x16, language="en", fp16=False, temperature=0.0)["text"].strip()
        hp = m.transcribe(x16, language="en", fp16=False, temperature=0.0, initial_prompt=prompt)["text"].strip()
        forms = {key(w), key(reading)}
        s, sp = said(forms, h), said(forms, hp)
        res.append((arm, f"f{i:02d}", w, cat, s, sp, h))
        print(f"{arm}\tf{i:02d}\t{w}\t{s:.2f}\t{sp:.2f}\t{h}", flush=True)
with open(os.path.join(out, "eval.tsv"), "w") as f:
    f.write("arm\tid\tword\tcategory\tsim\tsim_prompted\thyp\n")
    for r in res:
        f.write("\t".join(map(str, r[:4])) + f"\t{r[4]:.3f}\t{r[5]:.3f}\t{r[6]}\n")
print()
for arm in arms:
    sel = [r for r in res if r[0] == arm]
    print(f"{arm}: said (sim>=0.6) {sum(r[4] >= 0.6 for r in sel)}/{len(sel)}   prompted {sum(r[5] >= 0.6 for r in sel)}/{len(sel)}   exact-ish (>=0.85) {sum(r[4] >= 0.85 for r in sel)}/{len(sel)}")
    for c in sorted({r[3] for r in sel}):
        cs = [r for r in sel if r[3] == c]
        print(f"    {c:<8} {sum(r[4] >= 0.6 for r in cs)}/{len(cs)}  prompted {sum(r[5] >= 0.6 for r in cs)}/{len(cs)}")
