"""Render a `name<TAB>text[...]` lines file with Kokoro (KPipeline) for the §20 comparisons.

    cd ~/.cache && ~/.cache/kv/bin/python kokoro_set.py LINES OUT_DIR [--voice af_heart]

Writes OUT_DIR/{name}_{voice}.wav (24 kHz) and a synth.tsv in `ribt-tts synth`'s
layout (name, speaker, text, …) so scripts/tts_asr.py scores it unchanged.
Run from ~/.cache as cwd (the kv venv's model cache).
"""
import argparse
import os

import numpy as np
import soundfile as sf
from kokoro import KPipeline


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("lines")
    ap.add_argument("out")
    ap.add_argument("--voice", default="af_heart")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    pipe = KPipeline(lang_code="a")
    rows = [l.rstrip("\n").split("\t") for l in open(a.lines) if l.strip() and not l.startswith("#")]
    with open(os.path.join(a.out, "synth.tsv"), "w") as f:
        f.write("name\tspeaker\ttext\tphonemes\ttokens\tframes\tseconds\tenc_ms\tdec_ms\tvoc_ms\tflow_ms\tnfe\n")
        for r in rows:
            name, text = r[0], r[1]
            audio = np.concatenate([np.asarray(res.audio, dtype=np.float32) for res in pipe(text, voice=a.voice)])
            sf.write(os.path.join(a.out, f"{name}_{a.voice}.wav"), audio, 24000)
            f.write(f"{name}\t{a.voice}\t{text}\t\t0\t0\t{len(audio) / 24000:.3f}\t0\t0\t0\t0\t0\n")
    print(a.out, len(rows))


if __name__ == "__main__":
    main()
