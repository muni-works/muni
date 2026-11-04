# Gap diagnosis (§29.1)

Where the held-50 UTMOS gap between RIBT (own vocoder, 4.136) and Kokoro (4.464) comes from.
`rung0.sh`/`rung0.py`: copy-synthesis of 50 held af_heart clips through our vocoder, pretrained Vocos,
BigVGAN-v2 and two STFT-swap oracles (real phase + our magnitude, our phase + real magnitude).
`chain3.sh`: the same vocoders on predicted mels. `bands.py`: log-spectral distance per band, HNR and
flatness. `werdiff.py`: every word error, RIBT vs Kokoro, classified. `bigmap*`: the fitted log-mel map
for BigVGAN.

The run directory (`mew:~/runs/ribt-gap/`) no longer exists; the numbers in the post come from §29.1.
The chain rows that were re-run later (`../eval/raw/release_ownvoc`) match it exactly.
