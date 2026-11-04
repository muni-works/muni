#!/bin/bash
# chain.sh TAG AC_RUN AC_CKPT FLOW|none VOC — §24 end-to-end eval of one chain on mew:
# synth (seed 0, flow @1 τ ${TAU:-0.3}) the wer50 / listen10 / held50 sets with the af_heart ref clip,
# then Whisper small.en WER + UTMOS (tts_asr.py) and WavLM-SV likeness vs the real af_heart held clips.
T=$1; AR=$2; AC=$3; FL=$4; VOC=$5; E=~/runs/ribt-afheart/eval; S=~/Developer/ipse-afheart/crates/ribt/scripts
REF=${REF:-$HOME/data/voices/afheart/00000/afheart_00000_000038.wav}
B=~/Developer/ipse-afheart/target/release/ribt-tts; export CUDA_HOME=/usr/local/cuda-12.8
F=(); [ "$FL" != none ] && F=(--flow $FL --nfe 1 --shortcut --temp ${TAU:-0.3})
for s in wer50 listen10 held50; do
  $B synth --run $AR --ckpt $AC "${F[@]}" --voc $VOC --ref $REF --seed 0 $EXTRA --lines $E/sets/$s.tsv --out-dir $E/$T/$s > $E/$T.$s.log 2>&1
  ~/venvs/voice-eval/bin/python -I $S/tts_asr.py $E/$T/$s --utmos 2>/dev/null | tail -2
done
~/venvs/voice-eval/bin/python -I $S/voice_sv.py --real "$HOME/data/voices-afroot/voc/held/*.wav" $E/$T/wer50 $E/$T/listen10 $E/$T/held50 2>/dev/null
