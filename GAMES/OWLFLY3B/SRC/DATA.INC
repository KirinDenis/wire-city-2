; DATA.INC - part of WIRE CITY (included from OWLFLY3.ASM)

; ============================================================================
;  DATA
; ============================================================================
vcard   db 7                    ; the INTERNAL card code the front step
                                ; picked (VID.INC): 1 Hercules, 2 CGA,
                                ; 3 EGA 640x350, 4 EGA 320x200,
                                ; 5 VGA 640x480x16, 6 MCGA, 7 VGA.

; ---- how much of the picture the machine is asked to work out -------------
;  Picked on the second front screen, beside the card. The levels are
;  CONDITIONS THAT SKIP WORK, not other renderers: FULL is this program
;  exactly as it has always been. Plan: Skill\QUALTASK.md.
;
;  What each one costs was measured before it was written: the bill is
;  FILLED AREA, not effects. Smoke and trails are single-digit percentages
;  against a terrain mesh that paints all 64000 pixels.
qual    db 2                    ; 2 LOW, always: the BOND has no other detail.
                                ; E_RAST.INC in ENGINE reads it: LOW strokes

; ---- the near plane the EDGE clipper uses, and why it is not a constant ----
;  NEARZ (40) is right for models: a wing tip may pass a metre from the
;  glass. It is WRONG for the ground grid, and the reason is in PROJPT: when
;  rz is under 256 and the point is far to the side, the projection would
;  overflow, so it CLAMPS the coordinate to +-4000 and keeps the sign. A
;  filled polygon does not care - the span filler clips it. A LINE does:
;  move one endpoint and the whole segment changes direction, which is
;  exactly the "the grid falls apart after a bank" the Hercules take showed.
;
;  At rz >= 256 the guard can never fire (|rx| would have to pass 37888, and
;  the grid's farthest corner is about 12000), so GRID clips at 256 instead.
;  The cost is the nearest quarter-cell of grid, straight under the nose.
nzmin   dw NEARZ
TMED    = 1600 - 576
                                ; 6 and 7 are ONE path - mode 13h IS
                                ; MCGA's mode. Everything below 6
                                ; converts the frame in VIDSEG

; ---- flight state ----
vel     dw CRUISE               ; airspeed, *16 fixed point
; The three things a pilot puts OUT into the airstream. Each one is a
; toggle, each one costs speed, and the flaps buy a slower stall for it -
; which is the whole trade and the reason they exist. F, L and B; the
; annunciator column on the left says which of them are hanging out.
; ...and how far out they actually ARE. The lever is instant; the legs are
; not. Six steps, one every fourth tick, so a cycle takes about a second -
; which is why the drag arrives before the legs finish coming down and stays
; a moment after they are up. SWKEYS walks this (it is called every tick and
; lives out in UISEG); GEARDRAWF in SYMSEG draws whichever step it lands on,
; straight out of GEARM.INC. Step 0 is stowed and is not drawn at all.
GEARNS  = 6                   ; steps of travel, and the vertices a leg has.
GEARNV  = 16                  ;  The guard beside the include in SYM.INC
GEARNF  = 4                   ;  checks GEARM.INC against these three.
vstl    dw VSTALL               ; stall speed AS FLOWN: flaps lower it
; ---- WHAT THE JET IS STANDING ON, which it never used to have an opinion
; about. Six bytes here and the whole ground school out in UISEG (GNDSCH).
; ---- the avionics that are SWITCHES, not lamps ----------------------------
; Each of these changes how the war behaves, and each can be turned off. A
; box that only reports is decoration; these three make other people act.
swgnd   db 1                    ; G: ground comms. Friendly batteries shoot
                                ;  at whatever the pilot has locked, instead
                                ;  of at whatever is nearest to them
swair   db 1                    ; U: air comms. Friendly bots launch at the
                                ;  pilot's designated target
swiff   db 1                    ; I: IFF. Turn it off and your own side stops
                                ;  recognising you - the flak will engage you
swtr    db 1                    ; R: emissions. Down, and nobody sees you -
                                ;  including you: your own scope goes dark
; (the key-down edge bytes and the table that walks them moved to UISEG on
;  2026-07-30 - see SWKEYS there. Twelve switches written out longhand cost
;  a hundred and forty bytes of a segment that had ten. The FLAGS stay
;  here, because half the game reads them with DS pointing at this
;  segment; only the machinery had to leave.)
fuel    dw FUELMAX              ; remaining fuel (burn 1/tick)
rho     dw 256                  ; air density factor 64..256 (from altitude)
horiz   dw 100                  ; fixed view centre row (real pitch rotates
                                ; the world now; kept for projection maths)
pcos    dw 256                  ; cos(pitch)*256
throt   dw 42                   ; throttle 0..64 (start at 65%: full
                                ; military power outruns the AI jets)
cockpit db 1                    ; 1 = instrument panel shown (C toggles)
mapt    dw 123                  ; minimap top row (rises above the panel)
pimgo   dw 1                    ; cockpit bitmap in resseg (0 = none).
swspd   dw 360                  ; sway: phase step per tick (~10 s cycle)
swamp   dw 4                    ; sway: current amplitude, screen pixels

; ---- AI traffic: low-poly jets (see PLANES.INC) ----------------------------
NPLANE  = 40                  ; 20 v 20 (slot 0 never flies: that seat
                                ; is the player's - green team = you + 19)
; THE GHOST SLOT rides at index NPLANE on each of these arrays: the
; pilot's own jet, standing where he left her while he crews the Shilka.
; It exists for PLANESDRAW ALONE - the draw loop's bound is [pdlim], and
; only the render ever raises it past NPLANE; every AI walk, every
; missile and every gun stops at NPLANE and cannot so much as see it.
premote db NPLANE dup(0)        ; 1 = a REAL pilot flies this slot over
ghprm   db 1                    ;  the wire: the AI keeps its hands off
                                ;  (the ghost IS a human's jet: it gets
                                ;  the nameplate box at any range)
pdlim   dw NPLANE*2             ; PLANESDRAW's bound: the render raises
                                ;  it by one slot while the pilot rides
; ---- owner authority over life and death (the immortal-pilot fix) ----------
; A real pilot dies on HIS machine and nowhere else: our guns only send the
; hit over the wire, and his own POS packet says whether he is still flying.
; Before this, a shot-down human exploded locally and kept flying anyway -
; his next POS resurrected him one tick later (the Highlander bug 2026-07-27).
netdead dw 0FFFFh               ; plane the wire says is down
gbots   db 1                    ; 1 = the 20v20 war flies with us
rzsh    db 9                    ; radar zoom shift: 6 close .. 10 far. It
pspd    dw 15                   ; AI speed of the plane being ticked
mvb     dw F15VT                ; model table of the plane being drawn
mvn     dw F15NV*6              ; its vertex bytes (vertices * 6)
mfb     dw F15FC                ; its face table
nfc     dw F15NF                ; its face count
; ---- the ground radar stations: one per side, deep behind its line --------
; Slot 0 is OURS (south of the border), slot 1 is THEIRS (north). They are
; not aircraft: they never move, they turn only their dish, and each one
; is the eye of its own side - lose yours and the scope goes to snow.
NRSTA   = 2
RSHITS  = 8                   ; cannon hits it soaks (a jet takes 2..5)
RSPINV  = 3                   ; dish angle per tick: one turn in ~4.7 s
RSMDMG  = 4                   ; a missile is worth four shells: two level it
; A locked STATION rides in locki as 0FFF0h + index*2. Two things fall out
; of that encoding for free: 0FFFFh (no lock) is still no lock, and bit 1 -
; the parity every IFF test in the game already reads - comes out FRIENDLY
; for ours (0FFF0h) and HOSTILE for theirs (0FFF2h). Real plane offsets are
; 0..78, so anything at or above RSLK is a station and nothing else.
RSLK    = 0FFF0h
RSAPRON = 800                 ; how far off the runway centreline the mast
                                ;  stands. The strip is 150 half-width and
                                ;  the flattened patch reaches 1024 either
                                ;  way, so this is beside the concrete and
                                ;  still on the aerodrome's own flat ground
RSRAD   = 90                  ; its footprint, half-width. Wider than the
                                ;  dish (54) ON PURPOSE: a cannon round steps
                                ;  150 units a tick, so a box thinner than
                                ;  that can be jumped clean over between two
                                ;  samples - 180 deep cannot be
; ---- where the cockpit's three screens are, straight from the artwork ----
; Generated by TOOLS\Panel2Inc from res\cockpit2.png every build. It has to
; come in HERE, near the top: these are immediates, and a one-pass assembler
; wants them defined before the include that uses them. Move a screen in the
; picture and the instruments follow it - no coordinate is retyped by hand
; any more. PZRDR is the left screen, PZADI the centre, PZMAP the right;
; the names are historical, the middle one has not been an ADI for a while.
        include 'PANELZO.INC'
; The rest of the panel's furniture, measured off the converted bitmap by
; hand. These SHOULD be cyan markup zones in the artwork so Panel2Inc finds
; them too - it already reports every cyan blob it sees. Until the artist
; paints them, they live here and have to be re-measured if the picture
; moves. The digit row is the IAS/ALT/HDG/VERT strip under the centre
; screen; the two columns are the annunciator stacks at the panel's ends.
PZDIGY  = 193                 ; the seven-segment row, y. Two lower than
                                ;  it was: the pilot put printed SPD / ALT /
                                ;  HDG / G legends above the row when he
                                ;  retouched the panel, and the digits were
                                ;  crowding them
; ---- THE PANEL'S OWN COLOURS (DAC 108..112, set in PALDAY/PALNITE) --------
; NEVER take one of these out of 31..93: that range is the photo cockpit's
; palette and Panel2Inc re-cuts it from the artwork on every build. These
; five are hand-written and cannot move. They are also a long way dimmer
; than the HUD set, on purpose - the HUD is projected over a bright sky and
; has to shout; a panel is read off black plastic at arm's length.
PNLCAP  = 108                 ; the lamp captions
PNLDIM  = 109                 ; a legend that is not lit
PNLGRN  = 110                 ; a system is on / out
PNLAMB  = 111                 ; a caution
PNLRED  = 112                 ; a warning
; ...and the SHADED half of each, exactly three slots higher, so a lamp
; only has to know its bright colour and add three for its own shadow.
; A lamp on this panel is a round lens, not a square: lit at the top left
; and falling away to the bottom right, which is what makes four pixels
; read as something with a volume instead of a blob of colour.
PNLSHAD = 3                   ; core colour + this = its shadow
PNLGRN2 = 113
PNLAMB2 = 114
PNLRED2 = 115
PNLNOIS = 116                 ; the speckle on the annunciator glass. A
                                ;  black rectangle reads as a hole cut in
                                ;  the panel; a barely-lit one reads as
                                ;  glass with a lamp behind it
; The SCANLINE shade: a hair darker than the core, nothing like PNLSHAD.
; PNLSHAD is a lens's own curvature and is meant to be seen; this is the
; faint banding an old lit display has, and is meant NOT to be. Every
; fourth row at half brightness was a zebra; at a tenth it is a surface.
PNLBAND = 7                   ; core colour + this = its scanline
PNLGRN3 = 117
PNLAMB3 = 118
PNLRED3 = 119
; How fast the panel blinks, as a bit of the tick counter. 4 was twice a
; second and read as an alarm going off; 8 is once, which reads as a lamp
; that wants attention without shouting.
;
; This used to say "every blinking thing uses THIS so they all wink
; together - two rates would be chaos", and the ANNUNCIATOR no longer does:
; its ten slots carry their own phase and period (SPBPH/SPBMK in UI.INC).
; The old rule was right about rates and wrong about lamps - ten things
; moving in perfect lockstep read as one timer driving ten holes, which is
; what they were. Everything else on the panel still winks off this.
PNLBLNK = 8
PZDIG0  = 124                 ; IAS
PZDIG1  = 141                 ; ALT (five digits of room)
PZDIG2  = 164                 ; HDG
PZDIG3  = 182                 ; VERT
PZLCX   = 14                  ; left annunciator column: x and width
PZLCW   = 16
PZRCX   = 289                 ; right annunciator column
PZRCW   = 18
; The clear glass runs from under the overhead bank (row 17) to the top of
; the panel (row 121). Its middle is where the view belongs when the cockpit
; is up - see SETHORIZ. The screen's middle is row 100, which is nearly at
; the panel's edge.
PZGLASSC = 69
; The canopy bows lean 17 pixels across 60 rows on the artwork - 9/32, near
; enough. The speed and altitude tapes ride them: what leans is WHERE each
; tick and number sits, shifted along x by how far its row is from the
; tape's middle. The ticks themselves stay level, and so do the numbers -
; a 4x6 font cannot turn, and a real tape does not turn them either.
HBPIV   = 83                  ; the row the lean pivots about
HBLEAN  = 9                   ; ...and how hard, in thirty-seconds a row
; The overhead black plate between the two lamp clusters - the burner strip
; and the wire count share it, and PANELBMP draws AB ON last so the burner
; wins while it is lit. Raise or lower BOTH by moving these.
PZABX   = 151
PZABY   = 6
PZLAMPY = 129                 ; first lamp slot, five of them 10 apart
PZLAMPH = 10
PZTHRX  = 35                  ; throttle ladder. It used to stand at 38,
PZTHRY  = 176                 ;  where its right-hand pixels climbed onto
                                ;  the radar screen's bezel. Moved in beside
                                ;  the FLAPS/GEAR column, on the bare strip
                                ;  of metal that is actually free
PZTHRW  = 4                   ; ...and how wide a rung is: x 35..38, a
                                ;  pixel of air to the lamps (33) and to
                                ;  the radar screen's bezel (40)
; ---- the moving map ------------------------------------------------------
; The map fills the WHOLE centre screen now and it zooms. Two things made
; that easy, and both come from the world itself: it is 64x64 nodes, and it
; is a TORUS - every node index in this game is taken mod 64, so flying off
; the east edge brings you in from the west. A map window therefore never
; has an edge to bump into. It is centred on the jet, it wraps, and the
; pixels that used to be a grey margin are now the far side of the world.
; (It was 32x32 nodes at half scale, then 48x48 at three quarters, both
; nailed to the world's corners with the jet wandering about inside.)
PZMMX   = PZADIX0             ; the map IS the screen now
PZMMY   = PZADIY0
; Zoom steps. Step 0 is THE WHOLE WORLD - three pixels to four nodes - and
; it had to be added: the widest setting used to be one pixel a node, which
; on a 55-wide screen is 55 of the 64 columns, and reads as "I can only see
; part of it". The other three are 1, 2 and 4 pixels a node.
; The baked world is TWO pages in [scrseg], 4096 bytes each. The first is the
; map proper: every built block in its place. The second, at MMWIDE, is the
; same land with the towns generalised into CITIES - see MMAPGENF - and it is
; what the whole-world step reads, because at that scale a block is one pixel
; and a scatter of single pixels is not a map. The page costs nothing: scrseg
; is a whole 64K and only the first 4K of it was ever used (cpsseg is a full
; 64K above it, not 4K - see CPSLOADF).
MMWIDE  = 1000h
MMZN    = 4
MMZALL  = 0                   ; the index of the whole-world step
MMZICO  = 3                   ; ...and the step from which the MAP stops
                                ;  drawing marks and starts drawing the same
                                ;  symbols the scope uses. The CLOSEST step
                                ;  only. It was tried at 2 as well: a symbol
                                ;  is ten pixels wide and step 2 puts four
                                ;  pixels on a node, so a flight of bots came
                                ;  out as one long green chain instead of as
                                ;  aeroplanes. Eight pixels a node gives them
                                ;  room to be read one at a time
; How far the radar scope reaches, in pixels from its centre. It was a flat
; 14 everywhere - sized to a 36-row screen that no longer exists - and the
; grey range rose was worse, drawn at a hardcoded 87,171. Now the frame is
; carried in rbcx/rbcy/rbrad and every piece of scope furniture reads it:
; the blips, the missile sparks, the ground-radar crosses, the range rose
; and the snow. Three rows of margin keep a blip's own shape on the glass.
PZRDRR  = (PZRDRH-6)/2
PZADIR  = (PZADIH-6)/2
RSTOP   = 190                 ; and how high the mast and dish reach
; ---- the Shilkas: three a side, over the lines they cover -----------------
; Slots 0..2 are OURS (south of the border), 3..5 THEIRS. The vehicles have
; no state words HERE - it all lives in UISEG beside the code that owns it
; (see SHKINIT in UI.INC) - but the COUNT is an immediate, and a one-pass
; assembler wants those before the include that uses them.
NSHILK  = 20                  ; ten a side. Their job is to cover the
                                ;  radar and the cities, so they are laid
                                ;  out in two belts per side: one forward
                                ;  over the towns, one back over the mast
; Ground a vehicle can actually STAND on. WORLDH gives 0 for anything at or
; below sea level and climbs at 5 a unit, doubling past 560 - so a height of
; zero IS water, and anything over GNDHI is the steep stuff. A radar station
; floating on the sea was the old behaviour and it looked exactly as silly
; as it sounds.
GNDLO   = 20                  ; above the waterline by a real margin
GNDHI   = 430                 ; and below the mountains
; A locked SHILKA rides in locki as SHKLK + index*2, the trick the stations
; play one shelf up. Plane offsets are 0..78 and stations 0FFF0h..0FFF2h, so
; a single compare sorts all three - and bit 1, the parity every IFF test in
; this game already reads, comes out FRIENDLY for an even slot and HOSTILE
; for an odd one. That is why they are interleaved by side (see SHKPX in
; UI.INC): it buys the whole IFF for free.
;
; SHKLK IS DERIVED, and it has to be. It was written down as a literal
; 0FFE0h when there were six Shilkas, which left room for eight; the day the
; flak went to twenty, locking number eight started decoding as a radar
; STATION (and past number nine as a read off the end of a two-entry array),
; and locking number sixteen wrapped past 0FFFFh into PLANE ZERO -
; the pilot's own aeroplane. F4 then orbited the player, who is not drawn in
; that view, and the scope's Shilka "vanished". Nothing here may be a typed
; constant again: the shelf is measured from the one above it.
SHKLK   = RSLK - NSHILK*2
if SHKLK <= (NPLANE*2)
        %OUT *** the Shilka lock shelf has grown down into plane offsets ***
        .ERR
end if
if (SHKLK AND 2) <> 0
        %OUT *** SHKLK must be even-parity: the IFF reads bit 1 of the lock ***
        .ERR
end if
SHKTOP  = 18                  ; how high the vehicle stands, in engine
                                ;  units - aim at half of it, the turret
SHKHITS = 4                   ; cannon shells it soaks before it burns
SHKMDMG = 4                   ; and a missile is worth all four
SHKRAD  = 90                  ; the HIT box, half-width - and the vehicle
                                ;  is only 50 across, so this is deliberately
                                ;  too big. A cannon round steps ~150 units
                                ;  a tick: a box thinner than the step is
                                ;  jumped clean over between two samples,
                                ;  which is why RSRAD is 90 as well. It is
                                ;  the difference between a target and a
                                ;  thing you empty the guns at for nothing.
SHKHBOX = 120                 ; ...and how high that box reaches
SHKGRNG = 3200                ; how far its guns reach: inside this it
                                ;  tracks, and a high pass stays safe
SHKTRAV = 4                   ; turret slew, of 256 a tick - about seven
                                ;  seconds for a full turn. THE LAG IS THE
                                ;  CHARACTER: a mount that snaps onto you is
                                ;  a turret, one you can out-turn is a Shilka
SHKDSPN = 3                   ; and the RADAR turns steadily on its own,
                                ;  a full sweep in about five seconds - that
                                ;  is the part that spins, not the guns.
                                ;  (7 - two seconds a turn - read as FRANTIC
                                ;  on the phosphor scope, 2026-08-28)
SHKELEV = 3                   ; barrels rise this fast, of 256 a tick
SHKELMX = 56                  ; ...and no higher than about 78 degrees:
                                ;  straight overhead is the one place a
                                ;  Shilka cannot reach, and a pilot who
                                ;  finds that out has earned the pass
SHKTRNY = 10                  ; the TRUNNION, in model units: where the
SHKTRNZ = 5                   ;  barrels are bolted to the drum
; ---- THE GUNNER'S SEAT ----------------------------------------------------
SHKEYE  = 13                  ; his eye, in engine units above the tracks.
                                ;  The drum's roof is 12 and the radar mast
                                ;  reaches 19, so 13 is a head at the hatch.
                                ;  It was SHKTOP+10 = 28 - two metres above
                                ;  the dish, a seat floating over its own
                                ;  vehicle
SHCABHZ = 58                  ; ...and where the horizon belongs on his
                                ;  glass. The cabin artwork's window runs
                                ;  rows 10..106, so its middle is 58 - the
                                ;  same rule PZGLASSC follows for the jet.
                                ;  The seat held 100, which is the bottom
                                ;  EDGE of that window: the whole cabin was
                                ;  sky
; ---- and the short lens the barrels are drawn through ---------------------
; NEARZ is 40 units and the whole vehicle is 34 long, so every face of the
; Shilka a gunner sits in - hull, drum, dish, barrels - lies inside the near
; plane and is clipped away before it is ever projected. The guns cannot be
; rendered by the world's lens at all. SHKBRL projects the SBARR model on
; its own instead: no yaw (the drum's bearing IS the way the camera looks),
; no near clip (nothing here can reach the eye), and an eye of its own.
BRLEYD  = 24                  ; how far behind the trunnion that eye sits
BRLEYH  = 6                   ; ...and how far above it. The pair is chosen
                                ;  so the muzzles cross the window from row
                                ;  89 at zero elevation to row 23 at the
                                ;  mount's stop: the whole sweep is IN the
                                ;  frame, which is the point of the exercise
BRLEX   = 3                   ; and on the GUNS' axis, not the hull's: the
                                ;  mount stands three units right of the
                                ;  centreline (a real Shilka's does), and
                                ;  0.6 m of parallax is under a pixel at any
                                ;  range worth firing at. Drawn on the hull's
                                ;  axis the guns would sit off to one side of
                                ;  the very shells they fire
BRLNZ   = 4                   ; the divide's floor. This geometry cannot get
                                ;  nearer than about twenty, but a fixed-point
                                ;  divide that COULD is a hang, not a glitch
BRLFLIP = 20                  ; past this elevation the muzzles are above the
                                ;  eye and the six faces are painted the other
                                ;  way about - about 28 degrees, where the
                                ;  barrel axis crosses the lens
; ---- driving and shooting -------------------------------------------------
SHKSPD  = 3                   ; world units a tick: a crawl, on purpose.
                                ;  It is not the war, it is scenery that
                                ;  shoots - and a gun that repositions fast
                                ;  is a gun you can never plan around
SHKSTR  = 2                   ; how fast the hull comes round, of 256
SHKLSH  = 1400                ; how far it will stray from its post before
                                ;  it turns back. It PATROLS; it does not
                                ;  wander off and leave the city open
SHKLEG  = 90                  ; ticks on one leg before it picks a new one
SHKFRAT = 8                   ; ticks between bursts - about two a second
SHKAPER = 5                   ; how closely the mount must be on the mark
                                ;  before it fires, in compass units. This
                                ;  is the whole difference between a gun
                                ;  that hoses the sky and one that aims
SHKHITC = 1                   ; the dice: 1 of 2 bursts connects, against
                                ;  the AI's 1 of 4. He asked for accurate
; ---- THE AERODROMES -------------------------------------------------------
; Four strips, interleaved by side the way everything else in this game is:
; an EVEN slot is ours, an ODD one theirs, so the parity that already carries
; IFF everywhere carries it here too. They stand back from the front line on
; the same x = 24576 spine the squadrons form up on, two either side.
;
; The runway runs NORTH-SOUTH, along z. That is not decoration: ours point
; at the enemy, so a sortie rolls out of the blocks already facing the war,
; and the takeoff heading is 0 with nothing to work out.
;
; A strip is FLAT because the heightmap says so - AFINITF stamps its nodes
; to one value right after DSGEN, before the block table or the minimap are
; baked off it. The mesh, TERRH, the road walk and the collision test then
; all agree about the concrete for free, with no special case anywhere. And
; the value is forced into the PLAINS band, below the city: no block whose
; centre lands on a runway can ever be zoned built-up, so nothing grows on
; the aerodrome without a line of code to prevent it.
NAF    = 4
AFHLO  = 96                  ; the band a strip's height is clamped into -
AFHHI  = 116                 ;  inside 88..119, which is plain grass
AFNW   = 2                   ; the patch AFPATCH JUDGES, in heightmap
AFNL   = 4                   ;  NODES: 2 x 4 = 2048 x 4096 world units
AFSW   = 5                   ; ...and the patch AFINITF actually IRONS.
AFSL   = 7                   ;  TERRH does not read A node, it INTERPOLATES
                               ;  the four around the point - so ironing only
                               ;  the judged patch left every height under
                               ;  the concrete a blend of flat runway and the
                               ;  hill just past its edge. The strip was never
                               ;  level: it read 250-odd on the altimeter
                               ;  where the stamped value says 140 at the very
                               ;  most, and it sloped.
                               ;  THE SIZES ARE DERIVED, NOT PADDED. The
                               ;  concrete reaches AFW=150 in x and AFLEN=1500
                               ;  in z from the centre; a node is 1024. Worst
                               ;  case the centre sits hard against a node
                               ;  edge, so x touches nodes -1..+1 and needs
                               ;  -2..+2 for their interpolation partners,
                               ;  and z touches -2..+2 and needs -3..+3.
                               ;  Judging stays on AFNW x AFNL, so nothing
                               ;  about WHERE a field may stand has changed;
                               ;  ironing more ground can never hurt.
                               ;  WANTS EYES: this is a 5x7-node plateau now,
                               ;  5120 x 7168 units, four of them in a world.
AFLEN  = 1500                ; the concrete itself, half-length along z...
AFW    = 150                 ;  ...and half-width across it
AFSEG   = 6                  ; slabs the strip is laid in - see AFDRAWF for
AFSEGD  = AFLEN/AFSEG        ;  why it is not one, and why 250 is the size
AFVIS   = 6000               ; BOND: 6000, not 12000 - a strip far off is
                               ;  a few pixels and a dozen projections.
                               ; v3: how far the concrete is drawn, on EITHER
                               ;  axis. At this range a strip is five pixels
                               ;  across; nearer than this the quads are
                               ;  small enough that all four corners of one
                               ;  clamp together and go off-glass as a unit,
                               ;  which is the difference between a runway
                               ;  that vanishes politely and one that fills
                               ;  the windscreen
                               ;  NOT "AFZ": TASM folds case and that is the
                               ;  afz array two dozen lines down
AFPAINT = 8                  ; the markings: white, the way they are white
AFEDGE  = 12                 ; the edge lines, half-width...
AFCTR   = 8                  ;  ...the centreline...
AFTHR   = 60                 ;  ...and the threshold bar, half-depth
AFSEA  = 92                  ; no corner of a strip may sit this low...
AFTOP  = 190                 ;  ...and none of it this high
AFREACH = 12                 ; how far the siting walk may go, in NODES.
                               ;  Measured, not guessed: twelve places all
                               ;  four fields in every one of forty test
                               ;  worlds, six leaves one placement in
                               ;  thirteen with nowhere to stand, and the
                               ;  fixed sites the stations use put a THIRD
                               ;  of the aerodromes in the sea or up a hill
; ---- THE APRON: the hangars and the tower (AFBLD, in TOWN.INC) -------------
; All of it stands on the +x side, the same side the mast does, so a field
; reads as ONE place with a near side and a far side rather than a strip
; with clutter scattered round it. The scale is the airframe's own: the F-15
; model is 26 units across the wings against 13 metres of real span, so a
; unit is HALF A METRE and every figure below is a real dimension halved.
;
; Everything here has to sit inside the patch AFINITF ironed flat - 1024
; either way in x, 2048 in z - or a building stands on a slope it was never
; levelled for. The furthest thing out is the tower cab at 360, and the
; longest reach along the strip is a hangar at 690. Both are well inside.
AFAPX   = 620                ; the apron: how far off the centreline the
                               ;  hangars stand. Clear of the concrete
                               ;  (AFW=150) and short of the mast (RSAPRON
                               ;  =800), which parks the row between them
AFHGN   = 3                  ; three hangars...
AFHGS   = 620                ;  ...this far apart along the strip
AFHGW   = 90                 ; one of them: half-width across the apron,
AFHGD   = 70                 ;  half-depth along it, and 23 metres tall -
AFHGH   = 46                 ;  a fighter shed, not an airliner's
AFTWX   = 330                ; THE TOWER STANDS CLOSER IN AND WELL DOWN THE
AFTWZ   = 900               ;  FIELD, abeam the touchdown point rather than
                               ;  at midfield: it is the thing you have in the
                               ;  corner of your eye on short finals, and that
                               ;  is the whole reason to put a landmark beside
                               ;  a runway at all
AFTWW   = 16                 ; the shaft, half-width...
AFTWH   = 96                 ;  ...and 48 metres of it
AFTCW   = 30                 ; the cab OVERHANGS the shaft, the way a real
AFTCH   = 26                 ;  one does - it is how a tower reads as a
                               ;  tower and not as a chimney
AFBWL   = 0                  ; the paint: the greys the mast already wears,
AFBWS   = 16                 ;  lit face and shaded face...
AFBRF   = 17                 ;  ...and the roof
AFTGL   = 20                 ; the cab is GLASS, and it is the only glass on
                               ;  the field. No window lattice runs on any of
                               ;  this: EDGEWIN wants bhw>=50 AND 60 units of
                               ;  wall, and every box here misses one or the
                               ;  other. The hangars are too flat and the
                               ;  tower too thin, which is exactly right -
                               ;  a city window grid on a hangar would read
                               ;  as an office block parked on the grass
rsx     dw 0,0                  ; where each station stands
rsy     dw 0,0                  ;  (rsy = the ground under its feet)
rsz     dw 0,0
rsst    db 0,0                  ; 0 = standing, 1 = down
rshp    db 0,0                  ; hits it still has in it (a building, not a jet)
airng   dw 10000                ; how far the AI may shoot: its own radar
                                ;  down and it is 2500, eyeball range
; The F4 orbit camera used to sit a flat 100 units out, which is four
; wingspans from a jet and INSIDE a Shilka - the vehicle is 100 long by
; itself. Worse, at that distance the camera lands a few dozen units above
; the ground and any rise between it and the target swallows it: that is
; the "camera appears somewhere odd" on a ground target. It is a variable
; now, set by what is being orbited, and Z/X move it while you watch.
tgrad   dw 100                  ; how far the orbit camera stands off
TGRMIN  = 70                  ; ...and how close or far it may be wound
TGRMAX  = 2400
tgzo    dw 75                   ; TGT page: stand-off and vertical centre
MSGNORAD db 'NO RADAR',0        ; the legend under the snow
TYPN1   db 'BOMBER',0
TYPN2   db 'RADAR',0
TYPN3   db 'TRANSP',0
TYPN4   db 'TANKER',0
TYPTAB  dw TYPN0,TYPN1,TYPN2,TYPN3,TYPN4
; ---- the fighter: BAKED at build time from res\F15.OBJ by Obj2Inc ----------
; (TOOLS\Obj2Inc, C# - the tooling contract). 23 verts, 14 faces, the
; twin-tail. Its first 13 vertices keep the CLASSIC meanings - nose,
; rear box, wingtips, roots, left fin - because the wreck pool below
; cuts its debris from the classic MFACE over exactly those.
        include 'F15M.INC'
; ---- the ground radar station, baked the same way from res\RBASE.OBJ and
; res\RDISH.OBJ: a lattice tower and a SIX-panel dish. Six, not the eight
; the trainer's dish has - this world is cut from flat chunks and a smooth
; bowl read as a foreign object (user's call, 2026-07-28). Both stand at
; the station's feet: the tower spans y 0..40, the dish y 26..58, so one
; position draws both and the dish alone takes the spin.
        include 'RDISHM.INC'
; ---- the ZSU-23-4 "Shilka", baked from res\SHULL.OBJ and res\STURR.OBJ.
; Two models, one vehicle, the station's trick again: the CHASSIS on the
; driving heading and the TURRET on its own, both drawn at the same world
; point by MODELDRAW. 18/14 and 25/15 against the engine's 25/16 - the
; turret is FULL, so anything added to it has to buy its vertices back.
; Both span y 0..54 in engine units (hull deck 21, turret roof 36, the top
; of the Gun Dish 54), so one ground height draws the whole vehicle.
;
; These tables are the ONLY part of the Shilka that lives in the main
; segment, and they have to: MODELDRAW reads them through DS, and DS is
; the main segment even out in UISEG. Everything that merely computes -
; the sites, the state, the tick and the draw loop - is in UI.INC.
; the classic eight faces, kept ONLY for the wreck pool (see above)
MFACE   db 0,1,2,0, 24          ; body top (sun-lit white)
        db 0,3,4,0, 16          ; body bottom (shade)
        db 0,1,3,0, 25          ; body left
        db 0,2,4,0, 25          ; body right
        db 7,5,8,7, 0           ; wing L (light grey)
        db 7,6,9,7, 0           ; wing R
        db 10,11,12,10, 25      ; tail fin
        db 1,2,4,3, 94          ; engine nozzle: palette-cycled fire
NFACE   = 8
GLOWT   db 63,52,12             ; nozzle DAC cycle: yellow
        db 63,34, 6             ; orange
        db 56,14, 4             ; red
        db 63,34, 6             ; orange again (smooth loop)
; ---- the rest of the air force: variable geometry per type ----------------
; Each type has its own vertex table (mvb/mvn) and face table (mfb/nfc).
; The FIRST 13 vertices and 8 faces are always the core airframe with the
; standard topology - the wreck pool breaks exactly those, so pods and
; domes simply vanish in an explosion (nobody mourns a nacelle).
MVTAB   dw F15VT,MVERT1,MVERT2,MVERT3,MVERT4
MVNTAB  dw F15NV*6,25*6,19*6,13*6,19*6
MFTAB   dw F15FC,MFACE1,MFACE2,MFACE,MFACE4
NFCTAB  dw F15NF,12,10,8,10
MVERT1  dw   0,  1, 34          ; BOMBER: long, four engines on the wings
        dw  -5,  5,-22
        dw   5,  5,-22
        dw  -5, -4,-22
        dw   5, -4,-22
        dw -28,  1, -6
        dw  28,  1, -6
        dw   0,  1, 10
        dw  -5,  1,-20
        dw   5,  1,-20
        dw   0,  5,-10
        dw   0, 13,-26
        dw   0,  5,-22
        dw -10,  0,  6          ; 13..15 engine pod, inner left
        dw -10,  0, -2
        dw -10, -4,  2
        dw -19,  0,  2          ; 16..18 outer left
        dw -19,  0, -6
        dw -19, -4, -2
        dw  10,  0,  6          ; 19..21 inner right
        dw  10,  0, -2
        dw  10, -4,  2
        dw  19,  0,  2          ; 22..24 outer right
        dw  19,  0, -6
        dw  19, -4, -2
MFACE1  db 0,1,2,0, 24          ; the core 8 (exactly MFACE)...
        db 0,3,4,0, 16
        db 0,1,3,0, 25
        db 0,2,4,0, 25
        db 7,5,8,7, 0
        db 7,6,9,7, 0
        db 10,11,12,10, 25
        db 1,2,4,3, 94
        db 13,14,15,13, 16      ; ...and four dark engine slabs
        db 16,17,18,16, 16
        db 19,20,21,19, 16
        db 22,23,24,22, 16
MVERT2  dw   0,  2, 20          ; RADAR: fat body, the rotodome on top
        dw  -4,  5,-14
        dw   4,  5,-14
        dw  -4, -3,-14
        dw   4, -3,-14
        dw -18,  2, -2
        dw  18,  2, -2
        dw   0,  2,  6
        dw  -4,  2,-12
        dw   4,  2,-12
        dw   0,  5, -6
        dw   0,  9,-14
        dw   0,  5,-14
        dw   0, 10,  2          ; 13..16 the dome: a horizontal diamond
        dw   4, 10, -4
        dw   0, 10,-10
        dw  -4, 10, -4
        dw   0, 12, -4          ; 17 dome top
        dw   0,  8, -4          ; 18 dome bottom
MFACE2  db 0,1,2,0, 24
        db 0,3,4,0, 16
        db 0,1,3,0, 25
        db 0,2,4,0, 25
        db 7,5,8,7, 0
        db 7,6,9,7, 0
        db 10,11,12,10, 25
        db 1,2,4,3, 94
        db 13,14,15,16, 24      ; the dome disc, sun-lit
        db 13,17,15,18, 16      ; the dome lens, shaded
MVERT3  dw   0,  2, 18          ; TRANSPORT: fat and slow
        dw  -5,  6,-14
        dw   5,  6,-14
        dw  -5, -4,-14
        dw   5, -4,-14
        dw -20,  3, -2
        dw  20,  3, -2
        dw   0,  3,  6
        dw  -5,  3,-12
        dw   5,  3,-12
        dw   0,  6, -6
        dw   0, 12,-16
        dw   0,  6,-14
MVERT4  dw   0,  2, 26          ; TANKER: the fat fuel truck, two engines
        dw  -7,  7,-18
        dw   7,  7,-18
        dw  -7, -5,-18
        dw   7, -5,-18
        dw -22,  2, -4
        dw  22,  2, -4
        dw   0,  2,  8
        dw  -7,  2,-16
        dw   7,  2,-16
        dw   0,  7, -8
        dw   0, 13,-20
        dw   0,  7,-18
        dw -11,  1,  6          ; 13..15 engine left
        dw -11,  1, -2
        dw -11, -4,  2
        dw  11,  1,  6          ; 16..18 engine right
        dw  11,  1, -2
        dw  11, -4,  2
MFACE4  db 0,1,2,0, 24
        db 0,3,4,0, 16
        db 0,1,3,0, 25
        db 0,2,4,0, 25
        db 7,5,8,7, 0
        db 7,6,9,7, 0
        db 10,11,12,10, 25
        db 1,2,4,3, 94
        db 13,14,15,13, 16
        db 16,17,18,16, 16
; ---- the second joint: PITCH, applied before the yaw ----------------------
; A model used to be able to yaw and nothing else, which is why gun barrels
; could not elevate. MODELDRAW now turns each vertex about a TRUNNION first
; - a point on the parent's own body - and then yaws the result, so a barrel
; group rides its turret round AND tilts at the joint. One more angle, at
; the place a real mount has one. Off by default: [mpon] gates it, and
; everything that is not a gun pays two MOVs a vertex for the privilege.
mpcs    dw 256
; THE TURRET's scratch, and it is called trn* for a reason. It was mtpy /
; mtpz / mtvy / mtvz, one letter from the MISSILE's mpy / mpz / mvy / mvz,
; and MSLUPD had picked up the wrong four: it flew a dumb-fired missile on
; the turret's vertex scratch as its vertical and z velocity, drew the
; exhaust puff off the trunnion, and stamped the missile's last position
; into the turret's geometry every tick it was in the air. It assembled
; silently because both sets exist. Names one letter apart, in one file,
; for two unrelated things - now they are not.
TLN     = 12                  ; contrail points per plane
; TLX/TLY/TLZ live in BSS now (see OWLFLY3.ASM): spawn-generated, and the
; segment budget is too tight to ship 3.8K of zeroes in the image
locki   dw 0FFFFh               ; locked plane (0FFFFh = no lock)
; ---- the scope's symbols ---------------------------------------------------
; A contact is an AEROPLANE now, not a square or a diamond: three lines -
; fuselage, wing, tailplane - swung to the target's heading relative to
; ours. Lines, not sprites, because a sprite would have to be held at
; sixteen angles and this engine turns things with SINQ for a living.
; The COLOUR is the side and nothing else. It used to go white for a human,
; which threw away the one thing a pilot needs from a blip - whose side is
; it - and humans take sides here like everyone (they land in plane slots
; 36..39, and this game reads allegiance off the slot's parity, so joiners
; alternate teams by themselves). A human is flagged by a pip over the
; symbol instead, which adds information rather than replacing it.
; How much symbol a contact gets. THE ZOOM DECIDES, for the whole scope at
; once - not each contact by its own range. Zoomed in, the glass is a
; picture of a fight and every mark is worth a shape; zoomed out it is a
; picture of where people ARE, and forty little aeroplanes is noise. The
; symbol is not to scale and never was: it says which way he is pointing
; and roughly how far, relative to the others. That is all a pilot has
; time to read.
BQZHOUS = 7                   ; and at THIS zoom or closer, the ground
                                ;  itself: the city, cell by cell. Only the
                                ;  two tightest settings - there is no list
                                ;  of buildings to walk, every cell has to
                                ;  be asked, and at the widest zoom the
                                ;  scope covers eighty cells each way
BQZICON = 8                   ; at this zoom or closer: aeroplanes
BQZCROS = 9                   ; at this one: crosses. Beyond: dots.
rbrad   dw PZRDRR               ; ...and how far it reaches, in pixels. Kept
rbradn  dw -PZRDRR              ;  negated too: the clip is two compares in
                                ;  the hottest loop on the panel, and a NEG
                                ;  per blip per frame buys nothing
; callsign names: friendly and hostile pools (4x6 font, A-Z only)
FNAM0   db 'VIPER',0
FNAM1   db 'EAGLE',0
FNAM2   db 'HAWK',0
FNAM3   db 'STORM',0
HNAM0   db 'BANDIT',0
HNAM1   db 'COBRA',0
HNAM2   db 'RAPTOR',0
HNAM3   db 'VULTUR',0
FNTAB   dw FNAM0,FNAM1,FNAM2,FNAM3
HNTAB   dw HNAM0,HNAM1,HNAM2,HNAM3
MSGTGT  db 'TARGET',0
MSGFRD  db 'FRIEND',0
MSGGUN  db 'GUN',0              ; the right MFD status rows
MSGMSL  db 'MSL',0
MSGDAM  db 'DAM',0
MSGSIT  db 'SIT',0              ; the centre MFD page furniture
MSGNOT  db 'NO TGT',0
MSGRNG  db 'RNG',0
; wireframe edge list for the MFD sensor view (vertex id pairs)
WEDG    db 0,1, 0,2, 0,3, 0,4, 1,2, 3,4, 1,3, 2,4
        db 7,5, 5,8, 8,7, 7,6, 6,9, 9,7
        db 10,11, 11,12, 12,10
NWEDG   = 17
; ---- missiles and wrecks ----------------------------------------------------
pst     db NPLANE dup(0)        ; plane state: 0 = flying, else respawn timer
ghpst   db 1                    ; the ghost slot's state: dead until the
                                ;  render arms it (see pdlim in the pax
                                ;  block - only PLANESDRAW looks here)
pammo   db 4                    ; player missiles on the rails
mstgt   dw 0FFFFh               ; homing target (plane offset)
; ---- THE PLAYER'S FOUR RAILS ----------------------------------------------
; Everything above is ONE missile, and for a long time that is all the pilot
; had: four on the rails and no way to put a second one in the air until the
; first died, up to fifteen seconds later. In a fight that is not a weapon,
; it is a wait - which is exactly the moment you need the second missile.
;
; The pool is held HERE, and the eleven words above are the WORKING SET. A
; slot is loaded into them, the existing code runs on it untouched, and it
; is written back: MSLLOAD / MSLSAVE. That is deliberate. The homing, the
; proximity fuse, the detonation and the smoke are sixty-odd accesses of
; delicate arithmetic; rewriting every one of them to carry an index is how
; you introduce three new bugs while fixing one. The bodies did not change
; by a single instruction.
; The pool itself lives OUT in SYMSEG with the loops that walk it - it is
; ninety-six bytes of array and the main segment had a hundred and eleven.
; Only these two words stay home, because MCEND reads them.
NPMSL   = 4
; ---- AI missile pool (the war fights itself) --------------------------------
NAMSL   = 4
aifire  dw 90                   ; cooldown until somebody opens fire
aigt    dw 60                   ; cooldown until somebody strafes
; ---- tick interpolation: physics is 18.2 Hz, frames are faster ----
MSGM2   db 'M',0
spklc   dw 7                    ; the noise generator (a small LCG): the
                                ;  square wave's only way to sound broken
RDRMAP  = 0F000h              ; the radar tube's PHOSPHOR: a 64x64 charge
                                ;  map (4K) on the top shelf of the cabin's
                                ;  far page. The art blob is ~42K and the
                                ;  loader's read is capped below this, so
                                ;  the shelf cannot be loaded over. Charge
                                ;  15 = the beam's head, 0 = dark glass;
                                ;  UI.INC writes it, SYMSEG:RDRPHOSF decays
                                ;  and paints it
; ---- the Shilka's OWN side consoles (F6/F7 from the seat, 2026-08-30) ----
; Two RLE streams in SIDEBMPF's grammar, baked by TOOLS\Cab2Dat from
; res\shilka_left/right.png (SHSIDE.DAT, or the marker bake the card
; wears). There is no free 64K page left - the cabin page is the last one
; under the 640K ceiling - so each stream rides a TAIL somebody else's
; page was not using: the left below the phosphor shelf on the cabin page
; (the blob ends at 0A466h), the right in scrseg past the retro card bake
; (which ends at 9D00h). Cab2Dat measures both and refuses to emit a
; stream its shelf cannot hold, because a loader trusting a fat file
; would write over the phosphor or the jet's own side art.
SHSLOFF = 0A800h              ; the LEFT stream, on the cabin page
SHSROFF = 0A000h              ; the RIGHT stream, in scrseg
MSGP2   db 'P',0                ; the pause letter on the panel
TAPSC   db 48h,50h,4Bh,4Dh,11h,1Fh,39h
                                ; their scancodes, GAMELOOP walks both
sndmod  db 2                    ; 2 = all sounds, 1 = effects only
MSGS3   db 'S',0                ; panel sound-mode letter
; ---- THE FRONT DOOR IS THE WAR. Arrive at a sky somebody is already
; flying and you do not read a list, you watch: the orbit camera stands off
; whoever is in the fight, Space walks to the next one, and it moves on by
; itself if you do not. Enter takes a jet.
;
; It is a STATE OF THE RUNNING GAME, not a screen of its own - the wire, the
; blit, the clock and the render all carry on exactly as they do in flight,
; and the panel is already skipped whenever tgtcam is up. That is the whole
; reason this is small: the camera it needs was written for F4.
SPTIME  = 273                 ; ...which is fifteen seconds at 18.2 Hz
tgspare dw 0FFFFh               ; the first living jet the walk saw, for when
                                ;  no human is up (0FFFFh = it saw none)
tgel    dw 12                   ; orbit elevation (-30..56)
MSGGO   db 'GAME OVER',0
MSGPS2  db 'PRESS SPACE',0
; ---- the ramp prompt (RAMPTXT). Centred by hand at 4 px a character on a
; 320-wide screen: ftx = 160 - 2*length.
MSGBRK  db 'BRAKES ON',0        ; 9 chars  -> 142
MSGBRK2 db 'PRESS B TO RELEASE',0 ; 18     -> 124... 110 leaves it clear of
                                ;  the left annunciator column
MSGBRK3 db 'W THROTTLE  A BURNER',0 ; 20   -> 120
bhpc    dw 4 dup(0FFFFh)        ; wounded buildings: cell keys
MASK8   db 1,2,4,8,16,32,64,128 ; bit masks for the ruins bitmap
MSGVWIN db 'VIPERS WIN',0
MSGBWIN db 'BANDITS WIN',0
php     db NPLANE dup(3)        ; hit points: 2..5 cannon hits to down
gunam   dw 250                  ; cannon rounds
hitfx   dw 0FFFFh               ; plane flashing from a cannon hit
NTRC    = 4                   ; tracer rounds in the pool. BOND: 4, not 16 -
                                ;  a power of two still (the ring ANDs it)
GBUF    db ' 1.0G',0            ; the G readout scratch
        include 'SFXIDX.INC'   ; SFXN and the SFX_* indices, from Snd2Dat
BONDMEM db 'OWL FLY III BOND needs 256K free',13,10,'$'
; BOND: the line clipper's rectangle (ENGINE\E_RAST.INC reads these when
; they exist). Full screen here; SKYGNDF narrows it to the small window on
; the world for a cockpit frame, VPANELF/VBLITF open it again.
clipx1  dw 319
clipy1  dw 199
; (F15FN/MHDR gone: the model is baked into the image at build time)
; ---- Ctrl+D: the diagnostic marks. OFF by default, and that is the point -
; the stage square and the render bar are instruments for catching a freeze,
; and an instrument that is always on the glass stops being an instrument and
; becomes clutter a player has to learn to ignore.
daymode db 1                    ; 1 = day palette, 0 = night (N key toggles)
pmrow   dw -9999                ; MKPATT: the row its anchor was cut for
hcur    dw 100                  ; the horizon pivot: row, column, and the
cx0     dw 160                  ; frame's roll pair (copied from rsin/rcos)
cosr    dw 256
; ---- LADR: the pitch ladder's walkers (code in HUD.INC) --------------------
LBUF    db '   ',0              ; ladder label scratch
; mountain / megablock work

; ---- Diamond-Square world heightmap (the CityGame terrain generator) -------
; 64x64 nodes on a TORUS (indices wrap &63) -> seamlessly tiles our toroidal
; 256-cell world: 1 node = 4x4 cells. Generated once at startup by DSGEN.
rseed   dw 21845                ; LCG state (re-seeded from the clock at boot)
; HMAP lives in the BSS block past the file image (see OWLFLY3.ASM); the baked
; minimap moved out to the far scratch segment [scrseg] to free 4K of BSS.

; ---- 3D terrain mesh state (one node = 4 cells = 1024 world units) ---------
NR      = 20                  ; terrain draw radius in nodes around camera
NSIDE   = 41                  ; cached node grid side (2*NR+1)
scol    db 3                    ; stroke colour for the current building
PUFO    dw 0,21,42              ; smoke puff phase offsets (loop of 64)

; building draw order: v3 sorted every cell in [-24..24]^2 by squared
; distance DESCENDING (painter far -> near), 2401 of them. The BOND walks
; only the nearest BONDCELLS, so only the tail of that list is kept: the
; same cells in the same far-to-near order, 4.4K less in the file.
BORD    db 8,1, 1,8, 8,-1, 8,0, 0,8, -8,0, 0,-8, -5,6, 5,6, 5,-6
        db -5,-6, 6,5, -6,-5, -6,5, 6,-5, 7,-3, -3,7, 7,3, -7,-3, 3,7
        db -3,-7, -7,3, 3,-7, 7,2, 2,7, -7,2, -2,7, -7,-2, 7,-2, 2,-7
        db -2,-7, -4,-6, 6,-4, -4,6, 4,6, 6,4, -6,-4, -6,4, 4,-6, -1,7
        db 1,-7, -7,1, -5,5, -1,-7, 1,7, 5,5, 5,-5, -5,-5, -7,-1, 7,-1
        db 7,1, 7,0, 0,-7, 0,7, -7,0, 3,6, -6,3, 3,-6, -3,-6, 6,-3
        db -6,-3, -3,6, 6,3, 5,-4, -4,5, -5,4, 4,-5, -5,-4, 4,5, 5,4
        db -4,-5, -6,2, -6,-2, -2,6, 2,6, 6,-2, -2,-6, 6,2, 2,-6, -1,6
        db -6,-1, 6,1, 1,6, 6,-1, -1,-6, -6,1, 1,-6, -6,0, 0,6, 6,0
        db 0,-6, -3,5, 5,3, -5,3, -3,-5, 3,-5, 5,-3, 3,5, -5,-3, -4,4
        db -4,-4, 4,4, 4,-4, 2,5, -2,5, 2,-5, -5,-2, -5,2, 5,2, 5,-2
        db -2,-5, 5,-1, 5,1, -1,-5, 1,5, -5,1, -5,-1, 1,-5, -1,5, -4,3
        db -4,-3, 4,3, 0,5, 0,-5, -3,4, -3,-4, 5,0, -5,0, 3,-4, 4,-3
        db 3,4, 2,-4, 4,-2, -4,2, -4,-2, -2,-4, 4,2, 2,4, -2,4, -3,-3
        db 3,-3, -3,3, 3,3, -1,4, 1,-4, 4,1, 1,4, -1,-4, -4,1, -4,-1
        db 4,-1, 0,4, 0,-4, -4,0, 4,0, -3,2, -2,3, 2,-3, 2,3, 3,-2
        db -2,-3, -3,-2, 3,2, -1,-3, -3,1, 3,1, -1,3, -3,-1, 1,3, 1,-3
        db 3,-1, 0,-3, 0,3, 3,0, -3,0, 2,-2, -2,-2, 2,2, -2,2, 2,-1
        db -1,2, 1,2, 1,-2, 2,1, -2,-1, -1,-2, -2,1, 2,0, 0,-2, -2,0
        db 0,2, -1,-1, 1,1, 1,-1, -1,1, 0,-1, -1,0, 1,0, 0,1, 0,0
assert ($-BORD) = BONDCELLS*2      ; more cells? take a longer tail of
                                ;  BORD from GAMES\OWLFLY3\SRC\DATA.INC
wallS   db 16                   ; current shaded wall colour (E/W faces)
WSCH    db 0,16, 20,21, 22,23, 24,25 ; scheme pairs: grey/blue/red/white
; TRX/TRZ/TWH/TH: per-frame caches, in BSS past the image (see OWLFLY3.ASM)

camy    dw 120




; ---- free-flight camera / trig ----
; per-building work
roofc   db 17                   ; the top face: 17 for a building, its own
                                ; paint for a vehicle
; ---- traffic (TOWNSEG's TRAFFICF). No vehicle list: a vehicle is a
; function of (lane, slot, clock), so all that is kept is the clock.

; quarter sine table: SINT[i] = round(256*sin(i*90/64 deg)), i=0..64
SINT    dw 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115
        dw 121,126,132,137,142,147,153,157,162,167,172,177,181,185,190,194
        dw 198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243
        dw 245,247,248,250,251,252,253,254,255,255,256,256,256








; palette: 12 colors, DAC values 0..63 (R,G,B) - indigo / cornflower
; Two 18-colour palettes (DAC 0..63), toggled with the N key.
; Index map: 0 wall N/S  1 far stroke  2 mid stroke  3 near stroke
;            4 window    5 window amber 6 ground grid 7 sky top
;            8 HUD       9 sky band    10 ground     11 field/ground band
;            12 haze     13 mountains  14 water      15 forest
;            16 wall E/W (shade)       17 roof
NPALC   = 137                 ; ...+ asphalt + 8 vehicle pairs (120..136)
NPALCOLD = 120                ; 31 game + 63 cockpit + glow + 2 IFF +
                                ; amber + 7 NEWTON sky (SKYZ..SKYZ+6) +
                                ; ladder dim + HUD cyan + true black
                                ; + 5 PANEL colours (108..112): the cockpit
                                ; legends, deliberately far dimmer than the
                                ; HUD set they used to borrow
; (PALDAY/PALNITE moved to UISEG 2026-07-27 with SETPAL: 648 bytes of
;  once-at-startup DAC data - the stack guard's rent for the SA pages.
;  The tables and the loader live in UI.INC as APPLYPALF.)

STARN   = 16                  ; stars as DIRECTIONS: azimuth, elevation

MSGTITLE db 'WIRE CITY',0
MSGALT   db 'ALT ',0
MSGSPD2  db 'SPD',0
MSGTHR2  db 'THR',0
MSGFUE2  db 'FUEL',0
MSGHDG2  db 'HDG',0
MSGAB    db '+',0
MSGMIN2  db '-',0              ; VERT is the one readout that goes negative
MSGABON  db 'AB ON',0
MSGTIM   db 'T',0              ; the no-cockpit strip's clock label. It used

