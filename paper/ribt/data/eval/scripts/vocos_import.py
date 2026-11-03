"""§29.2 step 1: charactr/vocos-mel-24khz (MIT) -> ribt vocoder safetensors (model.rs V1 naming).

vocos_import.py OUT.safetensors [--f0]   (--f0 adds a zero src.w so the file loads as v1f0 = same function)

Mapping (checked against model.rs `vocoder`/`istft` and vocos 0.1.0):
  backbone.embed (Conv1d 100->512 k7 p3)      -> embed.w [512,100,7], embed.b
  backbone.norm (LN eps 1e-6)                 -> norm.g/b
  backbone.convnext.i.dwconv [512,1,7]        -> blocks.i.dw.w [512,7], dw.b
  .norm / .pwconv1 [1536,512] / .pwconv2 / .gamma -> ln.g/b, pw1.w/b, pw2.w/b, gamma
  backbone.final_layer_norm                   -> final.g/b
  head.out Linear(512, n_fft+2): rows [:513] = log-mag, [513:] = phase (x.chunk(2, dim=1))
                                              -> head.mag.w/b, head.ph.w/b
  Head: mag = clip(exp(a), max=100), S = mag·e^{iφ}; ISTFT padding "same", periodic hann,
  irfft norm="backward", divide by Σw² — identical to model.rs `istft` (dsp::istft_bases/ola).
Known non-identities: our GELU is the tanh form (Vocos: erf); our mel floor 1e-5 (Vocos 1e-7)."""
import sys, numpy as np, torch
from safetensors.numpy import save_file
from vocos import Vocos

out = sys.argv[1]; f0 = "--f0" in sys.argv
sd = {k: v.detach().float().cpu().numpy() for k, v in Vocos.from_pretrained("charactr/vocos-mel-24khz").state_dict().items()}
o = {}
def put(n, a): o[n] = np.ascontiguousarray(a.astype(np.float32))
put("embed.w", sd["backbone.embed.weight"]); put("embed.b", sd["backbone.embed.bias"])
put("norm.g", sd["backbone.norm.weight"]); put("norm.b", sd["backbone.norm.bias"])
L = 1 + max(int(k.split(".")[2]) for k in sd if k.startswith("backbone.convnext."))
for i in range(L):
    p = f"backbone.convnext.{i}."; q = f"blocks.{i}."
    put(q + "dw.w", sd[p + "dwconv.weight"][:, 0, :]); put(q + "dw.b", sd[p + "dwconv.bias"])
    put(q + "ln.g", sd[p + "norm.weight"]); put(q + "ln.b", sd[p + "norm.bias"])
    put(q + "pw1.w", sd[p + "pwconv1.weight"]); put(q + "pw1.b", sd[p + "pwconv1.bias"])
    put(q + "pw2.w", sd[p + "pwconv2.weight"]); put(q + "pw2.b", sd[p + "pwconv2.bias"])
    put(q + "gamma", sd[p + "gamma"])
put("final.g", sd["backbone.final_layer_norm.weight"]); put("final.b", sd["backbone.final_layer_norm.bias"])
W, b = sd["head.out.weight"], sd["head.out.bias"]; k = W.shape[0] // 2
assert k == 513 and W.shape[1] == 512 and L == 8, (W.shape, L)
put("head.mag.w", W[:k]); put("head.mag.b", b[:k]); put("head.ph.w", W[k:]); put("head.ph.b", b[k:])
if f0: put("src.w", np.zeros((512, 102, 7)))
o["meta.step"] = np.zeros(1, np.float32)
left = [n for n in sd if not n.startswith("feature_extractor") and not any(n.startswith(s) for s in ("backbone.", "head.out", "head.istft"))]
assert not left, left
save_file(o, out); print(out, len(o), "tensors,", sum(v.size for v in o.values()), "values")
