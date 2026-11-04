#!/bin/bash
# §29.1 chain eval: RIBT (bon acoustic, tau0.3 student, af_heart vocoder), 3 knob configs
E=~/runs/ribt-afheart/eval; G=~/runs/ribt-gap; S=~/Developer/ipse-gap/crates/ribt/scripts; R=~/runs/releases/ribt-2
B=~/Developer/ipse-gap/crates/ribt/target/release/ribt-tts; export CUDA_HOME=/usr/local/cuda-12.8
F=(--flow $R/flow_student_af.safetensors --nfe 1 --shortcut --temp 0.3 --voc $R/vocoder_af_step0012000.safetensors --ref $R/ref_afheart.wav --seed 0)
run() { T=$1; shift
  for s in wer50 listen10 held50; do
    $B synth --run $G/acrun --ckpt acoustic_af_bon.safetensors "${F[@]}" "$@" --lines $E/sets/$s.tsv --out-dir $G/eval/$T/$s > $G/eval/$T.$s.log 2>&1
    echo "== $T $s"; ~/venvs/voice-eval/bin/python -I $S/tts_asr.py $G/eval/$T/$s --utmos 2>/dev/null | tail -2
  done
  ~/venvs/voice-eval/bin/python -I $S/voice_sv.py --real "$HOME/data/voices-afroot/voc/held/*.wav" $G/eval/$T/{wer50,listen10,held50} 2>/dev/null
}
run ship --pitch 1 --accent minnesota
run pitch --pitch 1
run accent --accent minnesota
run plain
