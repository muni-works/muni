"""seedstats.py EVALROOT TAG SEED... : per-set UTMOS mean over seeds (± sd of the seed means) and pooled WER, from asr.tsv."""
import csv, sys, jiwer, numpy as np
R, T, K = sys.argv[1], sys.argv[2], sys.argv[3:]
out = []
for s in ["wer50", "listen10", "held50"]:
    um, refs, hyps = [], [], []
    for k in K:
        rows = [r for r in csv.DictReader(open(f"{R}/{T}-s{k}/{s}/asr.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE) if r.get("kind", "tts") == "tts"]
        um.append(np.mean([float(r["utmos"]) for r in rows])); refs += [r["ref"] for r in rows]; hyps += [r["hyp"] for r in rows]
    out.append(f"{s} {np.mean(um):.3f}±{np.std(um):.3f} WER {100*jiwer.wer(refs, hyps):.2f}%")
print(T, f"seeds {','.join(K)}:", " | ".join(out))
