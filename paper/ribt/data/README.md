# RIBT: data behind the post

Raw evaluation files, and the scripts that produced them, for `../ribt.typ`. Numbers in the post that
are not in these files cite a section of the RIBT lab log (`docs/voice-model.md` in our ipse repository)
as §N; the folders below say which sections their files back.

No audio, mel arrays or model weights are here: only per-clip scores, transcripts, timings and logs.
Texts in the evaluation sets are LibriTTS-R transcripts (CC BY 4.0, Koizumi et al. 2023) and our own
lines. Paths inside logs are the machines they ran on: `mew` (one shared RTX 3090) and an M4 Max Mac.

| folder | what | post section | lab log |
|---|---|---|---|
| `eval/` | the three-set chain eval: Kokoro af_heart, the licence-clean checkpoint, RIBT with its own vocoder and with the Vocos weights, 8 seeds, the "4:15" probe | 7, Table 2, Fig 3 | §24.3, §29.2 |
| `gap/` | scripts of the vocoder diagnosis (copy-synthesis and phase/magnitude swaps) | 3.5 | §29.1 |
| `latency/` | streaming timings on the M4 Max, per chunk and per utterance | 6, Fig 2 | §24.3 |
| `lilt/` | the unknown-word evaluation (82 sentences, before/after/ladder) and its scripts | 3.1 | §27 |
| `browser/` | the WebGPU build's README (parity and size tables) and its test lines | 8 | — |
| `corpus/` | af_heart corpus stats and the render scripts | 4 | §24.1 |
| `release.toml` | the release manifest: files, sha256s, default knobs, eval numbers, provenance | all | §24, §29 |

`eval/results.json` is recomputed from the per-clip files by `eval/scripts/summarize.py`; it reproduces
the post's tables to the last digit.

The run directory for the vocoder diagnosis (§29.1) was removed from `mew` before this post was written;
its scripts are here and its numbers come from the lab log.
