# SHILKA - the task for the next session

Self-propelled anti-aircraft guns for both sides. The pilot's spec, in
his words: a ZSU-23-4 **Shilka** - "зенитка с 4 пулеметами и вращающейся
башней" - **three per side**, the player's and the enemy's. They cover
the cities with flak. They **drive slowly**, **turn the turret** and
**fire at aircraft**, and the shots are **visible in flight** ("как
летят пули у нас есть - выстрел самолета": the tracer machinery already
exists, reuse it). He supplied a four-view drawing: side, front, rear,
plan, plus the turret alone in three-quarter view.

**START WITH THE 3D MODEL. That is the whole first milestone.** Nothing
else in this brief is worth touching until a Shilka stands in the world
and its turret turns.

## The shape, from his drawing

A tracked hull - flat deck, sloped glacis, six road wheels, drive
sprocket at the rear, idler at the front - carrying a boxy turret. The
turret has the four 23 mm barrels in a stack of two pairs on the right
cheek, and the folding radar dish on the roof behind. Read the drawing
again before modelling; it is the source, not this paragraph.

## What the engine will and will not give you

- **Two models, one vehicle.** The radar station of 2026-07-28 is the
  pattern to copy exactly: hull and turret are separate models drawn at
  the same world point, the hull at the driving yaw and the turret at
  its own. `MODELDRAW` (PLANES.INC) does one model at pdx/pdy/pdz with
  msin/mcos; `RSTADRAW` in UI.INC calls it twice. Steal that routine
  wholesale.
- **The caps are 25 vertices and 16 faces PER MODEL** (PVX/PVY/PVZ and
  FCD/FCO in DATA.INC). Hull and turret each get their own budget, so
  the vehicle can be ~50/32 in total. Tracks as one slab a side, wheels
  as painted-on faces if at all: this world is flat chunks.
- **MODELDRAW yaws only - it cannot pitch.** Barrel elevation is not
  free. Cheapest honest answer: bake the barrels at a fixed ~15 deg and
  let the turret's yaw do the tracking. If elevation is really wanted,
  it is a third model at a pitch, or a pitch pass added to MODELDRAW -
  cost it before promising it.
- **Scale.** `MAKE.BAT` runs `TOOLS\Obj2Inc -s N` per model. The F-15 is
  `-s 2` and 26 units across; the radar station is `-s 6` because it had
  to read as a landmark. A Shilka is a small vehicle - pick the scale by
  eye at gun range (2000-4000 units), not by arithmetic, and expect to
  rebuild once or twice to get it right. Materials are `usemtl PALnn`;
  the palette worth knowing: 0 lit grey, 16 shaded grey, 17 roof grey,
  24/25 white lit/shade, 13 dark brown, 19 red, 95 green, 96 yellow.
- **The wreck pool is already generic.** `WRKAT` (PLANES.INC) breaks
  anything at bpx/bpz into eight burning slabs; the radar station uses
  it through the far door `WRKATF`. A killed Shilka should too.
- **Tracers exist.** `TRCUPD` flies the player's rounds and `GUNDRAW`
  draws them as 3D streaks; `AIGUN` is the AI's knife-range strafing.
  Read all three before inventing anything - the pilot explicitly said
  the bullets are already there.

## The room you have (measured 2026-07-28, after the radar work)

| segment | used | free |
|---|---|---|
| main CODE (the stack guard, BSS-START vs 42279) | ~41.7 K | **~500 bytes** |
| UISEG (8176-byte window) | 6255 | **~1900 bytes** |
| SKYSEG (8176-byte window) | holds the sky + the wire | check `$-BNOISE` |

That is the real constraint of this task and it will bite on day one.
The discipline that got the radar in:

- Only **models, state words and call sites** stay in the main segment.
  Everything that merely computes goes to **UISEG** behind a far door
  (`PROC FAR` there, `call FAR PTR` here), and knocks back through the
  thunks in PLANES.INC: MODELDRAWF, ROTXZF, SINQF, TERRHF, WRKATF,
  PPOINTF, LKPOSF, FDRAWF, FNUMF, FNUMKF, CSDRAWF, TYPDRAWF, CLIPLINF,
  LINEF. Add another thunk rather than another copy.
- Far segments run with **DS = the main segment** and cannot near-call
  into CODE. `offset SOMETHING` still gives the main-segment offset -
  that is why model tables can live at home and be drawn from out there.
- When the guard fires, **evict cold code**, do not shave the stack.
  MINIMAP2F, MAPHUM, STATPG and the whole TGT page already went that
  way. To measure headroom, drop a ladder of
  `IF (BSS-START) GT n / %OUT PROBE over n / ENDIF` before the guard,
  build, read the log, delete the ladder.
- If UISEG runs out too, the next move is a **fourth segment**, not a
  squeeze. SKYSEG/UISEG each own an 8K window with an assemble-time
  guard; copy that arrangement.

## The shape of the feature, after the model stands

1. **Six vehicles**, three a side, parked near the cities they cover
   (HBLD/GETZONE say where the city is; the radar stations' RSTAGND
   shows how to probe the terrain for a spot). Ground height per tick,
   because they move.
2. **They drive slowly** - a few units a tick along a heading, turning
   at random or patrolling a short leg. They are not the war; they are
   scenery that shoots.
3. **The turret tracks** the nearest aircraft inside its reach and
   turns toward it at a limited rate. That limited rate is the whole
   character of the thing: a Shilka that snaps to the target is a
   turret, a Shilka that lags is a Shilka.
4. **It fires** in short bursts when the target is roughly under the
   barrels, and the rounds fly as visible tracers with the existing
   machinery. Give it a real ceiling and a real range so a high pass is
   safe and a low one is not.
5. **It can be killed** - cannon and missile, through the same box test
   the radar station uses (`RSHIT` is the pattern), into `WRKAT`.
6. **The wire**, last: the same owner-authority shape as the stations -
   a one-shot packet when one dies plus the state in the host's 'G' ad.
   Positions of moving vehicles are a harder question than the
   stations' were; decide whether they are deterministic from the seed
   (cheapest) or need syncing.

## Traps that have bitten this project

- The CODE stack guard fires on nearly every feature now (see above).
- `SINQ` clobbers SI. `HLINE2` eats CX in its rep stosb. A non-local
  label resets TASM's `@@` scope. One-pass TASM: constants used as
  immediates must be defined BEFORE the include that uses them.
- **A box hit test can be jumped clean over.** A cannon round steps 75
  units a tick, so a box thinner than that between two samples is never
  entered - the radar station's RSRAD is 90 for exactly this reason.
  A Shilka is smaller than a radar station: this WILL bite.
- Check every new arithmetic line against the seven 8086 integer traps.

## Build, run, publish

    MAKE.BAT OWLFLY2

Drive it in DOSBox with a rig that **HOLDS keys** - the game reads
KEYS[] from its own INT 9 handler at 18 Hz, so an instant down/up is
invisible to it (keybd_event with a ~150 ms hold; Ctrl+F5 grabs a
screenshot into the conf's `captures=` folder). The menu is: SPACE
skips the splash, C names a new sky, B toggles bots, ENTER flies.
Two instances on one IPX wire: `NETHOST.BAT` then `NETJOIN.BAT`.

Publishing is `PUBLISH.BAT` (it defaults to OWLFLY2 since 2026-07-28)
or `GAMES\OWLFLY2\PUBLISH.BAT`. It commits and pushes - **that is the
pilot's to run, never yours.** Same for every other commit in this
repo: he owns the history.

## Done when

A Shilka stands in the world with its turret turned to a different
bearing between two frames; three of them a side sit over the cities;
one tracks a jet, fires, and the tracers are visible flying up; a jet
that presses the attack is hit; and a Shilka that is shot up burns.
