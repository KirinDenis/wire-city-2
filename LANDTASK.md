# AERODROMES AND THE LANDING - planned 2026-08-05, stage 0 done

The pilot's spec: take the gear and the landing out of the trainer, without
breaking the flight model that exists - **landing mode arms only with the
flaps down**. A couple of aerodromes each side. Land, and you refuel and
rearm.

## Stage 0 - DONE: the byte budget, measured instead of guessed

`BSSMARK`'s trick is now on every far segment: `SKYEND`, `UIEND`, `SYMEND`,
`TWNEND` are PUBLIC labels at the end of each window, so the linker map
prints how full each one is. "Will this fit" is a number now, not a build
that either passes or explodes. What it said:

| segment | used | window | free |
|---|---|---|---|
| CODE (main) | FDEC | FDEE | **2 bytes** |
| SKYSEG | 7112 | 8176 | 1064 |
| UISEG | 13371 | 16368 | 2997 |
| SYMSEG | 2526 | 8176 | 5650 |
| TOWNSEG | 4496 | 8176 | 3680 |

So there is 13K of room for the WORK, and **no sixth segment is needed** -
which matters, because opening one moves the back buffer and everything
stacked above it, and that has gone wrong twice.

What was actually scarce is the main segment, where every far call site
costs five bytes. `MMAPGEN` moved out to SYMSEG as `MMAPGENF`: it bakes the
minimap once, at startup, out of HMAP, calls nothing hot and is never
called again - the coldest code in the program. **116 bytes back**
(BSSMARK FDEC -> FD78, 118 free). That is the whole feature's call sites
paid for, with change.

## Stage 1a - DONE: the four fields are sited and the ground is flat

`AFINITF` (UISEG) runs between DSGEN and BLKTABF, so the block table and the
minimap are both baked off a heightmap that already has concrete in it.
Four strips, interleaved by side the way everything else here is - even ours,
odd theirs - running north-south so ours point at the war.

**The siting is not FINDGND's.** FINDGND asks whether one POINT is legal and
searches +-200 world units for it, a fifth of a single heightmap node: it can
step off a shoreline and nothing more. Measured over forty worlds, the fixed
sites the radar stations use put **a third of the aerodromes in the water or
up a mountain**. A runway wants a legal PATCH, so `AFPATCH` scores the whole
2x4-node footprint and `AFINITF` walks out in rings to twelve nodes taking
the flattest legal one, with the ring number added to the score so a field
stays in the quarter of the map it was designed to hold. Measured over the
same forty worlds: **160 placements out of 160, mean ground spread 9
heightmap units, mean walk 4.9 nodes.**

**The radar now stands ON the aerodrome** (the pilot's note, and he is right
that it is what a real field looks like). It used to be planted on the spine
at its own fixed offset, 7000 back from the line, which put the mast and the
strip in unrelated fields. The dependency runs strip-first because the strip
is the fussy one: it has to walk until it finds ground flat enough to land
on, and a mast does not care what it stands on. So `RSTAINIT` reads `afx/afz`
and sets down `RSAPRON` (800 units) to the side of the centreline - beside
the concrete, still on the aerodrome's own flat ground. Station 0 is ours and
so is field 0, 1 is theirs and so is field 1: the same parity that carries
IFF everywhere else lines them up for nothing.

Fields 2 and 3 have no mast. That is deliberate - they are the secondary
strips, and there are only two stations.

The stamped height is clamped into 96..116 - inside the plains band, below
the city band - so no block whose centre lands on a runway can ever be zoned
built-up. Nothing grows on an aerodrome, and it costs no code to prevent it.

Cost: 31 bytes of the main segment (124 left), 743 of UISEG.

## Stage 1b - DONE: the concrete, with markings

`AFDRAWF` (TOWNSEG), called from RENDER between TERRAIN and BUILDINGS. Six
flat slabs a field: the concrete in ASPHALT, two edge lines, a centreline
and a threshold bar at each end, all in white. Each is the shape the streets
and the buildings already use - a world footprint through ROTCUL, the top
quad off FACETOPC, FACEFILL - so the rasteriser learned nothing new.

**The corners are not bent, and that is the flattening paying out again.**
`ROADYF` cannot be used here for two independent reasons: it assumes the
quad lies inside ONE heightmap node cell and a strip spans three, and there
is nothing to bend to anyway - `AFINITF` stamped the ground level before the
world was baked, so all four corners share one height and it goes straight
into `bry1`.

Cost: 13 bytes of the main segment (two far doors and the call site; 111
left), 337 of TOWNSEG.

Known and accepted: the strip is drawn after the whole terrain mesh, so a
ridge between the camera and the field does not occlude it. The streets have
carried the same artefact since they were written, and the fix for both is
the same one - draw ground decoration inside the distance walk - which is
not worth doing for four objects.

## Stage 1c - DONE (2026-08-06): the apron, and the sortie starts on it

**Hangars and a tower.** Three hangars in a row on the +x side, the same side
the mast stands, and the control tower closer in and well down the field -
abeam the touchdown point rather than at midfield, because a landmark beside
a runway is there to be in the corner of your eye on short finals. `AFBLD`
in TOWN.INC, called from AFDRAWF's own per-field loop.

**They are BOXES, not models, and that was the decision worth writing down.**
MODELDRAW reads its vertex and face tables through DS, and DS is the main
segment even out in a far window - so a hangar drawn the way the radar mast
is drawn would have put its geometry in the one segment that had three bytes
left. DRAWBOX takes eight words of parameters and no data at all, the traffic
opened that far door years ago, and a hangar is honestly a box. **Cost to the
main segment: nothing. 227 bytes of TOWNSEG.**

Every box is deliberately outside EDGEWIN's window grid (it wants `bhw`>=50
AND 60 units of wall): the hangars are too flat and the tower too thin. A
city window lattice on a hangar reads as an office block parked on the grass.
The tower cab is the only glass on the field.

**And a sortie now starts on the concrete.** The old spawn hunted the
heightmap for a city node and dropped the jet over it at 1450 doing cruise
speed. `AFSPAWN` puts her at the near threshold of field 0, stopped, gear
down, flaps set, facing up the strip - which is heading 0, because the
runways were laid north-south so ours point at the war. The wire's pilots
line up ALONG the strip now; four jets fanned 128 apart across a runway 150
half-wide was three of them in the grass.

**Every life costs a takeoff.** PLAYERRESET goes through the same AFSPAWN.
This is the question the old text below wrote down rather than answered, and
it is one line to undo.

Still open here: the mark on the map and the scope in the two IFF colours,
and the aerodrome has no garrison - the flak is placed along the front line
and knows nothing about the fields. **The hangars and the tower are scenery,
not obstacles**: collision is the city-cell test in COLLIDE and knows nothing
about them, so you can fly through the tower. Fixing that is a new test in
the main segment, which is why it is not in this pass.

## Stage 1c - the original list

The mark on the map and the scope, in the two IFF colours - the
cross-with-a-hole grammar the stations use, so the map keeps one visual
language. Then the sortie start moves onto the concrete, which is what the
gear was for. And the aerodrome has no garrison: the flak is placed along
the front line and knows nothing about the fields.

## Stage 1 - the aerodromes exist

Four fields, following the radar stations' proven pattern (`RSTAINITF` and
friends): two ours to the south of the front line, two theirs to the north,
on the x = 24576 spine the squadrons already form up on.

**The runway is stamped FLAT into HMAP, once, right after DSGEN.** This is
the decision the rest hangs on. The world is diamond-square; a runway laid
on its natural slope is unlandable, and special-casing the terrain under it
would mean special cases in the mesh, in TERRH, in the road walk and in the
collision test - four places to forget. Flatten the heightmap instead and
every one of them agrees for free, with no code at all. The strip takes the
median height of its own footprint so it sits in the landscape rather than
on a plinth.

Then: the strip drawn as asphalt (ROADYF already lays a quad on the ground),
threshold bars and a centreline, and a mark on the map and the scope in the
two IFF colours - the same cross-with-a-hole grammar the radar stations use,
so the map keeps one visual language.

## STAGE 2a - DONE (2026-08-06): THE GROUND SCHOOL

**And the plan below was wrong about why it had to wait.** The premise was
that the trainer "carries `vsp` as STATE with `GRAV` acting on it", so the
vertical axis had to be restructured before anything could land. It does not.
`F_PHYS.INC` writes `vsp` in exactly two places and both are derived -
`vsp = spd*sin(pitch)`, then the ground cushion damps it - which is the SAME
LAW this game already uses for `vvy`. `GRAV` acts on the AIRSPEED along the
flight path: dive buys speed, climb spends it. OWLFLY2 has had that line
since it was written, with 24 where the trainer has 4.

So the two models are the same model, and the school is a self-contained
branch hanging off it. It went in without the approach model existing.

Ported: brakes, rolling resistance, nose-wheel steering whose rate grows with
ground speed, rotation at VR, the float-off at VLOF, concrete versus grass,
and the greased/firm/slammed touchdown gate. `GNDSCH` in UI.INC (UISEG);
`ONPAVE` shared with LANDF; **one far call from INPUT, straight after the
3-D advance.** The airborne code runs first and the school overrides
whichever axes a jet standing on three legs is entitled to argue with - but
NOT thrust and drag, which bite exactly as hard standing still.

Reading the advance's own answer is what decides the takeoff. There is no
separate test for "has she flown": the advance ran a few instructions ago
with the pitch the school set last tick, and if that carried her above the
wheels she is flying. It cannot disagree with the physics because it is the
physics.

### The two things that could NOT be transcribed, and how they were caught

Both were found by re-implementing INPUT and GNDSCH in C# and running them -
not by reading. Neither would have survived a first flight.

**1. The trainer's VR is unreachable here, so the burner is how you leave the
ground.** The trainer rotates at 330 because its drag is QUADRATIC
(`V*V/680`); ours is LINEAR (`vel*rho/256`) with the gear and flaps adding
three quarters again on top. **Measured: a jet on the deck at full DRY thrust
settles at 254 and can never see 330 at all.** So VR is hung off what this
jet can actually reach - `VRSPD 290`, `VRFLAP 40`, `VLOFD 45` - and what
falls out is worth having. Dry with flaps, the nose comes up at 250 and the
speed then DECAYS to 226, because the rotation spends energy the dry engine
cannot replace: she sits there nose-high going nowhere. Light the burner and
she is off in three seconds and 150 units. The failure states its own cause.

**2. Two units of nose-up is not flight in this arithmetic.** The trainer
floats off at `pit=2`. Ours climbs `(vel/32)*sin(pitch)/256` in WHOLE units,
and at these speeds two units of pitch truncates to zero climb - she would be
"flying" and still pinned to the concrete. `VLOFP` is 5.

**And one real bug the reading did catch, late:** `lgnd` is written by
COLLIDE, which runs AFTER the physics, so on the first tick of a life it
holds whatever was under the previous one - zero at startup. GNDSCH's first
question is whether camy has risen above `lgnd+14`, and against a stale zero
the answer is yes. She would have been declared airborne while standing on
her own ramp. AFSPAWN seeds `lgnd`.

### The sink gate, and what it can and cannot see

`vsp8` is the sink rate in 8.8 units a tick - the trainer's own scale, where
`vsp8 = vvy*256` exactly. It is kept every tick, airborne or not, because the
one tick anybody reads it is the tick she arrives. It had to be a fraction:
`vvy` beside it is the same number in whole units, and one whole unit a tick
is about nine metres a second, three times a gear-collapsing arrival. A
landing cannot be judged on it. `TDSLAM -700` and `TDFIRM -300` are the
trainer's numbers unchanged, and they transfer because `vel` means the same
thing in both programs.

**What it does not see is APPRCH.** The scaffolded settle is 3 units a tick
applied straight to `camy`, so it never reaches `vsp8` and the gate judges
the AERODYNAMIC sink only - a dive onto the numbers is a wreck, a settle is
greased. That is the right behaviour for now and it stops being a compromise
the moment APPRCH goes.

Measured rollout: **44 units with brakes, 184 without**, from VAPP-10. Both
are short against 3000 units of runway, and that is not the school - it is
this game's drag being strong at landing speed. It is a number to have the
scales conversation with, not a fault in the port.

**APPRCH and the gear-gated cushion are still in, deliberately.** They are
scaffolding, but pulling them without the approach model would make it
impossible to get DOWN to the runway the school now knows how to receive you
on. They come out together with Stage 2b.

## STAGE 2b - THE APPROACH MODEL. Start here. (the task, 2026-08-05)

The pilot's decision, and it is the shape of the whole job:

> **F not set: the existing physics, exactly as it is - it is proven, do not
> touch it. F set: switch to the model from the TRAINER, so that nothing
> that already works can break.**

### Why the current model cannot land, and no patch will make it

Altitude in OWLFLY2 comes from ONE line: `camy += vel/32 * sin(pitch)`. It
is a pure function of attitude and speed. **There is no such thing as "not
enough lift" in it** - so there is nothing for the aeroplane to sink on. It
holds height exactly when level and dives when you push, and those are the
only two things it can do.

Three patches were tried on top of it this session and they are SCAFFOLDING,
to be deleted when the real model lands: `APPRCH` (a fixed sink when flaps
are out and slow), `LANDF` (arrival or accident), and a gate that switches
the ground-effect cushion off when the gear is down - the cushion pushes up
to 7 units a tick against a 3-unit sink, which is why the jet hung over the
runway and why diving through it always broke. They make a landing possible.
They do not make it a landing.

### What to port, and why it is not a foreign body

`GAMES\TRAINER\SRC\F_PHYS.INC`, 758 lines. Its own header says it: **ported
from OWL FLY (FLIGHT.INC)**. Same lineage, same trig, same order - density,
thrust, drag, F=ma, roll, rudder, elevator through the roll plane, energy,
stall, cushion, 3-D advance. The ground school on top of it - nose-wheel,
VR, brakes, dirt, touchdown - was written FOR the trainer.

This is not `EXAMPLES\LNDPHYS.ASM`. That one is 1709 lines in its own units
(1/16 m/s, 1/64 m) modelling one scripted approach, and it is not what to
reach for.

~~**The one structural thing to bring across is the VERTICAL AXIS**: the
trainer carries `vsp` as STATE with `GRAV equ 4` acting on it.~~

**WRONG - corrected 2026-08-06, see Stage 2a.** It does not. `vsp` is written
in two places and both are derived (`spd*sin(pitch)`, then damped by the
cushion); `GRAV` acts on the airspeed along the flight path, which OWLFLY2
already does with 24 in place of 4. There is no vertical axis to bring
across, because the trainer has not got one either.

**Which means the hard part of this task is still ahead of it, not behind.**
Neither model can sink without pointing the nose down, so porting the trainer
wholesale does NOT produce an aeroplane that settles onto a runway - it
produces the same aeroplane with a ground school under it, which is what
Stage 2a shipped. What is actually needed is the thing NEITHER program has:
a vertical rate that is state, with weight on it and lift opposing, so that
"not enough lift" becomes expressible. That is new work, and the trainer is a
reference for the ground school and the constants, not a donor for this.

### The seam, which is the only real risk

The two models share position, speed, pitch, roll and heading. They do not
share `vsp`, because the cruise model has no such thing.

- **Going in** (F set): seed `vsp` from the climb rate the jet HAS right now.
  `vvy` is already computed every tick for the IVV caret - use it. Miss this
  and the aeroplane jerks the moment the flaps come out.
- **Coming out** (F cleared): nothing to do. The cruise model never reads
  `vsp`.

### The scales, which are the other real risk

**Corrected 2026-08-06 by reading both files.** "OWLFLY2's are not the same
numbers" was wrong, and wrong in the helpful direction: `THRUST 720`,
`VSTALL 300`, `TURNDRG 2` and `CEIL 3000` are IDENTICAL in the two programs,
`vel` means airspeed x16 advancing vel/32 units a tick in both, and the
trainer's `MASS 8000` is exactly OWLFLY2's `MEMPTY 4000 + FUELMAX/3` with
full tanks. This is one family and the shared constants came across
untouched.

There are exactly **two** real divergences, and naming them is worth more
than a warning about scales:

- **The drag LAW.** Ours is linear (`vel*rho/DRAGK`, DRAGK 256), the
  trainer's quadratic (`V*V/DRAGK2`, DRAGK2 680). This is what made the
  trainer's VR unreachable here - see Stage 2a - and it is the thing to
  decide about first, because everything else is downstream of how much
  speed the aeroplane has.
- **Mass.** Ours falls as the fuel burns (4000..8000); the trainer's is
  nailed to full tanks.

`GRAV 4` and `VRSPD 330` exist only in the trainer, and now for a clear
reason: OWLFLY2 had nothing to fall and nowhere to take off from.

The old warning still stands for anything NEW: port a formula without
mapping the scale and the approach will be arithmetically right in the wrong
speeds, which reads as a lie the first time you fly it.

**Verify it before anybody flies it.** Both models are integer and
deterministic: re-implement each in C# and run them on the SAME inputs -
same throttle, same stick, same start - and compare the altitude and speed
profiles. That is how the gear was fitted and how the aerodromes were sited
this session, and it is what stops a flight model being shipped "roughly
right". The trainer already flies the way the pilot wants; it is a reference
you can diff against, not a guess.

### Where it lives

~~The main segment has 3 bytes.~~ **It has 232 as of 2026-08-06** - the
eviction this paragraph asked for was done: `PLAYERRESET` had one caller,
ran once per death and was the coldest thing left in there, and the
city-node spawn search went with it when the sortie moved onto the concrete.
The approach model itself still goes in a far segment, which is where it
belongs anyway: it runs a few times a second and is cold next to the render.

### Also waiting in the build

The four `*** TEMP ***` stage markers (SYM.INC, and four call sites in
CITY.ASM) are still in. They are there to catch a network freeze the pilot
and a friend can reproduce - a frozen frame stamps its stage colour into
video memory. **Take them out once that is caught**, and the main segment
gets ~20 bytes back.

## Stage 2 - the landing (the original sketch, superseded by the task above)

Not a port of `EXAMPLES\LNDPHYS.ASM` - that is 1700 lines of a standalone
program in its own units (1/16 m/s, 1/64 m) modelling one scripted approach
to one runway. What comes across is its ARGUMENT: the touchdown is not an
event, it is what happens when lift, drag and weight stop arguing.

The gate, in the pilot's words: **flaps down or it is not a landing.** Gear
too - a belly landing must not refuel anybody. The hook is one branch in
`COLLIDE`, where `camy` dropping below the ground currently means
`CRASHHANDLE` and nothing else:

    jge  @@terok
    call FAR PTR LANDF          ; is this an arrival, or an accident?
    jc   @@terok
    call CRASHHANDLE

`LANDF` (far, all of it) judges: on a runway, gear down, flaps down, sink
rate under the limit, wings near level, nose not down. Miss any and it is
still a crash - the pilot wants consequences, not a forgiving box. Then it
holds the jet on the strip, bleeds speed, and the airbrake and the wheel
brakes do what they say.

## Stage 3 - fuel and arms

Stopped on a friendly strip: fuel back to `FUELMAX`, missiles back to full,
and the damage that is repairable repaired. Ours only - putting down on
theirs should be its own kind of story, and is not this task.

## Answered by the pilot, 2026-08-05

**A sortie STARTS on the strip.** In his words: fuelled, towed out, made
ready. So the jet no longer arrives at 1450 doing cruise speed - it begins
stopped, on its own concrete, and the first thing any flight contains is a
takeoff. That is the whole reason the gear went in.

The question this drags behind it, and it is not a small one: **does a fresh
jet after a DEATH also start on the strip?** The house rule here is
consequences over convenience, so the answer that fits is yes - every life
costs you a takeoff. It is written down rather than done quietly because it
changes what dying feels like more than anything else on this list.

**You can land on the ENEMY's field, and shoot it up from there.** No fuel,
no rearm - that is ours only. What it buys instead is a raid: put down on
their concrete and work over whatever is parked on it. Which means their
field has to have things ON it worth a cannon, and something that answers
back - the flak that covers a field is the obvious garrison, and it already
exists.
