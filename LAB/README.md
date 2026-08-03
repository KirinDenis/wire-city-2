# The house lab

`HOUSE.COM` — one city block, standing still, and a camera to walk round
it. Not a game and not a teaching machine: a **workbench**, for the work
on how buildings look. No flight model, no physics, no combat, no panel,
no sound.

```
MAKE.BAT LAB      (from the repo root, Windows)
LAB\RUN.BAT       (runs it in DOSBox)
```

## Why it is a separate program

Two reasons, both hard.

**There is no room.** OWL FLY II's main 64 KB segment has about fifty
bytes left in it. A camera, a second main loop and a set of debug
switches do not fit, and making them fit would cost a reclaim campaign
before any of the actual work started.

**A simulator never holds still.** You cannot judge how a wall looks
from a cockpit doing 900 km/h. Worse, the game has *no building list*:
`HBLD` computes every house from a hash of its cell, fresh, every frame.
Nothing can be edited and looked at — each experiment costs a full
sortie to see once. A lab pays for itself on the second iteration.

## What is the same as the game, deliberately

Everything that decides how a building **looks**:

| | |
|---|---|
| `CELLHASH`, `SBHASH` | the hashes that plan the city |
| footprint / height / scheme bit-fields | half-size 84..115, heights, `WSCH` |
| the five structure types | box, spire, telescoping tower, arch, factory + smoke |
| `DRAWBOX`, `ROTCUL`, `FACEV`, `FACETOPC` | the box pipeline |
| `WINFACE`, `WLIT2` | the windows and which of them are lit |
| `PALDAY` 0..30 | the game's own day colours |
| `FOCAL` 220, `NEARZ` 40, 256-unit cell | the same lens, the same scale |
| `ENGINE\E_M3D.INC`, `E_RAST.INC` | the same modules, not copies |

The block on screen is the game's **own cells 24..35** — the same hashes,
so the same houses, down to which windows are lit. Change a number here
and it means the same thing there.

Which is the point, and which is why every deliberate departure from the
game is written down under **Changes to port back**, below. The lab is
allowed to get ahead of the game. It is not allowed to get ahead of it
quietly.

## What is different, and why

- **The ground is flat at y=0.** No terrain mesh: a lab wants a scene it
  can hold still. `gbase` is still a variable, and still added exactly
  where the game adds it, so the code that goes back is unchanged.
- **The superblock clustering test is dropped.** In the game only ~3/16
  of blocks are built up; here every non-street cell has a structure, or
  you would spend the session hunting for a house. The block straddles
  the superblock boundary at cell 32, so more than one district is on
  screen at once.
- **No ruins, no zoning, no roll.** A camera does not bank, so `roll`
  stays 0, `APPLYROLL` is the identity, and the horizon is a straight
  line a three-band fill can draw.

## Keys

| | |
|---|---|
| arrows | fly: up/down forward and back, left/right turn |
| `A` / `Z` | climb / descend |
| `S` / `X` | look up / look down |
| `,` / `.` | slide left / right |
| Shift | fast |
| `W` | windows on / off |
| `E` | outlines on / off |
| `T` | wall shading on / off |
| `C` | traffic on / off |
| ESC | back to DOS |

The three letters at the bottom right are those switches: the letter is
ON, a dash is OFF.

The bottom line is the camera: X, Z, height, heading, and the two
switches. A lab that cannot tell you where you were standing makes you
fly the same approach twice.

The switches are the point: a look is judged by what it is worth, and you
cannot see what a thing contributes until you can turn it off. They read
`HITS`, the key-went-down table the interrupt fills, not the held-state
table — a switch is an event, and polling once a frame misses any tap
shorter than a frame.

## What it is for, in order

1. **Windows.** In progress — see below.
2. **Textures and halftones.** First pass tried and rejected — see below.
   The screen-anchored dither crawls in motion; the flat-band version is
   the next thing to try.
3. **Explosions.**

Sound is the *next* lab, after this one.

## The windows, so far

**A pane is a quad on the wall now, not a square on the screen.** What
was there before got the pane centres right — lerped in camera space,
projected one at a time — and then drew each as an axis-aligned square of
fixed world size. A square does not foreshorten. Look along a wall and
its columns crowd together while the glass keeps its width: the windows
stop lying on the brick and start floating over it.

The fix costs almost nothing, because of one property of the wall:

> `A_top - A_bot` equals `B_top - B_bot` — both are the same vertical
> rise — so a wall quad is a **parallelogram**, and `PITCH4` is linear,
> so it is still one after the pitch. Every point on it is
> `V0 + (i/NCOL)·U + (j/NROW)·V`.

So the whole corner lattice comes out of one row of column offsets and
one column of row offsets, combined by **addition**: `NCOL+NROW+2`
interpolations for the face, then nothing but adds. The panes share that
lattice — 24 projections carry 15 panes instead of 60 — and the mullion
between them is made by shrinking each pane to half its cell after
projection, which for something that small is the same picture as
shrinking it on the wall.

**The distance gate is gone.** There is no `minrz <= 1200` any more. The
wall's own projected box decides: glass appears the moment the wall is
worth more than `WMINPX` pixels. A far-off lit facade *is* speckle, and
it should fade in rather than switch on at a magic radius.

**Quads or dots is decided PER WALL, and this one matters.** The first
version decided per pane — under two pixels, draw a dot — and the far
city crawled: a pane sitting on the threshold flipped between a dot and a
two-pixel quad as the camera crept, its neighbour flipped on a different
frame, and the facade seethed, some windows bigger, some smaller, every
frame. A pane's projected size is not a smooth function of anything you
control. The **wall's** size is: it grows steadily and in one direction as
you approach. So the test moved up a level — one cell narrower than
`WQUADPX` pixels and the whole facade drops to lit dots, all together,
once. A dot has no size to change, and it sits on the *unshrunk* centre,
which moves smoothly. The far city twinkles at worst.

The general lesson, worth more than the fix: **put a level-of-detail
switch on the quantity that varies smoothly, not on the one you are
actually drawing.**

**What is still wrong, and it is visible.** The grid is a fixed 3 × 5 for
every wall, so a low wide block gets letterbox slots and a tall tower
gets bands. Windows want to be roughly the same size on every building —
that is the main thing a facade gives you, a sense of scale. Making the
grid follow the wall's world size is the next step, and it is not free:
a 6 × 12 lattice is 91 projections a face instead of 24, so it needs a
detail cap from the projected size, which in turn makes the grid reflow
as you approach. That trade is the next session's to make.

Windows cost real time now that every visible wall has them. If the lab
feels heavy, raise `cycles` in `RUN.BAT` — the number there is a lab
setting, not a measurement of the target machine.

## The traffic

Coloured cars, buses and trucks driving the avenues, obeying signals.
`C` turns them off.

**There is no list of vehicles**, exactly as there is no list of
buildings. A vehicle's position is a function of *(lane, slot, time)* and
nothing is stored. The same argument that lets the world ship as a recipe
lets the traffic ship as one — and it means two clients of the same sky
compute identical traffic from the clock, with no network traffic at all.

**The lane carries the phase, not the cell.** Hash the phase per cell and
a vehicle jumps sideways every time it crosses a cell boundary. So slots
are spaced one cell apart *along a lane* and numbered globally; a cell
works out which slot is inside it right now. A vehicle stays the same
vehicle — same size, same paint — all the way down the street.

### The rules

**Right-hand traffic falls out of the geometry.** An avenue is two cells
(512 units) wide; the lanes sit at ±`LANEOF` from its centre, and which
lane runs which way is fixed so a driver's right hand is always toward
the kerb. Nothing enforces it — it is just where the lanes are.

**The lights need no state either.** North–south avenues take the first
green, east–west the second, with an all-red clearance between. A whole
lane starts and stops together, which is what a signalled platoon
actually looks like, so one closed form serves every vehicle on it:

```
d = CARV * clamp(clock - green_start, 0, CARG) + CARRST
```

**And the one that makes it all work: a green is worth EXACTLY ONE
BLOCK.** `CARV * CARG = 2048 = 8 cells`. Because a slot advances a whole
number of blocks per cycle, and a block is eight cells, **the cell a slot
comes to rest in never changes modulo 8.** So "does this slot stop on a
crossing?" is answered once, by `s AND 7`, and forever. Ban those two
slots in eight and every junction is clear at every red — for free, with
no vehicle ever having to look at another vehicle. The gap travels along
with the platoon, which is also what real traffic does.

Stopped vehicles wait at `CARRST` into their cell, just short of the stop
line, so a red leaves a proper queue rather than a row of cars parked on
cell boundaries.

### The clock, and a bug worth keeping

`CCLOCK` runs the traffic off the **BIOS tick, interpolated by counting
frames inside it** — the same thing the game does for the camera. Two
separate reasons, and the second one bit:

- moving on the raw 18.2 Hz tick judders, because the world around it is
  redrawn three or four times as often;
- moving per *frame* makes the signal cycle a measurement of the
  renderer. Not hypothetical: the first pass ran the lights on frames,
  the scene got heavy enough to drop to a dozen frames a second, and a
  twenty-second cycle quietly became a minute and a half. The cross
  street never went green in half a minute of watching, and it looked
  exactly like broken traffic code.

Time comes from the clock, smoothness comes from the frame rate, neither
borrows from the other.

### Vehicles

Three types from the slot hash — car (a low body with a cabin on it), bus
(a bus *is* a box), truck (a tall cab in front, a longer body behind) —
in eight paints, DAC 126..141, each a lit face and a shaded one. The city
is grey by design; the traffic is the only thing in it allowed to be a
colour. `DRAWBOX` draws them, so they get the same distance-coloured
outline the buildings do, and `WINMAYBE`'s `bhw >= 50` gate keeps windows
off them without a special case.

### Not done yet: hitting them

Designed, not built — there is nothing in the lab to shoot with. The test
is `O(1)` and needs no list: a tracer already computes its cell to test
against buildings, so given the cell you compute where the vehicle is
*right now* and compare against its box. Sixteen rounds in the pool,
sixteen tests a tick. Death is one entry in a small ring of
`(lane, slot, timer)` — the same trick as the buildings' four-slot
"walking wounded" table — and in multiplayer only the kill needs a
message, because the traffic itself was never transmitted.

That pairs naturally with **explosions**, which is item 3.

## The shading — TRIED, AND SWITCHED OFF

**Verdict (pilot, at the glass): fine in a still, dances in motion.**
`texon` now defaults to 0. The code is kept, not deleted — the switch is
`T`, and the diagnosis below is worth more than the code.

**Why it crawls, and why tuning would not have fixed it.** The dither
threshold is indexed by **screen** x and y: `DITH2[(y & 7)*2 + (x & 1)]`.
The pattern is therefore nailed to the glass, and the wall slides through
it. Every frame the camera moves, every pixel of the wall lands on a
different threshold cell and flips colour — so the grain boils while the
building underneath it is perfectly still. No amount of adjusting
`DGRAIN`, `DSHADE` or the matrix touches this: it is not a tuning problem,
it is where the pattern is anchored.

Anchoring it to the **wall** instead means knowing each pixel's position
in wall coordinates, which under perspective means a divide per pixel —
texture mapping. On an 8086 that is a different program, and it is the
reason the pilot's "доводить будем долго" was the right call.

**The cheap thing to try when we come back**, and it is about five lines:
drop the dither and keep the curve. Pick one of the three ramp colours by
mix level and fill flat spans — `rep stosb`, no pattern at all. The band
edges are computed from `dtop`/`dhgt`, so they are anchored to the *face*
and travel with it: three solid horizontal bands down a wall, moving as
one with the building. No per-pixel grain to boil, no cardboard either.
It loses the fine texture and keeps the shading, which on this evidence is
the half worth keeping.

## What it does, for when it comes back

A flat span of one palette index is the flattest thing a screen can show,
and a box made of four of them is a box. The cure is not more colours —
it is **per-pixel variation**, the same answer the NEWTON sky and the
annunciator plates arrived at.

**`DITHPOLY` is `SCANPOLY` with two colours instead of one**, mixed by an
ordered dither. The matrix is **2 wide by 8 tall**, and both numbers are
the design:

- **2 wide** means the pattern repeats every *word* along a scanline, so
  the inner loop is still `REP STOSW`. A dithered wall costs what a flat
  wall costs. A 4×4 Bayer would need a four-byte period and an unrolled
  loop for the same number of levels.
- **8 tall** buys 16 mix levels, which is what keeps a gradient from
  stepping in visible bands.

The word is phased to where the span actually starts, or the grain swims
along the wall as the polygon edge moves.

Two properties are built into the matrix and both are load-bearing.
Thresholds 0–7 sit on a **checkerboard**, so mix 8 comes out as a clean
50/50 chequer rather than stripes. And inside that, low thresholds
alternate columns as well as rows — the first version put 0, 1 and 2 all
in one column, and the light stipple that most of a wall wears lined up
into vertical rows: the eye read corduroy, not texture.

**The mix curve matters more than the dither.** A straight 0→16 ramp down
a wall spends most of its area near half mix, and half mix in a
two-colour dither is a checkerboard — the loudest pattern available,
shouting over the shading it is supposed to carry. So the curve is: a
thin stipple (`DGRAIN` = 3) over the whole wall, just enough that it is
not one flat index, and the real darkening saved for the bottom third
(`DSHADE` = 9 of 16), where a building genuinely does stand in its own
shadow and its neighbours'. Light shading, not a halftone screen.

**Which two colours** is what keeps the sun in the picture. Each scheme
now has a three-rung ramp — light, mid, dark. The sunny walls (N/S) run
light→mid down their height; the shaded walls (E/W) run mid→dark. The two
sides stay a clear step apart while neither is flat: nine effective steps
out of three indices. Roofs are horizontal, so they get no gradient —
just a fixed stipple of 17 against 0, the *closer* pair, or the speckle
reads as dirt instead of gravel.

`T` turns the whole thing off, against the same frame.

## Changes to port back — DONE 2026-08-03

All four went into the game on 2026-08-03. The windows and the traffic
live in the game's **fifth segment**, `TOWNSEG` (`SRC\TOWN.INC`), opened
because the main segment was down to twenty-six bytes; deleting the old
`WINFACE` from it gave back five hundred, so the port ended with more room
than it started with. The lab is still where to change any of it.

Two things the port cost that the lab could not have told us:

- **Opening a far segment moves the back buffer, and moving the back
  buffer moves everything stacked above it.** `resseg` sat inside the new
  buffer, so the world drawn into the bottom of it came back up as the top
  of the cockpit, pixel for pixel. This had happened once before, when
  `SYMSEG` was opened. The rule is now written at the point of the fault
  in `CITY.ASM`.
- **`ROADZ`.** The lab walks 289 cells and can surface all of them; the
  game walks 2401 and cannot. Tarmac and traffic stop at `ROADZ`.

And one thing found by accident on the way: `DSTB`, the ruins bitmap, was
never initialised in the whole history of the game, so a random scatter of
the city could start as rubble depending only on where the program landed
in memory. `DSTCLR` now stands it up.

What follows is what changed, kept because it is the reasoning, not just
the diff.

**1. Wider streets.** `ISROAD` marks **two cells in every eight** as road
(`gi & 7 < 2`), where `HBLD` marks one in four (`gi & 3 == 0`). The
avenue goes from 256 units to 512 and the blocks double in size, but the
built fraction is untouched — (6/8)² is exactly what (3/4)² gave. Wider
streets, bigger blocks, the same amount of city. Streets are what a city
is *seen through*; at one cell the far side of the road stood right on
top of the near side. The 8-cell period also lines up with the downtown
height bonus, which already measures its distance from the block centre
with `gi & 7`.

**2. Districts are mixed.** The district used to come from `SBHASH`
alone, so a superblock was 64 cells of the same thing — eighty identical
sheds, then eighty identical houses, which is what a city looks like when
a zoning computer drew it. Now the block sets the flavour and the *cell*
gets a say: three cells in eight take a neighbouring district instead, so
a machine shop stands behind the houses and a shed leans on a tower,
while the block still reads as what it mostly is.

That needs a second, independent hash — `DHASH`. The cell hash's bits are
all spoken for (width, depth, selector, scheme) and reusing them would
tie a cell's district to its shape: the tall buildings would always be
the ones that changed district, and the eye finds that sort of thing.

**3. The whole of `WINFACE`**, as described above.

**4. `DITHPOLY` and the third wall rung — NOT YET.** Switched off; see the
shading section. The third rung (`WDRK`, DAC 122..125) is worth keeping
whatever replaces the dither, since flat bands need it too. `WSCH` gives
every scheme a lit
and a shaded colour and stops there — enough to tell two sides of a box
apart, not enough to shade either of them. `WDRK` adds the step below the
shaded one, and it costs nothing anyone else wants: the cockpit owns
31..93 and Panel2Inc rewrites those every build, the game itself stops at
119, and the DAC has 134 slots nobody has ever asked for. The lab uses
120..125 and the game's own 0..30 are untouched.

When `DITHPOLY` goes back it belongs in `ENGINE\E_RAST.INC` beside
`SCANPOLY`, not in the game's segment — the examples will want it too.

Everything else — `CELLHASH`, `SBHASH`, the footprint and height fields,
the five structure types, `WSCH`, `PALDAY` — is still the game's, byte
for byte.

## The palette rule

Slots **31..93 are the photo cockpit**. `Panel2Inc` rewrites them from
the artwork on every build, so nothing outside the cockpit may use them —
and the lab does not. It loads `PALDAY` 0..30 verbatim and takes its own
six colours from **120..125**, above where the game stops at 119: asphalt
and pavement, then the dark rung of each of the four wall schemes.

## Notes for whoever runs it next

- `RUN.BAT` passes `-noautoexec`. Without it DOSBox runs the machine's
  own autoexec and every `-c` is buried under it.
- `RAD` (the painter's walk radius, in cells) has to reach **across** the
  block from outside it. At 8 you stand off and see one row of houses
  with the rest of the city missing.
- The painter's order is built at startup by a counting pass, far to
  near, exactly like the game's shipped `BORD` — one table serves every
  camera position, because translation does not change relative order.
  The world costs no sort per frame.
