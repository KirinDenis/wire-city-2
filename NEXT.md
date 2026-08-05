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
bytes of it.** As of this writing it has **180 bytes** free. There is 13K
free across the far segments. The linker map now tells you exactly, because
every window carries a PUBLIC end marker - `BSSMARK` (main), `SKYEND`,
`UIEND`, `SYMEND`, `TWNEND`. Build and read `SRC/CITY.MAP`:

    0000:FD3A  BSSMARK    main, guard is FDEE
    1000:1BC8  SKYEND     window 8176
    1200:344C  UIEND      window 16368
    1600:0CB2  SYMEND     window 8176
    1800:1190  TWNEND     window 8176

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

**3. `SETTRIG` must run after the render as well as before it.** `INPUT`
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

## Open work, in the order I would take it

### 1. The player's missile POOL  (small-to-medium, and it is a real bug)

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

### 4. Explosions and gunfire should SOUND like it  (medium)

The engine note is generated and is not to be touched (`GENBED`). What
wants work is `SFXBOOM` and the cannon: a blast needs layers - the crack of
the front, the low thump, the tail - not a louder single sample. Work in
`SOUND.INC` / `ENGINE/E_SND.INC`, and it has to be judged by ear.

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
