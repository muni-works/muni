#!/bin/bash
# same mel npy -> ribt infer (imported, v1 cfg) vs torch Vocos.decode: numerical parity
U=~/runs/ribt-utmos; G=~/runs/ribt-gap/r0; RB=~/Developer/ipse-afheart/target/release/ribt; export CUDA_HOME=/usr/local/cuda-12.8
mkdir -p $U/s1/impnpy
for f in $(ls $G/ourmel/*.npy | head -10); do $RB infer --ckpt $U/vocos_import_v1.safetensors --cfg v1 $f $U/s1/impnpy/$(basename $f .npy).wav > /dev/null 2>&1; done
N=10 ~/venvs/voice-eval/bin/python -I ~/Developer/ipse-utmos/crates/ribt/scripts/utmos/vocos_check.py $G/ourmel $U/s1/impnpy $U/s1/torch10 2>&1 | grep -v Warn
