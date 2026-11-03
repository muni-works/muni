#!/bin/bash
# §29.2 step 2: GAN fine-tune of the imported Vocos on af_heart, real + predicted mels (vocp.sh recipe, low G lr, D warm-up).
# s2_ft.sh RUN LR_G STEPS [extra gan args]  — resumable (last.safetensors); D starts from the §24 voc2 D (af_heart-trained)
RUN=$1; LR=$2; ST=$3; shift 3; A=~/runs/ribt-afheart; export CUDA_HOME=/usr/local/cuda-12.8
PP=(--p-pred 0.5); [[ " $* " == *" --p-pred "* ]] && PP=()  # Args::opt takes the FIRST occurrence
mkdir -p $RUN; [ -f $RUN/last.safetensors ] || cp -n $A/voc2/d_last.safetensors $RUN/
~/Developer/ipse-afheart/target/release/ribt gan --run $RUN --data ~/data/voices-afroot/voc/train --heldout ~/data/voices-afroot/voc/held --held-by-clip --heldout-n 48 \
  --init ~/runs/ribt-utmos/vocos_import.safetensors --cfg v1f0 --dcfg v1 --frames 64 --batch 16 --lr $LR --lr-d 5e-5 \
  --log-every 50 --ckpt-every 250 --eval-every 250 --keep-every 250 --pairs $A/pairs "${PP[@]}" --steps $ST "$@"
