"""Intelligibility + naturalness of synthesized TTS (docs §14).

    python -I scripts/tts_asr.py SYNTH_DIR [--gt-root LIBRITTS_R/test-clean] [--model small.en] [--utmos]

Reads SYNTH_DIR/synth.tsv (`ribt-tts synth` output): Whisper transcribes
each `{name}_{speaker}.wav`; WER vs the input text after Whisper's English
normalizer (jiwer, corpus-level). With --gt-root, the same is done for the
ground-truth recordings (name = LibriTTS utt id) as the ceiling. --utmos adds
SpeechMOS utmos22_strong (torch hub) for both. Writes asr.tsv to SYNTH_DIR.
"""
import argparse
import csv
import os

import jiwer
import numpy as np
import soundfile as sf
import torch
import whisper
from whisper.normalizers import EnglishTextNormalizer


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("synth")
    ap.add_argument("--gt-root")
    ap.add_argument("--model", default="small.en")
    ap.add_argument("--utmos", action="store_true")
    a = ap.parse_args()
    rows = list(csv.DictReader(open(os.path.join(a.synth, "synth.tsv")), delimiter="\t", quoting=csv.QUOTE_NONE))
    norm = EnglishTextNormalizer()
    m = whisper.load_model(a.model)
    utmos = None
    if a.utmos:
        utmos = torch.hub.load("tarepan/SpeechMOS:v1.2.0", "utmos22_strong", trust_repo=True).eval()

    def run(path):
        x, sr = sf.read(path, dtype="float32")
        assert sr == 24000
        x16 = whisper.audio.resample(torch.from_numpy(x), 24000, 16000).numpy() if hasattr(whisper.audio, "resample") else None
        if x16 is None:
            import scipy.signal
            x16 = scipy.signal.resample_poly(x, 2, 3).astype(np.float32)
        hyp = m.transcribe(x16, language="en", fp16=False, temperature=0.0)["text"]
        mos = float(utmos(torch.from_numpy(x)[None], 24000)[0]) if utmos is not None else float("nan")
        return hyp, mos

    out = []
    for r in rows:
        p = os.path.join(a.synth, f"{r['name']}_{r['speaker']}.wav")
        hyp, mos = run(p)
        rec = dict(kind="tts", name=r["name"], speaker=r["speaker"], ref=norm(r["text"]), hyp=norm(hyp), utmos=mos)
        out.append(rec)
        if a.gt_root:
            u = r["name"]
            s, c = u.split("_")[:2]
            gp = os.path.join(a.gt_root, s, c, u + ".wav")
            if os.path.exists(gp):
                gh, gm = run(gp)
                out.append(dict(kind="gt", name=u, speaker=s, ref=norm(r["text"]), hyp=norm(gh), utmos=gm))
        print(f"{rec['name']}: {rec['hyp']}", flush=True)
    with open(os.path.join(a.synth, "asr.tsv"), "w") as f:
        f.write("kind\tname\tspeaker\tutmos\tref\thyp\n")
        for o in out:
            f.write(f"{o['kind']}\t{o['name']}\t{o['speaker']}\t{o['utmos']:.3f}\t{o['ref']}\t{o['hyp']}\n")
    for kind in ["tts", "gt"]:
        sel = [o for o in out if o["kind"] == kind and o["ref"].strip()]
        if not sel:
            continue
        w = jiwer.wer([o["ref"] for o in sel], [o["hyp"] for o in sel])
        c = jiwer.cer([o["ref"] for o in sel], [o["hyp"] for o in sel])
        mos = np.nanmean([o["utmos"] for o in sel]) if a.utmos else float("nan")
        print(f"{kind}: n={len(sel)}  WER {100 * w:.2f}%  CER {100 * c:.2f}%  UTMOS {mos:.3f}  (whisper {a.model})")


if __name__ == "__main__":
    main()
