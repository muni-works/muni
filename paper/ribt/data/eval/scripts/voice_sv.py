"""Speaker-verification likeness (§22): WavLM-base-plus-SV x-vectors (microsoft/wavlm-base-plus-sv).

    python -I scripts/voice_sv.py --real DIR_OR_GLOB DIR [DIR ...]

For each DIR (synth dir or wav dir): mean cosine of each clip's x-vector to the centroid of the real
clips' x-vectors ("sv"), and the fraction of clips above the model card's 0.86 same-speaker threshold.
"""
import argparse, glob, os
import numpy as np, soundfile as sf, torch
from scipy.signal import resample_poly
from transformers import AutoFeatureExtractor, WavLMForXVector

M = "microsoft/wavlm-base-plus-sv"
FE = AutoFeatureExtractor.from_pretrained(M); NET = WavLMForXVector.from_pretrained(M).eval()


def emb(p):
    x, sr = sf.read(p, dtype="float32")
    if x.ndim > 1: x = x.mean(1)
    if sr != 16000: x = resample_poly(x, 16000, sr).astype(np.float32)
    with torch.no_grad():
        e = NET(**FE(x, sampling_rate=16000, return_tensors="pt")).embeddings[0]
    return torch.nn.functional.normalize(e, dim=-1).numpy()


def wavs(d):
    return sorted(glob.glob(os.path.join(d, "*.wav"))) if os.path.isdir(d) else sorted(glob.glob(d))


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--real", required=True); ap.add_argument("dirs", nargs="+")
    a = ap.parse_args()
    r = np.stack([emb(p) for p in wavs(a.real)]); c = r.mean(0); c /= np.linalg.norm(c)
    print(f"real: {len(r)} clips, self-sim to centroid {float((r @ c).mean()):.4f}")
    for d in a.dirs:
        e = np.stack([emb(p) for p in wavs(d)]); s = e @ c
        print(f"{d}\tsv {s.mean():.4f}\tmin {s.min():.4f}\tp>0.86 {(s > 0.86).mean():.2f}\tn {len(s)}")


if __name__ == "__main__":
    main()
