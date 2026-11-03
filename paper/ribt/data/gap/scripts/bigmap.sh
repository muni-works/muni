#!/bin/bash
G=~/runs/ribt-gap; O=$G/r0; P=~/venvs/voice-eval/bin/python; export CUDA_HOME=/usr/local/cuda-12.8
mkdir -p $O/fitmel; for f in $O/fit/*.wav; do ~/Developer/ipse-afheart/target/release/ribt mel $f $O/fitmel/$(basename $f .wav).npy --cfg v1f0 >/dev/null 2>&1; done
cd $G/ext && $P $G/bigmap.py $O $G/eval/ship/held50
cd $G && $P -I ~/Developer/ipse-gap/crates/ribt/scripts/afheart/utmos_dirs.py $O/bigvgan_logmap $O/pred_bigvgan_logmap 2>/dev/null
