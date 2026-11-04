"""§29.1 rung 0: where the vocoder loses. Eval only.

rung0.py OUT  (expects OUT/real/*.wav, OUT/ours/*.wav (ribt infer copy-synth), OUT/ourmel/*.npy (ribt mel),
               PRED (dir of *_ref.mel.npy + *_ref.wav from the chain), KOK (Kokoro held50 wavs), FIT (wav glob for the mel map))
"""
import glob, os, sys, json
import numpy as np, soundfile as sf, torch

OUT, PRED, KOK, FIT = sys.argv[1:5]
dev = "cuda"
sys.path.insert(0, os.path.expanduser("~/runs/ribt-gap/ext/bigvgan"))
import bigvgan as bv
from meldataset import get_mel_spectrogram
from vocos import Vocos

voc = Vocos.from_pretrained("charactr/vocos-mel-24khz").to(dev).eval()
BD = os.path.expanduser("~/runs/ribt-gap/ext/bigvgan")
from env import AttrDict
h = AttrDict(json.load(open(f"{BD}/config.json")))
big = bv.BigVGAN(h, use_cuda_kernel=False)
big.load_state_dict(torch.load(f"{BD}/bigvgan_generator.pt", map_location="cpu")["generator"])
big.remove_weight_norm(); big = big.to(dev).eval()
fb_ours = None

def rd(f):
    x, sr = sf.read(f, dtype="float32"); assert sr == 24000, f
    return x

def wr(d, name, y):
    os.makedirs(d, exist_ok=True); sf.write(os.path.join(d, name), np.clip(y, -1, 1), 24000)

@torch.no_grad()
def vocos_wav(x):
    return voc.decode(voc.feature_extractor(torch.from_numpy(x)[None].to(dev))).cpu().numpy()[0]

@torch.no_grad()
def vocos_mel(m):  # our ln-mel [100,T]; same htk/power-1 fbank as Vocos
    return voc.decode(torch.from_numpy(m)[None].float().to(dev)).cpu().numpy()[0]

@torch.no_grad()
def big_mel_of(x):
    return get_mel_spectrogram(torch.from_numpy(x)[None].to(dev), h)[0].cpu().numpy()

@torch.no_grad()
def big_dec(m):
    return big(torch.from_numpy(m)[None].float().to(dev)).cpu().numpy()[0, 0]

import torchaudio
htk = torchaudio.transforms.MelSpectrogram(24000, n_fft=1024, hop_length=256, n_mels=100, power=1, center=True, mel_scale="htk", norm=None).to(dev)

# linear map exp(our htk mel) -> exp(BigVGAN slaney mel), least squares on FIT clips (not held)
@torch.no_grad()
def fit_map():
    A, B = [], []
    for f in sorted(glob.glob(FIT))[:300]:
        x = torch.from_numpy(rd(f))[None].to(dev)
        a = htk(x)[0]; b = torch.exp(torch.from_numpy(big_mel_of(rd(f))).to(dev))
        t = min(a.shape[1], b.shape[1]); A.append(a[:, :t].T); B.append(b[:, :t].T)
    A = torch.cat(A).double(); B = torch.cat(B).double()
    W = torch.linalg.lstsq(A, B).solution  # [100,100]
    return W.float()
W = fit_map()

def our_to_big(m):
    e = torch.from_numpy(np.exp(m)).float().to(dev).T @ W
    return torch.log(torch.clamp(e, min=1e-5)).T.cpu().numpy()

def align(x, y, L=800):
    n = min(len(x), len(y), 48000)
    a, b = x[:n], y[:n]
    c = np.fft.irfft(np.fft.rfft(a, 2 * n) * np.conj(np.fft.rfft(b, 2 * n)))
    lags = np.r_[0:L, -L:0]; v = np.r_[c[0:L], c[-L:]]
    lag = int(lags[np.argmax(v)])  # x[t] ~ y[t-lag]
    y = np.roll(np.pad(y, (L, L)), lag)[L:-L] if lag else y
    m = min(len(x), len(y)); return x[:m], y[:m], lag

real = sorted(glob.glob(f"{OUT}/real/*.wav"))
lags = {}
for f in real:
    n = os.path.basename(f); x = rd(f)
    wr(f"{OUT}/vocos", n, vocos_wav(x))
    wr(f"{OUT}/bigvgan", n, big_dec(big_mel_of(x)))
    m = np.load(f"{OUT}/ourmel/{n[:-4]}.npy")
    wr(f"{OUT}/vocos_ourmel", n, vocos_mel(m))
    wr(f"{OUT}/bigvgan_mapmel", n, big_dec(our_to_big(m)))
    # STFT-swap oracles vs our copy-synthesis
    xa, ya, lag = align(x, rd(f"{OUT}/ours/{n}")); lags[n] = lag
    w = torch.hann_window(1024)
    S = lambda s: torch.stft(torch.from_numpy(s), 1024, 256, window=w, return_complex=True)
    I = lambda Z, L: torch.istft(Z, 1024, 256, window=w, length=L).numpy()
    X, Y = S(xa), S(ya)
    wr(f"{OUT}/oracle_ident", n, I(X, len(xa)))
    wr(f"{OUT}/oracle_realphase_ourmag", n, I(Y.abs() * torch.exp(1j * X.angle()), len(xa)))
    wr(f"{OUT}/oracle_ourphase_realmag", n, I(X.abs() * torch.exp(1j * Y.angle()), len(xa)))
json.dump(lags, open(f"{OUT}/lags.json", "w"))

# predicted mels (chain held50) and Kokoro held50 copy-synthesis
for f in sorted(glob.glob(f"{PRED}/*_ref.mel.npy")):
    n = os.path.basename(f).replace("_ref.mel.npy", ".wav"); m = np.load(f)
    wr(f"{OUT}/pred_vocos", n, vocos_mel(m))
    wr(f"{OUT}/pred_bigvgan", n, big_dec(our_to_big(m)))
for f in sorted(glob.glob(f"{KOK}/*.wav")):
    n = os.path.basename(f).replace("_af_heart.wav", ".wav"); x = rd(f)
    wr(f"{OUT}/kok_vocos", n, vocos_wav(x))
    wr(f"{OUT}/kok_bigvgan", n, big_dec(big_mel_of(x)))
print("done synth", flush=True)
