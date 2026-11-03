# The af_heart corpus (§24.1)

`afheart_stats.json`: 92,050 rendered utterances, 135.2 hours (52,000 book, 40,000 conversational, 50
held out), loudness-matched to LibriTTS-R. Its `note` field dates from before the decision to release
with disclosure. `texts.py` builds the texts (seed 0), `gen.py` renders them with kokoro 0.9.4,
`post.py` validates and levels them. The audio is not published.
