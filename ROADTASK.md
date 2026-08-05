# THE RING ROAD - built 2026-08-04

The pilot asked for a ring road round the city. The decision, and why it
went this way rather than the obvious way:

**A road that follows the contour would look LESS real, not more.** A road
is a made thing - it is laid out in straight runs at right angles, because
that is how roads get built. A winding line, stepped every 256 units,
reads from the air as the edge of a texture, not as a highway. So the
geometry is engineering, and the SHAPE comes from the city that is already
there.

**And the ring did not need drawing - it needed CLOSING.** The street grid
was already on an eight-cell lattice. What was wrong was that the streets
kept stopping. HBLD asked the per-cell zoning first, and the zoning reads a
height node every four cells; wherever one node inside a city block
wandered out of the 120..167 band, its cells fell through to "the terrain
mesh paints this" and the avenue running past them lost two cells in the
middle. From the air the city did not read as a city - it read as street
fragments, with no line at all round the outside of it.

So: **decide the street at the level of the BLOCK, not the cell.** A built
city block's avenues run end to end, all eight cells, whatever the ground
under any one of them is doing. And the outermost avenues of the built-up
blocks then form a closed belt round the district for free.

## What shipped

- **The block table** (`SRC/TOWN.INC`, TOWNSEG). One byte per 8x8-cell
  block, the whole toroidal world in 32x32 of them, 1024 bytes, baked once
  by `BLKTABF` right after DSGEN in CITY.ASM. Bits 0..3 the superblock
  hash & 15 (the 3-in-16 clustering test), bits 4..5 the district, bit 6
  BLKCITY - the block's CENTRE node is in the city band. Bits 0..5 sit
  exactly where the old SBHASH put them, so the building path reads the
  byte through `BLKINFF` and carries on unchanged.
- **`SBHASH` is gone from the main segment.** It had always been *called*
  the single source of truth for "is this block built up" - and it was
  being ASKED cell by cell, which is precisely what let the cells of one
  block answer differently. It is now `BLKHASH`, character for character,
  asked once per block and written down. There is one implementation.
- **`ROADOKF`** decides one avenue cell. It asks whether ANY block the
  strip touches is a built city block - not just the cell's own. That is
  the whole ring: ISROAD puts the two-cell strip on the WEST and SOUTH
  edges of a block, so a block only owns half of its own frame; the other
  two sides belong to the blocks north and east of it, which are usually
  empty. Testing the strip rather than the block paves the far kerb as
  well, corners included (the diagonal block is tested too, or the ring
  would have a 2x2 notch at every corner).
- **`HBLD` asks the two questions at two scales now.** ISROAD first, and
  the block decides it; only then the per-cell zoning, and the cell decides
  its plot. Non-road cells behave bit for bit as before - the set of cells
  carrying a building is unchanged.
- **The sea still cuts a street.** A cell below raw height 88 is never
  paved, block or no block: a causeway standing on the water at height zero
  reads worse than an honest gap.
- **The traffic was not touched, and did not need to be.** Every stretch of
  the ring is still axis-aligned and still eight cells to a green, so the
  lanes, the global slot numbering and the identity CARV*CARG = one block
  all hold. Cars drive the belt with the code that already existed.

## Round two, the same day: reach, and sitting on the ground

The pilot flew it and photographed two things wrong.

**The streets showed up far too late.** ROADR was 9 cells - 2304 units - and
that was a budget, honestly arrived at: at ROADZ 5200 every street inside
twenty cells ran a full ROTCUL and filled a large ground quad, hundreds a
frame, and that is what froze the web build once. So the reach was bought
back rather than simply turned up:

- ROADR 9 -> **24, the whole walk**. That is as far as a road can go without
  lengthening the buildings walk itself (BORD is 49x49), so it is 2.7x, not
  quite the 3x asked for - the last third needs a bigger walk, which is a
  separate and much more expensive change.
- Past **ROADLOD** (9 cells) a quad covers a **2x2 GROUP** of cells instead
  of one, and only the group's even/even anchor draws it. This is an EXACT
  merge, not a simplification: an avenue is two cells wide, and every road
  cell falls in an even/even 2x2 group that is road all the way through.
  One quad in four.
- Net: 2.7x the reach for about 2.4x the fills, and the far ones are a few
  pixels each. **Whether that actually holds the frame rate has not been
  measured** - it is the first thing to watch on the next flight.
- The traffic did not move. It is gated on CARZ *and* on being in ungrouped
  detail, and CARZ 2200 < ROADLOD*256 keeps that automatic.

**The tarmac did not lie on the ground.** A road cell took ONE height -
GETH at the cell, i.e. the height NODE it falls in, held flat across all 256
units. The terrain under it is not flat: the mesh interpolates between nodes
1024 apart. So on any slope the cell was a paving slab hovering over the
hill at one end and buried in it at the other. `ROADYF` (TOWNSEG) now bends
the quad onto the ground **per corner**, interpolating exactly the way the
mesh does. It is cheap because the corners are not arbitrary: a cell edge is
a multiple of 256 and a node is 1024, so every corner lands on a quarter of
a node cell - the weights are only ever 0/4..4/4. Four node heights fetched
once, then two multiplies and a shift per corner. No divides. The flat
`gbase` survives as what the VEHICLES stand on, and nothing else.

The forest / water / field patches (`bstreet` 2) still take one flat height
and will float on a slope the same way. Same fix, one call - not done,
because it was not what was asked for.

## Where it lives, and what it cost

All of it is in TOWNSEG behind four far doors - BLKTABF, BLKINFF, ROADOKF,
ROADYF - which is why it could be written at all: the main segment had 83
free bytes when this started. Round one came out 69 bytes BETTER OFF than
it went in (BSSMARK FD9B -> FD56), because SBHASH left and HBLD's four-way
zone compare collapsed to `or ax,ax`; round two spent 81 of that back on
ROADCELL's level-of-detail split, leaving **71 bytes** (FDA7 against the
FDEE guard). TOWNSEG's code needs no far doors home: it runs with DS = the
main segment, so it reads HMAP directly, and `CELLH` / `NODEH` are the
engine's GETH and WORLDH written out locally rather than called.

## Verified

- **It assembles, links and fits.** MAKE OWLFLY2 clean; TOWNSEG still
  inside its 8K window; the main segment's BSS guard happier than before.
- **The geometry, exhaustively.** A C# mirror of ROADOKF, branch for
  branch, over 24 block layouts - a single block, a bar, an L, a hollow
  ring, and twenty random maps at the game's own 3-in-16 density - checked
  for three properties, all clear:
  1. every built block's avenues run all eight cells, no gaps;
  2. the two-cell frame round every built block is fully paved, all four
     sides and all four corners - the ring closes;
  3. nothing is paved that does not touch a built block, so the island does
     not wear a road grid over empty countryside.

## NOT verified - the pilot flies this one

Round one was flown by the pilot and the ring itself was not what came
back wrong - the reach and the ground fit were. Round two has NOT been
flown at all. Three things to watch, in order:

1. **Frame rate.** 2.7x the reach at ~2.4x the fills is arithmetic, not a
   measurement. If the far city drags, the lever is ROADLOD (drop it and
   more of the road runs in 2x2 groups) before ROADR.
2. **The tarmac on slopes** - does it lie on the hill now, at both ends,
   near and far.
3. **The seams between grouped and ungrouped detail** at ROADLOD, and
   between a 2x2 group and the terrain quad under it.

OWLFLY2 has no serial telemetry, so FlyDbg cannot reach it; this is flown
by hand.
