# The 3D graphics of WIRE CITY 86, with the sources open

How a full 3D world — terrain to the horizon, a destructible city,
twenty aircraft a side — renders at speed on an 8086 with no z-buffer,
no floating point and no multiply faster than `imul`. Every section
links into the real code at the [v1.0 tag](https://github.com/KirinDenis/wire-city-2/tree/v1.0),
so the links never rot. Read with the sources open; that's what they
are for.

## 0. The frame, end to end

Every frame: clear the sky bands into an off-screen buffer, draw the
terrain far→near, the buildings far→near, the aircraft, the HUD — then
blit 64000 bytes to VGA in one `rep movsw`. The order IS the visibility
algorithm: this is the painter's algorithm, and it appears three times
in three different costumes.

- Frame driver: [`SRC/SCENE.INC`](https://github.com/KirinDenis/wire-city-2/blob/v1.0/SRC/SCENE.INC)

## 1. Fixed point: everything is `*256`

There is no floating point. Angles are bytes: **256 = a full circle**,
so wrapping is a free `and ax,255`. Sines come from a 65-entry quarter
table (`SINT`, values `sin*256`) unfolded by symmetry in `SINQ`.
Every rotation is the same two-line idiom:

```
imul word ptr [hcos]   ; DX:AX = x * cos*256
mov  bx,256
idiv bx                ; /256 - the scale cancels
```

- `SINQ`, `SETTRIG`, `ROTXZ`: [`ENGINE/E_M3D.INC`](https://github.com/KirinDenis/wire-city-2/blob/v1.0/ENGINE/E_M3D.INC)
- The quarter table `SINT`: [`SRC/DATA.INC`](https://github.com/KirinDenis/wire-city-2/blob/v1.0/SRC/DATA.INC)

## 2. Projection with a bodyguard

`PROJPT` is the classic `sx = 160 + rx*FOCAL/rz` — plus the part
tutorials omit: **on the 8086, `idiv` fires INT 0 both on divide-by-zero
and on quotient overflow**. A vertex far to the side at small `rz`
overflows the 16-bit quotient and kills the machine. So `PROJPT` guards:
if `rz < 256`, it first proves `|rx| <= rz * (32767/FOCAL)`; if not, the
point clamps off-screen with its sign kept. Both constants scale with
the lens — change `FOCAL`, and the guards follow.

After projection every vertex passes through `APPLYROLL`, which rotates
the whole projected scene about the pitched horizon — that is how the
world banks when you roll while the HUD stays put.

- `PROJPT`, `APPLYROLL`, `CLAMPAX`: [`ENGINE/E_M3D.INC`](https://github.com/KirinDenis/wire-city-2/blob/v1.0/ENGINE/E_M3D.INC)

## 3. Painter #1 — the world, sorted before the game even runs

Terrain quads and city blocks draw far→near with **zero sorting per
frame**. The trick: sort *camera-relative offsets*, not positions. The
tables `TORD` (terrain) and `BORD` (buildings) hold every cell offset in
the visible square, pre-sorted by squared distance, descending. Since
translation does not change relative order, one table is correct from
every camera position, forever. The renderer just walks it.

- The tables: [`SRC/DATA.INC`](https://github.com/KirinDenis/wire-city-2/blob/v1.0/SRC/DATA.INC) (search `TORD`, `BORD`)
- The walks: [`SRC/TERRAIN.INC`](https://github.com/KirinDenis/wire-city-2/blob/v1.0/SRC/TERRAIN.INC) (search `TERRAIN:`),
  [`SRC/WORLD.INC`](https://github.com/KirinDenis/wire-city-2/blob/v1.0/SRC/WORLD.INC) (search `BUILDINGS`)

## 4. Painter #2 — aircraft, a bubble sort that earns its keep

Each aircraft is 13..25 vertices and 8..12 quad faces (per-type tables —
`MVTAB/MFTAB` — give the bomber four engine pods and the radar picket
its rotodome; the first 13/8 are always the core airframe, which is all
the wreck pool breaks). Per frame: rotate the vertices by the model's
yaw relative to the camera, average each face's corner depths, and
**bubble-sort** the faces far→near. A bubble sort in 2026! — but between
two frames the order barely changes, so it runs nearly O(n), and n ≤ 12.

- `PLANESDRAW` (vertex cache, face depths, the bubble, the draw):
  [`SRC/PLANES.INC`](https://github.com/KirinDenis/wire-city-2/blob/v1.0/SRC/PLANES.INC)
- The models: [`SRC/DATA.INC`](https://github.com/KirinDenis/wire-city-2/blob/v1.0/SRC/DATA.INC) (search `MVERT`)
- Standalone playground: [`EXAMPLES/JET.ASM`](https://github.com/KirinDenis/wire-city-2/blob/v1.0/EXAMPLES/JET.ASM) —
  the hangar: all five aircraft, Up/Down to cycle, Space to blow one up.

## 5. The face pipeline: clip, project, fill

Every face funnels through `FACEFILL`: near-plane polygon clipping
(`CLIPNEAR`, Sutherland–Hodgman against `Z = NEARZ`, up to 6 output
vertices), projection (`PROJPOLY`), and a scanline fill (`SCANPOLY`)
into the back buffer. Lines get Cohen–Sutherland (`OUTCODE`/`CLIPLINE`)
and Bresenham (`LINE`).

The clip interpolation carries a war wound worth reading: a garbage
face (16-bit coordinate wrap upstream) once drove `idiv` into quotient
overflow — the hang was caught **under Turbo Debugger**, mapped to the
line with a TASM listing, and fixed by clamping the interpolation
parameter into [0..1], which makes overflow mathematically impossible.
The comment block at the site tells the story.

- All of it: [`ENGINE/E_RAST.INC`](https://github.com/KirinDenis/wire-city-2/blob/v1.0/ENGINE/E_RAST.INC)
  (search `APPENDISECT` for the hardened divide)

## 6. What we DON'T do, on purpose

- **No z-buffer**: at 320×200 it would cost 64 KB — more than the whole
  program. Painter's order costs nothing.
- **No per-pixel tests**: visibility is decided per-face and per-cell.
- **Known honest hole**: aircraft draw after the world, assuming a sky
  background; a jet directly behind a tower paints over it. The cheap
  fix (one depth test per jet vs. the occluding column) is left as the
  first exercise for a fork.

## 7. Try it yourself

`EXAMPLES/` builds three standalone `.COM`s on the same engine modules
(each states its variable CONTRACT in the header — one-pass TASM's
undefined-symbol errors literally dictate it):

- `TERRA.COM` — the island factory (Diamond-Square on a torus)
- `RING.COM` — the one-channel sound mixer (not graphics, but the same
  discipline)
- `JET.COM` — this document, running: rotation, sorting, clipping,
  filling, and the breakup physics, in ~5 KB

Build everything with `MAKE.BAT` (see the repo README). The listing
trick from section 5 — `TASM /T /l`, then grep the crash offset — works
on any DOS-era binary you'll ever have to rescue.
