#!/usr/bin/env python3
"""Merge gen.py shards into the af_heart corpus files (docs/voice-model.md §24).

    python post.py CORPUS PHON_OUT ROOT_OUT [--dev-every 200]

CORPUS = ~/data/voices/afheart (gen.py output). Writes
  CORPUS/metadata.tsv, CORPUS/stats.json
  PHON_OUT/{train,dev,test}.phon.tsv   (test = the 50 `held` texts; dev = every Nth other utt)
  ROOT_OUT/{train,dev,test}/afheart -> CORPUS  (ribt loaders read ROOT/split/S/C/S_C_n.wav)
"""
import argparse
import json
import os
from pathlib import Path

import numpy as np

COLS = "id kind src_id text seconds lufs_in gain_db peak rms sil_frac ok reason phonemes".split()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("corpus")
    ap.add_argument("phon_out")
    ap.add_argument("root_out")
    ap.add_argument("--dev-every", type=int, default=200)
    a = ap.parse_args()
    c = Path(a.corpus)
    rows = []
    for f in sorted((c / "shards").glob("meta.*.tsv")):
        rows += [dict(zip(COLS, l.rstrip("\n").split("\t"))) for l in open(f)]
    phon = {}
    for f in sorted((c / "shards").glob("phon.*.tsv")):
        for l in open(f):
            phon[l.split("\t", 1)[0]] = l
    rows = sorted({r["id"]: r for r in rows}.values(), key=lambda r: r["id"])  # last row per id (--redo-rejects)
    ok = [r for r in rows if r["ok"] == "1" and r["id"] in phon]
    with open(c / "metadata.tsv", "w") as f:
        f.write("\t".join(COLS) + "\n")
        for r in rows:
            f.write("\t".join(r[k] for k in COLS) + "\n")
    po = Path(a.phon_out)
    po.mkdir(parents=True, exist_ok=True)
    outs = {s: open(po / f"{s}.phon.tsv", "w") for s in ["train", "dev", "test"]}
    split_of = {}
    j = 0
    for r in ok:
        if r["kind"] == "held":
            s = "test"
        else:
            j += 1
            s = "dev" if j % a.dev_every == 0 else "train"
        split_of[r["id"]] = s
        outs[s].write(phon[r["id"]])
    ro = Path(a.root_out)
    for s in outs:
        (ro / s).mkdir(parents=True, exist_ok=True)
        ln = ro / s / "afheart"
        if not ln.exists():
            os.symlink(c.resolve(), ln)
    sec = lambda rs: float(sum(float(r["seconds"]) for r in rs))
    kinds = {}
    for r in ok:
        k = kinds.setdefault(r["kind"], [0, 0.0])
        k[0] += 1
        k[1] += float(r["seconds"]) / 3600
    rej = {}
    for r in rows:
        if r["ok"] != "1":
            rej[r["reason"]] = rej.get(r["reason"], 0) + 1
    pk = np.array([float(r["peak"]) for r in ok])
    gain = np.array([float(r["gain_db"]) for r in ok])
    du = np.array([float(r["seconds"]) for r in ok])
    st = dict(rendered=len(rows), kept=len(ok), hours=sec(ok) / 3600, rejected=rej,
              by_kind={k: dict(n=v[0], hours=round(v[1], 3)) for k, v in kinds.items()},
              by_split={s: sum(1 for v in split_of.values() if v == s) for s in outs},
              seconds_p10_p50_p90=np.percentile(du, [10, 50, 90]).round(2).tolist(),
              peak_p50_p99_max=[float(np.median(pk)), float(np.percentile(pk, 99)), float(pk.max())],
              peak_limited=int((pk >= 0.9799).sum()), gain_db_p50=float(np.median(gain)),
              note="RESEARCH-ONLY: Kokoro-82M af_heart renders; Kokoro's training data included synthetic audio "
                   "from closed commercial TTS providers. Not licence-clean.")
    json.dump(st, open(c / "stats.json", "w"), indent=1)
    print(json.dumps(st, indent=1))


if __name__ == "__main__":
    main()
