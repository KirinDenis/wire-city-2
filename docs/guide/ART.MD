# ART - pictures drawn by rule, in sixteen colours, at every size

How MULTIPLAY SOKO II's 70 kinds of picture are made: by rules, not by
painting - a rule is small, draws at any size, and changes with a word
("thinner", "rounder", "not black at the edge"). The rules here are its
generator's (TOOLS\ArtGen2, C#, in the repository); what lands on the
disk is A:\GAMES\MULTSOK2\ART.INC - every picture as text, readable - and
ARTF.INC, the same at double width, packed. A model working in the DOS
PC has no C#: write small pictures as text by hand, or let FASM compute
them at assembly time (below), or draw them by a rule in assembly at
start. How they are drawn on the screen is SCENE; the cards VIDEO.

## Rules you must not break

- Light comes from the top left, on every picture: lit on the top and
  left edges, shaded on the bottom and right, highlights up-left. One
  light makes forty pictures one world.
- Sixteen colours, used as meanings, and set as the game's own palette
  (on a VGA through the DAC from the art file; a real EGA shows its own
  sixteen, so keep each of yours near the EGA colour it replaces):
  0 black - the floor, outlines | 1 deep blue - water | 2 green - the
  park | 3 teal | 4 dark red - a goal's shade | 5 purple | 6 brown - wood,
  the dark side of a crate | 7 grey - stone | 8 dark grey - stone's shade
  | 9 blue - swells, the spires | A lime - growth, leaves in the light |
  B pale cyan - glints | C red - a goal, fire's edge | D pink | E gold -
  a crate's rim, fire | F white - light. "Sixteen colours and a palette -
  don't be shy": juicy EGA greens, warm stone, deep water.
- Nothing played with may be black at its edge on a black floor: a crate
  is a gold rim lit on top and left, brown below and right, iron corners -
  black-edged crates "looked like arrows".
- Draw the small sizes by rule too, or check them: what reads at 16
  pixels may vanish at 6. The crate is drawn by its rule at every size so
  its rim survives (CrateN); a candy is reduced by averaging, a flower by
  majority.
- A picture with no see-through pixel is solid - half the memory and a
  plain copy (SCENE). Make the ground, water, stone and crates solid.

## The text form

A:\GAMES\MULTSOK2\ART.INC, one picture:

```
GOL_16: db 16,16
        db '.....4EEEE4.....'
        db '...4EE6666EE4...'
        ...
```

`db width, height`, then a row of characters per row: `.` see-through,
`0`..`9`, `A`..`F` a colour; `S s P p` the man's shirt and cap colours,
swapped for each player's look when compiled. A directory of words
(ARTDIR) gives every picture's place: one per kind for each size 16, 12,
10, 8, 6, one per kind isometric, the isometric floor. The game reads the
file at start and compiles every picture (DRAW.INC COMPILE). Widths are
even: two pixels a byte. A file of 64 KB is the most one read can take;
the art and the game's code together are more than a .COM may be, so
the art is a file of its own (ART.ASM: `format binary as 'DAT'`).

## The rules a picture is drawn with

- A lit round thing - a candy, a boulder, a mine (ArtGen2 Shade): for a
  pixel at (nx, ny) from the centre, in radii, `l = -(nx + ny) * 0.707`
  is its light; l > 0.55 near the middle - the highlight; > 0.15 lit;
  > -0.25 mid; > -0.6 shade; else dark - five colours of a ramp
  ("FAA22" a green candy, "FEE66" a gold one).
- Leaves (Foliage, Leaf): a crown is a few overlapping circles (lobes);
  a pixel belongs to the lowest lobe that covers it; past 0.86 of its
  radius - the dark edge; inside, lit by the same `l`: lime with a dark
  speck now and then, lime and green in a checker, green, green and black.
  Bushes, trees, oaks, birches, blossom, the growth on the walls are all
  lobes.
- Stones (Stones): three courses, stones 8 wide, every other course half
  a stone along; the joint column and the course's bottom row dark; each
  stone lit on its top row and left column, shaded on its bottom and
  right, corners rounded into the joint; one stone in five darker (a
  hash); a pit here and there.
- A thing that must survive every size is drawn by rule at each size n
  (CrateN): iron corners 3 pixels (2 under 10), a rivet at 10 and over,
  the rim a pixel, the frame inside it 2 (1 under 12), planks with a seam
  every max(2, n/5) rows.
- Scatter by a hash of the pixel and the picture, never by a random
  number: the same picture every build, and every machine draws the same.
- A shadow is a dithered ellipse under the thing, drawn only where it is
  see-through (Shadow).
- Water, grass, ground: patterns that repeat in 16 so cells meet without a
  seam.

## Bringing a picture down to the small sizes

Each smaller pixel covers 16/n of the big one each way. Weigh the colours
it covers; half or more see-through - see-through. Then one of three:
'm', majority - the colour that covers most, dark on a tie (outlines,
dots, the man, stones); 'a', average - mix the colours' red, green and
blue and take the nearest of the sixteen, weighting green most (round
shaded things: candies, boulders, the diamond); 'r', no reduction - the
rule draws it at that size (crates, growth, banks).

## FASM computes a picture

FASM's `repeat`, `if`, `=` and integer arithmetic run at assembly time,
so a rule can be written as the picture's own source (VIDEO.INC computes
its 4 KB of EGA tables so):

```
BALL16: db 16,16                ; a lit ball, light from the top left
repeat 16
  y = (% - 1) * 2 - 15          ; the row's distance from the middle, x2
  repeat 16
    x = (% - 1) * 2 - 15
    d = x * x + y * y           ; the distance squared, x4
    if d > 196
      db '.'                    ; outside the ball (radius 7)
    else if d > 160
      db '0'                    ; its dark edge
    else if x + y < -6 & d < 90
      db 'F'                    ; the highlight, up left, inside the rim
    else if x + y < 6
      db 'A'
    else
      db '2'
    end if
  end repeat
end repeat
```

Inner `%` is the inner loop's count: take the row before the inner
`repeat`. (Assembled, it is a 16x16 lime ball with a dark rim, a white
crescent of light up-left, green shade down-right - checked with FASM.)
The same in assembly at run time - squared distances in integers, no
square roots - is how the game draws its torches' flames and its
fireflies every frame (SCENE.INC FLAME, LIFE).

## Sixteen colours on every card

- VGA: the sixteen attributes point at DAC registers; write the game's
  colours there (VIDEO.INC VSET, DACIX). EGA: its own sixteen.
- CGA, four colours: each of the sixteen is a 2x2 half-tone of the four
  (a table of 16 x 4 in the art file: even row even x, odd x, odd row ...)
  - grey a checker of white and black, green cyan and black.
- Hercules, black and amber: each colour a brightness 0..4 drawn as a
  density of dots in 2x2; a pixel is two dots wide, 200 rows become 300.
- One buffer, one set of pictures; each card is a converter [VIDEO].

## Twice as fine across: EGA 640

At 640x200 every one of the game's 320 columns is two pixels. The
pictures are drawn again with a fineness K = 2: a rule gets the fine
column x and works out where it is in the 320 picture - `X(x) = (x + 0.5)
/ K - 0.5` for circles and shading, the single fine column `x == c*K +
K/2` for a line one pixel thin (a stone's joint, a crate's rim, a
spire's edge, a lamp's post), `x / K` for what should stay as it was. At
K = 1 every rule must give exactly the 320 pictures: compare the file
byte for byte after any change. Pictures drawn by hand pixel by pixel
(the man, the owl, the deer) have no fine version: the game doubles each
pixel. 300 fine pictures packed - a bit a pixel for see-through, then
four bits a pixel - are 61 KB (ARTF.INC; DRAW.INC COMPILEF unpacks them).

## The taste, as it was said

- "The floor black and clean, so the players see the field and are not
  distracted."
- "The stones big and distinct; juicy lime growth on the outside."
- "The crates look like arrows" (dark edges) - then gold rims.
- "Why these turds - not romantic" (red cone roofs) - slender spires.
- "The bushes and trees behind the castle - make life more interesting" -
  birches, blossom, willows, deer, rabbits, mushrooms, stumps; then
  butterflies, fireflies and ducks.
- "EGA 640, a little finer" - joints, rims and edges a pixel thin.

Each was a rule for every picture after it, not a fix for one.
