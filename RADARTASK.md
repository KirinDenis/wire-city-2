# RADAR STATIONS - built 2026-07-28

Ground radar stations as targets you must defend. The user's spec, in
his words: two stations appear on the map, one on the NORTH side and
one on the SOUTH; one belongs to the player and has to be protected,
the other to the enemy. They show on the cockpit radar, and they are
marked SPECIALLY there ("не забудь радары особо отметить на панели
радара в кабине") - not with a plane symbol. If your station is
destroyed, your scope fills with interference and says it is not
available; if theirs is destroyed, the enemy goes blind. The dish
spins, and a destroyed station breaks apart, burns and smokes.

## What shipped

- **The models.** `res/RDISH.OBJ` (six panels, hand-authored; the
  trainer's has eight - simplified on STYLE grounds at the user's
  request) and `res/RBASE.OBJ` (the mast, from `GAMES/TRAINER/res`).
  MAKE.BAT converts both through `TOOLS/Obj2Inc` at `-s 6` into
  `SRC/RDISHM.INC` and `SRC/RBASEM.INC`. Steel greys, not the OBJs'
  original brown and red: mast 16, head 0, cap 17, and the dish
  alternates 24/25 panel by panel so the sweep reads as it turns.
  21 verts / 14 faces and 16 / 9 - inside the 25 / 16 engine caps.
- **MODELDRAW** (PLANES.INC), lifted out of PLANESDRAW: transform,
  sort and fill the current model at pdx/pdy/pdz with msin/mcos.
  A station is now just "set the four table words and call it",
  twice - the mast at minus our heading, the dish at the spin angle.
- **The stations.** x = 24576 (the spine the squadrons form up on),
  z = 24576 -/+ 7000; RSTAGND probes eight spots 1024 apart along
  each station's east-west line and keeps the highest ground, which
  on an island world also keeps it out of the sea. State: standing /
  down plus RSHITS(8) hit points. The dish angle advances RSPINV(3)
  a tick on the physics clock, one turn in ~4.7 s.
- **The marks.** Scope (RSBLIP): a cross with a hole - centre dot
  plus four arms two pixels out - green ours, yellow theirs, no
  velocity stub, no blink, and nothing at all once it is down.
  Rides RBLIPS' own frame, so it lands on the radar and the SIT page
  alike. Map (RSMAP): the same cross at map scale, and a station
  that is DOWN stays there in trim grey - the ruin is information.
- **Destruction.** RSHIT box-tests a point against a standing
  station (RSRAD 90, RSTOP 190) and RSDAM takes the hit points off
  it. Wired to the cannon (TRCUPD, 1 point) and the player's missile
  (MSLUPD, RSMDMG 4). BWRECK was split: everything from bpx/bpz on
  is now `WRKAT`, so a station borrows the whole building teardown -
  eight slabs, fire, smoke, distance-scaled bang - in scheme 0 so
  the debris is grey steel.
- **The consequences.** OUR station down: RBLIPS hands the glass to
  RSNOISE - 150 dots of crawling static in two greys, reseeded every
  BIOS tick, NO RADAR in red across it. THEIR station down: that
  side's AI drops from 10000-unit missile shots to `airng` 2500,
  eyeball range. The rule is symmetric - each side's own station is
  its own eyes - and there is no friendly-fire guard: a pilot who
  strafes his own antenna has earned the snow.
- **The wire.** RSDAM sets `rsnet`; NETPOS sends a one-shot 'R'
  packet (pid, gid, index). NETPOLL's RSDOWN marks it down and sets
  `rsboom`, which NETAPPLY (main segment - far segments cannot reach
  the wreck pool) turns into the same fire on every machine. The
  host's 'G' ad grew a byte at +17 with the standing/rubble bits, so
  a lost 'R' heals within a second and a joiner arrives correct.

- **The lock** (added the same day, on the pilot's word: "для радара
  должен работать Target как и для воздушных целей"). A locked
  station rides in `locki` as **RSLK + index*2** = 0FFF0h / 0FFF2h.
  Two things fall out of that encoding for free: 0FFFFh is still no
  lock, and bit 1 - the parity every IFF test in this game already
  reads - comes out FRIENDLY for ours and HOSTILE for theirs, so the
  ring colour, the TGT/FRD word and the lock lamp all took it
  without a line of change. `RSLOCK` is the second half of the ENTER
  scan and plays by the same rule as the jet loop above it - inside
  24 px of the ring, NEAREST WINS - so a jet crossing in front of
  the antenna still takes the lock. `LKPOS` answers "where is the
  locked target" for the ring, the TGT page, the missile's homing
  head and the F4 orbit camera alike (a station is aimed at half its
  height - that is where the dish is); `LKDEAD` answers "is it still
  there". CSDRAW prints TYPN2 - the word RADAR was already in the
  image - and TYPDRAW keeps quiet. The TGT page draws the DISH,
  turning, walking its face table as closed quads since a station
  has no edge list. The lock dies with the station, locally and over
  the wire.

## Where it lives, and why

The main segment had roughly 600 bytes free when this started and the
station code alone wanted more. Only the MODELS, the state words and
the few call sites stayed home; everything that merely computes lives
in **UISEG** behind far doors - RSTAINITF, RSTADRAWF, RSBLIPF,
RSHITF, RSNOISF, RSLOCKF, and RSMAP riding out with MAPHUMF. The far
segment knocks back through MODELDRAWF / ROTXZF / SINQF / TERRHF /
WRKATF / PPOINTF / LKPOSF / FDRAWF / FNUMF / FNUMKF / CSDRAWF /
TYPDRAWF / CLIPLINF / LINEF in the main segment. To pay for it:
MAPHUM, STATPG and finally the whole TGT page followed MINIMAP2F out
to UISEG, and the dead flat-ground `GRID` in WORLD.INC is now wrapped
in `IF 0` - every line still readable, none of them shipped.

## Verified

Screenshots through a DOSBox rig (menu driven with HELD keys - the
game reads KEYS[] at 18 Hz and an instant down/up is invisible to it):
the station standing with its dish at different angles between frames;
both crosses on the map, north and south of the red front line; the
cross on the scope; a cannon hit taking a hit point off; the NO RADAR
snow; the grey ruin left on the map; ENTER locking a station (FRIEND /
RADAR under the ring, the lamp lit) and the TGT page naming it with
its dish turning in wireframe; two missiles homing on it and putting
the scope into snow; and two instances on one IPX wire agreeing on
both stations while seeing each other as humans.

## Left open

- The AI never attacks the ground, so in a bots-only sky nobody ever
  shoots YOUR station - the snow is reachable solo only by strafing
  your own. That is honest, not a bug, but bombers with a ground
  mission would make the defence half of this feature real.
- AI missiles do not test the stations (they home on jets; the test
  would cost bytes for a near-zero chance of an accidental hit).
- The end-to-end wire kill - shoot a station on one instance, watch
  it fall on the other - was not driven automatically; every link in
  that chain was verified on its own.

## Unrelated, still open

- ViewOwl `IpxRelay.MaxPacketsPerMinute` 120 -> 3000 is edited but NOT
  committed. Without it live players are cut off ~6 s after take-off.
- `docs/owlfly2_v5.jsdos` (kill sync, window fix, spinning smoke, the
  browser +/- keys) is packed but not published.
