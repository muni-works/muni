"""UTMOS22-strong mean/p10 over each dir (or glob) of 24 kHz wavs (§24 vocoder gate).

    ~/venvs/voice-eval/bin/python -I utmos_dirs.py DIR [DIR ...]
"""
import glob, os, sys
import numpy as np, soundfile as sf, torch

m = torch.hub.load("tarepan/SpeechMOS:v1.2.0", "utmos22_strong", trust_repo=True).eval()
for d in sys.argv[1:]:
    fs = sorted(glob.glob(os.path.join(d, "*.wav"))) if os.path.isdir(d) else sorted(glob.glob(d))
    v = []
    for f in fs:
        x, sr = sf.read(f, dtype="float32")
        with torch.no_grad():
            v.append(float(m(torch.from_numpy(x)[None], sr)[0]))
    v = np.array(v)
    print(f"{d}\tutmos {v.mean():.3f}\tp10 {np.percentile(v, 10):.3f}\tn {len(v)}", flush=True)
