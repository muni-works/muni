import csv, sys, jiwer
def load(p): return {r["name"]: r for r in csv.DictReader(open(p), delimiter="\t", quoting=csv.QUOTE_NONE)}
for st in ["wer50", "listen10", "held50"]:
    for tag, p in [("KOK", f"/home/cam/runs/ribt-afheart/eval/kokoro/{st}/asr.tsv"), ("RIBT", f"/home/cam/runs/ribt-gap/eval/ship/{st}/asr.tsv")]:
        for n, r in load(p).items():
            if r["ref"] == r["hyp"]: continue
            o = jiwer.process_words(r["ref"], r["hyp"]); errs = []
            R, H = r["ref"].split(), r["hyp"].split()
            for c in o.alignments[0]:
                if c.type == "equal": continue
                errs.append(f'{c.type[:3]}:{" ".join(R[c.ref_start_idx:c.ref_end_idx])}->{" ".join(H[c.hyp_start_idx:c.hyp_end_idx])}')
            print(f"{st}\t{tag}\t{n}\t{o.substitutions+o.deletions+o.insertions}\t{'; '.join(errs)}")
