#!/bin/bash
G=~/runs/ribt-gap; O=$G/r0; P=~/venvs/voice-eval/bin/python; export CUDA_HOME=/usr/local/cuda-12.8
RB=~/Developer/ipse-afheart/target/release/ribt; V=~/runs/releases/ribt-2/vocoder_af_step0012000.safetensors
mkdir -p $O/ours $O/ourmel
for f in $O/real/*.wav; do n=$(basename $f .wav)
  $RB infer --ckpt $V --cfg v1f0 $f $O/ours/$n.wav > /dev/null 2>&1
  $RB mel $f $O/ourmel/$n.npy --cfg v1f0 > /dev/null 2>&1
done
cd $G/ext && $P $G/rung0.py $O $G/eval/ship/held50 ~/runs/ribt-afheart/eval/kokoro/held50 "$O/fit/*.wav"
cd $G && $P -I ~/Developer/ipse-gap/crates/ribt/scripts/afheart/utmos_dirs.py $O/{real,ours,vocos,bigvgan,vocos_ourmel,bigvgan_mapmel,oracle_ident,oracle_realphase_ourmag,oracle_ourphase_realmag} $G/eval/ship/held50 $O/{pred_vocos,pred_bigvgan} ~/runs/ribt-afheart/eval/kokoro/held50 $O/{kok_vocos,kok_bigvgan} 2>/dev/null
