# RENDER - 3D and 2D drawing in integers on the 8086

Drawing a world into the 320x200 back buffer, from the sine table to the
terrain. Working code: A:\ENGINE\E_M3D.INC (SINQ, SETTRIG, ROTXZ, PROJPT,
APPLYROLL, CLAMPAX), E_RAST.INC (PITCH4, CLIPNEAR, SCANPOLY, FACEFILL,
CLIPLINE, LINE), E_TERR.INC; the game's in A:\GAMES\OWLFLY3\SRC\.

## Rules you must not break

- No divide that can fault. INT 0 fires on divide by zero AND on a
  quotient that does not fit (byte IDIV: -128..127). Under DOSBox the
  fault returns to the IDIV and loops for ever. Guard every divide (near
  plane, clamped dividend, t in 0..1), use a reciprocal table, or install
  an INT 0 that never returns (A:\EXAMPLES\RELIEF.ASM TRAP0).
- IMUL and IDIV read a byte operand as SIGNED: 135 is -121, a depth of 163
  is -93. Keep byte operands in -128..127 or widen (CBW, IMUL WORD).
  A:\LESSONS\L15\PERSP.ASM ProjDiv breaks this itself (`dcon db DEYE/2` =
  135): do not copy it.
- IMUL never traps and a 16-bit ADD of two products wraps silently: the
  overflow is a wrong-signed number, not a crash. Bound the inputs.
- Clip before drawing: z >= near before projecting, the screen before
  LINE. Without the near clip the world behind you shows mirrored above
  the horizon; without the screen clip a frame takes a minute.
- MUL/IMUL/DIV/IDIV overwrite DX; only BX, SI, DI, BP survive them.

## Fixed point and tables

- Angles are bytes: 256 = a circle, 64 = 90 degrees, `and ax,255` wraps.
  Subtracting two angles gives the short way round, already signed.
- Game sine: SINT, 65 words of sin*256 (0..90 degrees; copy it from
  DATA.INC), unfolded by quadrant in SINQ; cos(a) = SINQ(a+64). Lesson
  sine: 256 signed bytes of 127*sin (A:\LESSONS\L14\SINTAB.INC), read by
  XLATB, `add al,64` for cos; IMUL then SAR 7.
- /256 after IMUL: the middle bytes of DX:AX ARE the quotient -
  `mov al,ah` / `mov ah,dl`, no IDIV. Exact only if the result fits 16
  bits (DH is dropped silently); rounds DOWN where IDIV truncates, so a
  negative can come out one lower. ROTXZ does this.
- Perspective by table: RECIP[z] = round(d*256/z), x' = (x*RECIP[z])>>8.
  It cannot trap. Rows under the near plane hold 0 (a too-near vertex
  collapses to the centre), row 255 is the far plane. FASM mints it:

```
RECIP:                          ; d/z in 8.8, one word per depth 0..255
repeat 256
  if % - 1 < ZNEAR
        dw 0                    ; nearer than the near plane: no answer
  else
        dw (DEYE*256 + (%-1)/2) / (%-1)   ; rounded d*256/z
  end if
end repeat
```

  If max|x| * RECIP[ZNEAR] < 32768, `sar ax,cl` (CL=8) does (43 x 728 = 31304
  at d 270, near 95); else take the middle bytes (A:\LESSONS\L16\CAM.ASM).
- y*320 = (y SHL 8) + (y SHL 6); a*41 = (a SHL 5) + (a SHL 3) + a.
- atan2: octant from the signs, then a 33-entry table indexed by
  smaller*32/larger (SHKATN, SYM.INC). Length: a*sin + b*cos at theta =
  atan2(a,b). Range: max + 3*min/8. isqrt: subtract odd numbers.
- Coordinates run to 49152: scale (>>4) before differencing for "nearest".
  Used only as world - cam (mod 65536), positions survive the wrap.
- RND16 (A:\ENGINE\E_MATH.INC): take its HIGH byte; low bit k cycles every
  2^(k+1) draws.

## Rotation

- A turn about an axis is a 2D turn of the other pair: Y turns (x,z), X
  turns (y,z), Z turns (x,y). One Rot2 does all of 3D (A:\LESSONS\L14\
  CUBE.ASM). y' needs the OLD x: keep x' aside, store both at the end.
- Turn about the model's own centre first, then translate. Y-then-X is
  not X-then-Y. Flip y once, at the projection, never in the model.
- The overflow is in the 16-bit SUM, so the LENGTH of the pair must fit
  (under ~258 with sin*127 words). A square view block 24 nodes out has
  corners at 34756 at a 45-degree heading: the far squares fling across
  the world. Walk a DISK (the first n entries of a distance-sorted table)
  and no heading overflows - also a quarter fewer squares (A:\LESSONS\L23\
  HOUSES.ASM).

## Projection

- sx = 160 + x*d/z, sy = horiz - y*d/z. d IS the field of view:
  FOV = 2*atan(160/d). 100 = 116 degrees (a cube reads as a tapered box),
  160 = 90 (a diorama), 220 = 72 (OWL FLY's FOCAL), 270 = 61 (the lessons,
  about the viewer's real eye). Stay at 60-72 degrees.
- The near plane comes from the overflow budget: znear >= max|x|*d/Qmax,
  Qmax = the biggest quotient you can hold (127 for a byte IDIV: |x| 44, d
  270 -> 95). The object's centre stops at near + its radius.
- PROJPT: word IDIV by rz, but for rz < 256 and |rx| > rz*(32767/FOCAL)
  it substitutes +-4000; then CLAMPAX, roll, clamp. NEARZ 40, FARZ 21600.
- CLAMPAX substitutes, it does not clip. A fill does not care (SCANPOLY
  clamps spans); a LINE swings. With FOCAL 220 it bites past |x|/z = 18.2:
  keep worst lateral offset / near plane under that for strokes (GRID,
  A:\GAMES\OWLFLY3\SRC\WORLD.INC: 12 cells, nzmin 288, restored to 40).
- Keep ground quads about cell-sized (256 units): a runway drawn as one
  3000x300 quad had a clamped corner fill half the sky; it is six slabs
  now (AFDRAWF, TOWN.INC).
- Roll: rotate each projected vertex about (160,horiz) (APPLYROLL); the HUD
  skips it. Pitch: rotate (y,z) per vertex (PITCH4) and shift the sky by
  pofs = psin*FOCAL/pcos, or +-2600 when pcos < 48 (SETTRIG).

## Camera

- view = R(-yaw) * (world - camera): subtract, then turn by MINUS the yaw
  (`neg al`); placing a model is the reverse. Move the camera, not the
  world. A step forward: rotate (0,step) by the yaw, add (CAM.ASM).
- Trig once a frame (SETTRIG). Whatever moves the camera for one render
  (chase, orbit, head turn, interpolation) restores the angles AND reruns
  SETTRIG before physics, or the jet flies off down the line of sight.
- A 90-degree head turn is Y(+-90)*M decomposed back to heading, pitch and
  roll (SVIEWF, SYM.INC); swapping pitch and bank is exact only at pitch 0.
- 18.2 Hz physics, smooth picture: draw old + (new-old)*fcnt/fprev, angles
  the short way, then restore the true state (LERPSET, PLANES.INC).
- A cockpit's horizon row is the middle of its own window glass.
- Lines and polygons must share one camera: PITCH4 pitches faces, PITCHP
  (WORLD.INC) gives edges the same turn. PITCH4 rotates IY/IZ IN PLACE:
  stash a face you fill and then stroke, or it is pitched twice.

## Clipping

- Edge: NEARCLIP -> PROJ2 -> CLIPLINE (Cohen-Sutherland) -> LINE
  (DRAWEDGE3D, M3D.INC); the cut (x1-x0)*num/den is exact via DX:AX.
- Face: Sutherland-Hodgman against z = NEARZ (CLIPNEAR): a quad becomes
  3..5 vertices. APPENDISECT makes den > 0, sets t = 0 for den 0 and clamps
  num to 0..den, so a garbage face clips ugly instead of faulting.
- Declare words clipx0/clipx1/clipy0/clipy1 and OUTCODE/CLIPLINE clip to
  that movable rectangle instead of 0..319 x 0..199.
- Whole-square cull: per node an outcode (z < near; x > 3z/4; x < -3z/4,
  as 3/4 ~ 160/FOCAL; SAR, z can be negative); skip a square when the AND
  of its four codes is non-zero (A:\LESSONS\L22\FILL.ASM). It assumes a
  level eye. Cull ground objects on |dx| AND |dz| before rotating.

## Fills and lines

- FACEFILL = CLIPNEAR + PROJPOLY + SCANPOLY. SCANPOLY fills a CONVEX
  polygon: per row, every edge half-open (lo <= y < hi, so exactly two
  hits), min/max x, clamp 0..319, `rep stosb`. All of OWL FLY III's fills
  pass there, so its wire mode is one `cmp byte [qual],2` inside.
- LINE never clips. It writes its +-1/+-320 steps into two `add di,320`
  (the placeholder keeps FASM's imm16 form), then JMPs: the prefetch queue
  holds old bytes until a jump. `linereg` keeps the distances in SI/BP
  (~40% faster on an 8088). With the fast ROTXZ: 60 -> 88 FPS (L19 CLIP).

## Draw order and hidden surfaces

- Painter's order by SQUARED distance (di*di + dj*dj), far to near;
  Chebyshev rings let far diagonals overdraw nearer cells. Precompute it as
  a table (TORD, BORD in DATA.INC); starting later in it is a detail level.
- Models: face depth = mean of its corners, bubble sort far to near, fill
  (MODELDRAW, PLANES.INC; small version A:\EXAMPLES\JET.ASM). 6 bytes a
  vertex, 5 a face, at most 25 and 16.
- Axis-aligned box: a wall faces you only from its outer side (camx < x0
  shows the west wall), the roof only from above. Hidden lines free: fill
  each visible face black, then stroke it, far to near (VISFILL,
  A:\GAMES\WIRECITY\CITY.ASM).
- Floating horizon for wireframes: HOR[320] = 200 each frame, draw near to
  far, a pixel shows only if y < HOR[x] and then becomes it (HLINE,
  A:\LESSONS\L21\RELIEF.ASM; needs the screen clip). 60 FPS against 76
  see-through. A filled world hides for free and needs none of it.
- Classes drawn in turn (terrain, then buildings) are not sorted against
  each other: a house behind a ridge paints over it.
- Coplanar slabs tie and flicker: lift markings one unit, draw them after.
  A single quad vanishes edge-on: build thin parts as two crossed quads.

## Terrain

- Diamond-Square on a 64x64 TORUS (DSGEN, E_TERR.INC; A:\EXAMPLES\
  TERRA.ASM, A:\LESSONS\L17\TERRAIN.ASM): `and 63` wraps, no edges.
  Anchors at step 32 take 64..191; per octave (32..2) diamond then square;
  noise = avg4 + (rnd_hi AND amp-1) - amp/2, clamped 0..255, amp 128 halving.
  Then stretch min..max to 0..255, or the averaging flattens the land.
- One island is exactly 4096 draws, which divides the LCG period: only 8
  different islands. One extra draw (stride 4097) frees the whole orbit.
- Bands: < 88 sea, 88-119 plains, 120-167 city, 168-199 woods, 200+
  mountains (GETZONE). World height (H-88)*5, sea 0, slope doubled above
  560 (WORLDH). A node is 1024 units = 4x4 cells of 256.
- Per frame: rotate and cache 41x41 nodes once, then 1600 quads far to
  near through FACEFILL, coloured by the highest raw corner, skipped when
  all z < NEARZ or all > FARZ (TERRPREP/TERRAIN, TERRAIN.INC).
- The cost is the NUMBER of squares, not their size: 625 squares ran 38
  FPS, 2401 ran 12 (38x625 ~ 12x2401). Twice the reach, four times the
  price. The side cull took 38 -> 54 and 12 -> 19. Stroke each shared edge
  once, owned by the nearer square.
- A wireframe needs vertical exaggeration (RELIEF doubles heights): a
  9-degree slope reads flat in lines. Spawn above the map's highest point.
- Flatten the DATA, never only the drawing: stamp a runway into the
  heightmap before anything is baked from it, one node wider than the
  patch; fill the map with one value for a flat mode. Far code holds inline
  copies of WORLDH that an override of the reader would miss.

## Things on the ground

- Sit anything on the terrain the way the mesh interpolates, per corner:
  bilinear over four nodes; corners on 256 multiples weigh 0..4 quarters,
  no divide (ROADYF, TOWN.INC). Round half-widths UP into quarters.
- A building stands on its LOWEST corner (the uphill excess hides behind
  terrain painted earlier), a vehicle on the mean. One routine (CELLYF)
  answers for drawing and every collision test.
- Sum world heights, not camera-relative ones: four of those overflow.
- Detail: roads one quad a cell within 9 cells, one per 2x2 out to 24;
  walls under 6 px get no glass; traffic only within 2200; on an 8088 one
  model costs ~60 ms (IMUL-bound), so far jets become markers.
- A vehicle you sit in lies inside the near plane: draw its guns through
  their own lens (eye 24 behind, 6 above), and floor that divide too (4).

## Sprites and effects

- Sprite: width, height, signed x/y (may crop), transparent index 255,
  pixels; skip 255. A grey outline (opaque pixel with a transparent
  neighbour) shows an item not yet taken, with no second picture. Cockpit
  overlays (span and RLE streams): video topic.
- Fireball: per row half-width = isqrt(r*r - dy*dy), rows clipped to
  0..199 and spans to 0..319 before `rep stosb`; radius r*FOCAL/rz, reject
  rz < NEARZ, cap 60 px (BLDISC/BLBALL, SYM.INC).
- No alpha in 256 colours: a hit flash floods every Nth row instead. A
  banking sky needs blue-noise dither: Bayer turns to dirt when rotated.

## Measuring

- With a retrace wait a frame takes whole retraces: 70, 35, 23 FPS and
  nothing between. Measure with the wait off.
- Prove a fast path by overlay: trusted in grey, fast in white, a red dot
  where they differ by more than a pixel (CAM.ASM Differ).
