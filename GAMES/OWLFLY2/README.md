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
2. **done** — F-15 SE II keys: throttle gates (Shift+W full, Shift+S
   idle - they lived on Shift+plus/minus until 2026-07-27, when the
   obvious broke: '+' IS Shift+'=' on a real keyboard, so the manual's
   own throttle key could never ramp, it just pinned 100%) and
   top-row 1/3 rudder pedals added; arrows-as-stick
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
   Browser skies ride the same IPX through WebSocket into the relay
   (docs/owlfly2.html); native DOSBoxes keep `ipxnet`. Next: in-game
   chat on the same wire, real callsigns, Claude in the tower. NB the
   ECB layout lesson lives in EXAMPLES\BBS.ASM and the project
   memory - link dword first, or the wire eats you
7. **done 2026-07-27** — the SA / cockpit redesign. The scope speaks
   NATO shapes (friend = square, hostile = diamond, humans white with
   a callsign letter, a velocity stub on every blip); the ADI died
   (it duplicated the HUD) and the centre MFD pages through
   MAP (north-up island, front line, humans as letter + altitude
   digit) -> SIT (close-zoom scope) -> TGT (callsign in IFF colour,
   type, RNG/ALT, live wireframe) on the M key; the right MFD is
   pure status (score, GUN, MSL, DAM); any human in view wears a
   white nameplate - letter + range - at any distance
8. **done 2026-07-28** — **the radar stations**: two of them, one per
   side, planted on the map's north-south spine 7000 either side of
   the front line, standing on the highest ground within 4 km of
   their mark. A lattice mast and a six-panel dish (`res/RBASE.OBJ`,
   `res/RDISH.OBJ` through Obj2Inc, six panels not eight - this world
   is cut from flat chunks and a smooth bowl read as a foreign
   object), and the dish sweeps: one turn every ~4.7 s. On the scope
   they are NOT aircraft - a cross with a hole, owner-coloured, no
   velocity stub, no blink - and they sit on the centre-MFD map too,
   so you can see what you are defending. Eight cannon hits or two
   missiles and a station comes apart into the wreck pool: slabs,
   fire, smoke, the bang scaled by distance. Then the consequences.
   YOURS down and the scope goes to crawling snow with NO RADAR
   across it - no blips, no stations, nothing. THEIRS down and their
   AI is blind: 10000-unit missile shots become 2500, eyeball range.
   Over the wire an 'R' packet reports the fall and the host's 'G' ad
   carries the standing/rubble bits every second, so a lost packet
   heals and a joiner arrives with the right picture. And a station
   is a TARGET like any other: ENTER locks it by the same
   nearest-inside-the-ring rule the jets play by, the designator ring
   and its off-screen pointer follow it, the TGT page names it RADAR
   and draws its dish turning in wireframe, a missile homes on it
   (two level a station), F4 orbits it, and the lock dies with it.
   The trick that made that cheap: a locked station rides in `locki`
   as 0FFF0h + index*2, so the IFF parity test every reader already
   does comes out right, and one helper - LKPOS - answers "where is
   the target" for the ring, the page, the missile and the camera
   alike. The station code lives in UISEG behind its far doors - the
   main segment had ~600 bytes left and this feature wanted more

## The front door (2026-07-24)

`SRC/UI.INC` is the third far segment: a splash (the three-ship of
wireframe F15s out of the night, straight at you, under a spooling
turbine and the big amber title - any key skips) and the sky list.
The list is LIVE: every host advertises its sky once a second over
IPX ('G' packets: name, seed, heads, the war score, bots), the menu
just listens and draws. ENTER joins the picked sky - the ad already
carries the world seed. C names a new sky (type 8 letters), B picks
bots on (the 20v20 war) or off (a clean PvP arena, Counter-Strike
manners: shot down - SPACE - back in). Ten minutes, a whole sortie:
that is the pilot this game is for.

## What NEWTON left us

NEWTON lives on in `GAMES\NEWTON` as the physics laboratory: full
Newtonian flight (loops, energy, induced drag, CFIT), the calibration
benches (flat checker and the pyramid, `CALIB equ`), the surveyor's
corner protocol, the two-mode control scheme, and the hard-won ledger
of 8086 integer traps and projection lessons in the project memory.
Raid it for parts; do not resurrect it whole.

## Building

    MAKE.BAT            (or MAKE.BAT OWLFLY2 from the repo root)

Output: `INSTALL\FLYOWL2.EXE` + `INSTALL\CITY.DAT` (no ENGINE.RAW:
the turbine is generated at startup - GENBED). Web bundle:
`docs\pack.ps1 -Game OWLFLY2`; deploy with `PUBLISH.BAT OWLFLY2`.
