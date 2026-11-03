# Chain evaluation: Kokoro af_heart vs RIBT

Three sets (`raw/sets/`): **wer50** (50 LibriTTS-R test-clean sentences), **listen10** (ten conversational
sentences) and **held50** (50 af_heart texts held out of training, 25 book and 25 conversational).
Every system renders every line once, seed 0 unless noted.

- UTMOS: UTMOS22-strong (SpeechMOS v1.2.0), per clip, in `asr.tsv`.
- WER: Whisper small.en, Whisper's English normalizer on both sides; corpus WER over the set.
- Likeness (SV): WavLM-base-plus-SV cosine to the centroid of 121 held af_heart clips (`scripts/voice_sv.py`);
  printed as `sv` lines in `raw/s1chain.out`.
- DNSMOS (P.835 and P.808) and NISQA-TTS on held50: `judges.py`, printed in `raw/s1chain.out`.

| dir | system |
|---|---|
| `raw/kokoro` | Kokoro-82M af_heart, kokoro 0.9.4 `KPipeline` (`scripts/kokoro_set.py`) |
| `raw/librittsr_zeroshot` | the earlier LibriTTS-R-only checkpoint with the af_heart reference clip, no fine-tune |
| `raw/first_ownvoc_noknobs` | the af_heart chain as first trained (§24): af_heart acoustic @20k, τ0.3 student, own vocoder, no pitch/accent |
| `raw/release_ownvoc` | release knobs (best-of-N acoustic, pitch +1, minnesota) with the own af_heart vocoder |
| `raw/release` | **RIBT as released**: same, with the imported Vocos vocoder |
| `raw/release_liltfix` | `release` plus the lilt digraph fix (§29.2 step 4) |
| `raw/release_midwest_noO` | `release` with `--accent midwest` (no held o) |
| `raw/seeds/s1..s7` | `release` at flow seeds 1–7 (seed 0 is `raw/release`) |
| `raw/bestofn/bonN` | per line, the best-UTMOS take of the first N seeds; `raw/bonpick.out` is the table |
| `raw/clock` | the "4:15" probe: 6 text variants × 8 seeds; `raw/wer.out` holds the counts |
| `raw/pert.out` | UTMOS re-scored after an inaudible change (−1 dB, 7 ms of silence) |

`*.log` are the synth logs, named by internal run tag (`imp` = release, `ship` = release_ownvoc, `impL`, `impLnoO`, `fts03_voc` = first_ownvoc_noknobs, `r1zs` = librittsr_zeroshot) (per-line stage timings on the 3090). `results.json` is
`python3 -I scripts/summarize.py raw`. Scripts: `chain.sh` (the 3-set eval), `tts_asr.py`, `voice_sv.py`,
`judges.py`, `bestofn.py`, `seedstats.py`, `perturb.py`, `s4_clock.sh`, `vocos_import.py` and
`vocos_check.py` (the converter and its parity check), and the §24 drivers.
