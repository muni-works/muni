#!/bin/bash
# §29.2 step 1: copy-synthesis of the 50 rung-0 held clips through the imported Vocos (ribt infer) vs PyTorch Vocos
U=~/runs/ribt-utmos; G=~/runs/ribt-gap/r0; P=~/venvs/voice-eval/bin/python; S=~/Developer/ipse-utmos/crates/ribt/scripts
RB=~/Developer/ipse-afheart/target/release/ribt; export CUDA_HOME=/usr/local/cuda-12.8
mkdir -p $U/s1/imp
for f in $G/real/*.wav; do $RB infer --ckpt $U/vocos_import.safetensors --cfg v1f0 $f $U/s1/imp/$(basename $f) > /dev/null 2>&1; done
$P -I $S/utmos/vocos_check.py $G/ourmel $U/s1/imp $U/s1/torch | tail -4
$P -I $S/afheart/utmos_dirs.py $G/real $G/ours $G/vocos_ourmel $U/s1/imp $U/s1/torch 2>/dev/null
