# OWL FLY II - where the work stands, 2026-08-05

Written to be read COLD, at the start of a session, by someone who was not
in the last one. Read this, then the task file for whatever you pick up.

## Read these first, in this order

1. **`GAMES/OWLFLY2/ARCHITECTURE.md`** - the engine.
2. **This file** - what is done, what is open, what will bite you.
3. The task file for the thing you are picking up: `LANDTASK.md`,
   `VIEWTASK.md`, `BOOMTASK.md`, `ROADTASK.md`, `RADARTASK.md`.

## The three things that will bite you

**1. The main segment is the only scarce thing, and every far call costs 5
bytes of it.** As of 2026-08-06 it has **232 bytes** free, and it is worth
knowing where they came from: it was down to 3, and the ground school needed
a call site, so `PLAYERRESET` was evicted to UISEG (one caller, once per
death, the coldest thing left) and the city-node spawn search was deleted
outright when the sortie moved onto the concrete. That is the procedure,
every time: **do not shave - EVICT, coldest first.** About 20 bytes more come
back the moment the `*** TEMP ***` freeze markers come out. The linker map
tells you exactly, because every window carries a PUBLIC end marker -
`BSSMARK` (main), `SKYEND`, `UIEND`, `SYMEND`, `TWNEND`. Build and read
`SRC/CITY.MAP`:

    0000:FD06  BSSMARK    main, guard is FDEE   <-- 232 bytes
    1000:1BC8  SKYEND     window 8176           (1064 free)
    1200:3BA2  UIEND      window 16368          (1102 free)
    1600:146F  SYMEND     window 8176           (2945 free)
    1800:1415  TWNEND     window 8176           (3035 free)

UISEG is now the tight one, not the main segment.

When the main segment is tight, do not shave - **evict**. The coldest code
is the cheapest: `MMAPGENF` (bakes the minimap once at startup) moved to
SYMSEG this session and gave back 116 bytes for four bytes of call.

**2. Opening a new far segment MOVES THE BACK BUFFER and everything stacked
above it.** This has gone wrong twice and both times looked like a
deliberate graphics effect rather than a fault. The stack from the buffer
up is: bufseg CS+1A00h, resseg CS+2A00h (CITY.DAT), sndseg (64K-aligned
from CS+4FFFh), scrseg (the baked minimap), cpsseg (= scrseg+1000h, the
side panels). If you must add a far DATA page, put it **on top** past
cpsseg, where nothing is stacked on anything - that is why CPSIDE.DAT sits
where it does. Read the comment beside `resseg` in CITY.ASM before you
touch any of it.

**3. A FIXED-POINT `idiv` IS A HANG WAITING FOR ENOUGH SPEED.** `idiv` traps
INT 0 when the QUOTIENT will not fit in a word, nothing here catches INT 0,
and the machine stops mid-frame looking exactly like a hang. The flight model
is full of `imul`/`idiv` pairs and they are all safe for one reason: **they
SHIFT FIRST.** The advance computes `(vel>>5)*psin/256`, not `vel*psin/32` -
same number, eight times the headroom.

The ground school's sink rate divides by 32 precisely to KEEP the fraction,
and shipped without buying that headroom back. It overran at `vel` 4096,
which this jet reaches in about fifteen seconds of vertical dive at full
burner - reported as *"took off, flew a bit, and it froze"*, which is the
shape of it: you have to be fast before you can be fast enough. Found by
running the model in C#, not by reading it. **Any new fixed-point divide in
here clamps its dividend at the door**, and the sibling `imul` wants the same
treatment - that one does not trap, it hands back a wrong-signed low word,
which is worse because it looks like a physics bug.

**4. `SETTRIG` must run after the render as well as before it.** `INPUT`
flies the jet straight off `hsin/hcos/psin/pcos` and never computes them.
Anything that moves the camera for the length of a render - chase, orbit,
the pilot's head - must leave the trig belonging to the AIRCRAFT. This cost
a whole extra round trip with the pilot; the contract is now written at the
top of CITY.ASM.

## Done this session

- **The ring road** (`ROADTASK.md`). Streets are planned by the BLOCK, not
  the cell, so avenues run end to end and a built-up district wears a
  closed belt. Reach went 9 cells -> 24 (the whole walk) paid for by a 2x2
  level of detail. Road quads are bent onto the terrain corner by corner.
- **Looking out of the side** (`VIEWTASK.md`). F6 / F7 and Ctrl+arrows,
  ninety degrees, with the two painted consoles from `res/cockpit_left.png`
  and `cockpit_right.png`. The head turn is a real matrix rotation
  decomposed back into the engine's yaw-pitch-roll - verified exact over
  24024 attitudes.
- **The moment of destruction** (`BOOMTASK.md`). A fireball and three
  cook-offs over the first seven seconds, on every kill in the game.
- **Weapons stopped regenerating.** Four missiles and 250 rounds are now
  spent for good. Fuel doubled to 12000 (~11 minutes).
- **Panel**: BURN reads red; AB ON moved up into the black plate.

## Fixed on the way past (2026-08-05)

**The lock encoding had outgrown its shelf.** A locked target rides in
`locki` as one number: a plane is an offset 0..78, a Shilka is
`SHKLK + index*2`, a station is `RSLK + index*2`. `SHKLK` was a TYPED
CONSTANT, 0FFE0h, written when there were six Shilkas - it left room for
eight. There are twenty. So locking Shilka 8 decoded as a radar STATION,
past 9 it read off the end of a two-entry array, and from 16 it wrapped
past 0FFFFh into **plane offset zero: the pilot's own aeroplane**. F4 then
orbited the player, who is deliberately not drawn in that view, and the
flak vehicle "vanished". `SHKLK` is now `RSLK - NSHILK*2` with two
assemble-time guards - the shelf is measured from the one above it and
cannot be typed wrong again.

**Neither cinema camera was switched off on respawn.** Take a fresh jet
while F4 is orbiting and the new aeroplane arrives with no cockpit (the
panel is skipped whenever `tgtcam` is up), no view of itself, and the arrow
keys still steering the CAMERA. Nothing answers the stick, so it reads
exactly like a hang. `PLAYERRESET` clears `tgtcam` and `mcact` now.

If a freeze is ever reported again, the question that splits it is whether
the PICTURE is still moving - a lost-control state still has a falling
wreck and a turning camera in it; a real hang does not.

## The manual (2026-08-05)

It is ALL ON `docs/owlfly2.html`, under the game - not separate pages. That
was the pilot's correction and it was right: a manual you have to navigate to
is a manual nobody reads. Sections: what this is, the front door, the
labelled cockpit, every key in one table, how to fight, the switch panel,
the aerodromes, the war.

**The diagram is not hand-placed.** `docs/cockpit.png` is `PANELIMG.INC`
rendered through PALDAY by the rig (`panel` mode), and the callouts are an
SVG whose viewBox CARRIES the game's own 320x200 screen at x=100 - so every
leader line is anchored on the same number the source uses (`PANELZON.INC`,
`WLMPX`, `SWX`, `OSBX`, `PZDIG*`). Move a screen in the artwork and the
diagram is re-fitted from the constants rather than by eye.

The page had also been telling two lies for a while - missiles and cannon
rounds have not reloaded themselves since the pilot asked for that to stop -
and the switch section is deliberately honest about which plates do nothing
yet. An unlit plate is a better way to say "not yet" than pretending the
aeroplane has a capability it has not got.

## Done 2026-08-06: the apron, and the ground school

`LANDTASK.md` stages 1c and 2a have the whole of it. In short:

- **Hangars and a control tower on every field**, drawn as parameterised
  boxes through the traffic's own `DRAWBOXF` door rather than as models -
  MODELDRAW reads its tables through DS, so models would have cost the one
  segment that had three bytes. Main segment: nothing. TOWNSEG: 227 bytes.
- **The ground school**, ported from the trainer: brakes, rolling
  resistance, nose-wheel steering that grows with ground speed, rotation at
  VR, float-off at VLOF, concrete versus grass, and a real
  greased/firm/slammed touchdown gate on an 8.8 sink rate.
- **A sortie starts on the concrete**, stopped, and so does every life
  after a death.

**And it corrected the plan.** The reason the approach model was supposed to
come first - "the trainer carries vsp as STATE with gravity on it" - is not
true: the trainer derives vsp from pitch and speed exactly the way this game
derives vvy, and its GRAV acts on airspeed. Both programs are the same model.
Which means the approach model is still ahead and is genuinely NEW work, not
a port: what is needed is a vertical rate with weight on it, so that "not
enough lift" can be expressed at all. Neither program can express it today.

## A PARKED JET IS A NEW STATE, AND THE AIR MODEL DID NOT KNOW ABOUT IT

Three faults in a row had one shape: **something that models moving air was
still acting on an aeroplane standing on its wheels.** Until this week the
jet could not be stationary - a sortie began at 1450 doing CRUISE - so none
of it could ever show.

- **The sway.** The whole view floats on a slow sine. Parked, the horizon
  rocked while the aeroplane was plainly bolted to the ground, which reads as
  the picture being broken rather than as weather. Gated on `onrwy`.
- **The wind.** `WINDDRF` tapers the breeze to nothing at the surface, which
  is honest - but it tapers against HEIGHT ABOVE GROUND, and a jet on its
  legs sits fourteen units up. Fourteen times WINDX is 28 of the 512ths a
  whole unit takes, so a parked jet earned one unit of sideways drift every
  eighteen ticks and slid off its own apron at a unit a second. Reported as
  *"it slowly creeps to the right"*. Gated on `onrwy` - tapering to zero at
  14 instead would be arithmetic covering a category error, because wind does
  not push a machine held by friction.
- **The ground cushion** was already gated, on the gear, back when the
  landing scaffolding went in - same instinct, found the hard way.

**If you add anything that acts on the airframe, ask whether it should act on
a jet that is parked.** The test is not "is the number small down here", it
is "is this aeroplane in the air at all".

## The burner is four times dry thrust now (2026-08-06)

**And it is not a difficulty knob, it is a bug the runway exposed.** Measured
net acceleration per tick, clean at full throttle, against the angle held:

| pitch (256ths) | 0 | 14 | 24 | 32 | 46 |
|---|---|---|---|---|---|
| x2, vel 450 | 7 | -1 | -6 | -9 | -14 |
| x4, vel 450 | 18 | 10 | 5 | 2 | -3 |

At x2 **every climb angle was zero or negative**: point the nose up and the
jet bleeds, and past 20 degrees it bleeds into the stall and the nose falls
through on its own. Nobody could notice for as long as a sortie began at 1450
doing CRUISE 736 - the jet was handed to you with all the energy it would
ever need. A sortie now begins STOPPED and unsticks around 264, and this game
had never once been flown at that end of its own model. Time to a thousand
units off the deck: 22 s at x2, 6 s at x4.

**Only the burner changed.** Dry thrust is untouched, so the clean jet still
runs out at CRUISE and cruises exactly as it always did - the proven model is
not retuned, it is given a top end. The cost is the honest part: 8 fuel a
tick against a 12000 tank is about eighty seconds of burner in a sortie of
eleven minutes. Throttle ramp also went 2 -> 4 a tick; a lever you hold down
while counting reads as a delay, not a throttle.

**The jet has a VNE now, and it did not before.** Every multiply and divide
in this program was written when `vel` could not pass about 1500 - the old
burner's terminal. At altitude `rho` floors at 64, drag collapses with it,
and x4 thrust works out to a level terminal near 7200, which is not a fast
aeroplane, it is Mach 6. `VNE 2600` is about Mach 2.2 in this world's units
and still three and a half times CRUISE, so nothing enjoyable is taken away -
and it bounds every reader downstream in ONE place, because it sits on the
last write to `vel` in the tick. The trainer has always clamped its own.

Note for whoever tunes next: at 65 degrees she still bleeds (-3), so the
energy trade survives at the extreme. That is deliberate. If it ever needs to
go further, the constant to look at is the 24 in the energy term (`psin*24
/256`), and it is the trainer's GRAV with a six on it - but that one touches
ALL flight, not just the burner.

## PICK THIS UP FIRST: `LANDTASK.md`, "STAGE 2b - THE APPROACH MODEL"

**The pilot's call stands and is still the safest shape there is: F not set
is the existing physics, untouched; F set switches models.** What has changed
is what goes behind the switch. Read Stage 2a's two measured findings before
writing anything - the drag law is linear here and quadratic in the trainer,
which is what made the trainer's rotation speed unreachable, and it is the
first thing the approach model has to decide about.

`APPRCH` and the gear-gated cushion are still in, deliberately: they are
scaffolding, but pulling them now would make it impossible to get DOWN to the
runway the school already knows how to receive you on. They come out with 2b.

## Open work, in the order I would take it

### 1. The player's missiles

**FIXED 2026-08-05, and it was not the pool.** Going in to widen the pool I
found MSLUPD and MSLDRAW reading the WRONG VARIABLES. The missile's previous
position and velocity are `mpy/mpz` and `mvy/mvz`; the Shilka TURRET's
model-space scratch was `mtpy/mtpz` and `mtvy/mtvz`. One letter apart, in
the same file, and the missile code had picked up the turret's four for two
of its three axes. It assembled silently because both sets exist. What it
did:

- a missile fired **without a lock** took its vertical and z velocity from
  whatever the turret geometry had last left there. Only the x component was
  its own, so a dumb-fire flew off in a direction nobody chose;
- the exhaust puff was drawn off the trunnion instead of off the missile;
- and every tick a missile was in the air it **stamped its own last position
  into the turret's scratch**, so the flak's guns were being fed missile
  coordinates while you had one flying.

`mvy/mvz/mpy/mpz` were written at launch and never read once. The turret's
four are now `trnpy/trnpz/trnvy/trnvz` so the names cannot collide again.

### 1b. The pool  (DONE 2026-08-05)

Four rails, four in the air if he wants them. The gate was "the missile is
not in flight" and a missile lives 280 ticks, so a second launch was
impossible for fifteen seconds - always the fifteen you needed it.

**The bodies did not change by one instruction.** `MSLUPD1` and `MSLDRAW1`
are still the code written for one missile; what is new is a POOL and a pair
of swaps. A slot is loaded into the eleven working words the old code reads,
the old code runs, the slot is written back. Rewriting sixty-odd accesses of
homing, fusing and detonation arithmetic to carry an index is how you put
three new bugs in while taking one out.

The pool, the swaps and the walks live in **SYMSEG**: the arrays alone are
96 bytes and the main segment had 111. It pays two thunks and a handful of
call sites instead of four loops. `MCEND` is gated on the slot the camera
actually rides (`mcsl`), because three other missiles can die while that one
still flies.

**THE MAIN SEGMENT IS DOWN TO 25 BYTES** (BSSMARK FDD5, guard FDEE). The
next thing to touch it must EVICT first - see the top of this file. The
coldest code is the cheapest.

The pilot asked for "four missiles, fire as many as you like, they run
out". Half of that shipped - they no longer regenerate. The other half did
not: **the player has exactly ONE missile's worth of state** (`msact`,
`msx/msy/msz`, `mvx/mvy/mvz`, `mstgt`, `mlife` - all scalars) while the AI
has a pool of four (`NAMSL equ 4`). So a second launch is impossible until
the first one dies, up to 280 ticks - fifteen seconds - later.

Widen the player's to four. The AI pool is the model to copy. Touches:
`MSLUPD`, `MSLDRAW`, the missile camera (`mcact` rides "this one" - decide
which), the hit tests, and the wire. Most of it can go far; the state
arrays cannot.

### 2. Aerodromes and the landing  (large - `LANDTASK.md` has the plan)

Stage 0 is done (the byte budget). The design decision that everything
hangs on is written up there and is worth not re-deriving: **stamp the
runway FLAT into HMAP once, right after DSGEN**, and the terrain mesh,
TERRH, the road walk and the collision test all agree for free.

Two questions the pilot has not answered: does landing on the ENEMY's
field do anything, and should a sortie START on a runway.

### 3. Landing gear you can see  (BUILT 2026-08-05, wants a look from F3)

Three legs under the belly, on the `gear` lever, visible from the chase
camera - `PLAYERDRAW` is the one call site and it is the only view that
draws your own jet. They could not go in the F15 model (23/14 against the
engine's 25/16 cap), so `GEARDRAWF` lives in SYMSEG and fills its quads
through a new `FACEFILLF` door. **Fifteen bytes of the main segment, all
told**; 165 left.

**The placement was NOT eyeballed in flight, and did not need to be.** The
chase view was re-implemented in C# - `PLAYERDRAW`'s transform verbatim,
`PROJPT` with FOCAL 220, painter sort, PALDAY - and the legs were fitted
against the rendered airframe at several attitudes before a line of assembly
was written. Scale came out of the model itself: 26 units of wingspan
against the F-15's 13 metres makes a unit half a metre, so the legs are four
units of strut and a wheel of one.

**No trigonometry runs in the game.** The travel is SIX POSES, fitted
outside and shipped as `GEARM.INC` - one canonical leg per step, in whole
model units, about its own pivot. All three legs are that one leg with
(x0,-1,z0) added. `SWKEYS` walks `gearp` a step every fourth tick, which is
about a second either way, and it rides there because it is the only
per-tick routine outside the main segment. The DRAG still switches with the
lever, not with the legs: you pay the moment you ask.

Each leg is a CROSS of two strut quads and two wheel quads. A single quad is
invisible edge-on and the chase camera sits directly astern - a wheel
modelled only in the side plane read as a dark stick, which the rig showed
before anybody flew it.

What still wants eyes: whether the legs read at all at 320x200 from the F3
distance, and whether the nose leg should be visible when the jet is pitched
up (it is behind the fuselage from dead astern, which is honest but may look
like a missing leg).

### 3c. Being hit now costs you something  (2026-08-06)

Taking a round used to flash the aiming ring red and nothing else - four
hits could land and the only way to know was to read the DAM figure. A hit
is now a sound, a jolt and a flare, and **all three hang off `phit`**, which
the three damage sites (cannon, flak, the wire) already set to 9 between
them. Not one of them needed a call site.

- **Heard**: the explosion recording at a quarter swing - a thump on your
  own airframe rather than a blast out in the world, and the same sample, so
  the bank costs nothing. Triggered on the EDGE of `phit`, compared against
  `phitp`, because the three damage sites do not all run before the tick
  that counts it down - "it equals 9 now" is true on different ticks
  depending on who shot you.
- **Felt**: a jolt added to `swayx`/`swayy`, which PROJPT already adds to
  every projected vertex. The WORLD jumps and the cockpit does not, which is
  what a hit looks like from inside one. It sits below the on-the-ground
  branch, so a hit shakes you on the runway too.
- **Seen**: `HITFLSHF` floods alternating rows red and yellow - this game's
  own two attention colours - drawn AFTER the world and BEFORE the HUD. Both
  halves matter: the flare replaces the ground, and the gunsight rides on
  top, because a pilot who has just been hit is the one who most needs to
  still see it. Bands and not a wash: there is no alpha in a 256-colour
  buffer, so a flood would replace the picture instead of flaring over it.
  Three ticks of the nine, about a sixth of a second - longer and it stops
  being an impact and starts being a screen effect.

### 3b. The click in the engine loop  (FIXED 2026-08-06, one instruction)

*"Like a scratch on a record"* - a click at a dead-regular interval, and the
interval was the tell: 32768 samples at 11 kHz is 2.97 s, so it was the ring
wrapping, not anything in the effects.

`GENBED` copies the finished bed into the top half of the segment for
SNDHEAL to heal from. **DI was never set for that copy.** The crossfade above
it recomputes DI from SI every iteration and never advances it, so DI arrived
at SNDN-1 and the copy landed one byte low. Three things followed:

- the last byte of the ring was clobbered by the first byte of the copy;
- every healed sample came back shifted one place (inaudible on noise);
- the copy ended at 65534, so **offset 65535 was never written** - and that
  is precisely the byte SNDHEAL reads to heal ring position 32767, the last
  sample before the wrap. One byte of uninitialised memory, once per lap.

`mov di,SNDN`. The lesson worth keeping is the diagnosis, not the fix: a
periodic click times the buffer that carries it, and 2.97 s named the ring
before a line of code was read.

### 4. Explosions and gunfire  (DONE 2026-08-06 - they are RECORDINGS now)

The plan here was to give the synthesised blast more layers. It got
something better instead: the pilot supplied a sound library, so the five
synthesisers are gone and the game plays actual audio.

`TOOLS\Snd2Dat` (C#, per the tooling contract) cuts ordinary WAVs into
SIGNED 8-bit mono at 11025 Hz - the rate the ring already spins at, so a
sound is mixed in as it lies - and packs them with an index into
`INSTALL\SFX.DAT`. Signed because `SFXMB` ADDS into a ring of unsigned bytes
centred on 80h: storing the deltas makes the player load, sign-extend, add.

**The tail trimming is the point of the tool.** A library file is mastered
with silence around it - Explosion.wav carried 1.46 s of padding, rocket.wav
1.19 s - and on a machine where every sound must fit ahead of a DMA beam in
a 32768-sample ring, that padding is the difference between fitting and
lapping. Both ends are cut at the first and last real signal and the cut is
faded over 6 ms, because an abrupt end is a click and a click is louder than
the sound it ends. The peak is measured on **what ships**, not on the source:
the rocket's peak is four seconds into a ten-second burn that the game never
takes, and normalising against the source sent it out at half swing.

**Not one call site had to change**, because the existing entry points
already carried the right signatures: `SFXPOP`, `SFXHISS`, `SFXBOOM` (AH
still picks the volume), `SFXBM2` (still does its own range falloff and
calls SFXBOOM), `SFXBEEP` (BL now says caution-or-critical instead of a
pitch). The player's own death got its own recording via `SFXDETH`.

**It GAVE the main segment 218 bytes** - five synthesisers out, one 60-byte
mixer in. There is no voice pool and no mixer routine: the whole sound is
written once, 60 ms ahead of the beam, and SNDHEAL erases it from behind out
of the pristine copy. The ring is the mixer and always was.

Volume is a right SHIFT, four steps. A 16-bit IMUL per sample over fourteen
thousand samples would cost more than the frame it plays in.

The bank sits one page above `cpsseg` - the only safe shelf, per the top of
this file - which puts it about 512K above the code. That is close enough to
a 640K ceiling to ask rather than assume, so SFXLOADF checks 0040:0013 and
declines to load if it will not fit. No bank, no sound, the game runs on.

**Still open:** the FLAK recording is in the bank with nowhere to play from.
The Shilka's only moving part is its turret - it does not shoot yet - so the
sound is waiting for the gun, not the other way round.

### 5. The black dots on the map  (FOUND AND FIXED 2026-08-05)

**It was never the map.** The pilot said so three times and he was right
both about that and about what it was - *"leftovers of the panel
decoration"*. It is `SIDEPNL`'s annunciator glass speckle, and the bug is
one instruction:

    and  bx,3        ; the speck's own offset in the row, 0..3
    push di
    call UROW        ; ...and UROW builds row*64 in BX on its way to row*320
    pop  ax
    add  di,ax
    add  di,bx       ; so this adds row*64, not 0..3

The specks were landing at `row*384 + x`. Sixty-four pixels further right
every row, marching diagonally across the whole panel - over both MFDs and
the map - and past row 170 the offset walks off the end of the 64K buffer
and wraps to the TOP of the screen, which is the other scatter, the one
under the overhead bank. Fixed by pushing BX across the call: two bytes.

**This is the third time this trap has been sprung in this project** -
`ROW320` and `VLINE2` both carry notes about clobbering BX. If you write a
row-address helper here, it clobbers BX and CX, and nothing you care about
may live in either across the call.

**How it was found, because none of the reading found it.** Static reading
failed four times: the bake was re-implemented and proved clean, the
artwork under the centre MFD was rendered and proved flat black, the map
blit was proved to cover all 55x50, and every routine drawing after the map
was read and cleared by its own coordinates. What worked was two throwaway
builds: first the map painted FLAT WHITE (which proved the specks were
drawn on top, not baked in), then the PALETTE PROBED - every near-black
index in `PALDAY` given a screaming colour, so the pixels named their own
colour index from a screenshot. That found 116 = `PNLNOIS` in one flight.
Then the three sites that write `PNLNOIS` were given three different
colours, and the guilty one lit up yellow in one more. **When reading has
failed twice, stop reading and make the picture answer.**

---

The rest of this section is the MAP work that came out of the same hunt. It
was real and it shipped, but it was never the black dots.

Nothing was corrupting anything. `RND16`, `DSGEN` with its histogram
stretch, `MMAPGENF`, `MMSETUP`/`MMSCL` and the blit were re-implemented in
C# and the map was rendered outside the game, at its real 55x50. Two
separate faults, and the pilot's instinct named both.

**The brown was a lie.** The bake had SIX height bands where `TERRAIN` has
five, and the extra one - 120..167, brown - was `GETZONE`'s city ZONE,
which is a range of heights and nothing else. Measured over five seeds it
covers **28 to 40 per cent of the world**, and the 3D mesh paints all of it
plain grass. So over a third of the map disagreed with the ground under the
nose. On the SCOPE the same brown is honest: `BQCITY` asks `HBLD`, which
asks `BLKCTY` - centre node in the band AND the 3-in-16 clustering hash.
Hence *"good for the radar, does not suit the map"*, exactly.

**The specks were the threshold.** One pixel per node with a hard cutoff:
a single node that stepped over 168 on its own became a lone dark dot.
Counted on the real glass: **55 lone pixels of 2750** at one pixel a node,
32 of them dark - and **zero** at two and four pixels a node. That zoom
dependence is the fingerprint; a real feature of the world would not care.

Fixed in `MMAPGENF`: the world's own five-band ladder (`MMTCOL`), then a
node with no orthogonal neighbour of its own colour is given to the
majority around it, then the town is painted from `BLKCTYF` - the same
question the buildings and the scope ask. Lone pixels at one px a node:
55 -> 10, of them dark 32 -> 2. Costs the main segment nothing (SYMSEG
+232 bytes, TOWNSEG +4) and the frame nothing - it is all in the one-time
bake.

**The wide zoom needed a second page, and that is a fact about the WORLD,
not about the map: this world's towns really are isolated single blocks.**
`BLKHASH` passes three blocks in sixteen and it has no spatial clustering
in it at all - it is a hash of the block index, and it does not even take
the seed, so that lattice is identical in every world ever generated. A
world holds 55 to 75 built blocks and **a third of them touch nothing**.
At the whole-world step a block is 2 nodes, which at three pixels to four
nodes is ONE PIXEL, often dropped outright by the sampling. Drawing that
honestly draws speckle, honestly.

So the wide step reads its own page now. `MMAPGENF` bakes **two**: the map
proper at offset 0, every built block in its place, and at `MMWIDE` the
same land with the towns generalised - a 2x2 patch of blocks with two or
more built in it is painted WHOLE. About 8 to 17 places in a world, four
nodes square, which reads as a town instead of dirt on the glass. A city
on a map at 1:world is a symbol, not a footprint; it is allowed to be
bigger than the streets under it. `MMSETUP` adds `MMWIDE` to the row table
when `mmzs` is `MMZALL` and the blit never learns of it.

Measured on the wide page: the town now contributes **zero** lone pixels.
What is left there is 6 to 18 lone pixels of 2750, and in the worst of
five seeds ten of them are ROCK - single peaks, which is what a peak looks
like at world scale. The page costs nothing: `scrseg` is a whole 64K and
only its first 4K was ever used (`cpsseg` sits a full 64K above it).

## How this gets tested

**The pilot flies it. Do not drive his desktop.** He stopped a run that was
injecting keystrokes into his live machine, and he was right to - it is his
working desktop with Visual Studio and Teams open. Build it, say plainly
what to look for on the next flight, and hand it over. Screen capture for
READING the screen is fine when the desktop is unlocked.

OWLFLY2 has no serial telemetry, so `Debug/FlyDbg.exe` (the TRAINER rig)
cannot reach it. What CAN be verified without flying, and was, every time
this session: build and segment budgets from the map; geometry and data
formats re-implemented in C# and compared against the shipped bytes. That
caught the ring-road corner case, proved the head-turn matrix exact, and
proved the fireball rasteriser cannot write outside the back buffer.

## Build and run

    MAKE.BAT OWLFLY2        (from the repo root; DOSBox + TASM + dotnet)
    GAMES\OWLFLY2\PLAY.BAT

The panel converter now takes all three cockpit images in ONE run - the
DAC lends this game 63 slots and the front and both sides share them, so
running the front alone leaves the sides quantised against a palette they
never voted in. MAKE.BAT passes `-left` and `-right`; do not split them.
