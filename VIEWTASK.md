# LOOKING OUT OF THE SIDE - built 2026-08-05

The pilot drew a left and a right console and asked for the 1980s move:
press a key, the camera turns **exactly ninety degrees** inside the
cockpit, and a painted side panel takes the screen. Exactly ninety,
because a painted console can only be right at one angle - anything else
and the artwork is a lie about where your head is.

## The keys

**F6 look left, F7 look right**, and **Ctrl+Left / Ctrl+Right** the same,
so the hand already on the stick never leaves it. Pressing the side you
are on - or the other side - comes back to the front: one key, both ways.

The pilot chose these. The MicroProse convention as far as I can recall it
put the views on F1/F2/F3 with forward on F1, but this game already spends
F2/F3/F4/F5 on the cockpit toggle, the chase, the orbit and the missile
camera, and I could not honestly claim from memory that the F-15 II manual
said F2 and F3. Guessing would have meant re-teaching four keys twice, so
it was asked rather than assumed.

Ctrl+arrow does NOT bank the jet - the roll input now refuses while Ctrl is
down. That is not a detail: the whole reason for putting a view on the
arrows is that the hand stays on the stick, and it would be worthless if it
rolled you every time you looked.

## What shipped

- **The artwork**, `res/cockpit_left.png` and `res/cockpit_right.png`, both
  1586x992 - the same 1.6 the screen is, so nothing stretches.
- **One palette for three pictures.** The VGA DAC lends this game 63 slots
  (31..93) and now three panels have to live in them, so `Panel2Inc` takes
  `-left` and `-right` and feeds ALL THREE to a single median cut, the
  front counted twice because it is the one you stare at. Running the front
  alone would leave the sides quantised against a ramp they never voted in
  - and they are far darker artwork, so they came out in three shades of
  near-black when I tried it. MAKE.BAT passes both; they cannot go stale
  separately.
- **They are NOT stored as bitmaps.** The front panel is 64000 raw bytes in
  a 64K page of its own; two more of those would want two more pages, and
  moving the far map is how this project has broken itself twice. The sides
  are RLE'd to about 24K each and **blitted straight out of the compressed
  stream** - there is no decompressed copy anywhere. Token byte, two bits
  of type and six of count, count 0 meaning a word count follows:
  `40|n` literal, `80|n` run, `C0|n` skip (transparent), `00` end.
- **`CPSIDE.DAT`, its own file**, built by `SRC/SIDEDAT.ASM` the way
  RESDAT.ASM builds CITY.DAT. It is separate because CITY.DAT is read in
  one go with `CX=0FFF0h` and so can never exceed 64K - and the front panel
  alone is 64000 of those bytes. Both streams and an 8-byte header come to
  48231 bytes, one page with room to spare.
- **The page goes ON TOP**, at `scrseg + 1000h`. Everything from the back
  buffer up is stacked nose to tail, so a page opened anywhere below shoves
  the whole map along; past the scratch page nothing is stacked on
  anything, and this one costs no other segment a paragraph. `CPSLOADF`
  computes it from **DS**, not from a typed-in paragraph offset - that kind
  of hand-copied constant is what went stale the last two times.
- **A HEAD TURNS INSIDE THE AEROPLANE.** `SVIEWF` rewrites the attitude
  before `SETTRIG` and `SVRSTF` puts it back after `RENDER`, so the physics
  step that follows never sees it - the trick `CHASESET`/`CHASERST` already
  play. It refuses outright while the chase, orbit or missile camera is up:
  those own the camera, and there is no cockpit around it to look out of.

  **This took two goes, and the second one is the story.**

  The first cut turned the YAW and nothing else. The pilot caught it at
  once - *"the plane flies as it flew, it is the pilot's HEAD that turns
  ninety degrees"* - so the second cut swapped the angles about as well:
  pitch = ∓bank, bank = ±pitch. That is EXACT at zero pitch and steadily
  wrong away from it, and he caught that too: *"fine while you fly
  straight, but start banking and it tilts and the scene moves at you; in a
  loop it starts right and then goes strange."* Which is precisely what a
  formula that is only right at pitch = 0 does. His own diagnosis was the
  correct one: **take the camera matrix and turn it ninety degrees.**

  The renderer has no camera matrix to hand - it is a chain, yaw in ROTXZ,
  pitch in PITCH4, roll as a rotation of the finished picture in APPLYROLL.
  But written out that chain IS a matrix, `M = Z(roll)·X(pitch)·Y(heading)`,
  and a head turning about the pilot's own spine - which in camera axes is
  just Y - is `M' = Y(±90)·M`. The catch is that M' has to go back INTO the
  chain as a new (heading, pitch, roll), and no substitution of angles will
  do it. Ninety degrees folds by hand, though:

      Y(90)·Z(r) = X(−r)·Y(90)        Y(90)·X(p) = Z(p)·Y(90)
      look RIGHT:  M' = X(−r)·Z(p)·Y(h+90)
      look LEFT :  M' = X(+r)·Z(−p)·Y(h−90)

  Those leading two are in the wrong order for the chain, so the product is
  multiplied out and read back as Z·X·Y. Its bottom row and middle column
  are all that is needed, and both sides share them but for one sign:

      m20 = −sinR·sinP     m21 = ∓sinR·cosP     m22 = cosR

      heading' = heading ±90 + atan2(m20, m22)
      pitch'   = atan2(m21, |(m20,m22)|)
      bank'    = atan2(±sinP, cosR·cosP)

  Three arctangents and a length, **once a frame** - not per vertex - so
  the exact answer costs about what the wrong one did. `SHKBRG` is already
  a full atan2 in this segment (it is what the Shilkas take their bearings
  with) and the length falls out of the first angle without a square root:
  rotate (m20,m22) back by it and read the axis. Nothing is clamped and
  nothing goes singular. The view is right at any attitude, upside down
  included.

  **And a third fault, which was not geometry at all.** With the matrix
  right, the pilot flew it again: the loops and the turns looked correct,
  *"but the plane still starts flying in the direction the player is
  looking."* Restoring the three ANGLES after the render is not enough -
  `INPUT`, the physics step, integrates the flight path straight off
  `hsin/hcos/psin/pcos` and never computes them itself. It trusts whatever
  the render left behind. That was harmless for as long as the render only
  ever drew the pilot's own attitude; the moment the head could turn, the
  angles went back and the SINES did not, and the jet flew off down the
  line of sight.

  `CHASERST` and `LERPRST` each call `SETTRIG` for precisely this reason -
  *"physics needs the real trig back"* - and **both are conditional**. In
  ordinary flight neither of them fires. So there is now one unconditional
  `SETTRIG` at the bottom of the render block, and the contract at the top
  of CITY.ASM says it outright: anything that moves the camera for the
  length of a render must leave the trig belonging to the AIRCRAFT, not to
  the view.

  What the second version was missing shows up plainly in the heading term:
  at 20 units of bank AND 20 of pitch, `atan2(m20,m22)` is −10 units - and
  the old code had no heading correction at all. Ten units is fourteen
  degrees of the world swinging the wrong way, growing as you pull. That
  was the scene moving at you.
- **No glass HUD in a side view.** The aiming ring, the gunsight, the
  compass and the strips are a HEAD-UP display, and a head-up display is
  bolted to the front of the cockpit. The MFDs go with them - they are on
  the front panel, out of shot.
- Missing or corrupt `CPSIDE.DAT`: `cpsseg` stays 0, the four keys are
  dead, and the game flies exactly as it did before.

## Where it lives

All of it is in **SYMSEG** - `CPSLOADF`, `SVIEWF`, `SVRSTF`, `SIDEBMPF` -
including the saved heading and the four key-edge bytes, which are
CS-relative there rather than in main-segment BSS. The main segment paid
about 40 bytes for the three call sites and the two branches.

**IT IS NOW FULL. BSSMARK sits at FDEC against the FDEE guard: TWO BYTES.**
The next thing that wants main-segment space has to evict something first.

## Verified

- Builds clean; SYMSEG inside its 8K window; the BSS guard passes by two
  bytes.
- **The shipped `CPSIDE.DAT` was decoded independently** (C#, the same
  token rules SIDEBMPF walks) and drawn with the generated PALPNL palette:
  header offsets right, both streams cover exactly 64000 pixels, every
  index inside the 31..93 panel ramp, and the pictures are the two consoles
  - not a smear. That proves the whole data path except the assembler
  mirror of the same loop.
- The shared palette was judged by eye on all three panels; the front one
  is unchanged to look at.
- **The head turn is proved, not argued.** A C# model builds
  `M = Z(roll)·X(pitch)·Y(heading)` from the engine's own three matrices -
  read off ROTXZ, PITCH4 and APPLYROLL, in their own signs - turns it by
  `Y(±90)`, then runs SVIEWF's formulas and recomposes `Z(bank')·X(pitch')
  ·Y(heading')`. Over **24024 attitudes** (both sides, bank right round the
  circle, pitch −64..+64, several headings) the worst disagreement between
  the two matrices is **0.000000**. The decomposition is exact, not an
  approximation with a small error - which is what the previous two
  attempts were.

  What that does NOT cover: the 8-bit angles and the 33-entry SHKATN table
  the shipped code actually computes with. Those cost about a unit - a
  degree and a half - which is the precision everything else in this sim
  runs at.

## NOT verified - the pilot flies this one

Nothing here has been flown. Watch, in order:

1. **The head turn, which is now the whole point.** Bank into a turn and
   look toward the low wing: you should be looking DOWN at the ground, and
   up at the sky the other way. Nose up, wings level, look out of the side:
   the horizon should lie over at an angle. Then **bank and pull at the
   same time**, and fly a loop looking sideways - that combination is what
   the first two versions got wrong, and it is the one worth flying.
2. **Does the console line up with the horizon** - the artwork assumes a
   particular eye point, and if the window in the picture does not frame
   the world the way the front panel does, the number to look at is not the
   code but the drawing.
3. **The panel bottom**: the front panel has a 399-span loader cap and the
   sides do not use that path at all, so if anything is missing along the
   bottom it is a different fault from the one that comment warns about.
4. Ctrl+Left / Ctrl+Right while manoeuvring - the jet must not bank.
5. F6/F7 while the chase (F3) or orbit (F4) camera is up: nothing should
   happen at all.
