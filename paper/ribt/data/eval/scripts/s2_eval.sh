#!/bin/bash
# s2_eval.sh RUN STEP... : copy-synthesis UTMOS on the 50 rung-0 clips + chain held50 (ship knobs) per checkpoint
RUN=$1; shift; U=~/runs/ribt-utmos; G=~/runs/ribt-gap/r0; P=~/venvs/voice-eval/bin/python; S=~/Developer/ipse-utmos/crates/ribt/scripts
RB=~/Developer/ipse-afheart/target/release/ribt; export CUDA_HOME=/usr/local/cuda-12.8; n=$(basename $RUN)
for st in "$@"; do c=$RUN/step$(printf %07d $st).safetensors; o=$U/cs/$n-$st; mkdir -p $o
  for f in $G/real/*.wav; do $RB infer --ckpt $c --cfg v1f0 $f $o/$(basename $f) > /dev/null 2>&1; done
  $P -I $S/afheart/utmos_dirs.py $o 2>/dev/null
  SETS=held50 bash $S/utmos/chain.sh $n-$st $c | grep -v '^=='
done
