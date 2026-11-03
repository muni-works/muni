"""Held-out MOS judges (§29.2 step 3b): DNSMOS P.835 (SIG/BAK/OVRL) + P.808, and NISQA-TTS, per dir of wavs.

judges.py DIR [DIR ...]   (models under ~/runs/ribt-utmos/ext: dnsmos/*.onnx, nisqa/ clone)
DNSMOS logic follows microsoft/DNS-Challenge dnsmos_local.py (non-personalized polyfit, 9.01 s tiled input)."""
import glob, os, sys, subprocess, tempfile, numpy as np, soundfile as sf, librosa, onnxruntime as ort, pandas as pd
X = os.path.expanduser("~/runs/ribt-utmos/ext")
so = ort.SessionOptions(); so.intra_op_num_threads = 8
prim = ort.InferenceSession(f"{X}/dnsmos/sig_bak_ovr.onnx", so, providers=["CPUExecutionProvider"])
p808 = ort.InferenceSession(f"{X}/dnsmos/model_v8.onnx", so, providers=["CPUExecutionProvider"])
P_O = np.poly1d([-0.06766283, 1.11546468, 0.04602535]); P_S = np.poly1d([-0.08397278, 1.22083953, 0.0052439])
P_B = np.poly1d([-0.13166888, 1.60915514, -0.39604546])
def mel(a):
    m = librosa.feature.melspectrogram(y=a, sr=16000, n_fft=321, hop_length=160, n_mels=120)
    return ((librosa.power_to_db(m, ref=np.max) + 40) / 40).T
def dns(f):
    a, sr = sf.read(f, dtype="float32"); a = librosa.resample(a, orig_sr=sr, target_sr=16000) if sr != 16000 else a
    L = int(9.01 * 16000)
    while len(a) < L: a = np.append(a, a)
    hops = int(np.floor(len(a) / 16000) - 9.01) + 1; r = []
    for i in range(hops):
        s = a[i * 16000: i * 16000 + L]
        if len(s) < L: continue
        sg, bk, ov = prim.run(None, {"input_1": s[None]})[0][0]
        p = p808.run(None, {"input_1": mel(s[:-160])[None].astype(np.float32)})[0][0][0]
        r.append((P_S(sg), P_B(bk), P_O(ov), p))
    return np.mean(r, 0)
def nisqa(d):
    with tempfile.TemporaryDirectory() as o:
        subprocess.run([sys.executable, f"{X}/nisqa/run_predict.py", "--mode", "predict_dir", "--pretrained_model",
                        f"{X}/nisqa/weights/nisqa_tts.tar", "--data_dir", d, "--num_workers", "0", "--bs", "10", "--output_dir", o],
                       cwd=f"{X}/nisqa", check=True, capture_output=True)
        return pd.read_csv(f"{o}/NISQA_results.csv")["mos_pred"].mean()
for d in sys.argv[1:]:
    v = np.array([dns(f) for f in sorted(glob.glob(f"{d}/*.wav"))])
    try: n = nisqa(d)
    except Exception as e: n = float("nan"); print("nisqa failed:", e, file=sys.stderr)
    print(f"{d}\tDNSMOS sig {v[:,0].mean():.3f} bak {v[:,1].mean():.3f} ovrl {v[:,2].mean():.3f} p808 {v[:,3].mean():.3f}\tNISQA-TTS {n:.3f}\tn {len(v)}", flush=True)
