"""§29.1 band/artifact metrics vs the real clips (CPU). bands.py OUT SYS [SYS ...]
LSD by band (2048-pt STFT, hop 256), HNR (praat cc) on real-voiced frames, spectral flatness (1-12 kHz) on real-unvoiced non-silent frames."""
import glob, os, sys
import numpy as np, soundfile as sf, parselmouth

OUT = sys.argv[1]; SYS = sys.argv[2:]
BANDS = [(0, 1000), (1000, 4000), (4000, 8000), (8000, 12000)]
sr, nf, hop = 24000, 2048, 256
win = np.hanning(nf)

def rd(f): return sf.read(f, dtype="float64")[0]

def align(x, y, L=800):
    n = min(len(x), len(y), 48000)
    c = np.fft.irfft(np.fft.rfft(x[:n], 2 * n) * np.conj(np.fft.rfft(y[:n], 2 * n)))
    lags = np.r_[0:L, -L:0]; v = np.r_[c[0:L], c[-L:]]
    lag = int(lags[np.argmax(v)])
    y = np.roll(np.pad(y, (L, L)), lag)[L:-L] if lag else y
    m = min(len(x), len(y)); return x[:m], y[:m]

def pspec(x):
    fr = np.lib.stride_tricks.sliding_window_view(np.pad(x, nf // 2), nf)[::hop] * win
    return np.abs(np.fft.rfft(fr, axis=1)) ** 2 + 1e-12

fq = np.fft.rfftfreq(nf, 1 / sr)

def masks(x):
    s = parselmouth.Sound(x, sr)
    p = s.to_pitch(time_step=hop / sr, pitch_floor=75, pitch_ceiling=600)
    P = pspec(x); T = P.shape[0]
    tt = np.arange(T) * hop / sr
    f0 = np.array([p.get_value_at_time(t) or 0 for t in tt]); f0 = np.nan_to_num(f0)
    e = 10 * np.log10(P.sum(1)); act = e > e.max() - 50
    return f0 > 0, (f0 == 0) & act, act, tt

def hnr(x, tt, vm):
    hh = parselmouth.Sound(x, sr).to_harmonicity_cc(time_step=hop / sr, minimum_pitch=75)
    v = np.array([hh.get_value(t) for t in tt[vm]]); v = v[np.isfinite(v) & (v > -100)]
    return v.mean() if len(v) else np.nan

def flat(P, um):
    b = (fq >= 1000) & (fq <= 12000); Q = P[um][:, b]
    return np.mean(np.exp(np.log(Q).mean(1)) / Q.mean(1)) if len(Q) else np.nan

rows = {s: [] for s in ["real"] + SYS}
for f in sorted(glob.glob(f"{OUT}/real/*.wav")):
    n = os.path.basename(f); x = rd(f)
    vm, um, act, tt = masks(x); Px = pspec(x)
    rows["real"].append([0, 0, 0, 0, hnr(x, tt, vm), flat(Px, um)])
    for s in SYS:
        xa, y = align(x, rd(f"{OUT}/{s}/{n}"))
        Pxa, Py = pspec(xa), pspec(y); T = min(len(Pxa), len(Py), len(act))
        a = act[:T]; d = 10 * np.log10(Py[:T][a]) - 10 * np.log10(Pxa[:T][a])
        lsd = [np.mean(np.sqrt(np.mean(d[:, (fq >= lo) & (fq < hi)] ** 2, 1))) for lo, hi in BANDS]
        rows[s].append(lsd + [hnr(y, tt[:T], vm[:T]), flat(Py[:T], um[:T])])
print("system\tLSD0-1k\tLSD1-4k\tLSD4-8k\tLSD8-12k\tHNR_voiced_dB\tflatness_unvoiced")
for s, r in rows.items():
    r = np.array(r, float); m = np.nanmean(r, 0)
    print(s + "\t" + "\t".join(f"{v:.3f}" for v in m), flush=True)
