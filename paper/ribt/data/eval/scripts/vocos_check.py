"""vocos_check.py MELDIR OURS_WAVDIR OUTDIR: PyTorch Vocos on our mels (*.npy) vs `ribt infer` of the imported ckpt.
Writes OUTDIR/*.wav (torch reference) and prints max-abs / rms diff per clip (after length crop)."""
import glob, os, sys, numpy as np, soundfile as sf, torch
from vocos import Vocos
M, O, D = sys.argv[1:4]; os.makedirs(D, exist_ok=True)
v = Vocos.from_pretrained("charactr/vocos-mel-24khz").eval()
if os.environ.get("GELU") == "tanh":  # match ribt's ir::gelu (tanh form) to isolate the remaining difference
    for blk in v.backbone.convnext: blk.act = torch.nn.GELU(approximate="tanh")
mx, rel = [], []
for f in sorted(glob.glob(f"{M}/*.npy"))[:int(os.environ.get("N", 1000))]:
    n = os.path.basename(f)[:-4]; m = np.load(f)
    with torch.no_grad(): y = v.decode(torch.from_numpy(m)[None].float()).numpy()[0]
    sf.write(f"{D}/{n}.wav", np.clip(y, -1, 1), 24000)
    if not os.path.exists(f"{O}/{n}.wav"): continue
    x, _ = sf.read(f"{O}/{n}.wav", dtype="float32")
    best = None
    for lag in range(-1024, 1025):  # x[t+lag] ~ y[t]
        a = x[max(lag, 0):]; b = y[max(-lag, 0):]; t = min(len(a), len(b))
        e = np.mean((a[:t] - b[:t]) ** 2)
        if best is None or e < best[0]: best = (e, lag)
    lag = best[1]; a = x[max(lag, 0):]; b = y[max(-lag, 0):]; t = min(len(a), len(b)); a, b = a[:t], b[:t]
    k = 2048; d = np.abs(a[k:-k] - b[k:-k])  # interior (edge frames differ by padding convention)
    mx.append(d.max()); rel.append(np.sqrt((d**2).mean() / (b[k:-k]**2).mean()))
    print(f"{n} len {len(x)}/{len(y)} lag {lag} maxabs {d.max():.2e} rel_rms {rel[-1]:.2e} peak {np.abs(b).max():.2f}")
print(f"n={len(mx)} maxabs max {max(mx):.2e} median {np.median(mx):.2e}  rel_rms median {np.median(rel):.2e}")
