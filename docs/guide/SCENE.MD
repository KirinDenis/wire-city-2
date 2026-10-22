# SCENE - a calm, living picture round a playing field

How MULTIPLAY SOKO II draws its castle: a clean field to play on, a park
round it that lives, all of it at the pace of a heartbeat, on EGA, CGA
and Hercules from one buffer. The rules came from the people who played
it, one complaint at a time; the complaints are quoted, because each is a
rule. The code is A:\GAMES\MULTSOK2\SCENE.INC (the picture) and DRAW.INC
(the buffer); the pictures themselves are ART, the cards VIDEO. In mode
13h every rule here holds, with a byte a pixel instead of two.

## Rules you must not break

- The field is clean. The floor is black and bare; only what is played
  with stands on it - crates, men, candies, the diamond, the marks.
  Nothing on it is black at its edge: crates with dark outlines on a black
  floor "looked like arrows" - a crate is a gold rim lit on its top and
  left, brown on its bottom and right (ART).
- Warm things on the floor, cool water and green round it, grey stone
  between: the eye finds the play at once. The busy park is outside the
  walls, never over the castle, and darkens towards the screen's edges.
- News goes in the top line, over the level counts - never over the floor
  (SCENE.INC TOPLINE). A banner across the field covered the game.
- One clock for everything that moves: a step every 8 ticks, two to a
  heartbeat at rest, 68 a minute (MULTSOK2.ASM TIMERS: anim = tick >> 3).
  The game was "wildly dynamic - calm is needed, a relaxing evening after
  work, the rhythm of a human heart, like a DJ's". Only fire and glints
  change faster, at the frame rate, and never all at once.
- Nothing moves in step with anything else. Every candy, torch, firefly
  has its own period and its own phase, taken from a hash of where it is;
  a period is never a multiple of the beat. "Every crystal moves on one
  timer - there is no mystery in it."
- Nothing blinks. Two pictures swapped on a clock read as blinking ("the
  torches do not burn, they blink"): a flame changes its shape a little
  every frame, a light fades in and out over a few frames.
- Romantic, not cartoon: slender slate-blue spires with a gold pennant
  replaced red cone roofs that at 8 pixels dithered into brown swirls.

## The layers, back to front

1. The floor, black; the goals, a red mark ringed in gold.
2. The walls: big grey stones in courses, a stone lit on its top and left;
   lime growth only on the side that faces out of the castle (BGCELL:
   which neighbours are outside) - a different picture for each side.
3. The moat: every cell round the walls that is not floor. Its cells are
   listed when the background is made (water's x, y, which banks, its
   phase), because they are drawn again every frame; banks where the next
   cell is dry land.
4. The land: the engine's Diamond-Square (A:\ENGINE\E_TERR.INC), seeded
   by the level number, so every machine grows the same park (MULTSOK2.ASM
   LANDGEN). Its height picks a zone - wet low ground, the garden, a wood,
   a pine wood on a dark floor - and its ground picture (GROUND).
5. The park's things: each cell of park takes a byte from a hash of
   (column, row, level); a zone's table of thresholds turns the byte into
   a kind and its width (SCENE.INC DECOR, ZWET..ZPINE):
   `db 18,K_PND,2, 30,K_WIL,2, 44,K_BSH,1, ...` - below 18 a pond two
   cells wide, below 30 a willow... Each thing is set a little off the
   grid (a second hash: -3..4 sixteenths across, -1..2 eighths down),
   claims every cell it covers, and stands only where all of them are park
   (STAND, CLAIMED). Rows top first: what is lower covers what is behind.
6. Towers on the outer corners of the walls, torches on walls beside the
   floor, a road out from the gate.
7. The dusk (below), over all of it.

## Dusk by the golden section

Across each margin of land - between the castle and the screen's edge -
the first 0.382 stays in full light; beyond it each pixel goes one colour
step darker when the margin's fraction there passes its place in a 4x4
ordered (Bayer) matrix, so a few pixels darken first and all of them at
the edge - a dusk with no edge, and the eye goes to the floor (SCENE.INC
DUSKPREP, DUSK). Rules found the hard way:

- One step only: two steps went black.
- A margin narrower than 3 cells keeps its light (a big level fills the
  screen; dusk over it is gloom).
- The darker colour of each of the sixteen is a table (DIM16), not a
  formula: water goes to deeper water, lime to green, white to grey.
- Things drawn every frame where the dusk may be (the fountains, the owl)
  get the dusk laid over them again; lights (torches, fireflies) do not.
  The moat is near the castle, in the light.

## Drawn once, sent out by the stretch

- The background - floor, walls, moat's first frame, park, dusk - is drawn
  once per level and view into its own buffer. A frame is a copy of it,
  then what moves: the water, the torches, the fountains, the creatures,
  the floor's things, the owl, the numbers (RENDER, FRAMEFL, THINGS).
- The buffer is two pixels a byte. Each row is compared with what the
  card already shows (a copy) and only the stretch between the first and
  the last differing word is converted to the card [VIDEO]. Where there
  is no room for a copy (EGA 640: frame and background take a segment
  each), keep a checksum a row - its words added with a rotate between,
  so a moved pixel changes it - and send a changed row whole (BLITW).
- A frame is drawn only when something changed and at most every second
  tick, nine a second; between frames the game sleeps (STI, HLT) until
  the next tick or key, so a desktop DOSBox rests [TIME].

## Compiled pictures

- At start every picture is compiled from its text form into its own
  segment: `db rows, db bytes a row`, then a (mask, ink) pair per byte,
  drawn as `buf = (buf AND mask) OR ink` (DRAW.INC COMPILE, DRAWSPR). A
  picture with no see-through pixel - stone, water, grass, a crate - is
  SOLID: bytes a row + 80h, the ink alone, half the room, a plain copy.
- A picture stands on its cell's bottom row: drawn at `y + cell - rows`,
  so tall things (trees, towers, 32 rows) rise over the cell above.
- Every size is its own picture (16, 12, 10, 8, 6 and the isometric set);
  a table gives each its place and its segment, 4 bytes an entry, and the
  places fill one segment after another (MULTSOK2.ASM LOADART, PLACE).
  The man is compiled once per look (shirt, cap colours swapped in).
- Clip rows to the field, columns per byte with one unsigned compare: a
  negative column is a huge unsigned one, and both are off the screen.

## What moves, and how

- Water: four frames of long low swells, each cell at its own phase (from
  a hash), a frame every two beats; once a minute a band 48 px wide - a
  breath of wind - passes across, the swells brighter under it (FRAMEFL).
- Torches: the bare torch is a picture; its flame is drawn every frame
  (SCENE.INC FLAME): rows of fire from the cup up, each narrower (a
  half-width table), white at the heart, yellow, red at its edges; its
  height and its lean from two short irregular tables, each torch at its
  own place in them. At EGA 640 in fine half-columns.
- Fountains: four frames, the drops a row lower each - it flows.
- Candies glint (GLINT): dark most of the time, then for 8 ticks a spot of
  light at a place on a ring round it - blue, pale, white, pale - each
  candy on a period of its own, 80..207 ticks from its cell, at a new
  place every time, every fourth time a white star.
- The diamond: grows for a second, then a light goes round it.
- The park's life (LIFE): butterflies over flower beds and blossom, two
  pixels whose wings open and shut; fireflies by the trees of the wood,
  out in the dusk, glowing two thirds of a second on periods of their own
  (2.6 to 4.3 s); a duck or two drifting on the moat. Their homes are
  listed when the background is made; a 16-step swing table moves them.
  A few of each, never on the floor.
- The owl: flies in from the screen's edge at 36 px a second, sits on its
  wall (it hoots on landing and once near its going), flies off the
  nearer way.
- Numbers rising over a man (POPS), the winner rising and settling on his
  podium over the dimmed castle while petals drift down (WINNER).

## Traps of a scene

- Garbage on the screen when something leaves the left edge -> a box
  half off the screen clamped on its left but not its right: the right
  side negative, compared unsigned, huge - the routine dimmed far past
  its row -> after clamping, return if the box has no width (DUSK).
- A level change shows two levels at once, or the packets are garbage, on
  one card only -> that card's converter left ES pointing at the card,
  and every later STOSW went to the screen -> save and restore ES around
  the whole blit (BLITW).
- A picture's pixel cannot be found in a screenshot -> draw it as a red
  square in a throwaway build to see where it is [TILES].
- The playfield looks busy -> the park is too bright near the castle or
  something on the floor has a black edge: dusk, gold rims, fewer things.
