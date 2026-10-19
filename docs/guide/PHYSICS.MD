# PHYSICS - motion in fixed point: flight, ground, collision, landing

How things move with 16-bit integers on an 8086, as the OWL FLY games do
it: the step, the flight model and its limits, terrain height, collisions,
landing, scale, overflow. The code: A:\GAMES\OWLFLY3\SRC\FLIGHT.INC (INPUT,
COLLIDE), UI.INC (GNDSCH, LANDF, WINDDRF, AFSPAWN), TERRAIN.INC (TERRH),
TOWN.INC (CELLYF); the forces lesson A:\LESSONS\L24\FORCES.ASM.

## Rules you must not break

- Step physics on the BIOS clock, never on the frame: the tick at
  0040:006C (18.2 Hz), one step per elapsed tick, at most MAXSTEP = 6 a
  frame. Hook no INT 8 and do not reprogram the PIT: both hung in the
  emulator the games target.
- No divide whose quotient can overflow. IDIV traps INT 0 on overflow as
  well as on zero, and under DOSBox the fault returns to the IDIV and loops
  for ever: a hang mid-flight. Shift before you multiply, clamp the input
  at the door, floor every divisor (a parked jet's speed to 1).
- Picture and physics read ONE answer: the draw walk and every collision
  test call the same height routine. Flatten or stamp the DATA (the
  heightmap), never only the drawing, or you fly through the picture.
- A new state exposes old forces (a parked jet still felt sway, wind and
  the cushion): for a new regime, list what already acts there and gate
  what does not belong.

## The fixed step

```
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,[es:6Ch]        ; BIOS tick, 18.2 Hz
        pop  es
        mov  bx,ax
        sub  bx,[lasttk]        ; ticks since last frame (wraps cleanly)
        mov  [lasttk],ax
        cmp  bx,MAXSTEP         ; anti-spiral: never more than 6 steps
        jbe  .n
        mov  bx,MAXSTEP
.n:     test bx,bx
        jz   .draw
.step:  push bx
        call INPUT              ; one physics tick
        pop  bx
        dec  bx
        jnz  .step
.draw:
```

- Smooth pictures: draw old + (new-old)*fcnt/fprev (fcnt = frames into the
  tick, angles the short way round), restore the true state before physics
  (PLANES.INC LERPSET). Cost: half a tick of latency.
- Physics flies off the trig the render left (hsin/hcos/psin/pcos). Any
  camera trick for one render (chase, orbit, head turn, interpolation) must
  restore the angles AND the trig: OWL FLY III calls SETTRIG after RENDER
  unconditionally. Without it the jet flew off where the pilot looked.
- Pause: force the elapsed count to 0 but keep lasttk fresh (no catch-up
  burst on resume); gate every other clock run off the tick too. Decay
  and animation run on the tick, never the frame.
- State written by a later stage is stale on the first tick: lgnd (ground
  under the jet) is written by COLLIDE after INPUT, so a fresh life read the
  last one's value and fell off its own ramp. Seed it at spawn.

## Fixed-point quantities

- vel is airspeed x16; a tick advances vel>>5 world units: CRUISE 736 = 23
  units a tick, VNE 2600 = 81.
- Angles are bytes, 256 a circle (64 = 90 degrees, AND 255 wraps); pitch is
  signed -64..64. Sines are x256 from SINQ (A:\ENGINE\E_M3D.INC).
- Keep the remainder of every small rate or slow things round to nothing:
  stick and rudder in eighths (pfrac/hfrac keep IDIV's remainder),
  nose-wheel steering and sink rate in 8.8, wind in 512ths. Speed carries a
  byte of 256ths (FORCES.ASM); nothing between the pair may touch CF:

```
        add  [velf],bl          ; the force's fraction, 256ths
        adc  [vel],ax           ; whole part plus the carry
        ; taking away: sub [velf],bl / sbb [vel],ax
```

## The flight model: OWL FLY III INPUT, one tick

- Air: rho = 256 - camy/8, clamped 64..256.
- Thrust = 720*(rho+256)/512 * throttle/64; burner x4 for 8 fuel a tick (1
  dry); no fuel, no thrust.
- Drag = vel*rho/256; flaps add 1/4 of it, gear 1/2, airbrake 1.
- vel += (thrust - drag)*64/mass, mass = 4000 + fuel/3; vel never below 0.
- Roll 3 a tick (a roll in ~4.7 s); hands off, the bank holds in free air;
  within 90 units of the ground the wings level at 2 a tick.
- Pitch through the roll plane: a pull q turns pitch by q*cos(roll) and
  heading by q*sin(roll) - level it loops, knife-edge it turns flat,
  inverted it splits-S. The stick ramps 2 eighths a tick up to 16: a tap
  nudges ~1/3 degree for aiming, a hold reaches 2 units a tick in ~0.4 s.
  A tick of stick costs TURNDRG 2 of vel.
- Past |pitch| 64 flip: pitch = +-128 - pitch, heading and roll +128.
- Energy: vel -= psin*24/256 - a climb spends speed, a dive buys it.
- VNE 2600 on the LAST write to vel bounds every reader below, all written
  for vel < ~1500 (in thin air the x4 burner would reach ~7200).
- Stall: under VSTALL 300 (225 with flaps) the nose drops 1 a tick to -48.
- camy clamped 24..CEIL 3000; the wind; then the advance, shifted first:

```
        mov  ax,[vel]
        mov  cl,5
        shr  ax,cl              ; units this tick = vel/32, SHIFT FIRST
        imul word [psin]        ; DX:AX = step * sin(pitch)*256
        mov  bx,256
        idiv bx                 ; climb; step <= 81, so it always fits
        add  [camy],ax          ; (the same with pcos, split by hsin/hcos)
```

- Measured clean at vel 450, gain a tick at pitch 0/14/24/32/46: burner x2
  7/-1/-6/-9/-14 (no climb held speed), x4 18/10/5/2/-3; 1000 units off
  the deck in 22 s at x2, 6 s at x4.
- What it cannot do: altitude is a pure function of attitude and speed,
  so "not enough lift" does not exist and a jet cannot settle onto a
  runway. The approach is scaffolding: APPRCH lowers camy 3 a tick with
  flaps out under VAPP 170, whatever the pitch. For a real wing carry the
  vertical rate as STATE: lift ~ v^2 * alpha against the weight, a stall
  that is an ANGLE (A:\LESSONS\L29\WING.ASM: alpha = ACRIT*Ncmd/Nmax, ACRIT
  15 degrees) and the relative wind, alpha + 229*vs/v, which stops a
  runaway zoom (A:\EXAMPLES\SOLO.ASM, LNDPHYS.ASM). Switching models in
  flight, seed the new state from the old (vsp from vvy) or she jerks.

## Ground and terrain height

- HMAP: 64x64 heights on a torus (index AND 63), nodes 1024 apart, cells of
  256 (4x4 a node). WORLDH = (H-88)*5, sea (H < 88) flat at 0, slope doubled
  above 560, peaks ~1110 (A:\ENGINE\E_TERR.INC).
- TERRH: bilinear between the four nodes round a point, fractions in 1/64
  of a node (TERRAIN.INC). WORLDH's IMUL clobbers DX: reload before HGET.
- What stands on a slope interpolates exactly like the mesh, per corner,
  or it hovers at one end and is buried at the other. A building stands on
  the LOWEST corner of its footprint, a vehicle on the CENTRE (the mean of
  four corners); one routine, CELLYF, answers the draw and every collision
  test. Sum WORLD heights, not camera-relative ones (four lifted heights
  overflow at altitude); round half-widths UP: (bhw+127)>>7.
- Stamp flat ground into the map right after generation, BEFORE anything
  is baked from it, and iron one node WIDER than the patch you judged:
  TERRH blends the nodes round a point, and ironing only the judged 2x4
  left the strip's edges sloping (5x7 now; UI.INC AFINITF). Mesh, TERRH,
  roads and collision then agree with no special case. Far segments keep
  inline copies of WORLDH, so change the map, not the routine.

## Collisions

- COLLIDE, once a tick: lgnd = TERRH; ground effect; below lgnd+14 (the
  hull) LANDF decides arrival or crash - a new outcome hooks into the one
  place an outcome is decided; then buildings: inside the footprint AND
  below CELLYF + height.
- The collision footprint moves with the drawing: when buildings grew onto
  2x2 plots (centre +256) the tests kept +128 and guarded empty ground.
- Hit boxes wider than a step: a shell moving 75..150 units a tick jumps a
  thinner box between samples. Station and flak boxes are 90 half-width
  (the flak hull is 34x16). Boxes, not meshes: a lattice mast is air.
- Nearest of many: a difference of two far coordinates can wrap; compare
  them >>4 (UI.INC SHKPICKF). Range without a root: max + 3*min/8.

## Landing and the parked state

- The gate (UI.INC LANDF): gear down, flaps down, under VAPP 170, over any
  side's concrete (260 off a centreline, AFLEN 1500 along it), and sink
  vsp8 = vel*sin(pitch)/32 in 8.8 above TDSLAM -700. Past TDFIRM -300 it was
  firm: +2 nose up, no bounce (from 2 units of pitch a bounce climbs 0 and
  re-contacts for ever); gentler is greased. Whole units cannot judge it:
  one unit a tick is ~9 m/s.
- LANDF runs every tick the wheels are down; its first test is "already on
  the wheels?" (onrwy), or a takeoff passing VAPP with flaps out crashes.
- GNDSCH runs right AFTER the advance and overrides only what three wheels
  decide: pitch, roll (level) and climb (pinned to lgnd+14); thrust and drag
  still act. Takeoff is the advance lifting camy above lgnd+14: one compare
  that cannot disagree with the physics.
- Wheel brakes (vel>>5)+3 a tick, rolling (vel>>8)+1; idle 24 of 64 gives
  +2 against 3+1, so parked she holds and brakes off she creeps. Nose wheel
  +-12 (arrows) +-6 (pedals) times vel, clamped +-512 a tick in 8.8. Nose up
  from VRSPD 290 (250 with flaps) to 14; at VR+45 she floats off at VLOFP 5
  (2 units of pitch truncates to zero climb). Grass above 160 is a wreck,
  90 ticks of grinding too; gear up on the wheels is a wreck. Rollout from
  VAPP-10: 44 units braked, 184 not.
- Dry with flaps she rotates at 250 and decays to 226; in burner she is off
  in ~3 s. A ported VR must be re-derived: the trainer's 330 assumed
  quadratic drag, and here gear and flaps settle at 254. A C# re-run of the
  integer steps found this, the zero-climb truncation and the vel-4096
  overflow before anyone flew: do it for any model you cannot fly yet.
- Parked is a state: gate on onrwy, never taper by height. Sway is zero on
  the wheels (the hit jolt still applies); wind is zero (tapered by height
  it still pushed a hull held 14 up a unit a second); the ground cushion is
  off with gear down (its up to 7 a tick beat the approach's 3, and the jet
  hung over the runway).
- Wind dies at the surface: full WINDX 2 / WINDZ -1 a tick above WINDH 512,
  linear to 0 at the ground, in 512ths (WINDDRF). A per-tick constant that
  is nothing at cruise dominates at landing speed.
- Ground effect: gear up, under 62 above the ground, vel >= 150, camy +=
  (62-h)>>3. Under 90, a dropped nose with the stick centred comes back 1
  a tick, so a gentle descent surfs the terrain.

## Scale - the code disagrees with itself

- Airframe and flight: the F-15 model spans 26 units against 13 m, so 1
  unit = 0.5 m. Speeds (1 unit a tick ~ 9 m/s, VNE "about Mach 2.2"), the
  sink limits, the apron (hangar 46 = 23 m, tower 96 = 48 m), the 3000 x 300
  runway (1500 x 150 m) and the 65536-unit world (32.8 km) all use it.
- The flak vehicle's hull is 34x16 units against a real 6.5x3.1 m: ~5 units
  a metre, as long as the F-15 on screen; its barrel comment (3 = 0.6 m)
  agrees. Its range readout uses 1 km = 1280 units (Manhattan); a working
  note gives 7 units a metre.
- Pick one scale before the first model, write it in one constant, convert
  every part with one factor (Obj2Inc -s N); the game's numbers are in its
  0.5 m units. Or carry real units in binary fractions, as SOLO.ASM does:
  height 1/64 m, speed 1/16 m/s, mass in kg.

## Overflow limits

- IDIV: vel*psin/32 passes 32767 at vel 4096 (a full-burner dive) - clamp
  vel to 2048 first; the advance's (vel>>5)*psin/256 has 8x the headroom.
- IMUL never traps: 18*vel wraps past 1820 and the nose wheel steers the
  wrong way - clamp to 1800. A wrong sign looks like a physics bug.
- DIV: SOLO's lift v^2*alpha/k faulted past ~550 km/h. When DX >= the
  divisor the quotient cannot fit: compare first and saturate.
- Signed flips: a lift word past 32767 became sink; cap below (29000), use
  JNO after a SUB that may overflow, compare unsigned values with JA/JB
  (62000 is -3536 to JLE).
- Positions are 16-bit and wrap mod 65536: use them only as differences
  from the camera, exact for small offsets. Byte operands of IMUL/IDIV
  must lie in -128..127.
