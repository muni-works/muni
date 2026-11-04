#!/bin/bash
# §29.2 step 3a: render seeds (chain.sh, ship knobs) then pick per line by UTMOS.
# s3_bon.sh render TAG VOC TEMP SEED...   |   s3_bon.sh pick TAG SEED...
U=~/runs/ribt-utmos; S=~/Developer/ipse-utmos/crates/ribt/scripts; R=~/runs/releases/ribt-2; P=~/venvs/voice-eval/bin/python
if [ $1 = render ]; then T=$2; V=$3; TP=$4; shift 4
  for k in "$@"; do FLOWARGS="--flow $R/flow_student_af.safetensors --nfe 1 --shortcut --temp $TP --seed $k" bash $S/utmos/chain.sh $T-s$k $V; done
else T=$2; shift 2
  for s in wer50 listen10 held50; do $P -I $S/utmos/bestofn.py $U/eval/$T-bon $s $(for k in "$@"; do echo $U/eval/$T-s$k/$s; done); done
  for N in 1 2 4 8; do [ -d $U/eval/$T-bon/bon$N ] && $P -I $S/voice_sv.py --real "$HOME/data/voices-afroot/voc/held/*.wav" $U/eval/$T-bon/bon$N/{wer50,listen10,held50} 2>/dev/null | grep -v ^real; done
  for N in 1 8; do [ -d $U/eval/$T-bon/bon$N ] && $P -I $S/utmos/judges.py $U/eval/$T-bon/bon$N/held50 2>/dev/null; done
fi
