"""§29.2 step 3a: inference best-of-N picked by UTMOS.

bestofn.py OUT SET SEEDDIR0 SEEDDIR1 ...   (each SEEDDIR = a chain.sh output dir for SET with asr.tsv: per-file hyp + utmos)
For N = 1,2,4,..,len: per line keep the take with the highest UTMOS among the first N seeds; print UTMOS mean and corpus WER
of the picks, and write OUT/bon{N}/ (symlinked wavs + synth.tsv) for SV / the held-out judges.
Also prints the oracle-free control: the per-line mean UTMOS over the N takes (what an unpicked draw scores)."""
import csv, os, sys, jiwer, numpy as np
O, SET, D = sys.argv[1], sys.argv[2], sys.argv[3:]
rd = lambda d: {r["name"]: r for r in csv.DictReader(open(f"{d}/asr.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE) if r.get("kind", "tts") == "tts"}
T = [rd(d) for d in D]; names = sorted(T[0])
Ns = sorted({n for n in [1, 2, 4, 8, 16, 32] if n <= len(D)} | {len(D)})
for N in Ns:
    pick = [max(range(N), key=lambda k: float(T[k][n]["utmos"])) for n in names]
    ut = np.mean([float(T[k][n]["utmos"]) for k, n in zip(pick, names)])
    mean_draw = np.mean([np.mean([float(T[k][n]["utmos"]) for k in range(N)]) for n in names])
    wer = jiwer.wer([T[k][n]["ref"] for k, n in zip(pick, names)], [T[k][n]["hyp"] for k, n in zip(pick, names)])
    od = f"{O}/bon{N}/{SET}"; os.makedirs(od, exist_ok=True)
    rows = list(csv.DictReader(open(f"{D[0]}/synth.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE))
    with open(f"{od}/synth.tsv", "w") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()), delimiter="\t", quoting=csv.QUOTE_NONE, quotechar=None, escapechar="\\"); w.writeheader(); w.writerows(rows)
    for k, n in zip(pick, names):
        sp = T[k][n]["speaker"]; src = f"{D[k]}/{n}_{sp}.wav"; dst = f"{od}/{n}_{sp}.wav"
        if os.path.lexists(dst): os.remove(dst)
        os.symlink(src, dst)
    print(f"{SET}\tN {N}\tUTMOS picked {ut:.3f}\tmean draw {mean_draw:.3f}\tWER {100*wer:.2f}%\tseeds used {sorted(set(pick))[:8]}", flush=True)
