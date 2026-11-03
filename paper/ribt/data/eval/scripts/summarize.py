"""Recompute the chain table from the per-clip ASR files in ../raw.

    python3 -I summarize.py ../raw > ../results.json

Each <system>/<set>/asr.tsv row is one synthesized clip: UTMOS22-strong and the Whisper
small.en transcript (both normalized by Whisper's English normalizer). WER is corpus WER:
word edit distance summed over the set, over the reference word count, as jiwer computes it.
Speaker similarity (WavLM-SV) is not in asr.tsv; it is read from the sv lines in the logs
(s1chain.out), which voice_sv.py printed.
"""
import csv
import json
import re
import sys
from pathlib import Path

SETS = ("wer50", "listen10", "held50")


def edits(a, b):
    prev = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        cur = [i]
        for j, y in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x != y)))
        prev = cur
    return prev[-1]


def score(path):
    rows = list(csv.DictReader(path.open(), delimiter="\t", quoting=csv.QUOTE_NONE))
    rows = [r for r in rows if r.get("kind", "tts") == "tts"]
    e = sum(edits(r["ref"].split(), r["hyp"].split()) for r in rows)
    n = sum(len(r["ref"].split()) for r in rows)
    return {"n": len(rows), "utmos": round(sum(float(r["utmos"]) for r in rows) / len(rows), 3), "wer": round(100 * e / n, 2)}


def sv_lines(raw):
    out = {}
    for log in raw.glob("*.out"):
        for line in log.read_text().splitlines():
            m = re.match(r"\S*/eval/([^/\s]+)/(\w+)\tsv ([\d.]+)", line)
            if m:
                out[(m.group(1), m.group(2))] = float(m.group(3))
    return out


def main(raw):
    raw = Path(raw)
    sv = sv_lines(raw)
    alias = {"release": "imp", "release_ownvoc": "ship", "release_liltfix": "impL", "release_midwest_noO": "impLnoO"}
    res = {}
    for sysdir in sorted(p for p in raw.iterdir() if p.is_dir() and p.name not in ("sets", "clock")):
        for asr in sorted(sysdir.rglob("asr.tsv")):
            key = str(asr.parent.relative_to(raw))
            r = score(asr)
            tag = alias.get(sysdir.name)
            if tag and (tag, asr.parent.name) in sv:
                r["sv"] = sv[(tag, asr.parent.name)]
            res[key] = r
    json.dump(res, sys.stdout, indent=1)
    print()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "../raw")
