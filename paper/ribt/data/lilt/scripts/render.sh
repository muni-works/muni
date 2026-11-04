#!/bin/bash
# render.sh — docs §27 end-to-end check on mew: the oov_fun.tsv sentences through RIBT af_heart
# (ribt-2-afheart release: τ0.3 student, af_heart vocoder, --pitch 1), three lilt arms:
#   before  = main (overrides on, no OOV fallback: unknown words dropped)
#   after   = overrides on + OOV ladder (the new default)
#   ladder  = overrides off + OOV ladder (the ladder alone, no hand fixes)
# then Whisper small.en per arm (eval.py). GPU work goes through the shared lock; one bounded run (~5 min).
set -e
W=${W:-$HOME/Developer/ipse-oov}; R=$HOME/runs/releases/ribt-2-afheart; O=${O:-$HOME/runs/ribt-oov/render}
B=$W/target/release/ribt-tts; S=$W/crates/ribt/scripts/oov; export CUDA_HOME=/usr/local/cuda-12.8
mkdir -p $O
(cd $W/crates/ribt && CARGO_TARGET_DIR=$W/target ~/.cargo/bin/cargo build --release --no-default-features --features cuda --bin ribt --bin ribt-tts 2>&1 | tail -1)
# held-out G2P score of the shipped recipe (CPU, deterministic; the embedded g2p.bin is this fit on all words)
$W/target/release/ribt lilt fit-g2p --half 5 --iters 12 --out $O/g2p_refit.bin > $O/g2p.txt 2>&1
cmp $O/g2p_refit.bin $W/crates/ribt/data/lilt/g2p.bin >> $O/g2p.txt 2>&1 && echo "refit == embedded g2p.bin" >> $O/g2p.txt
grep -v '^#' $W/crates/ribt/data/lilt/oov_fun.tsv | awk -F'\t' '{printf "f%02d\t%s\n", NR-1, $4}' > $O/lines.tsv
synth() {  # ARM, env...
  local arm=$1; shift
  env "$@" ~/.cache/ribt-gpu-lock.sh $B synth --run $HOME/runs/ribt-afheart/ac --ckpt $R/acoustic_af_step0020000.safetensors \
    --flow $R/flow_student_af.safetensors --nfe 1 --shortcut --temp 0.3 --voc $R/vocoder_af_step0012000.safetensors \
    --ref $R/ref_afheart.wav --seed 0 --pitch 1 --lines $O/lines.tsv --out-dir $O/$arm > $O/$arm.log 2>&1
}
synth before RIBT_LILT_FALLBACK=0
synth after RIBT_LILT_FALLBACK=1
synth ladder RIBT_LILT_FALLBACK=1 RIBT_LILT_OVERRIDES=0
~/.cache/ribt-gpu-lock.sh ~/venvs/voice-eval/bin/python -I $S/eval.py $W/crates/ribt/data/lilt/oov_fun.tsv $O before after ladder > $O/eval.txt 2>&1
echo done
