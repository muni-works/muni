# RIBT in the browser

Type any text, hear it, see every stage, with no server: lilt G2P compiled to
wasm, and the acoustic model, 1-step flow and Vocos vocoder running on WebGPU.

```
web/build.sh                          # wasm + graphs + weights + parity refs (needs ~/runs/releases/ribt-2-afheart)
python3 -m http.server 8737 -d web    # then /index.html (type → speak) and /parity.html
```

## How it works

| stage | where | what |
|---|---|---|
| G2P | `pkg/` (wasm) | `src/lilt` compiled unchanged (`lilt-wasm/` is a 40-line wasm-bindgen shim), accent `minnesota` |
| encoder | WebGPU | tokens + reference voice → token states, ln(d+1), pitch, energy, speaker |
| durations | JS | `round(exp(ld) − 1)`, pitch +1 st, hard alignment, as `ribt-tts synth` |
| decoder | WebGPU | → mel, F0, hidden |
| flow | WebGPU | 1-NFE shortcut student, temp 0.3, seed 0 (`Rng` ported bit-exactly) |
| vocoder | WebGPU | Vocos import, mel padded to the bucket with silence, trimmed |

The GPU programs are tang's own WGSL: `ribt-web-export` (`src/bin/ribt-web-export.rs`)
builds each graph at fixed bucket shapes, runs the same optimizer passes as
`runtime::optimize`, and writes `graphs/*.json` (buffers, kernels, dispatch order,
shaders). `ribt.js` uploads buffers and dispatches the kernels in order; there is
no hand-written model code in JS. Buckets: tokens 64/128/192, frames 256/512/1024
(2.7/5.5/10.9 s). Longer text is split into sentences, then clauses, then word runs
(`speak()`), and each chunk is played while the next one is computed.

## JS API

```js
import { RIBT } from "./ribt.js";
const tts = await RIBT.load({ base: "dist/", onProgress });  // download, sha256-verify, compile smallest buckets
const r = await tts.synth("Hello there.", { onStage, pitch_st: 1, rate: 1, seed: 0, temp: 0.3 });
for await (const chunk of tts.speak(longText, { onStage })) play(chunk);
tts.prewarm();                                               // compile the remaining buckets in the background
```

`onStage(name, data)` fires as each stage lands: `phonemes` (text, phoneme string,
words, tokens `[{ph, id}]`), `durations` (per-token frames, total, token pitch Hz),
`decoder` (F0 Hz per frame, decoder mel), `flow` (final mel), `audio` (the result).
A result holds `phonemes, words, tokens, durs, frames, f0, melDecoder, mel` (`[n_mels][frames]`,
row-major, ln magnitude), `audio` (Float32Array, 24 kHz), `buckets`, `timings`.

## Parity (Chrome 156, M4 Max, `parity.html`)

Two references for the 5 lines in `parity/lines.tsv`:
- **native**: `ribt-tts synth` on Metal, release config (`releases/ribt-2.toml` [synth]), f32 weights.
- **fp16-native**: the browser pipeline run natively by `ribt-web-export --check` (same buckets, the shipped weights).

| line | frames | durations vs native | audio rel RMS vs fp16-native | mel max abs vs fp16-native | audio rel RMS vs native | mel L1 vs native | warm ms | RTF |
|---|---|---|---|---|---|---|---|---|
| p1 | 418 | same | 3.4e-5 | 1.6e-5 | 1.1e-2 | 6.3e-4 | 63.6 | 0.014 |
| p2 | 300 | same | 5.6e-5 | 1.6e-5 | 9.8e-3 | 6.5e-4 | 60.5 | 0.019 |
| p3 | 498 | same | 2.6e-5 | 1.4e-5 | 1.9e-2 | 6.8e-4 | 63.3 | 0.012 |
| p4 | 420 | same | 2.1e-5 | 9.5e-6 | 1.4e-2 | 6.3e-4 | 63.0 | 0.014 |
| p5 | 479 | same | 5.3e-5 | 2.2e-5 | 1.6e-2 | 6.3e-4 | 65.8 | 0.013 |

- WebGPU vs native on the same weights: ≤ 6e-5 rel RMS (gate 1e-3). Bucketing alone (native, f32): ≤ 2.7e-5.
- The 1–2% vs `ribt-tts synth` is the fp16 weights: identical durations, mel L1 6e-4 (ln units), so it is
  phase-level waveform drift, not a different rendering. fp16 pitch/energy heads alone moved the
  waveform ~5%, so those heads (1.7M params) ship f32; everything else fp16.
- Warm RTF 0.014 (≈64 ms per 4–5 s sentence, four GPU round trips each). Cold: ready 0.8 s after page
  load on localhost (download + verify 0.6 s, first-bucket kernels 0.2 s), first utterance 0.25 s, so
  **~1.05 s to first audio on localhost**. Over a network the 115 MB download dominates
  (~9 s at 100 Mb/s); all 18 graphs compile in ~0.2 s.

## Sizes

| file | bytes | gzip | sha256 |
|---|---|---|---|
| `dist/ac.bin` (acoustic, fp16 + f32 heads) | 40.6 MB | 37.6 MB | `86a0b1cb22ac81af396c794c6d20249e655f7941171a90f8b0368ce8fad50380` |
| `dist/fl.bin` (flow student, fp16) | 43.8 MB | 40.1 MB | `32f3f65ba6418db46536b87c7cd4bac4700b81117f19fe0ae0912ceae11b5d1b` |
| `dist/voc.bin` (Vocos import, fp16) | 27.1 MB | 25.1 MB | `9d4b80634f9b8e4cd7012e9da83af8bd17b8755660272135ee16d62c4d39ac6c` |
| `dist/consts.f32.bin` (STFT/positional tables) | 6.4 MB | 3.5 MB | `ef898807585768b60a920146d7162ee83198425e579f0db964ff78d5bcf554a9` |
| `dist/graphs/*.json` (18 graphs) | 2.8 MB | 0.2 MB | |
| `pkg/lilt_wasm_bg.wasm` | 16.4 MB | 7.7 MB | |

The manifest carries the sha256s and `ribt.js` checks them before use. Weights are
weights-only (no `adam.*`); the release checkpoints are untouched.

## Known limits / next

- lilt's wasm embeds its 15 MB of tables (lexicons, tagger, OOV model); splitting silver.tsv and the
  tagger out for lazy fetch would cut the first-load wasm roughly in half.
- GPU memory: weights are expanded to f32 on upload (~216 MB). A `shader-f16` export would halve
  it and the download stays the same; worth it before targeting phones.
- `consts.f32.bin` could be computed in JS (sinusoids, STFT basis) to save 3.5 MB.
- Only the 1-NFE shortcut flow and the F0-free Vocos vocoder are exported (the release config).
- tang emits `f32::MAX` as `3.4028235e38`, which Tint rejects; the exporter rewrites it (`web_wgsl`).
  The real fix is in tang-compile's WGSL emitter.
- Nothing here is published: no weights uploaded, no remote pushed.
