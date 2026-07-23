# mkengine.py - carve the looping engine sample out of res/engine.mp3:
# 32768 samples, 11025 Hz, 8-bit unsigned, seamless crossfaded loop.
# The cut is chosen for STEADINESS (the window with the least loudness
# variance - no manoeuvre swells), the slow envelope is flattened, the
# pitch is shifted ~18% down and the top end is softened ("deeper"),
# and the level sits at 30% so the engine is a bed, not a lead.
# Output: INSTALL/ENGINE.RAW. Run from the repo root.
import os
import numpy as np
import soundfile as sf

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
d, sr = sf.read(os.path.join(root, 'res', 'engine.mp3'))
if d.ndim > 1:
    d = d.mean(axis=1)

RATE  = 11025
N     = 32768
FADE  = 4096
PITCH = 0.82        # stretch the wave: ~18% deeper at the same playback rate
LEVEL = 0.30        # 30% of full swing

# ---- find the steadiest stretch: minimal RMS variance over the span ----
need_src = int((N + FADE) / RATE * sr / PITCH) + sr // 10
win = sr // 2
nw = len(d) // win
rms = np.array([np.sqrt(np.mean(d[i*win:(i+1)*win]**2)) for i in range(nw)])
span = max(1, need_src // win)
best, best_var = 0, 1e9
for i in range(0, nw - span):
    v = np.var(rms[i:i+span]) / (np.mean(rms[i:i+span])**2 + 1e-12)
    if v < best_var:
        best, best_var = i, v
seg = d[best*win : best*win + need_src]
print(f'steadiest stretch: t={best*win/sr:.1f}s..{(best*win+need_src)/sr:.1f}s '
      f'(rel variance {best_var:.4f})')

# ---- resample with the pitch shift baked in ----
n_out = N + FADE
src_pos = np.arange(n_out) * (sr / RATE) * PITCH
seg = np.interp(src_pos, np.arange(len(seg)), seg)

# ---- flatten the slow envelope: no swells, one steady thrust ----
env_win = int(0.05 * RATE)
pad = np.concatenate([seg[:env_win], seg, seg[-env_win:]])
env = np.sqrt(np.convolve(pad**2, np.ones(env_win)/env_win, mode='same'))
env = env[env_win:env_win+len(seg)]
seg = seg / (env + 1e-9) * env.mean()

# ---- soften the top end: one gentle low-pass pole at ~3 kHz ----
a = 1.0 - np.exp(-2*np.pi*3000/RATE)
y = np.empty_like(seg)
acc = 0.0
for i in range(len(seg)):
    acc += a * (seg[i] - acc)
    y[i] = acc
seg = y

# ---- seamless loop: crossfade the head with the tail ----
w = np.linspace(0.0, 1.0, FADE)
loop = seg[:N].copy()
loop[:FADE] = seg[:FADE] * w + seg[N:N+FADE] * (1.0 - w)

# ---- normalize to 30% swing ----
loop -= loop.mean()
loop *= LEVEL * 127 / max(1e-9, np.abs(loop).max())
raw = (loop + 128).clip(0, 255).astype(np.uint8)

out = os.path.join(root, 'INSTALL', 'ENGINE.RAW')
open(out, 'wb').write(raw.tobytes())
print(f'wrote {out}: {len(raw)} bytes, {len(raw)/RATE:.2f} s loop @ {RATE} Hz, '
      f'level {LEVEL:.0%}, pitch x{PITCH}')
