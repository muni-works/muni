"""Build lilt's golden-parity text corpus (no network, nothing from mew).

Sources, all on disk and permissively licensed:
  * WordNet 3.0 glosses + usage examples (~/nltk_data/corpora/wordnet.zip;
    WordNet license is BSD-style, Princeton) -- ordinary English prose.
  * this repo's docs/*.md prose lines -- robot/K1/ML domain text with numbers,
    units, acronyms, file names.
  * scripts/lilt_edge.txt -- hand-built edge cases.

Writes one sentence per line to OUT (default data/lilt/corpus.txt) with a
split prefix: "train\t", "test\t" or "edge\t". The split is by a stable hash so
the tagger never trains on test sentences.

  python3 scripts/lilt_corpus.py [--n-wordnet 40000] [--n-docs 6000] [OUT]
"""
import hashlib, re, sys, zipfile, glob, os, random

HERE = os.path.dirname(os.path.abspath(__file__))
CRATE = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(CRATE))


def arg(k, d):
    return type(d)(sys.argv[sys.argv.index(k) + 1]) if k in sys.argv else d


def clean(s):
    s = re.sub(r"\s+", " ", s).strip()
    return s


def wordnet():
    z = zipfile.ZipFile(os.path.expanduser("~/nltk_data/corpora/wordnet.zip"))
    out = []
    for pos in ("noun", "verb", "adj", "adv"):
        for line in z.read(f"wordnet/data.{pos}").decode("utf-8", "replace").splitlines():
            if line.startswith("  ") or "|" not in line:
                continue
            gloss = line.split("|", 1)[1]
            for part in gloss.split(";"):
                part = clean(part)
                q = re.fullmatch(r'"(.+?)"(?:\s*-+\s*.*)?', part)
                if q:  # usage example: a real sentence
                    s = q.group(1)
                    if len(s.split()) >= 4:
                        out.append(s[0].upper() + s[1:] + ("" if s[-1] in ".!?" else "."))
                elif len(part.split()) >= 5 and '"' not in part:
                    out.append(part[0].upper() + part[1:] + ".")
    return out


def docs():
    out = []
    for p in sorted(glob.glob(os.path.join(REPO, "docs", "*.md"))):
        incode = False
        for line in open(p, encoding="utf-8", errors="replace"):
            if line.startswith("```"):
                incode = not incode
                continue
            if incode or line.startswith(("|", "#", "    ", "<", "!")):
                continue
            line = re.sub(r"`[^`]*`", "", line)            # inline code
            line = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", line)  # links (misaki syntax!)
            line = re.sub(r"[*_]{1,3}", "", line)
            line = re.sub(r"^\s*([-*]|\d+\.)\s+", "", line)
            for s in re.split(r"(?<=[.!?])\s+(?=[A-Z])", clean(line)):
                if 5 <= len(s.split()) <= 40 and re.search(r"[a-z]", s) and not re.search(r"[{}\\$=]{2,}|[\[\]]", s):
                    out.append(s)
    return out


def split_of(s):
    return "test" if int(hashlib.md5(s.encode()).hexdigest(), 16) % 5 == 0 else "train"


def main():
    out_path = next((a for a in sys.argv[1:] if not a.startswith("--") and not a.isdigit()), os.path.join(CRATE, "data", "lilt", "corpus.txt"))
    rng = random.Random(0)
    wn = sorted(set(wordnet()))
    rng.shuffle(wn)
    dc = sorted(set(docs()))
    rng.shuffle(dc)
    wn, dc = wn[: arg("--n-wordnet", 40000)], dc[: arg("--n-docs", 6000)]
    edge = [clean(l) for l in open(os.path.join(HERE, "lilt_edge.txt"), encoding="utf-8") if l.strip() and not l.startswith("#")]
    with open(out_path, "w", encoding="utf-8") as f:
        for s in wn + dc:
            f.write(f"{split_of(s)}\t{s}\n")
        for s in edge:
            f.write(f"edge\t{s}\n")
    print(f"wordnet {len(wn)} docs {len(dc)} edge {len(edge)} -> {out_path}")


main()
