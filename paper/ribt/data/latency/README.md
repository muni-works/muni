# Streaming latency (§24.3)

`ribt-tts stream` on the ten listen-10 lines, M4 Max (Metal), the RIBT af_heart chain with the vocoder of
§24 (the imported Vocos has the same graph shape and was not re-timed), all text available at t = 0.

- `summary.txt`: TTFA median 17.6 ms, p90 27.5 ms, RTF 0.027, no underruns.
- `synth.tsv`: per utterance (tokens, frames, TTFA, compute, RTF, chunks, worst chunk).
- `*_ref.chunks.tsv` / `*_ref.events.tsv`: per chunk and per event timings.

Kokoro's numbers (KPipeline on the same Mac: CPU 349 ms to the first segment, RTF 0.093; MPS 815 ms,
RTF 0.22) are from §24.3; that log was not kept.
