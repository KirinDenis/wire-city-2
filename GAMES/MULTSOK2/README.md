# MULTIPLAY SOKO II

Crates onto the red marks, in a castle seen from above, for up to eight on
the network - on an **EGA**, a **CGA** or a **Hercules**, with a **Sound
Blaster**: 8086 assembly, flat FASM, one `.COM` and its pictures,
`ART.DAT`. The 60 levels are the ones of
[Base-Z-47](https://github.com/KirinDenis/Base-Z-47-Rust-Game).

MULTIPLAY SOKO, the first one, is `GAMES\MULTSOKO` - CGA, a brick
warehouse, its own room - and stays as it is. This is the second, made
from what its first players said: the whole level on the screen, the
cards and the sound picked at the start, a castle to look at, something
to happen at the end of every level.

```
1 2 3     the first screen: EGA, CGA or Hercules     4  the sound on / off
Arrows    walk, and push the crate in front of you (or W A S D)
Space     lay your mine where you stand
Q, E      turn the view a quarter, either way; the arrows turn with it
V         the isometric view, and back
Z         close up, following you / the whole level again
R R       the level anew (the first R only asks)
N N, P P  the next, the previous level
ESC       back to DOS
```

## The first screen

Text mode, so every card shows it - a VGA, an EGA, a CGA, a Hercules or an
MDA. It knows what the machine has (the VGA BIOS's display code, the EGA's
answer to INT 10h 12h, the equipment word, a Hercules' retrace bit that
moves where an MDA's does not) and a card it has not got refuses its key.
By default the best card here - EGA "for authenticity" - and the sound on
if a Sound Blaster answers at 220h. The letters you type are your name.

## The game

- A crate onto a red mark **+10**, off one **-10**.
- Every free floor cell starts with a **candy**, Pac-Man's: +1, +2 or +3
  (green, gold, pink), eaten when you step on it.
- Now and then a **diamond** grows out of the floor - one at a time, 20 to
  27 s apart - and lies 15 s: **+25** to whoever steps on it. A crate cannot
  be pushed onto it.
- **Every crate home:** the gate in the wall rises (1.5 s), the drawbridge
  comes down over the moat, and the men walk out through it - **+50** each,
  the first out **+75**. When nobody is left inside, or after 15 s, the gate
  is shut, and the man who did most in the level stands on the podium:
  **WINNER**, his name and his points, for 6 s; then the next level.
  A level with no wall between floor and outside has no gate: it is the
  winner's at once, +50 to every man.
- **Mines**, as in the first game: one a man, 5 s, then the nine cells round
  it blast and every man on them stands still for 15 s; the next is his a
  minute later. The list shows `M` (he has one), `M42`, `Z12`, and `OUT`.

## On the network

Up to eight players in one castle. On the WIRE CITY site everyone who
plays MULTIPLAY SOKO II is in the room `multsok2`; in desktop DOSBox, start
the DOSBoxes on one `ipxnet`. It is the first game's protocol grown up
(socket 5454h, protocol 3, so the two games never read each other):

- **One machine keeps the castle** - the lowest name on the wire: the
  level and its phase, the crates, the candies, the clocks, the men and the
  scores. It sends the world whole (`'W'`, 408 bytes: a bit for every floor
  cell that still has a candy) twice a second and after every change; the
  others send their steps and orders (`'M'`) and their name (`'H'`) and draw
  what comes back, so two men can never push one crate two ways.
- A newcomer listens two seconds for a world; hearing none, it hosts. A man
  not heard for 3 s leaves the floor; a host not heard for 2 s is replaced
  by the lowest name still heard, from the world it last drew.
- Everything off the wire is checked; the sounds are not sent at all - every
  machine hears what changed in the world it draws (SNDDIFF).

It was tested with a fake player, `tests\SokoPilot\sokopilot2.mjs` in the
OWLOS-LAN repository, against the game in the site's page on a test
server. As a client the fake player was given a man next to the start,
its name and its step came back, it ate a candy (+1, 48 candies left 47)
and it was dropped 2.8 s after it went quiet. As the host it served level
1, the game joined it, ate a candy through it, and took the castle over
1.8 s after it went quiet - with its man, its point and the 47 candies.

## The picture

- **The whole level, always.** Straight down, the largest cell of 16, 12,
  10, 8 and 6 pixels that holds the level - turned as Q and E turn it - is
  the one; `Z` shows it at 16, following you.
- **The floor is black and bare.** What is played with stands on it and
  nothing else: crates, men, candies, the diamond, the red marks. Nothing
  on it is black at its edge - a crate is a gold rim lit on its top and
  left, brown on its bottom and right, iron at its corners, drawn by rule
  at every size so the rim survives 6 pixels. Warm things on the floor,
  cool water and green round it.
- **The walls** are big grey stones with lime growth on the side that
  faces out; then the moat, rippling - every cell in its own phase, and now
  and then a gust sweeping across it, the water torn white; then the land.
- **The land** is the engine's own Diamond-Square (`ENGINE\E_TERR.INC`,
  the islands of OWL FLY), seeded by the level, so every machine grows the
  same: low ground wet (ponds, bushes), then the garden (flower beds,
  hedges, fountains that flow in four frames, statues, lanterns, a well),
  then a wood of oaks, the highest a pine wood on a dark floor with
  boulders. Each thing is set a little off the grid, takes the cells it
  covers, and never stands over the castle. Towers with red roofs at its
  corners, torches on its walls, a road out from the gate, a crow now and
  then. Candies glint, each at its own moments.
- **Dusk at the edges.** Across each side's margin of land the light goes
  by the golden section: the first 0.382 of it in full light, then a
  colour step through a 4x4 ordered dither, a few pixels at first and all
  of them at the screen's edge - no edge to the dusk, and the eye goes to
  the floor. A narrow margin keeps its light, the castle always.
- **Drawn once, sent out by the stretch.** The buffer is 320x200, two
  pixels a byte. What does not move - the walls, the park, the goals, the
  dusk - is drawn into a background once a level; every frame is a copy of
  it with what moves on top: the water, the torches, the fountains (the
  dusk laid over them again), the gate, the bridge, the floor's things, the
  crow, the counts. A picture with no see-through pixel - a stone, the
  water, grass, a crate - is kept without masks: half the room in the 64 KB
  the compiled pictures live in, and drawn as a plain copy.
  Then each row is compared with what the card already shows and only the
  stretch that differs is converted:
  - **EGA**, mode 0Dh: four bit planes, a plane byte of 8 pixels made from
    four table lookups (FASM computes the 4 KB of tables). On a VGA the
    sixteen colours are the game's own, set in the DAC from `ART.DAT`: EGA's
    juicy greens, warm stone, deep water.
  - **CGA**, mode 4, palette 1 bright: every colour a 2x2 half-tone of cyan,
    magenta, white and black; even rows at B800:0000, odd at B800:2000.
  - **Hercules**, 720x348, the 6845 programmed by hand: a pixel two dots
    wide, 200 rows made 300, each colour a density of dots; four banks.
- **Text**: OWL FLY III's 4x6 letters for every count, the BIOS's 8x8 for
  the titles and the news - which goes in the top line, never over the floor.

## The sound

The WIRE CITY ring mixer (`EXAMPLES\RING.ASM`, `ENGINE\E_SND.INC`): one
Sound Blaster channel, a 32K ring looping through auto-init DMA, 11025
samples a second, no interrupts. The wind is the ring's bed - its clean
copy in the top half, which the heal puts back behind the playing position;
every effect is added a little ahead of it, so they sum and wipe themselves
out once played. Effects are made on the spot from lists of tones: a crate
scraping, two notes up for a crate home, a clack and ticks for a mine, the
blast, a diamond rising and taken, the portcullis's chain over a groaning
winch, the drawbridge landing, a fanfare for the winner, a candy's blip, a
crow's caw - and now and then a songbird somewhere in the park.

## Build it, run it

In DOSBox, with the repository mounted:

```
cd GAMES\MULTSOK2
MAKE
RUN
```

`MAKE` assembles `ART.ASM` into `ART.DAT` and then the game. `RUN` sets
DOSBox's CPU as fast as it goes first (`config -set "cpu cycles=max"`):
the game keeps time by the BIOS clock, so nothing runs too fast. From
Windows: `MAKEWIN` (`MAKEWIN CHECK` builds it again with the Windows FASM
and compares), then `RUNWIN` - `RUNWIN EGA`, `RUNWIN CGA` or `RUNWIN HGC`
plays it on DOSBox's real card of that kind. `MULTSOK2.COM` reads
`ART.DAT` from its own folder.

## The files

| File | What it is |
|---|---|
| `MULTSOK2.ASM` | the game: start, the rules, the phases, the network |
| `SCENE.INC` | the picture of the castle: the view, the background, the dusk, the frame, the HUD, the winner, the crow, the title |
| `DRAW.INC` | the buffer: compiled pictures, text |
| `VIDEO.INC` | the cards: detection, modes, the converters |
| `SOUND.INC` | the Sound Blaster, the ring, the effects, the birds |
| `MENU.INC` | the first screen |
| `ART.ASM` | `ART.INC` and `KINDS.INC` as `ART.DAT` |
| `ART.INC`, `KINDS.INC` | the pictures, the palette, the CGA and Hercules maps - made by `TOOLS\ArtGen2` |
| `LEVELS.INC` | the levels, made by `TOOLS\LevConv` from Base-Z-47's |
| `..\..\ENGINE\E_NET.INC` | the network: IPX, everyone in the room hears everyone |
| `..\..\ENGINE\E_TERR.INC`, `E_MATH.INC` | Diamond-Square and its generator: the land round the castle |

`TOOLS\ArtGen2` (C#) draws every picture at 16 pixels by rule or by hand,
brings them down to 12, 10, 8 and 6, lays the isometric tiles, and renders
a level the way the game does - on all three cards - as PNG:

```
dotnet run --project TOOLS\ArtGen2 -- GAMES\MULTSOK2\LEVELS.INC 0 PREV GAMES\MULTSOK2
```

A test build, `FASM -d TESTKEYS=1 MULTSOK2.ASM MULTSOK2.COM`, adds keys the
real one has not: F10 every crate home, F9 a diamond above your man, F7 the
fanfare, F8 `RING.DAT` (where the DMA plays, the effects asked for, the
crow, and the ring itself) - how the endings, the sound and the crow were
tested without a hand at the keyboard.
