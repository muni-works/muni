"""retry the htk->slaney mel map for BigVGAN in the log domain (affine, fit on non-held clips)."""
import glob, os, sys, json
import numpy as np, soundfile as sf, torch, torchaudio
OUT, PRED = sys.argv[1:3]; dev = "cuda"
BD = os.path.expanduser("~/runs/ribt-gap/ext/bigvgan"); sys.path.insert(0, BD)
import bigvgan as bv
from meldataset import get_mel_spectrogram
from env import AttrDict
h = AttrDict(json.load(open(f"{BD}/config.json")))
big = bv.BigVGAN(h, use_cuda_kernel=False)
big.load_state_dict(torch.load(f"{BD}/bigvgan_generator.pt", map_location="cpu")["generator"]); big.remove_weight_norm(); big = big.to(dev).eval()
rd = lambda f: sf.read(f, dtype="float32")[0]
A, B = [], []
with torch.no_grad():
    for f in sorted(glob.glob(f"{OUT}/fit/*.wav")):
        x = rd(f); n = os.path.basename(f)[:-4]
        a = torch.from_numpy(np.load(f"{OUT}/fitmel/{n}.npy")).to(dev)  # our own ln-mel (ribt mel)
        b = get_mel_spectrogram(torch.from_numpy(x)[None].to(dev), h)[0]
        t = min(a.shape[1], b.shape[1]); off = b.shape[1] - a.shape[1]
        A.append(a.T); B.append(b[:, off // 2: off // 2 + a.shape[1]].T)
    A = torch.cat(A).double(); B = torch.cat(B).double(); A1 = torch.cat([A, torch.ones(len(A), 1, device=dev, dtype=A.dtype)], 1)
    W = torch.linalg.lstsq(A1, B).solution.float()
    print("fit rmse (ln)", float(((A1.float() @ W - B.float()) ** 2).mean().sqrt()), flush=True)
    m2b = lambda m: (torch.cat([torch.from_numpy(m).float().to(dev).T, torch.ones(m.shape[1], 1, device=dev)], 1) @ W).T[None]
    def wr(d, n, y): os.makedirs(d, exist_ok=True); sf.write(f"{d}/{n}", np.clip(y, -1, 1), 24000)
    for f in sorted(glob.glob(f"{OUT}/ourmel/*.npy")):
        wr(f"{OUT}/bigvgan_logmap", os.path.basename(f)[:-4] + ".wav", big(m2b(np.load(f))).cpu().numpy()[0, 0])
    for f in sorted(glob.glob(f"{PRED}/*_ref.mel.npy")):
        wr(f"{OUT}/pred_bigvgan_logmap", os.path.basename(f).replace("_ref.mel.npy", ".wav"), big(m2b(np.load(f))).cpu().numpy()[0, 0])
print("done")
