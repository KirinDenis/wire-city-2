# MULTIPLAY SOKO II

Crates onto the red marks, in a castle seen from above, for up to eight on
the network - on an **EGA** at 640x200 or 320x200, a **CGA** or a
**Hercules**, with a **Sound Blaster**: 8086 assembly, flat FASM, one
`.COM`, its pictures (`ART.DAT`, and EGA 640's finer `ARTF.DAT`) and its
levels (`LEVELS.DAT`). The 60 levels are the ones of
[Base-Z-47](https://github.com/KirinDenis/Base-Z-47-Rust-Game).

MULTIPLAY SOKO, the first one, is `GAMES\MULTSOKO` - CGA, a brick
warehouse, its own room - and stays as it is. This is the second, made
from what its first players said: the whole level on the screen, the
cards and the sound picked at the start, a castle to look at, something
to happen at the end of every level.

```
1 2 3 4   the first screen: EGA 640, EGA, CGA or Hercules   5  the sound
Arrows    walk, and push the crate in front of you (or W A S D)
Backspace a step back, and the crate it pushed (or U; a Mac's delete)
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
By default the best card here - EGA 640, "recommended" (the pilot: "EGA
640, a little finer"), then EGA "for authenticity" - and the sound on if
a Sound Blaster answers at 220h. EGA 640 is offered only when the memory
holds its segments (about 470 KB). The letters you type are your name.

## The game

- A crate onto a red mark **+10**, off one **-10**.
- Every free floor cell starts with a **candy**, Pac-Man's: +1, +2 or +3
  (green, gold, pink), eaten when you step on it.
- Now and then a **diamond** grows out of the floor - one at a time, 20 to
  27 s apart - and lies 15 s: **+25** to whoever steps on it, or rolls a
  crate onto it - the crate takes it for the man who pushed it, so a
  diamond in the way never blocks a crate.
- **Every crate home:** the gate in the wall rises (1.5 s), the drawbridge
  comes down over the moat, and the men walk out through it - **+50** each,
  the first out **+75**. When nobody is left inside, or after 15 s, the gate
  is shut, and the man who did most in the level stands on the podium:
  **WINNER**, his name and his points, for 8 s; then the next level.
  A level with no wall between floor and outside has no gate: it is the
  winner's at once, +50 to every man.
- An **owl** lands on a wall beside the floor half a minute or so apart
  and sits a quarter of a minute: walk into its wall and it is yours,
  **+10**.
- **A step back**: Backspace (or U) takes your last step back, and the
  crate it pushed - up to 32 steps, your own, while nobody has moved into
  the way since. The crate's points go back with it; candies stay eaten.
- **Stuck**: a crate that can never go home again - in a corner, at the
  foot of a wall with no red mark along it (no push from any mark could
  ever bring a crate there), or in a square of four that are all crates
  and walls - is crossed in red, and the top line says
  `STUCK: BACKSPACE STEPS BACK, R R ANEW`. Every machine sees it in the
  floor it draws.
- Every gain of 5 or more - a crate home, the diamond, the owl - rises
  over the man who made it, gold; a crate off a mark, -10 in red.
- **Mines**, as in the first game: one a man, 5 s, then the nine cells round
  it blast and every man on them stands still for 15 s; the next is his a
  minute later. The list shows `M` (he has one), `M42`, `Z12`, and `OUT`.

## On the network

Up to eight players in one castle. On the WIRE CITY site everyone who
plays MULTIPLAY SOKO II is in the room `multsok2`; in desktop DOSBox, start
the DOSBoxes on one `ipxnet`. It is the first game's protocol grown up
(socket 5454h, protocol 4, so the two games never read each other):

- **One machine keeps the castle** - the lowest name on the wire: the
  level and its phase, the crates, the candies, the clocks, the owl, the
  men and the scores, and every man's last steps, to take back. It sends
  the world whole (`'W'`, 414 bytes: a bit for every floor cell that still
  has a candy; the owl's wall and clock) twice a second and after every
  change; the others send their steps and orders (`'M'`, a step back among
  them) and their name (`'H'`) and draw what comes back, so two men can
  never push one crate two ways. The owl's flight in and off is each
  machine's own.
- A newcomer listens two seconds for a world; hearing none, it hosts. A man
  not heard for 3 s leaves the floor; a host not heard for 2 s is replaced
  by the lowest name still heard, from the world it last drew.
- Everything off the wire is checked; the sounds are not sent at all - every
  machine hears what changed in the world it draws (SNDDIFF).

It was tested with a fake player, `tests\SokoPilot\sokopilot2.mjs` in the
OWLOS-LAN repository, against the game in the site's page on a test
server. As a client the fake player was given a man next to the start,
walked left twice, asked for a step back - the game, hosting, put it one
cell back, the moves 2 to 1, its candy points kept - and walked on; it was
dropped 3 s after it went quiet. As the host it served level 1, the game
joined it, stepped through it (and its step back reached the host as
order 8), and took the castle over 1.7 s after it went quiet - with its
man, its point and the 47 candies.

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
  faces out; then the moat, still at dusk - long low swells, every cell in
  its own phase, a breath of wind brightening them as it passes; then the
  land.
- **The land** is the engine's own Diamond-Square (`ENGINE\E_TERR.INC`,
  the islands of OWL FLY), seeded by the level, so every machine grows the
  same: low ground wet (ponds, willows, bushes, mushrooms, a rabbit), then
  the garden (flower beds, hedges, fountains that flow in four frames,
  statues, lanterns, a well, trees in blossom, a deer), then a wood of
  oaks, birches and stumps, the highest a pine wood on a dark floor with
  boulders. Each thing is set a little off the grid, takes the cells it
  covers, and never stands over the castle. And the park lives: a few
  butterflies flutter round the flowers, fireflies drift by the trees of
  the wood and glow half a second now and then, each on a period of its
  own, and a duck or two drifts on the moat. Towers with slate-blue spires
  and a gold pennant at its corners (they had red cone roofs: "why these
  turds - it is not romantic"), torches burning on its walls - the flame
  drawn by the game every frame (FLAME): rows of fire from the cup up,
  white at its heart, yellow, red at its edges, its height and its lean
  from small tables, each torch at its own place in them; they had been
  two pictures swapped on the beat ("they do not burn, they blink") - a
  road out from the gate, an owl now and then. A candy is dark most of the time, then glints: a spot of light on
  its ring for half a second, now and then a white star - each candy on a
  period of its own, 4 to 11 s, never a multiple of the beat, at a new
  place every time, so no two glint together (the pilot: "every crystal
  on one timer - no mystery in it"). The diamond's light goes round it.
- **Dusk at the edges.** Across each side's margin of land the light goes
  by the golden section: the first 0.382 of it in full light, then a
  colour step through a 4x4 ordered dither, a few pixels at first and all
  of them at the screen's edge - no edge to the dusk, and the eye goes to
  the floor. A narrow margin keeps its light, the castle always.
- **Drawn once, sent out by the stretch.** The buffer is 320x200, two
  pixels a byte (EGA 640: twice as wide, below). What does not move - the walls, the park, the goals, the
  dusk - is drawn into a background once a level; every frame is a copy of
  it with what moves on top: the water, the torches, the fountains (the
  dusk laid over them again), the park's creatures, the gate, the bridge,
  the floor's things, the owl, the counts. A picture with no see-through
  pixel - a stone, the water, grass, a crate - is kept without masks, half
  the room, and drawn as a plain copy. The compiled pictures fill their
  places in turn - sseg, at EGA 640 a second segment, then the sound
  ring's top half, over its 32K of sound and the moat's list - and every
  picture's entry says which segment it is in.
  Then each row is compared with what the card already shows and only the
  stretch that differs is converted:
  - **EGA 640**, mode 0Eh, 640x200: the buffer twice as wide, 320 bytes a
    row. The game still counts its 320 columns; every one is a byte - two
    pixels - so every picture is drawn twice as wide, and where `ARTF.DAT`
    has one drawn twice as fine across, a stone's joint, a crate's rim, a
    spire's edge are a pixel thin and rounds are round; where it has not
    (the man, the owl, the deer, drawn by hand pixel by pixel) the 320
    one is doubled. The frame and the background take a whole segment each,
    so there is no copy of the card: each row's checksum instead, and a row
    whose sum changed goes out whole - the same plane converter, 80 bytes a
    row. The 60 levels left the `.COM` for `LEVELS.DAT` to make the room.
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
samples a second, no interrupts. The ring's bed is the shore, made afresh
behind the playing position, never the same three seconds twice; every
effect is added a little ahead of the position, so they sum, and the new
shore wipes them out once played. Its own noise goes through a soft
filter - the waves' wash - and through it once more, darker - a breeze,
steady under everything. Now and then a wave rolls in: its wash rises
for 2 to 3 s, draws back for 3 to 5, and the shore is still for 2 to 6 s,
each wave a height of its own, at most 6 dB over the breeze, never on a
beat. It took three tries: a swell every ten seconds was "too many
waves", a steady wind with no loop was "like white noise", and the pilot
asked for "a calm breeze with waves coming in". Effects are made on the spot
from lists of tones, and the pilot asked for calm - an evening after work
- so they are soft triangle tones, low and long: a crate sliding, two
notes up for a crate home, a wooden knock and a clock's seconds for a
mine, the blast heard from a field away, a diamond rising and a music box
when it is taken, the portcullis's chain far off over a humming winch, the
drawbridge settling, a lullaby for the winner (E, E, G held over a low C),
a candy's soft pop, the owl's "hoo... hoo-hoo", its wings and a startled
hoo when it is caught - and now and then a songbird far off in the park.

## The pulse

Everything that moves keeps one clock: a step every 8 ticks, two to a
heartbeat at rest (68 a minute) - and a frame every second tick, nine a
second, for the candies' glints and the points rising. Between frames
the game sleeps (HLT) to the next tick or key: in a desktop DOSBox the
computer rests. In the site's page js-dos's own loop takes a core of the
CPU whatever DOS runs - measured the same with the file manager idle, at
`cycles=max` and at a fixed 40000, with the sleep and without. The water's long swells drift a pixel a
beat, a breath of wind crosses the moat once a minute, the torches burn
a step a frame (nine a second: fire is never still), fountains flow two
frames a beat, a soft light goes round every candy and
the diamond, the owl comes half a minute or so apart, flies in at 36 px a
second and sits a while, and the
winner rises and settles slowly while petals drift down.

## Build it, run it

In DOSBox, with the repository mounted:

```
cd GAMES\MULTSOK2
MAKE
RUN
```

`MAKE` assembles `ART.ASM` into `ART.DAT`, `ARTF.ASM` into `ARTF.DAT`,
`LEVELS.ASM` into `LEVELS.DAT`, and then the game. `RUN` sets
DOSBox's CPU as fast as it goes first (`config -set "cpu cycles=max"`):
the game keeps time by the BIOS clock, so nothing runs too fast. From
Windows: `MAKEWIN` (`MAKEWIN CHECK` builds it again with the Windows FASM
and compares), then `RUNWIN` - `RUNWIN EGA`, `RUNWIN CGA` or `RUNWIN HGC`
plays it on DOSBox's real card of that kind. `MULTSOK2.COM` reads its
three files from its own folder - one level of `LEVELS.DAT` at every level
change; `ARTF.DAT` only at EGA 640, and without it the pictures there are
all doubled.

## The files

| File | What it is |
|---|---|
| `MULTSOK2.ASM` | the game: start, the rules, the phases, the network |
| `SCENE.INC` | the picture of the castle: the view, the background, the dusk, the frame, the HUD, the winner, the owl, the title |
| `DRAW.INC` | the buffer: compiled pictures, text |
| `VIDEO.INC` | the cards: detection, modes, the converters |
| `SOUND.INC` | the Sound Blaster, the ring, the effects, the birds |
| `MENU.INC` | the first screen |
| `ART.ASM` | `ART.INC` and `KINDS.INC` as `ART.DAT` |
| `ART.INC`, `KINDS.INC` | the pictures, the palette, the CGA and Hercules maps - made by `TOOLS\ArtGen2` |
| `ARTF.ASM`, `ARTF.INC` | EGA 640's finer pictures as `ARTF.DAT`, packed four bits a pixel - made by `TOOLS\ArtGen2` |
| `LEVELS.ASM` | `LEVELS.INC` as `LEVELS.DAT` |
| `LEVELS.INC` | the levels, made by `TOOLS\LevConv` from Base-Z-47's |
| `..\..\ENGINE\E_NET.INC` | the network: IPX, everyone in the room hears everyone |
| `..\..\ENGINE\E_TERR.INC`, `E_MATH.INC` | Diamond-Square and its generator: the land round the castle |

`TOOLS\ArtGen2` (C#) draws every picture at 16 pixels by rule or by hand,
brings them down to 12, 10, 8 and 6, lays the isometric tiles, and renders
a level the way the game does - on every card - as PNG. Its pictures take
a fineness, K: at 1 they come out exactly as ever (`ART.INC`, byte for
byte), at 2 twice as fine across - circles and shading sampled at half
columns, lines one fine pixel thin - and those go into `ARTF.INC`:

```
dotnet run --project TOOLS\ArtGen2 -- GAMES\MULTSOK2\LEVELS.INC 0 PREV GAMES\MULTSOK2
```

A test build, `FASM -d TESTKEYS=1 MULTSOK2.ASM MULTSOK2.COM`, adds keys the
real one has not: F10 every crate home, F9 a diamond two cells left of
your man, F6 the owl on a wall beside him, F7 the fanfare, F8 `RING.DAT` (where the DMA plays, the effects asked for, the
owl, and the ring itself) - how the endings, the sound and the owl were
tested without a hand at the keyboard.
