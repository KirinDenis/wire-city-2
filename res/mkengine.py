# mkengine.py - carve the looping engine sample out of res/engine.mp3:
# 32768 samples, 11025 Hz, 8-bit unsigned, with a 4096-sample crossfade
# so the loop is seamless. Output: INSTALL/ENGINE.RAW (the game streams
# it through the Sound Blaster's auto-init DMA and bends the pitch with
# the DSP time constant - the throttle spools a REAL engine).
# Run from the repo root: python res\mkengine.py
import os
import numpy as np
import soundfile as sf

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
d, sr = sf.read(os.path.join(root, 'res', 'engine.mp3'))
if d.ndim > 1:
    d = d.mean(axis=1)

RATE = 11025
N = 32768
FADE = 4096

# take a steady stretch from the middle of the recording
need = (N + FADE) / RATE            # seconds of source at target rate
mid = len(d) / sr / 2
t0 = max(0.0, mid - need / 2)
seg = d[int(t0 * sr): int((t0 + need) * sr)]

# resample to 11025 Hz (linear interp is fine for a rumble)
src_t = np.arange(len(seg)) / sr
dst_t = np.arange(int(need * RATE)) / RATE
seg = np.interp(dst_t, src_t, seg)[:N + FADE]

# seamless loop: crossfade the head with the tail
w = np.linspace(0.0, 1.0, FADE)
loop = seg[:N].copy()
loop[:FADE] = seg[:FADE] * w + seg[N:N + FADE] * (1.0 - w)

# normalize to a healthy 8-bit swing
loop -= loop.mean()
loop *= 0.9 * 127 / max(1e-9, np.abs(loop).max())
raw = (loop + 128).clip(0, 255).astype(np.uint8)

out = os.path.join(root, 'INSTALL', 'ENGINE.RAW')
open(out, 'wb').write(raw.tobytes())
print(f'wrote {out}: {len(raw)} bytes, {len(raw)/RATE:.2f} s loop @ {RATE} Hz')
