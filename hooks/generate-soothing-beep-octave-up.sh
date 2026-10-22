#!/usr/bin/env bash
# Writes beep-soothing-octave-up.wav next to this script:
# /home/sound/beep-soothing.wav played twice as fast.
# Same samples, header relabeled to double the frame rate,
# so it sounds an octave higher and lasts half as long.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 -I - /home/sound/beep-soothing.wav "$script_dir/beep-soothing-octave-up.wav" << 'PY'
import sys
import wave

src, dst = sys.argv[1], sys.argv[2]
with wave.open(src) as r:
  params = r.getparams()
  frames = r.readframes(params.nframes)
with wave.open(dst, "w") as w:
  w.setparams(params._replace(framerate=2 * params.framerate))
  w.writeframes(frames)
print(f"Octave-up soothing beep created at {dst}")
PY
