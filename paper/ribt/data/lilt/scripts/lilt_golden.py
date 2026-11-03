"""Golden outputs + data export for lilt (the Rust misaki port).

Run with the kokoro venv (misaki 0.9.4, spaCy 3.8, en_core_web_sm 3.8):

  ~/.cache/kv/bin/python -I scripts/lilt_golden.py export        # data/lilt/{gold,silver,tok_rules}.tsv
  ~/.cache/kv/bin/python -I scripts/lilt_golden.py golden [CORPUS] [OUT]

`golden` runs misaki's en.G2P exactly as Kokoro does (version=None, so ɾ->T,
ʔ->t) but with fallback=None: a word that would have gone to espeak-ng comes
back with phonemes None and is written as \\x01 so the parity harness can
exclude it; a merged multi-part word with an unknown part keeps a ❓
(U+2753) where the part was (Kokoro itself uses unk='', which is what the S
line's final string uses). No espeak is involved at all.

Golden file format (tab separated, one record per line, no JSON so the Rust
side needs no parser):
  S <split> <text> <final phoneme string, unk=''>
  T <text> <tag> <ws>                 spaCy token (tagger training target)
  W <text> <tag> <ws> <phonemes|\\x01> misaki output token
"""
import json, os, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(os.path.dirname(HERE), "data", "lilt")


def export():
    from misaki import en
    lex = en.Lexicon(british=False)
    for name, d in (("gold", lex.golds), ("silver", lex.silvers)):
        rows = []
        for k, v in d.items():
            assert "\t" not in k and "\n" not in k
            if isinstance(v, dict):
                v = "|".join(f"{t}={'~' if p is None else p}" for t, p in v.items())
                v = "{" + v
            rows.append((k, v))
        rows.sort(key=lambda kv: kv[0].encode())
        with open(os.path.join(DATA, f"{name}.tsv"), "w", encoding="utf-8") as f:
            for k, v in rows:
                f.write(f"{k}\t{v}\n")
        print(name, len(rows))
    import spacy
    nlp = spacy.load("en_core_web_sm", enable=["tok2vec", "tagger"])
    rules = nlp.tokenizer.rules
    with open(os.path.join(DATA, "tok_rules.tsv"), "w", encoding="utf-8") as f:
        n = 0
        for k in sorted(rules, key=lambda s: s.encode()):
            if not k.strip() or any(c.isspace() for c in k):
                continue
            f.write(k + "\t" + "\t".join(t[65] for t in rules[k]) + "\n")
            n += 1
    print("tok_rules", n)


def golden(corpus, out):
    from misaki import en
    g2p = en.G2P(trf=False, british=False, fallback=None, unk="\u2753")
    t0 = time.time()
    n = 0
    with open(corpus, encoding="utf-8") as fin, open(out, "w", encoding="utf-8") as f:
        for line in fin:
            split, text = line.rstrip("\n").split("\t", 1)
            ps, toks = g2p(text)
            f.write(f"S\t{split}\t{text}\t{ps.replace(chr(0x2753), '')}\n")
            for t in g2p.nlp(text):
                f.write(f"T\t{t.text}\t{t.tag_}\t{t.whitespace_}\n")
            for t in toks:
                p = "\x01" if t.phonemes is None else t.phonemes
                f.write(f"W\t{t.text}\t{t.tag}\t{t.whitespace}\t{p}\n")
            n += 1
            if n % 5000 == 0:
                print(n, f"{time.time() - t0:.0f}s", flush=True)
    print("done", n, f"{time.time() - t0:.0f}s")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "export":
        export()
    else:
        golden(sys.argv[2] if len(sys.argv) > 2 else os.path.join(DATA, "corpus.txt"),
               sys.argv[3] if len(sys.argv) > 3 else os.path.join(DATA, "golden.tsv"))
