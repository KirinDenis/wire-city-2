# ============================================================================
#  mkpanel.py - pre-renders the cockpit PANEL BITMAP (the classic sim
#  trick: the 3-D cockpit stays a skeleton, the detailed instrument
#  face is an image). Runs on the Windows side (like OWLFLY's mkpanel);
#  the output PANEL1.RAW ships next to the DATs.
#
#  PANEL1.RAW: 'P','B', db npal, npal*(r,g,b 0..63), 320*72 pixels of
#  ABSOLUTE palette indices 96..96+npal-1 (baked, so the game blits with
#  one rep movsw). The game draws live needles over the gauges:
#      ASI centre (60,163) r24, compass (160,163), ALT (260,163)
#  (centres here are in panel rows 0..71 at y=35; screen row = 128+y.)
# ============================================================================
import math, os

W, H = 320, 72
BASE = 96
COLS = [                        # VGA 6-bit
    ( 9,  9, 11),   # 0 panel background
    (40, 40, 44),   # 1 bezel ring
    ( 3,  3,  4),   # 2 gauge face
    (60, 60, 60),   # 3 ticks / lettering
    (50,  6,  6),   # 4 red arc
    (16, 16, 18),   # 5 placards / shadow
    (28, 28, 30),   # 6 screws
    (60, 42, 10),   # 7 amber
]
px = bytearray([BASE] * (W * H))

def P(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[y * W + x] = BASE + c

def disc(cx, cy, r, c):
    for y in range(-r, r + 1):
        for x in range(-r, r + 1):
            if x * x + y * y <= r * r:
                P(cx + x, cy + y, c)

def ring(cx, cy, r0, r1, c, a0=0.0, a1=2 * math.pi):
    for y in range(-r1, r1 + 1):
        for x in range(-r1, r1 + 1):
            d = x * x + y * y
            if r0 * r0 <= d <= r1 * r1:
                a = math.atan2(x, -y) % (2 * math.pi)
                if a0 <= a <= a1:
                    P(cx + x, cy + y, c)

# panel top bevel and bottom shadow
for x in range(W):
    P(x, 0, 1); P(x, 1, 5)
    P(x, H - 1, 5)

def gauge(cx, cy, sweep_red=None):
    disc(cx, cy, 26, 1)          # bezel
    disc(cx, cy, 23, 2)          # face
    for k in range(13):          # 13 ticks over the 270-degree sweep
        a = math.radians(225 - k * 270 / 12.0)
        s, c = math.cos(a), math.sin(a)
        for rr in (18, 19, 20, 21):
            P(int(cx + rr * s), int(cy - rr * c), 3)
    if sweep_red:                # red arc at the top end of the scale
        a0, a1 = sweep_red
        ring(cx, cy, 21, 23, 4, a0, a1)
    P(cx, cy, 3)

gauge(60, 35, (math.radians(100), math.radians(135)))
gauge(260, 35, None)
# compass: full-circle ticks
disc(160, 35, 26, 1)
disc(160, 35, 23, 2)
for k in range(12):
    a = math.radians(k * 30)
    s, c = math.sin(a), math.cos(a)
    for rr in (18, 19, 20, 21):
        P(int(160 + rr * s), int(35 - rr * c), 3 if k % 3 else 7)

# placards between gauges + corner screws
for x0 in (96, 196):
    for y in range(52, 64):
        for x in range(x0, x0 + 28):
            P(x, y, 5)
for sx, sy in ((6, 6), (313, 6), (6, 65), (313, 65), (160, 66)):
    P(sx, sy, 6); P(sx + 1, sy, 6); P(sx, sy + 1, 6); P(sx + 1, sy + 1, 6)

out = os.path.join(os.path.dirname(__file__), '..', 'PANEL1.RAW')
with open(out, 'wb') as f:
    f.write(b'PB')
    f.write(bytes([len(COLS)]))
    for r, g, b in COLS:
        f.write(bytes([r, g, b]))
    f.write(bytes(px))
print('PANEL1.RAW: %dx%d, %d colours, %d bytes' % (W, H, len(COLS), 3 + len(COLS) * 3 + len(px)))
