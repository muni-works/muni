# lilt: unknown words (§27)

`raw/lines.tsv`: 82 sentences, one hard word each (coinages, names, tech, clock times, addresses).
Rendered through RIBT af_heart three ways: `before` (overrides, no fallback), `after` (overrides + the
unknown-word ladder) and `ladder` (ladder alone), then transcribed by Whisper small.en.
`raw/eval.tsv`/`eval.txt`: per word, the arm, the similarity of the best transcript span, and the
transcript. `raw/*.log` list the words lilt dropped (`OOV (dropped by lilt)`). `raw/g2p.txt`: the
letter-context tree's held-out score (8,806 words).

Parity with misaki (99.858% on 9,470 held-out sentences) is §12.3; its goldens are built by
`scripts/lilt_golden.py` from the corpus of `scripts/lilt_corpus.py`.
