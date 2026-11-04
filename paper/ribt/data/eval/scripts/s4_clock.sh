#!/bin/bash
# §29.2 step 4: the "4:15" reading. Text/pause variants x 8 flow seeds, ship knobs, imported vocoder; count Whisper "4.15".
U=~/runs/ribt-utmos; O=$U/clock; mkdir -p $O; S=~/Developer/ipse-utmos/crates/ribt/scripts; R=~/runs/releases/ribt-2
B=${RIBT_TTS:-~/Developer/ipse-gap/crates/ribt/target/release/ribt-tts}; export CUDA_HOME=/usr/local/cuda-12.8
V=${VOC:-$U/vocos_import_v1.safetensors}
P="The meeting moved to March 3rd, 2027, at"
{ printf "base\t$P 4:15 in the afternoon.\n"; printf "spelled\t$P four fifteen in the afternoon.\n"
  printf "hyphen\t$P four-fifteen in the afternoon.\n"; printf "comma\t$P four, fifteen in the afternoon.\n"
  printf "after\t$P 4:15, in the afternoon.\n"; printf "short\tThe meeting is at 4:15.\n"; } > $O/lines.tsv
for k in 0 1 2 3 4 5 6 7; do
  $B synth --run ~/runs/ribt-gap/acrun --ckpt acoustic_af_bon.safetensors --flow $R/flow_student_af.safetensors --nfe 1 --shortcut --temp 0.3 --seed $k \
    --voc $V --ref $R/ref_afheart.wav --pitch 1 --accent minnesota ${EXTRA} --lines $O/lines.tsv --out-dir $O/${TAG:-v}$k > $O/${TAG:-v}$k.log 2>&1
  ~/venvs/voice-eval/bin/python -I $S/tts_asr.py $O/${TAG:-v}$k > /dev/null 2>&1
done
for n in base spelled hyphen comma after short; do
  printf "%s\t" $n; cat $O/${TAG:-v}?/asr.tsv | awk -F'\t' -v n=$n '$2==n{print $6}' | sort | uniq -c | tr '\n' ';'; echo
done
