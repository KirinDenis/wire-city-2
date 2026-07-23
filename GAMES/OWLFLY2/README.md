# OWL FLY II

The successor. Forked 2026-07-23 from `GAMES\OWLFLY` — the complete,
proven game — after the NEWTON experiment ran its course. The verdict
that founded this project, in the pilot's words: the sky and clouds
were excellent, the physics was worth seeing, everything else fell
apart. So: start from the working core again, and this time the core
is the whole game.

The first build is byte-identical to OWL FLY (`FLYOWL2.COM` and
`CITY.DAT` both MD5-matched before anything was allowed to change).
**The flight model is OWL FLY's and stays OWL FLY's.**

## The road

1. **done** — the fork, proven identical
2. **done** — F-15 SE II keys: Shift+plus / Shift+minus throttle
   gates and top-row 1/3 rudder pedals added; arrows-as-stick
   (up = nose down), +/- throttle, A afterburner and the views were
   already the manual's scheme. L gear / B brakes / P autopilot are
   skipped: this sim has no landing model to hang them on (crash =
   respawn). The exit is **Alt-Q**, the MicroProse way - ESC is
   deliberately dead (players kept quitting whole sorties with it by
   accident), and the old Q/E rudder aliases died with it so a held
   rudder can never meet a stray Alt. W/S, Z/C and numpad aliases
   still work.
3. **done** — **EXE**: FLYOWL2.EXE via TLINK without /t. One PARA
   segment still, ORG 100h kept so every offset matches the proven
   COM image byte for byte; the entry prologue rebuilds the COM
   world by hand (SS:SP to the segment top first, then DS=ES=CS).
   The door past 64K is now open: new code/data can go into real
   second segments as steps 4-6 need them
4. **done** — the NEWTON sky, and it moved into the land the EXE
   opened: `SRC/SKY.INC` is a second segment (SKYSEG at CS+1000h)
   holding the blue-noise matrix, the ramp tables, four cloud coats
   and ninety-six world clouds. The main segment keeps only ~90 bytes
   of hot variables; the far-memory map moved up 100h paragraphs to
   make room. Sky: five-step ramp dithered by perpendicular distance
   to the real horizon (world-locked grain when banked), palette
   98..104 day and night. Clouds: baked silhouettes standing in the
   world - fly past them, climb above them; drawn after the stars,
   before the terrain, so a ridge buries what hides behind it
5. **done** — the OBJ2DAT model pipeline is wired in: the build
   converts `res/F15.OBJ` (a hand-built twin-tail F-15, 23 verts /
   14 faces) to `INSTALL/F15.DAT`, and the game loads it at startup
   straight into the fighter's slot of the type tables - the DAT
   payload IS the engine's native model format. On any load trouble
   the built-in fighter flies on. PLAYERDRAW (F3 chase) now reads
   the type-0 tables instead of its hardcoded 13/8 model, so player
   and AI fighters wear the same airframe. Wreck contract kept: the
   model's first 13 vertices carry the classic meanings, so the
   explosion debris still cuts sensible shards. New models: edit
   the OBJ (or export one from Blender with PALnn materials),
   ceilings are 25 vertices / 16 faces
6. **flying** — the network arc, first light 2026-07-23: `SRC/NET.INC`
   is IPX multiplayer the 1990 way. Joining a game is a TWO-BYTE
   handshake - the world is procedural, so the newcomer broadcasts
   HELLO, whoever is flying answers with the world seed, and DSGEN
   builds the same island, city and clouds on both machines. Then
   everyone broadcasts an 11-byte position per physics tick, and the
   other pilots fly your sky as F15s in the last four AI slots -
   PLANESDRAW, contrails, target lock and wrecks all come free.
   `NETHOST.BAT` starts a sky (ipxnet server, UDP 213), `NETJOIN.BAT
   <ip>` joins one; two windows on one machine is the dogfight lab.
   Proven: shared world (identical minimaps), mutual sightings.
   Next: the ViewOwl /ipx relay for internet skies, Claude in the
   tower. NB the ECB layout lesson lives in EXAMPLES\BBS.ASM and the
   project memory - link dword first, or the wire eats you

## What NEWTON left us

NEWTON lives on in `GAMES\NEWTON` as the physics laboratory: full
Newtonian flight (loops, energy, induced drag, CFIT), the calibration
benches (flat checker and the pyramid, `CALIB equ`), the surveyor's
corner protocol, the two-mode control scheme, and the hard-won ledger
of 8086 integer traps and projection lessons in the project memory.
Raid it for parts; do not resurrect it whole.

## Building

    MAKE.BAT            (or MAKE.BAT OWLFLY2 from the repo root)

Output: `INSTALL\FLYOWL2.EXE` + `INSTALL\CITY.DAT` + `ENGINE.RAW`.
