#!/usr/bin/env python3
"""Render the af_heart distillation corpus with Kokoro (docs/voice-model.md §24).

RESEARCH-ONLY: Kokoro-82M's training data included synthetic audio from closed
commercial TTS providers. Audio made here is not licence-clean.

    ~/venvs/kokoro/bin/python gen.py TEXTS.tsv OUT_ROOT --lufs L [--shard i/n] [--vocab kokoro_vocab.json]

Layout (LibriTTS-like, ROOT=OUT_ROOT/.., split=afheart):
    OUT_ROOT/<chunk>/afheart_<chunk>_<n>.{wav,original.txt,normalized.txt}
plus OUT_ROOT/shards/meta.<i>.tsv (id, kind, src_id, text, seconds, lufs_in, gain_db, peak,
rms, sil_frac, ok, reason, phonemes) and phon.<i>.tsv in phonemize_libritts.py's format,
built from Kokoro's own misaki phonemes (exactly what the audio was rendered from).
Resumable: ids already in meta.<i>.tsv are skipped.
"""
import argparse
import json
import os
from pathlib import Path

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
import torch
from kokoro import KPipeline

SR = 24000
PER_CHUNK = 1000


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("texts")
    ap.add_argument("out")
    ap.add_argument("--lufs", type=float, required=True)
    ap.add_argument("--shard", default="0/1")
    ap.add_argument("--voice", default="af_heart")
    ap.add_argument("--redo-rejects", action="store_true", help="re-render only ids whose last meta row was rejected")
    ap.add_argument("--vocab", default=str(Path(__file__).resolve().parent.parent.parent / "assets" / "kokoro_vocab.json"))
    a = ap.parse_args()
    si, sn = map(int, a.shard.split("/"))
    vocab = json.load(open(a.vocab))["vocab"]
    rows = [l.rstrip("\n").split("\t") for l in open(a.texts) if l.strip()]
    out = Path(a.out)
    (out / "shards").mkdir(parents=True, exist_ok=True)
    mp, pp = out / "shards" / f"meta.{si}.tsv", out / "shards" / f"phon.{si}.tsv"
    done, last_ok = set(), {}
    if mp.exists():
        for l in open(mp):
            c = l.split("\t")
            done.add(c[0])
            last_ok[c[0]] = c[10] == "1"
    if a.redo_rejects:
        done = {k for k, v in last_ok.items() if v}
    mf, pf = open(mp, "a"), open(pp, "a")
    pipe = KPipeline(lang_code="a", device="cuda" if torch.cuda.is_available() else "cpu")
    meter = pyln.Meter(SR)
    for gi, (src, kind, text) in enumerate(rows):
        if gi % sn != si:
            continue
        chunk = f"{gi // PER_CHUNK:05d}"
        uid = f"afheart_{chunk}_{gi % PER_CHUNK:06d}"
        if uid in done:
            continue
        auds, phs = [], []
        for res in pipe(text, voice=a.voice):
            if res.audio is not None:
                auds.append(np.asarray(res.audio, dtype=np.float32))
            phs.append(res.phonemes or "")
        ps = " ".join(p for p in phs if p).strip()
        x = np.concatenate(auds) if auds else np.zeros(0, np.float32)
        ok, reason = True, ""
        sec = len(x) / SR
        lin = gain = peak = rms = sil = float("nan")
        if len(x) < SR // 4 or not np.isfinite(x).all() or not ps:
            ok, reason = False, "empty/nan/no-phonemes"
        else:
            lin = meter.integrated_loudness(x) if sec >= 0.4 else 20 * np.log10(np.sqrt(np.mean(x**2)) + 1e-9) - 0.7
            gain = a.lufs - lin
            y = x * 10 ** (gain / 20)
            peak = float(np.abs(y).max())
            if peak > 0.98:  # limit by scaling, never clip
                y *= 0.98 / peak
                gain += 20 * np.log10(0.98 / peak)
                peak = 0.98
            x = y
            rms = float(np.sqrt(np.mean(x**2)))
            fr = x[: len(x) // 480 * 480].reshape(-1, 480)
            fdb = 20 * np.log10(np.sqrt((fr**2).mean(1)) + 1e-9)
            sil = float((fdb < fdb.max() - 40).mean())
            if rms < 1e-3:
                ok, reason = False, "silent"
            elif sil > 0.6 and sec > 2.0:  # short words are mostly Kokoro's edge padding
                ok, reason = False, "mostly-silence"
        if ok:
            d = out / chunk
            d.mkdir(exist_ok=True)
            sf.write(d / f"{uid}.wav", x, SR, subtype="PCM_16")
            (d / f"{uid}.original.txt").write_text(text)
            (d / f"{uid}.normalized.txt").write_text(text)
            ids = [0] + [vocab[c] for c in ps if c in vocab] + [0]
            pf.write(f"{uid}\t{' '.join(map(str, ids))}\t{ps}\t0\n")
        mf.write("\t".join(map(str, [uid, kind, src, text, f"{sec:.3f}", f"{lin:.2f}", f"{gain:.2f}",
                                      f"{peak:.4f}", f"{rms:.4f}", f"{sil:.3f}", int(ok), reason, ps])) + "\n")
        mf.flush()
        pf.flush()


if __name__ == "__main__":
    main()
