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

## Stage 1c - still to do

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

## Stage 2 - the landing

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
