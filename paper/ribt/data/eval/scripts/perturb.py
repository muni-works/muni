"""perturb.py IN OUT: copy wavs with an inaudible change (-1 dB, 7 ms of leading silence) to test whether a UTMOS-picked
take's advantage is a property of the audio or of the scorer's noise on that exact waveform."""
import glob, os, sys, numpy as np, soundfile as sf
I, O = sys.argv[1:3]; os.makedirs(O, exist_ok=True)
for f in sorted(glob.glob(f"{I}/*.wav")):
    x, sr = sf.read(f, dtype="float32")
    sf.write(f"{O}/{os.path.basename(f)}", np.concatenate([np.zeros(int(0.007 * sr), np.float32), x * 10 ** (-1 / 20)]), sr)
