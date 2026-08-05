; DATA.INC - part of WIRE CITY (included from CITY.ASM)

; ============================================================================
;  DATA
; ============================================================================
bufseg  dw 0
oldoff  dw 0                    ; saved INT 9 vector (keyboard)
oldseg  dw 0
lasttk  dw 0                    ; BIOS tick (0040:006C low word) at previous frame

; ---- flight state ----
vel     dw CRUISE               ; airspeed, *16 fixed point
; The three things a pilot puts OUT into the airstream. Each one is a
; toggle, each one costs speed, and the flaps buy a slower stall for it -
; which is the whole trade and the reason they exist. F, L and B; the
; annunciator column on the left says which of them are hanging out.
flaps   db 0                    ; F: high lift, high drag, low stall
gear    db 0                    ; L: three legs in the wind
; ...and how far out they actually ARE. The lever is instant; the legs are
; not. Six steps, one every fourth tick, so a cycle takes about a second -
; which is why the drag arrives before the legs finish coming down and stays
; a moment after they are up. SWKEYS walks this (it is called every tick and
; lives out in UISEG); GEARDRAWF in SYMSEG draws whichever step it lands on,
; straight out of GEARM.INC. Step 0 is stowed and is not drawn at all.
gearp   db 0
GEARNS  equ 6                   ; steps of travel, and the vertices a leg has.
GEARNV  equ 16                  ;  The guard beside the include in SYM.INC
GEARNF  equ 4                   ;  checks GEARM.INC against these three.
abrk    db 0                    ; B: the airbrake
prevfl  db 0                    ; ...their key-down edges
prevgr  db 0
prevbr  db 0
vstl    dw VSTALL               ; stall speed AS FLOWN: flaps lower it
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
swtac   db 0                    ; T: TACAN - the steer home on the glass
swmode  db 0                    ; O: master mode. 0 = air-to-air, 1 = air-
                                ;  to-ground. ONE state on TWO buttons, the
                                ;  way a real mode switch is: A-A lit or
                                ;  A-G lit, never both and never neither
swap    db 0                    ; P: autopilot
swtr    db 1                    ; R: emissions. Down, and nobody sees you -
                                ;  including you: your own scope goes dark
swecm   db 0                    ; J: ECM
swjmr   db 0                    ; Y: noise jammer
; (the key-down edge bytes and the table that walks them moved to UISEG on
;  2026-07-30 - see SWKEYS there. Twelve switches written out longhand cost
;  a hundred and forty bytes of a segment that had ten. The FLAGS stay
;  here, because half the game reads them with DS pointing at this
;  segment; only the machinery had to leave.)
fuel    dw FUELMAX              ; remaining fuel (burn 1/tick)
rho     dw 256                  ; air density factor 64..256 (from altitude)
teff    dw 0                    ; effective thrust this tick (scratch)
fwd     dw 0                    ; forward units this tick = vel/16 (scratch)
vrate   dw 0                    ; climb/dive rate this tick (scratch)
horiz   dw 100                  ; fixed view centre row (real pitch rotates
                                ; the world now; kept for projection maths)
pitch   dw 0                    ; pitch angle, signed -64..64 (64 = straight up)
psin    dw 0                    ; sin(pitch)*256
pcos    dw 256                  ; cos(pitch)*256
pofs    dw 0                    ; background horizon shift = tan(pitch)*FOCAL
throt   dw 42                   ; throttle 0..64 (start at 65%: full
                                ; military power outruns the AI jets)
abon    db 0                    ; afterburner active this tick
cockpit db 1                    ; 1 = instrument panel shown (C toggles)
prevc   db 0                    ; previous C-key state (edge detect)
mapt    dw 123                  ; minimap top row (rises above the panel)
mmzs    db 0                    ; map zoom as a SHIFT: 0/1/2 = 1/2/4 px a node
mmcol0  dw 0                    ; the window's top-left node, column...
mmrow0  dw 0                    ;  ...and row (row 0 is the world's north)
mmspx   dw 0                    ; how many nodes fit across at this zoom...
mmspy   dw 0                    ;  ...and down. Both change with mmzs.
resseg  dw 0                    ; segment CITY.DAT is loaded into (CS+2000h)
pimgo   dw 0                    ; cockpit bitmap offset in resseg (0 = none)
cpsseg  dw 0                    ; CPSIDE.DAT's own page, ABOVE scrseg so that
                                ; opening it moves nothing (0 = not loaded)
cplo    dw 0                    ; the left view's RLE stream in it
cpro    dw 0                    ; ...and the right's
sview   db 0                    ; 0 forward, 1 looking left, 2 looking right.
                                ; The saved heading and the four key edges
                                ; that go with it are CS-relative in SYMSEG:
                                ; only SVIEWF ever touches them, and this
                                ; segment is down to its last dozen bytes
swph    dw 0                    ; sway: phase, full circle = 65536
swspd   dw 360                  ; sway: phase step per tick (~10 s cycle)
swamp   dw 4                    ; sway: current amplitude, screen pixels
swayx   dw 0                    ; sway: this tick's X shift (screen px)
swayy   dw 0                    ; sway: this tick's Y shift (screen px)

; ---- AI traffic: low-poly jets (see PLANES.INC) ----------------------------
NPLANE  equ 40                  ; 20 v 20 (slot 0 never flies: that seat
                                ; is the player's - green team = you + 19)
pax     dw NPLANE dup(0)        ; world position
pay     dw NPLANE dup(0)
paz     dw NPLANE dup(0)
pah     dw NPLANE dup(0)        ; heading 0..255
ptype   db NPLANE dup(0)        ; 0 fighter / 1 bomber / 2 radar /
                                ;  3 transport / 4 tanker (FORMATION)
premote db NPLANE dup(0)        ; 1 = a REAL pilot flies this slot over
                                ;  the wire: the AI keeps its hands off
pltr    db NPLANE dup(0)        ; callsign letter of the human in the
                                ;  slot (ASCII, from pid; 0 = none)
; ---- owner authority over life and death (the immortal-pilot fix) ----------
; A real pilot dies on HIS machine and nowhere else: our guns only send the
; hit over the wire, and his own POS packet says whether he is still flying.
; Before this, a shot-down human exploded locally and kept flying anyway -
; his next POS resurrected him one tick later (the Highlander bug 2026-07-27).
netdead dw 0FFFFh               ; plane offset the wire says is down
netboom db 0                    ; 1 = this BOOM is the wire's, let it pass
nethdm  db 0                    ; damage points that arrived for US
nethby  dw 0                    ; who dealt them (pid)
lastklr dw 0                    ; who shot us down (rides our death POS)
wseed   dw 0                    ; the seed the world was built from
netup   db 0                    ; 1 = IPX answered at startup
netpid  dw 0                    ; our name on the wire (spawn fan-out)
gact    db 0                    ; the menu's verdict: 1 create, 2 join
gbots   db 1                    ; 1 = the 20v20 war flies with us
ggid    dw 0                    ; which sky we are in (the host's pid)
gname   db 9 dup(0)             ; our sky's name (8 + NUL)
kprev   db 84 dup(0)            ; the menu's key-edge memory (DS, plain)
rzsh    db 9                    ; radar zoom shift: 6 close .. 10 far. It
                                ;  used to stop at 8 (256 units a pixel);
                                ;  two closer steps were added so that at
                                ;  full zoom the whole scope is knife range
                                ;  and every contact earns its aeroplane
prevz   db 0                    ; Z / X edge memory (the scope zoom)
prevxx  db 0
prevk2  db 0                    ; K edge memory (the map zoom)
rgk     dw 0                    ; the radar grid's walkers
rgj     dw 0
pspd    dw 15                   ; AI speed of the plane being ticked
mvb     dw F15VT                ; model table of the plane being drawn
mvn     dw F15NV*6              ; its vertex bytes (vertices * 6)
mfb     dw F15FC                ; its face table
nfc     dw F15NF                ; its face count
bordz   dw 17 dup(0)            ; the front line: jagged z offsets (BRDGEN)
; ---- the ground radar stations: one per side, deep behind its line --------
; Slot 0 is OURS (south of the border), slot 1 is THEIRS (north). They are
; not aircraft: they never move, they turn only their dish, and each one
; is the eye of its own side - lose yours and the scope goes to snow.
NRSTA   equ 2
RSHITS  equ 8                   ; cannon hits it soaks (a jet takes 2..5)
RSPINV  equ 3                   ; dish angle per tick: one turn in ~4.7 s
RSMDMG  equ 4                   ; a missile is worth four shells: two level it
; A locked STATION rides in locki as 0FFF0h + index*2. Two things fall out
; of that encoding for free: 0FFFFh (no lock) is still no lock, and bit 1 -
; the parity every IFF test in the game already reads - comes out FRIENDLY
; for ours (0FFF0h) and HOSTILE for theirs (0FFF2h). Real plane offsets are
; 0..78, so anything at or above RSLK is a station and nothing else.
RSLK    equ 0FFF0h
RSAPRON equ 800                 ; how far off the runway centreline the mast
                                ;  stands. The strip is 150 half-width and
                                ;  the flattened patch reaches 1024 either
                                ;  way, so this is beside the concrete and
                                ;  still on the aerodrome's own flat ground
RSRAD   equ 90                  ; its footprint, half-width. Wider than the
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
        INCLUDE PANELZON.INC
; The rest of the panel's furniture, measured off the converted bitmap by
; hand. These SHOULD be cyan markup zones in the artwork so Panel2Inc finds
; them too - it already reports every cyan blob it sees. Until the artist
; paints them, they live here and have to be re-measured if the picture
; moves. The digit row is the IAS/ALT/HDG/VERT strip under the centre
; screen; the two columns are the annunciator stacks at the panel's ends.
PZDIGY  equ 193                 ; the seven-segment row, y. Two lower than
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
PNLCAP  equ 108                 ; the lamp captions
PNLDIM  equ 109                 ; a legend that is not lit
PNLGRN  equ 110                 ; a system is on / out
PNLAMB  equ 111                 ; a caution
PNLRED  equ 112                 ; a warning
; ...and the SHADED half of each, exactly three slots higher, so a lamp
; only has to know its bright colour and add three for its own shadow.
; A lamp on this panel is a round lens, not a square: lit at the top left
; and falling away to the bottom right, which is what makes four pixels
; read as something with a volume instead of a blob of colour.
PNLSHAD equ 3                   ; core colour + this = its shadow
PNLGRN2 equ 113
PNLAMB2 equ 114
PNLRED2 equ 115
PNLNOIS equ 116                 ; the speckle on the annunciator glass. A
                                ;  black rectangle reads as a hole cut in
                                ;  the panel; a barely-lit one reads as
                                ;  glass with a lamp behind it
; The SCANLINE shade: a hair darker than the core, nothing like PNLSHAD.
; PNLSHAD is a lens's own curvature and is meant to be seen; this is the
; faint banding an old lit display has, and is meant NOT to be. Every
; fourth row at half brightness was a zebra; at a tenth it is a surface.
PNLBAND equ 7                   ; core colour + this = its scanline
PNLGRN3 equ 117
PNLAMB3 equ 118
PNLRED3 equ 119
; How fast the panel blinks, as a bit of the tick counter. 4 was twice a
; second and read as an alarm going off; 8 is once, which reads as a lamp
; that wants attention without shouting. Every blinking thing on the panel
; uses THIS so they all wink together - two rates would be chaos.
PNLBLNK equ 8
PZDIG0  equ 124                 ; IAS
PZDIG1  equ 141                 ; ALT (five digits of room)
PZDIG2  equ 164                 ; HDG
PZDIG3  equ 182                 ; VERT
PZLCX   equ 14                  ; left annunciator column: x and width
PZLCW   equ 16
PZRCX   equ 289                 ; right annunciator column
PZRCW   equ 18
; The clear glass runs from under the overhead bank (row 17) to the top of
; the panel (row 121). Its middle is where the view belongs when the cockpit
; is up - see SETHORIZ. The screen's middle is row 100, which is nearly at
; the panel's edge.
PZGLASSC equ 69
; The canopy bows lean 17 pixels across 60 rows on the artwork - 9/32, near
; enough. The speed and altitude tapes ride them: what leans is WHERE each
; tick and number sits, shifted along x by how far its row is from the
; tape's middle. The ticks themselves stay level, and so do the numbers -
; a 4x6 font cannot turn, and a real tape does not turn them either.
HBPIV   equ 83                  ; the row the lean pivots about
HBLEAN  equ 9                   ; ...and how hard, in thirty-seconds a row
hbslp   dw 0                    ; the lean in force: -HBLEAN on the left
                                ;  tape, +HBLEAN on the right, 0 with the
                                ;  cockpit down (no bows to follow)
; The overhead black plate between the two lamp clusters - the burner strip
; and the wire count share it, and PANELBMP draws AB ON last so the burner
; wins while it is lit. Raise or lower BOTH by moving these.
PZABX   equ 151
PZABY   equ 6
PZLAMPY equ 129                 ; first lamp slot, five of them 10 apart
PZLAMPH equ 10
PZTHRX  equ 35                  ; throttle ladder. It used to stand at 38,
PZTHRY  equ 176                 ;  where its right-hand pixels climbed onto
                                ;  the radar screen's bezel. Moved in beside
                                ;  the FLAPS/GEAR column, on the bare strip
                                ;  of metal that is actually free
PZTHRW  equ 5                   ; ...and how wide a rung is
; ---- the moving map ------------------------------------------------------
; The map fills the WHOLE centre screen now and it zooms. Two things made
; that easy, and both come from the world itself: it is 64x64 nodes, and it
; is a TORUS - every node index in this game is taken mod 64, so flying off
; the east edge brings you in from the west. A map window therefore never
; has an edge to bump into. It is centred on the jet, it wraps, and the
; pixels that used to be a grey margin are now the far side of the world.
; (It was 32x32 nodes at half scale, then 48x48 at three quarters, both
; nailed to the world's corners with the jet wandering about inside.)
PZMMX   equ PZADIX0             ; the map IS the screen now
PZMMY   equ PZADIY0
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
MMWIDE  equ 1000h
MMZN    equ 4
MMZALL  equ 0                   ; the index of the whole-world step
MMZICO  equ 3                   ; ...and the step from which the MAP stops
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
PZRDRR  equ (PZRDRH-6)/2
PZADIR  equ (PZADIH-6)/2
RSTOP   equ 190                 ; and how high the mast and dish reach
; ---- the Shilkas: three a side, over the lines they cover -----------------
; Slots 0..2 are OURS (south of the border), 3..5 THEIRS. The vehicles have
; no state words HERE - it all lives in UISEG beside the code that owns it
; (see SHKINIT in UI.INC) - but the COUNT is an immediate, and a one-pass
; assembler wants those before the include that uses them.
NSHILK  equ 20                  ; ten a side. Their job is to cover the
                                ;  radar and the cities, so they are laid
                                ;  out in two belts per side: one forward
                                ;  over the towns, one back over the mast
; Ground a vehicle can actually STAND on. WORLDH gives 0 for anything at or
; below sea level and climbs at 5 a unit, doubling past 560 - so a height of
; zero IS water, and anything over GNDHI is the steep stuff. A radar station
; floating on the sea was the old behaviour and it looked exactly as silly
; as it sounds.
GNDLO   equ 20                  ; above the waterline by a real margin
GNDHI   equ 430                 ; and below the mountains
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
; and locking number sixteen wrapped past 0FFFFh into PLANE OFFSET ZERO -
; the pilot's own aeroplane. F4 then orbited the player, who is not drawn in
; that view, and the scope's Shilka "vanished". Nothing here may be a typed
; constant again: the shelf is measured from the one above it.
SHKLK   equ RSLK - NSHILK*2
IF SHKLK LE (NPLANE*2)
        %OUT *** the Shilka lock shelf has grown down into plane offsets ***
        .ERR
ENDIF
IF (SHKLK AND 2) NE 0
        %OUT *** SHKLK must be even-parity: the IFF reads bit 1 of the lock ***
        .ERR
ENDIF
SHKTOP  equ 54                  ; how high the vehicle stands, in engine
                                ;  units - aim at half of it, the turret
SHKHITS equ 4                   ; cannon shells it soaks before it burns
SHKMDMG equ 4                   ; and a missile is worth all four
SHKRAD  equ 90                  ; the HIT box, half-width - and the vehicle
                                ;  is only 50 across, so this is deliberately
                                ;  too big. A cannon round steps ~150 units
                                ;  a tick: a box thinner than the step is
                                ;  jumped clean over between two samples,
                                ;  which is why RSRAD is 90 as well. It is
                                ;  the difference between a target and a
                                ;  thing you empty the guns at for nothing.
SHKHBOX equ 120                 ; ...and how high that box reaches
SHKGRNG equ 3200                ; how far its guns reach: inside this it
                                ;  tracks, and a high pass stays safe
SHKTRAV equ 4                   ; turret slew, of 256 a tick - about seven
                                ;  seconds for a full turn. THE LAG IS THE
                                ;  CHARACTER: a mount that snaps onto you is
                                ;  a turret, one you can out-turn is a Shilka
SHKDSPN equ 7                   ; and the RADAR turns steadily on its own,
                                ;  a full sweep in two seconds - that is the
                                ;  part that spins, not the guns
SHKELEV equ 3                   ; barrels rise this fast, of 256 a tick
SHKELMX equ 56                  ; ...and no higher than about 78 degrees:
                                ;  straight overhead is the one place a
                                ;  Shilka cannot reach, and a pilot who
                                ;  finds that out has earned the pass
SHKTRNY equ 29                  ; the TRUNNION, in model units: where the
SHKTRNZ equ 15                  ;  barrels are bolted to the drum
; ---- driving and shooting -------------------------------------------------
SHKSPD  equ 3                   ; world units a tick: a crawl, on purpose.
                                ;  It is not the war, it is scenery that
                                ;  shoots - and a gun that repositions fast
                                ;  is a gun you can never plan around
SHKSTR  equ 2                   ; how fast the hull comes round, of 256
SHKLSH  equ 1400                ; how far it will stray from its post before
                                ;  it turns back. It PATROLS; it does not
                                ;  wander off and leave the city open
SHKLEG  equ 90                  ; ticks on one leg before it picks a new one
SHKFRAT equ 8                   ; ticks between bursts - about two a second
SHKAPER equ 5                   ; how closely the mount must be on the mark
                                ;  before it fires, in compass units. This
                                ;  is the whole difference between a gun
                                ;  that hoses the sky and one that aims
SHKHITC equ 1                   ; the dice: 1 of 2 bursts connects, against
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
NAF    equ 4
AFHLO  equ 96                  ; the band a strip's height is clamped into -
AFHHI  equ 116                 ;  inside 88..119, which is plain grass
AFNW   equ 2                   ; the flattened patch, in heightmap NODES:
AFNL   equ 4                   ;  2 x 4 = 2048 x 4096 world units
AFLEN  equ 1500                ; the concrete itself, half-length along z...
AFW    equ 150                 ;  ...and half-width across it
AFSEG   equ 6                  ; slabs the strip is laid in - see AFDRAWF for
AFSEGD  equ AFLEN/AFSEG        ;  why it is not one, and why 250 is the size
AFVIS   equ 12000              ; how far the concrete is drawn, on EITHER
                               ;  axis. At this range a strip is five pixels
                               ;  across; nearer than this the quads are
                               ;  small enough that all four corners of one
                               ;  clamp together and go off-glass as a unit,
                               ;  which is the difference between a runway
                               ;  that vanishes politely and one that fills
                               ;  the windscreen
                               ;  NOT "AFZ": TASM folds case and that is the
                               ;  afz array two dozen lines down
AFPAINT equ 8                  ; the markings: white, the way they are white
AFEDGE  equ 12                 ; the edge lines, half-width...
AFCTR   equ 8                  ;  ...the centreline...
AFTHR   equ 60                 ;  ...and the threshold bar, half-depth
AFSEA  equ 92                  ; no corner of a strip may sit this low...
AFTOP  equ 190                 ;  ...and none of it this high
AFREACH equ 12                 ; how far the siting walk may go, in NODES.
                               ;  Measured, not guessed: twelve places all
                               ;  four fields in every one of forty test
                               ;  worlds, six leaves one placement in
                               ;  thirteen with nowhere to stand, and the
                               ;  fixed sites the stations use put a THIRD
                               ;  of the aerodromes in the sea or up a hill
afx    dw NAF dup(0)          ; where each strip ended up: its centre,
afy    dw NAF dup(0)          ;  the flattened ground under it,
afz    dw NAF dup(0)
afi    dw 0                    ; the strip being sited or drawn
rsx     dw 0,0                  ; where each station stands
rsy     dw 0,0                  ;  (rsy = the ground under its feet)
rsz     dw 0,0
rsst    db 0,0                  ; 0 = standing, 1 = down
rshp    db 0,0                  ; hits it still has in it (a building, not a jet)
rspin   dw 0                    ; the dish angle 0..255 - both dishes turn
rsi     dw 0                    ; the station being ticked or drawn
rhx     dw 0                    ; RSHIT's question: did anything of ours
rhy     dw 0                    ;  reach this point in the world...
rhz     dw 0
rhdmg   db 0                    ;  ...and how hard (1 a shell, 4 a missile)
airng   dw 10000                ; how far the AI may shoot: its own radar
                                ;  down and it is 2500, eyeball range
; The F4 orbit camera used to sit a flat 100 units out, which is four
; wingspans from a jet and INSIDE a Shilka - the vehicle is 100 long by
; itself. Worse, at that distance the camera lands a few dozen units above
; the ground and any rise between it and the target swallows it: that is
; the "camera appears somewhere odd" on a ground target. It is a variable
; now, set by what is being orbited, and Z/X move it while you watch.
tgrad   dw 100                  ; how far the orbit camera stands off
TGRMIN  equ 70                  ; ...and how close or far it may be wound
TGRMAX  equ 2400
tgzo    dw 75                   ; TGT page: stand-off and vertical centre
tgyc    dw 0                    ;  of the model on the glass
lkx     dw 0                    ; LKPOS: where the locked target actually is,
lky     dw 0                    ;  jet or radar station - every reader of
lkz     dw 0                    ;  the lock goes through here now
rsnet   db 0                    ; a station fell HERE: tell the wire (idx+1)
rsboom  db 0                    ; the wire says one fell THERE: light the
                                ;  fire in the main segment (idx+1)
MSGNORAD db 'NO RADAR',0        ; the legend under the snow
TYPN0   db 0                    ; fighters wear no tag
TYPN1   db 'BOMBER',0
TYPN2   db 'RADAR',0
MSGFLAK db 'FLAK',0             ; what a locked Shilka calls itself
TYPN3   db 'TRANSP',0
TYPN4   db 'TANKER',0
TYPTAB  dw TYPN0,TYPN1,TYPN2,TYPN3,TYPN4
; ---- the fighter: BAKED at build time from res\F15.OBJ by Obj2Inc ----------
; (TOOLS\Obj2Inc, C# - the tooling contract). 23 verts, 14 faces, the
; twin-tail. Its first 13 vertices keep the CLASSIC meanings - nose,
; rear box, wingtips, roots, left fin - because the wreck pool below
; cuts its debris from the classic MFACE over exactly those.
        INCLUDE F15M.INC
; ---- the ground radar station, baked the same way from res\RBASE.OBJ and
; res\RDISH.OBJ: a lattice tower and a SIX-panel dish. Six, not the eight
; the trainer's dish has - this world is cut from flat chunks and a smooth
; bowl read as a foreign object (user's call, 2026-07-28). Both stand at
; the station's feet: the tower spans y 0..40, the dish y 26..58, so one
; position draws both and the dish alone takes the spin.
        INCLUDE RBASEM.INC
        INCLUDE RDISHM.INC
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
        INCLUDE SHULLM.INC
        INCLUDE STURRM.INC
        INCLUDE SDISHM.INC
        INCLUDE SBARRM.INC
; the classic eight faces, kept ONLY for the wreck pool (see above)
MFACE   db 0,1,2,0, 24          ; body top (sun-lit white)
        db 0,3,4,0, 16          ; body bottom (shade)
        db 0,1,3,0, 25          ; body left
        db 0,2,4,0, 25          ; body right
        db 7,5,8,7, 0           ; wing L (light grey)
        db 7,6,9,7, 0           ; wing R
        db 10,11,12,10, 25      ; tail fin
        db 1,2,4,3, 94          ; engine nozzle: palette-cycled fire
NFACE   equ 8
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
PVX     dw 25 dup(0)            ; camera-space vertex cache (max: bomber)
PVY     dw 25 dup(0)
PVZ     dw 25 dup(0)
FCD     dw 16 dup(0)            ; face depths for the painter sort
FCO     db 16 dup(0)            ; face draw order (16: the F15.DAT cap)
msin    dw 0                    ; model-vs-camera yaw sin/cos
mcos    dw 0
; ---- the second joint: PITCH, applied before the yaw ----------------------
; A model used to be able to yaw and nothing else, which is why gun barrels
; could not elevate. MODELDRAW now turns each vertex about a TRUNNION first
; - a point on the parent's own body - and then yaws the result, so a barrel
; group rides its turret round AND tilts at the joint. One more angle, at
; the place a real mount has one. Off by default: [mpon] gates it, and
; everything that is not a gun pays two MOVs a vertex for the privilege.
mpon    db 0                    ; 1 = this model pitches at its trunnion
mpsn    dw 0                    ; the pitch, sin/cos *256
mpcs    dw 256
; THE TURRET's scratch, and it is called trn* for a reason. It was mtpy /
; mtpz / mtvy / mtvz, one letter from the MISSILE's mpy / mpz / mvy / mvz,
; and MSLUPD had picked up the wrong four: it flew a dumb-fired missile on
; the turret's vertex scratch as its vertical and z velocity, drew the
; exhaust puff off the trunnion, and stamped the missile's last position
; into the turret's geometry every tick it was in the air. It assembled
; silently because both sets exist. Names one letter apart, in one file,
; for two unrelated things - now they are not.
trnpy    dw 0                    ; where the trunnion is, in model space
trnpz    dw 0
trnvy    dw 0                    ; the vertex being turned, y and z
trnvz    dw 0
trnvy2   dw 0                    ; ...relative to the trunnion
trnvz2   dw 0
pdx     dw 0                    ; plane centre in camera space
pdy     dw 0
pdz     dw 0
pidx    dw 0                    ; draw loop: plane offset
pfc     dw 0                    ; draw loop: face counter
tpi     dw 0                    ; draw loop: trail point counter
TLN     equ 12                  ; contrail points per plane
; TLX/TLY/TLZ live in BSS now (see CITY.ASM): spawn-generated, and the
; segment budget is too tight to ship 3.8K of zeroes in the image
tlh     dw 0                    ; shared ring head (byte offset, step 2)
locki   dw 0FFFFh               ; locked plane offset (0FFFFh = no lock)
lockd   dw 0                    ; lock scan: best distance so far
prevt   db 0                    ; Enter key edge detector
prevm   db 0                    ; M key edge detector
mfdmode db 0                    ; centre MFD page: 0 MAP / 1 SIT / 2 TGT
rbcx    dw 0                    ; RBLIPS: scope centre column
rbcy    dw 0                    ; RBLIPS: scope centre row
rbsh    db 0                    ; RBLIPS: zoom shift for this scope
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
bqcr    dw 0                    ; BQCITY: how many cells the glass reaches
bqci    dw 0                    ;  ...the cell we stand in...
bqcj    dw 0
bqcu    dw 0                    ;  ...and the walk across the box
bqcv    dw 0
gmkn    dw 0                    ; GNDMARK: the size numerator for this kind
gmks    db 0                    ;  ...and 0 = square (ours), 1 = diamond
bqx     dw 0                    ; symbol centre on the glass
bqy     dw 0
bqa     dw 0                    ; its heading, 0..255, relative to ours
bqsn    dw 0                    ; sin/cos of that, *256
bqcs    dw 0
bqal    dw 0                    ; BQPT's arguments: along the nose...
bqac    dw 0                    ;  ...and out to the right, in symbol units
; How much symbol a contact gets. THE ZOOM DECIDES, for the whole scope at
; once - not each contact by its own range. Zoomed in, the glass is a
; picture of a fight and every mark is worth a shape; zoomed out it is a
; picture of where people ARE, and forty little aeroplanes is noise. The
; symbol is not to scale and never was: it says which way he is pointing
; and roughly how far, relative to the others. That is all a pilot has
; time to read.
BQZHOUS equ 7                   ; and at THIS zoom or closer, the ground
                                ;  itself: the city, cell by cell. Only the
                                ;  two tightest settings - there is no list
                                ;  of buildings to walk, every cell has to
                                ;  be asked, and at the widest zoom the
                                ;  scope covers eighty cells each way
BQZICON equ 8                   ; at this zoom or closer: aeroplanes
BQZCROS equ 9                   ; at this one: crosses. Beyond: dots.
rbrad   dw PZRDRR               ; ...and how far it reaches, in pixels. Kept
rbradn  dw -PZRDRR              ;  negated too: the clip is two compares in
                                ;  the hottest loop on the panel, and a NEG
                                ;  per blip per frame buys nothing
pcs     db NPLANE dup(0)        ; callsign: name table index (0..3)
pnum    db NPLANE dup(0)        ; callsign: number 1..32
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
NWEDG   equ 17
; ---- missiles and wrecks ----------------------------------------------------
pst     db NPLANE dup(0)        ; plane state: 0 = flying, else respawn timer
pammo   db 4                    ; player missiles on the rails
mrel    dw 0                    ; reload timer (one missile per ~20 s)
prevf   db 0                    ; fire key edge detector
msact   db 0                    ; missile in flight?
msx     dw 0                    ; missile world position
msy     dw 0
msz     dw 0
mpx     dw 0                    ; previous position (smoke puff)
mpy     dw 0
mpz     dw 0
mvx     dw 0                    ; straight-flight velocity (no lock)
mvy     dw 0
mvz     dw 0
mstgt   dw 0FFFFh               ; homing target (plane offset)
mlife   dw 0                    ; ticks to self-destruct
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
NPMSL   equ 4
msi     dw 0                    ; the slot in the working set, as a WORD index
mcsl    dw 0                    ; ...and the one the missile camera rides
wnext   dw 0                    ; wreck pool: next slot byte offset
; ---- AI missile pool (the war fights itself) --------------------------------
NAMSL   equ 4
amact   db NAMSL dup(0)         ; slot in flight?
amx     dw NAMSL dup(0)         ; position
amy     dw NAMSL dup(0)
amz     dw NAMSL dup(0)
ampx    dw NAMSL dup(0)         ; previous position (exhaust puff)
ampy    dw NAMSL dup(0)
ampz    dw NAMSL dup(0)
amtgt   dw NAMSL dup(0)         ; target plane offset
amlife  dw NAMSL dup(0)         ; self-destruct timer
aifire  dw 90                   ; cooldown until somebody opens fire
aigt    dw 60                   ; cooldown until somebody strafes
pdam    db 0                    ; player damage taken (8 = shot down)
; ---- tick interpolation: physics is 18.2 Hz, frames are faster ----
ocx     dw 0                    ; camera state before the physics burst
ocy     dw 0
ocz     dw 0
ohd     dw 0
opt     dw 0
orl     dw 0
lvx     dw 0                    ; true state parked during the lerped frame
lvy     dw 0
lvz     dw 0
lvh     dw 0
lvp     dw 0
lvr     dw 0
fcnt    dw 0                    ; frames since the last physics burst
fprev   dw 0                    ; frames the previous interval lasted
chsview db 0                    ; F3 chase camera on?
tgtcam  db 0                    ; F4 orbit camera on the locked target
prevt4  db 0                    ; F4 edge detector
mslcam  db 0                    ; F5: ride the next missile?
prevf5  db 0                    ; F5 edge detector
mcact   db 0                    ; 0 off, 1 riding, 2 watching the kill
mcret   dw 0                    ; aftermath timer (~3 s)
mch     dw 0                    ; camera course (servo-follows the missile)
mimx    dw 0                    ; where the missile ended (the grave)
mimy    dw 0
mimz    dw 0
MSGM2   db 'M',0
sbok    db 0                    ; Blaster found AND ENGINE.RAW loaded?
sbmsk   db 0                    ; saved IRQ7 mask bit
sbtc    dw 0                    ; current DSP time constant
mlvl    dw 0                    ; manoeuvre loading (smoothed, 0..48)
sbrst   dw 0                    ; ring-heal cursor (behind the DMA beam)
sfa16   dw 0                    ; SFX: amplitude, 8.8 fixed point
sfdec   dw 0                    ; SFX: amplitude decay per sample
lastbp  dw 0                    ; last tick a lamp beeped on
sndmod  db 2                    ; 2 = all sounds, 1 = effects only
                                ;  (engine muted), 0 = silence
prevsk  db 0                    ; V key edge detector (sound)
MSGS3   db 'S',0                ; panel sound-mode letter
mprvp   dw 0                    ; previous pitch (for the delta)
mprvr   dw 0                    ; previous roll
qramp   dw 0                    ; elevator ramp: a tap is a feather (2/8
                                ;  unit), a hold builds to 16/8 in ~0.4 s
gq      dw 0                    ; the ramp SIGNED, for the HUD's G meter
                                ;  (+pull, -push, 0 hands-off)
vvy     dw 0                    ; climb per tick, world units (the IVV)
; ---- wreck smoke: the puff column's walkers (code in PLANES.INC) -----------
wpi     dw 0                    ; which puff of the four
wph     dw 0                    ; its phase up the column, 0..127
wpz     dw 0                    ; its camera depth (for the radius)
wpr     dw 0                    ; its screen radius
wpsx    dw 0                    ; its screen centre
wpsy    dw 0
wpc     db 0                    ; its grey of the cooling ramp
pfrac   dw 0                    ; pitch fraction accumulator (eighths)
hfrac   dw 0                    ; heading fraction accumulator (eighths)
sndseg  dw 0
scrseg  dw 0                    ; far scratch segment (holds the minimap)                    ; sample loop segment (64K-aligned)
; (ENGFN retired 2026-07-23: GENBED generates the NEWTON turbine bed)
; ---- GENBED: the turbine generator's state --------------------------------
bm1     dw 0                    ; bed: lowpass pole states
bm2     dw 0
bm3     dw 0
bm4     dw 0
praw    dw 0                    ; bed: previous raw sum (the muffler)
warmc   dw 2048                 ; bed: warm-up samples to discard
xtt     db 0                    ; bed: crossfade scratch
sbn2    dw 0                    ; the audio spool: the note chases the
                                ;  lever from 0 - startup whine for free
tgti    dw 0                    ; orbited plane (kept past the lock)
tcws    dw 0                    ; wreck slot the camera follows (mode 2)
tgaz    dw 0                    ; orbit azimuth (0..255)
tgel    dw 12                   ; orbit elevation (-30..56)
dying   db 0                    ; player down: cinematic fall running
dytick  dw 0                    ; ...for how long (Space works after 1 s)
flbh    dw 0                    ; black box: ring head (next write)
flbc    dw 0                    ; flashback: playback cursor
flbcnt  dw 0                    ; flashback: samples left to play
svh     dw 0                    ; saved heading (flashback swaps it too)
MSGGO   db 'GAME OVER',0
dcx     dw 0                    ; frozen death-camera position
dcy     dw 0
dcz     dw 0
bpx     dw 0                    ; WRKFILL input: breakup position
bpy     dw 0
bpz     dw 0
bph     dw 0                    ; WRKFILL input: breakup heading
MSGCR2  db 'CRASH',0
MSGPS2  db 'PRESS SPACE',0
prevv   db 0                    ; F3 edge detector
svx     dw 0                    ; pilot's world, saved during the chase
svy     dw 0
svz     dw 0
svp     dw 0                    ; saved pitch
svr     dw 0                    ; saved roll
rndovr  dw 0                    ; round-over countdown (0 = fighting)
rwin    db 0                    ; who wiped whom: 0 = friendlies won
bhpc    dw 4 dup(0FFFFh)        ; wounded buildings: cell keys
bhph    db 4 dup(0)             ; ...and their remaining hits
bhnext  dw 0                    ; round robin for fresh victims
MASK8   db 1,2,4,8,16,32,64,128 ; bit masks for the ruins bitmap
MSGVWIN db 'VIPERS WIN',0
MSGBWIN db 'BANDITS WIN',0
phit    dw 0                    ; player hit flash timer
tscf    dw 0                    ; team score: hostiles downed
tsch    dw 0                    ; team score: friendlies downed
psc     dw 0                    ; personal kills
php     db NPLANE dup(3)        ; hit points: 2..5 cannon hits to down
gunam   dw 250                  ; cannon rounds
gunreg  dw 0                    ; belt regen timer
guntik  db 0                    ; tracers on screen while > 0
hitfx   dw 0FFFFh               ; plane flashing from a cannon hit
hitft   dw 0                    ; ...and for how many ticks
NTRC    equ 16                  ; tracer rounds in the pool
trcact  db NTRC dup(0)          ; round in flight?
tcx     dw NTRC dup(0)          ; position
tcy     dw NTRC dup(0)
tcz     dw NTRC dup(0)
trvx    dw NTRC dup(0)          ; velocity (150/tick + spread, droops)
trvy    dw NTRC dup(0)
trvz    dw NTRC dup(0)
trlif   dw NTRC dup(0)          ; ticks to burn out
trnext  dw 0                    ; ring: next slot to fire from
ctx     dw 0                    ; BOOM scratch: face centroid
cty     dw 0
ctz     dw 0
wcc     dw 0                    ; BOOM scratch: corner counter
hbsx    dw 0                    ; HUD tapes: speed spine x
hbslb   dw 0                    ; speed labels/value x
hbst1   dw 0                    ; speed major tick x
hbst2   dw 0                    ; speed minor tick x
hbcx    dw 0                    ; speed critical mark x
hbax    dw 0                    ; altitude spine x
hbalb   dw 0                    ; altitude labels/value x
hbat1   dw 0                    ; altitude major tick x
hbat2   dw 0                    ; altitude minor tick x
hbacx   dw 0                    ; altitude critical mark x
hbscur  dw 0                    ; speed CURRENT value x (outboard side)
hbacur  dw 0                    ; altitude CURRENT value x (outboard)
GBUF    db ' 1.0G',0            ; the G readout scratch
ftx     dw 0                    ; font cursor x
fty     dw 0                    ; font cursor y
NB      db 6 dup(0)             ; number->text scratch for FNUM
FNAME   db 'CITY.DAT',0
SFNAME  db 'CPSIDE.DAT',0       ; the 90-degree views; optional, see CITY.ASM
RESMSG  db 'CITY.DAT not found - keep it next to CITY.COM',13,10,'$'
; (F15FN/MHDR gone: the model is baked into the image at build time)
daymode db 1                    ; 1 = day palette, 0 = night (N key toggles)
prevn   db 0                    ; previous N-key state (edge detect)
bcol    db 0                    ; terrain patch colour chosen by HBLD
; ---- the NEWTON sky: the hot variables (the code and its tables live -------
; in SKY.INC, in their own segment; these ~90 bytes stay here so the
; per-pixel loops read them through DS with no prefix)
dbase   db 0                    ; dither: ramp shade in play
dfrac   db 0                    ; dither: its fraction
PATT    db 16 dup(0)            ; the row's 16-pixel pattern
pmrow   dw -9999                ; MKPATT: the row its anchor was cut for
pf0     dw 0                    ; ...that anchor's tile row
pt0     dw 0                    ; ...and phase, plus the walking copy
pti     dw 0
cdup    dw 320                  ; the twin pixel's offset, across the line
cfv     dw 0                    ; a cloud row's f (whole part)
cxv     dw 0                    ; CLSEG: the walk's screen x and y...
cyv     dw 0
cxe     dw 0                    ; ...their 8.8 errors...
cye     dw 0
dxi     dw 0                    ; ...the step, split whole and fraction
dxf     dw 0
dyi     dw 0
dyf     dw 0
crb     dw 0                    ; ...the current row's base offset
ctrow   dw 0                    ; ...and the tile row, fixed per segment
wdith   db 0                    ; 1 = spans get the per-pixel world grain
wt8     dw 0                    ; the span's world coords, 8.8
wf8     dw 0
hcur    dw 100                  ; the horizon pivot: row, column, and the
cx0     dw 160                  ; frame's roll pair (copied from rsin/rcos)
sinr    dw 0
cosr    dw 256
mrow    dw 0                    ; BGND: current row and its buffer base
rowb    dw 0
fmv     dw 0                    ; f at the pivot column of the row
spa     dw 0                    ; the span: start, length, sky-or-ground
spl     dw 0
sptype  db 0
qcn     dw 0                    ; clouds: visible count, scratch, and the
qcb     dw 0                    ; one being drawn (d, u, index, t, f,
qcd     dw 0                    ; scale, rows, step, walkers, width)
qcu     dw 0
qci     dw 0
qct     dw 0
qcf     dw 0
qcs     dw 0
qch     dw 0
qcp     dw 0
qcr     dw 0
qcw     dw 0
qcv     dw 0
wdx2    dw 0                    ; WCAM2: world delta in, camera pair out
wdz2    dw 0
cldu    dw 0
cldd    dw 0
; ---- LADR: the pitch ladder's walkers (code in HUD.INC) --------------------
lp      dw 0                    ; rung index, tens of degrees
lfc     dw 0                    ; f of the screen centre
lke     dw 0                    ; last rung of this frame's four
lcx     dw 0                    ; the rung's centre on screen
lcy     dw 0
lx8     dw 0                    ; the walk along the line, 8.8
ly8     dw 0
li      dw 0                    ; which pixel of the walk
lpx     dw 0                    ; the pixel's column
lsn     dw 0                    ; sin scratch for the tangent
LBUF    db '   ',0              ; ladder label scratch
; mountain / megablock work

; ---- Diamond-Square world heightmap (the CityGame terrain generator) -------
; 64x64 nodes on a TORUS (indices wrap &63) -> seamlessly tiles our toroidal
; 256-cell world: 1 node = 4x4 cells. Generated once at startup by DSGEN.
rseed   dw 21845                ; LCG state (re-seeded from the clock at boot)
dss     dw 0                    ; DS: current side length
dsh     dw 0                    ; DS: half side
dsx     dw 0                    ; DS: loop x / scratch
dsy     dw 0                    ; DS: loop y / scratch
dsamp   dw 0                    ; DS: noise amplitude (power of two)
dsac    dw 0                    ; DS: accumulator
; HMAP lives in the BSS block past the file image (see CITY.ASM); the baked
; minimap moved out to the far scratch segment [scrseg] to free 4K of BSS.

; ---- 3D terrain mesh state (one node = 4 cells = 1024 world units) ---------
NR      equ 20                  ; terrain draw radius in nodes around camera
NSIDE   equ 41                  ; cached node grid side (2*NR+1)
tnx     dw 0                    ; camera node x = (camx+BIAS)>>10
tnz     dw 0                    ; camera node z
tidx    dw 0                    ; index into TORD
tta     dw 0                    ; node-grid loop a (0..NSIDE-1)
ttb     dw 0                    ; node-grid loop b
gbase   dw 0                    ; ground height under the current cell (world)
scol    db 3                    ; stroke colour for the current building
btype   dw 0                    ; building type: 0 box 1 spire 2 tower 3 arch 4 factory
boxb    dw 0                    ; current box: bottom, relative to gbase
boxt    dw 0                    ; current box: top, relative to gbase
pwcx    dw 0                    ; saved cell centre (composite buildings move wcx)
pwcz    dw 0
puffk   dw 0                    ; smoke puff loop counter
sbh     dw 0                    ; superblock hash (district decisions)
bdist   dw 0                    ; district: 0/3 residential, 1 downtown, 2 industry
PUFO    dw 0,21,42              ; smoke puff phase offsets (loop of 64)
SIY     dw 4 dup(0)             ; stashed face Y (PITCH4 mutates IY/IZ, and a
SIZ     dw 4 dup(0)             ; fill+stroke pair would pitch them twice)

; building draw order: every cell offset in [-24..24]^2 sorted by squared
; distance DESCENDING (painter far -> near). Replaces both the old bucket
; scan and the far-belt megablock stand-ins: real buildings all the way out.
BORD    db -24,24, 24,24, 24,-24, -24,-24, 24,23, -23,24, 23,-24, -23,-24, 23,24, -24,-23
        db -24,23, 24,-23, -22,24, 24,22, -24,22, -24,-22, -22,-24, 22,-24, 24,-22, 22,24
        db -23,-23, -23,23, 23,-23, 23,23, -24,21, 24,-21, -21,24, 21,-24, -24,-21, 24,21
        db 21,24, -21,-24, -22,-23, -23,22, -22,23, -23,-22, 23,22, 23,-22, 22,23, 22,-23
        db 24,20, -24,-20, -20,24, -20,-24, -24,20, 24,-20, 20,24, 20,-24, -23,-21, 21,23
        db 23,-21, -21,-23, 21,-23, -23,21, -21,23, 23,21, 22,22, 22,-22, -22,22, -22,-22
        db 24,-19, -24,-19, 24,19, -19,-24, -24,19, -19,24, 19,-24, 19,24, -23,20, 20,23
        db -20,23, 20,-23, 23,-20, -23,-20, -20,-23, 23,20, 22,-21, -21,-22, 22,21, 21,22
        db -22,-21, 21,-22, -22,21, -21,22, 18,24, 24,18, -24,-18, -18,24, 24,-18, -24,18
        db -18,-24, 18,-24, 19,-23, 23,19, -19,23, 23,-19, -19,-23, -23,-19, 19,23, -23,19
        db -20,22, -22,20, 20,-22, 22,20, 22,-20, -20,-22, -22,-20, 20,22, -21,21, 21,-21
        db -21,-21, 21,21, -17,24, -17,-24, 24,17, -24,17, 17,24, 24,-17, 17,-24, -24,-17
        db 23,18, -23,-18, -18,23, -23,18, 23,-18, 18,-23, 18,23, -18,-23, -19,-22, -22,-19
        db 22,19, 19,-22, -22,19, 19,22, -19,22, 22,-19, -21,20, -20,-21, -20,21, 20,21
        db -21,-20, 20,-21, 21,-20, 21,20, 24,-16, -24,-16, 16,-24, -16,24, 24,16, -16,-24
        db 16,24, -24,16, -17,-23, 17,23, 17,-23, -17,23, -23,17, 23,17, 23,-17, -23,-17
        db 18,-22, 22,-18, -18,-22, 18,22, -22,-18, 22,18, -22,18, -18,22, -19,21, 19,21
        db 21,-19, 21,19, -21,19, 19,-21, -21,-19, -19,-21, -15,-24, -24,15, 15,-24, 24,15
        db 15,24, -24,-15, -15,24, 24,-15, -20,20, -20,-20, 20,20, 20,-20, -16,-23, 23,16
        db 16,-23, 23,-16, -23,-16, -23,16, 16,23, -16,23, -22,17, 22,17, -17,22, -22,-17
        db 22,-17, 17,22, 17,-22, -17,-22, -24,14, -24,-14, 24,-14, -14,-24, -14,24, 14,24
        db 24,14, 14,-24, 18,-21, -18,21, -18,-21, 18,21, 21,18, -21,18, 21,-18, -21,-18
        db 20,19, 20,-19, -19,-20, 19,20, -20,19, -19,20, -20,-19, 19,-20, 15,-23, -15,23
        db 15,23, 23,15, -23,-15, -23,15, 23,-15, -15,-23, 24,13, -13,-24, 13,24, -13,24
        db -24,13, 24,-13, 13,-24, -24,-13, 16,22, 16,-22, 22,16, -16,-22, -22,-16, 22,-16
        db -22,16, -16,22, -21,17, -17,21, 17,21, 21,17, 17,-21, 21,-17, -17,-21, -21,-17
        db -14,-23, -23,14, -14,23, 14,23, 23,14, 23,-14, 14,-23, -23,-14, 18,20, -18,20
        db -20,-18, 18,-20, -18,-20, 20,-18, 20,18, -20,18, 19,19, 19,-19, -19,19, -19,-19
        db 24,-12, -12,-24, 12,-24, -24,12, -12,24, -24,-12, 24,12, 12,24, 15,-22, -15,22
        db 15,22, -15,-22, -22,15, -22,-15, 22,15, 22,-15, 13,-23, -23,13, -23,-13, 13,23
        db -13,23, -13,-23, 23,13, 23,-13, 11,24, 24,11, 11,-24, 16,21, 16,-21, -16,21
        db -16,-21, -24,11, -24,-11, -21,16, -21,-16, -11,24, 24,-11, 21,-16, 21,16, -11,-24
        db -17,20, -17,-20, 17,-20, -20,17, 17,20, 20,-17, -20,-17, 20,17, -19,18, -18,19
        db -19,-18, 19,-18, 18,-19, 19,18, 18,19, -18,-19, 22,14, -14,-22, -14,22, 22,-14
        db -22,-14, 14,-22, 14,22, -22,14, 10,-24, -24,-10, -10,-24, -24,10, 24,10, -10,24
        db 24,-10, 10,24, 12,-23, 23,12, -23,-12, -12,23, -12,-23, 23,-12, 12,23, -23,12
        db -21,15, 21,-15, -15,-21, -15,21, 15,21, 15,-21, 21,15, -21,-15, 24,9, -9,-24
        db -24,9, 9,24, -9,24, 24,-9, 9,-24, -24,-9, -20,-16, -16,-20, -16,20, 20,-16
        db -20,16, 16,-20, 20,16, 16,20, 13,22, -22,13, -22,-13, -13,22, 13,-22, 22,13
        db 22,-13, -13,-22, -17,-19, -23,-11, 19,17, 17,-19, 17,19, -23,11, 19,-17, -19,-17
        db -19,17, 11,-23, -17,19, -11,23, 11,23, 23,11, -11,-23, 23,-11, -18,18, -18,-18
        db 18,-18, 18,18, -24,-8, -8,24, -8,-24, -24,8, 8,24, 24,-8, 8,-24, 24,8
        db 14,-21, -14,21, -21,-14, 21,-14, 14,21, -14,-21, 21,14, -21,14, 23,10, -23,-10
        db 10,-23, -10,-23, 10,23, -10,23, 23,-10, -23,10, 12,22, -22,-12, -22,12, 12,-22
        db -12,22, 22,12, 22,-12, -12,-22, -7,24, 7,-24, 24,7, -15,20, -20,-15, 24,-7
        db -24,7, -24,-7, 7,24, -7,-24, 15,20, 20,-15, -15,-20, 20,15, -20,15, 15,-20
        db 16,19, -16,19, -19,16, 16,-19, -16,-19, 19,-16, -19,-16, 19,16, 18,-17, 17,18
        db 18,17, 17,-18, -18,-17, -17,18, -17,-18, -18,17, -6,-24, 6,24, -24,6, -24,-6
        db 24,-6, 6,-24, 24,6, -6,24, -9,-23, -13,-21, 9,23, 23,9, 23,-9, -21,-13
        db 13,-21, 21,13, -23,9, -21,13, -13,21, 21,-13, 13,21, -23,-9, -9,23, 9,-23
        db 22,11, -11,-22, -22,-11, -11,22, 22,-11, -22,11, 11,22, 11,-22, -24,-5, 24,-5
        db 24,5, -24,5, -5,-24, 5,-24, 5,24, -5,24, -20,-14, -20,14, 20,14, 14,-20
        db 20,-14, -14,-20, -14,20, 14,20, 8,-23, 8,23, 23,8, -23,8, -8,23, 23,-8
        db -8,-23, -23,-8, 4,24, 4,-24, 24,4, -24,-4, -24,4, 24,-4, -4,-24, -4,24
        db 15,19, 19,-15, -15,19, -19,-15, -15,-19, 19,15, 15,-19, -19,15, 21,12, 12,-21
        db 24,3, 24,-3, -12,21, 12,21, -24,3, -21,12, -21,-12, -24,-3, -3,24, -12,-21
        db 21,-12, 3,-24, 3,24, -3,-24, -10,22, -22,-10, 10,-22, 22,-10, 22,10, 10,22
        db -22,10, -10,-22, 24,-2, 24,2, -2,24, -2,-24, -16,18, -16,-18, -24,-2, 16,18
        db 2,24, 2,-24, 18,16, 18,-16, -24,2, -18,16, -18,-16, 16,-18, 7,-23, 23,-7
        db 23,7, 17,17, -23,-7, -17,-17, -7,23, -7,-23, 17,-17, 7,23, -17,17, -23,7
        db 1,-24, 24,1, -1,-24, -1,24, 1,24, -24,-1, 24,-1, -24,1, -24,0, 24,0
        db 0,24, 0,-24, -20,-13, 20,-13, 20,13, -20,13, 13,-20, -13,20, -13,-20, 13,20
        db -9,-22, -22,9, 9,22, 23,-6, 22,9, -6,23, 22,-9, 9,-22, -23,6, -6,-23
        db 23,6, 6,23, 6,-23, -22,-9, -9,22, -23,-6, -11,-21, -21,-11, 21,11, -21,11
        db 11,21, 21,-11, -11,21, 11,-21, 19,-14, 14,-19, -19,-14, 19,14, -19,14, -14,19
        db -14,-19, 14,19, 5,-23, -23,-5, -23,5, -5,23, 23,5, 5,23, -5,-23, 23,-5
        db -15,-18, -15,18, 18,15, 18,-15, -18,15, -18,-15, 15,18, 15,-18, -8,-22, 8,-22
        db 22,8, 8,22, 22,-8, -8,22, -22,8, -22,-8, 23,-4, 17,16, 23,4, -16,-17
        db 4,-23, 4,23, -23,-4, -23,4, -17,16, -16,17, 17,-16, -4,-23, -4,23, -17,-16
        db 16,17, 16,-17, -20,-12, 12,20, 12,-20, 20,12, -20,12, 20,-12, -12,-20, -12,20
        db 21,-10, 10,-21, -21,10, 10,21, 21,10, -10,-21, -10,21, -21,-10, 3,-23, -3,23
        db -3,-23, -23,3, 23,-3, -23,-3, 23,3, 3,23, -22,7, 2,-23, -7,-22, 2,23
        db -2,23, 7,-22, 22,-7, -2,-23, 22,7, 23,-2, -23,-2, -7,22, -23,2, 23,2
        db -22,-7, 7,22, -1,-23, 13,19, -19,13, 23,1, -13,-19, 23,-1, -19,-13, 19,13
        db -13,19, 19,-13, 13,-19, -23,1, 1,-23, 1,23, -1,23, -23,-1, 0,-23, 23,0
        db -23,0, 0,23, 9,21, -21,9, -9,21, 21,9, 9,-21, -9,-21, 21,-9, -21,-9
        db 20,-11, -20,-11, 20,11, 11,20, -11,20, -20,11, 11,-20, -11,-20, 22,6, -18,14
        db -6,22, 22,-6, -14,-18, -6,-22, -22,6, 14,-18, 18,14, 14,18, -14,18, 6,-22
        db -22,-6, 18,-14, -18,-14, 6,22, 17,15, 17,-15, -17,-15, -15,17, -17,15, 15,17
        db -15,-17, 15,-17, 16,16, -16,-16, 16,-16, -16,16, 22,-5, -22,5, -5,-22, -5,22
        db -22,-5, 5,-22, 22,5, 5,22, -21,-8, 19,12, -19,-12, -8,21, -12,-19, 8,-21
        db 8,21, 12,-19, -21,8, -12,19, 12,19, 19,-12, 21,8, -8,-21, 21,-8, -19,12
        db 20,10, 4,-22, -4,22, -22,4, -10,20, 22,4, -22,-4, -10,-20, 10,20, -4,-22
        db -20,10, -20,-10, 4,22, 22,-4, 10,-20, 20,-10, -18,-13, 22,3, 3,22, -3,-22
        db 3,-22, 22,-3, 18,-13, 13,18, -18,13, -22,3, -13,18, -22,-3, 18,13, -13,-18
        db 13,-18, -3,22, 21,7, -7,21, -21,-7, 7,-21, 7,21, 21,-7, -21,7, -7,-21
        db -2,-22, -22,2, -2,22, 2,22, -22,-2, 22,2, 2,-22, 22,-2, 17,14, 17,-14
        db -17,14, 1,-22, -22,1, -1,-22, -14,17, 14,-17, 22,1, 1,22, -22,-1, -17,-14
        db -1,22, 14,17, 22,-1, -14,-17, 0,-22, 22,0, -22,0, 0,22, -11,-19, 19,11
        db 19,-11, -19,11, -19,-11, 11,19, -11,19, 11,-19, -20,9, -15,16, -15,-16, -16,-15
        db -9,-20, 20,9, 15,-16, -9,20, 16,15, 9,20, -20,-9, -16,15, 15,16, 16,-15
        db 9,-20, 20,-9, -21,6, -6,21, 21,6, -6,-21, -21,-6, 21,-6, 6,-21, 6,21
        db 12,-18, -18,12, -18,-12, -12,-18, 18,-12, 12,18, -12,18, 18,12, -5,-21, 5,-21
        db 21,5, -21,5, 5,21, 21,-5, -21,-5, -5,21, 8,20, -20,8, 20,-8, -8,-20
        db 8,-20, 20,8, -8,20, -20,-8, -10,19, 10,19, -19,-10, -10,-19, 19,-10, 10,-19
        db -19,10, 19,10, 13,17, 17,13, 17,-13, -17,-13, -17,13, -13,-17, -13,17, 13,-17
        db -4,21, 21,-4, -4,-21, 21,4, -21,4, 4,-21, 4,21, -21,-4, 16,14, -14,-16
        db -14,16, -16,-14, 14,-16, 16,-14, -16,14, 14,16, -15,15, 3,21, -15,-15, 15,15
        db -3,-21, -21,-3, -21,3, 3,-21, 15,-15, 21,3, 21,-3, -3,21, 7,-20, 20,7
        db -7,-20, 7,20, -7,20, -20,7, -20,-7, 20,-7, -18,-11, 11,18, 21,2, 18,-11
        db -11,-18, -2,21, 21,-2, -21,-2, -18,11, -11,18, 18,11, 2,-21, 2,21, 11,-18
        db -21,2, -2,-21, -1,-21, -21,1, 9,-19, 1,21, -19,-9, -1,21, 19,9, 19,-9
        db -9,19, -21,-1, 1,-21, 21,-1, -9,-19, 9,19, 21,1, -19,9, 0,-21, 21,0
        db 0,21, -21,0, -20,6, -6,-20, 6,20, 20,6, 6,-20, -20,-6, 20,-6, -6,20
        db 12,-17, -12,17, 17,12, -17,-12, -12,-17, 17,-12, -17,12, 12,17, 16,13, 13,-16
        db 20,5, -5,20, 20,-5, -20,5, -8,-19, -19,8, 19,8, 5,20, -13,-16, 13,16
        db -16,-13, -8,19, -20,-5, -5,-20, 8,19, 5,-20, -16,13, 8,-19, 16,-13, 19,-8
        db -19,-8, -13,16, -10,18, 10,-18, 18,-10, -10,-18, -18,10, -18,-10, 18,10, 10,18
        db 15,-14, 15,14, 14,-15, 14,15, -15,-14, -14,15, -14,-15, -15,14, -4,-20, 20,4
        db -20,4, 20,-4, -4,20, 4,20, -20,-4, 4,-20, -19,-7, 7,19, -7,19, 11,17
        db -17,-11, 11,-17, 19,-7, 19,7, -7,-19, 17,11, -11,-17, -17,11, 17,-11, -11,17
        db -19,7, 7,-19, 20,-3, -20,-3, -3,20, -3,-20, 3,20, -20,3, 3,-20, 20,3
        db -9,18, -9,-18, 18,-9, 9,18, 9,-18, 18,9, -18,-9, -18,9, -20,2, -2,-20
        db -20,-2, 20,2, -2,20, 2,-20, 2,20, 20,-2, -20,1, -20,-1, -1,20, 20,-1
        db 1,20, -1,-20, 20,1, 1,-20, 20,0, -16,-12, -16,12, 16,-12, 0,20, 16,12
        db -12,16, 0,-20, 12,16, 12,-16, -20,0, -12,-16, 19,6, 6,-19, -6,19, 6,19
        db -6,-19, -19,6, -19,-6, 19,-6, -15,-13, 13,15, -13,15, -13,-15, 15,-13, -15,13
        db 13,-15, 15,13, 14,-14, 14,14, -14,14, -14,-14, 17,10, 17,-10, 10,-17, -17,-10
        db -10,-17, 10,17, -10,17, -17,10, 18,8, -8,18, 8,-18, 18,-8, -18,-8, 8,18
        db -8,-18, -18,8, 5,19, -5,-19, -5,19, -19,-5, 19,-5, 5,-19, -19,5, 19,5
        db 4,19, -4,-19, 19,4, 16,11, 16,-11, 4,-19, -4,19, 11,16, -16,11, 11,-16
        db -11,-16, -16,-11, -11,16, -19,-4, -19,4, 19,-4, 18,-7, -18,-7, -7,18, -18,7
        db 18,7, 7,-18, -7,-18, 7,18, 17,-9, -9,17, -17,9, 17,9, -19,3, 19,-3
        db -9,-17, 3,-19, -17,-9, 9,17, 19,3, -19,-3, 3,19, 9,-17, -3,-19, -3,19
        db -12,-15, 12,15, -12,15, -15,-12, 12,-15, -15,12, 15,-12, 15,12, 2,-19, -19,2
        db -14,-13, -2,-19, 14,-13, -13,14, -2,19, -14,13, 13,-14, 19,-2, 2,19, 19,2
        db 14,13, 13,14, -19,-2, -13,-14, 1,19, 19,-1, -19,1, -19,-1, 1,-19, -1,-19
        db -1,19, 19,1, 0,-19, 0,19, -19,0, 19,0, 6,18, -18,-6, 18,6, 18,-6
        db -18,6, 6,-18, -6,18, -6,-18, 16,10, -16,10, 10,-16, 10,16, -10,16, -10,-16
        db 16,-10, -16,-10, 17,-8, 8,17, 8,-17, -17,8, -8,17, 17,8, -8,-17, -17,-8
        db -18,5, 18,-5, -5,18, 5,-18, -5,-18, -18,-5, 5,18, 18,5, 11,15, -15,11
        db 11,-15, -11,-15, -11,15, 15,11, 15,-11, -15,-11, 12,14, -14,-12, 4,18, -4,18
        db 14,12, -18,-4, -4,-18, 14,-12, 12,-14, 18,-4, -12,-14, 18,4, -18,4, 4,-18
        db -14,12, -12,14, -7,17, -17,-7, -13,-13, 7,-17, -7,-17, -17,7, -13,13, 13,-13
        db 7,17, 17,-7, 17,7, 13,13, 16,-9, 16,9, 9,16, -9,-16, -16,9, 9,-16
        db -9,16, -16,-9, -3,18, -18,3, 3,18, 3,-18, 18,-3, 18,3, -3,-18, -18,-3
        db 2,18, -2,-18, 2,-18, -18,-2, 18,2, 18,-2, -2,18, -18,2, 17,6, 15,10
        db 10,-15, -18,1, -18,-1, 10,15, -15,10, -15,-10, -17,-6, 6,-17, 6,17, 17,-6
        db 15,-10, -10,-15, 18,1, 1,-18, -1,18, -17,6, 18,-1, -6,17, -6,-17, -1,-18
        db 1,18, -10,15, 0,18, -18,0, 18,0, 0,-18, -16,-8, 16,8, -8,-16, 16,-8
        db -8,16, 8,-16, 8,16, -16,8, 14,-11, -14,-11, -11,-14, 11,14, 14,11, 11,-14
        db -14,11, -11,14, -5,-17, 5,-17, 17,5, -17,5, -5,17, 5,17, -17,-5, 17,-5
        db 13,-12, 12,-13, -13,12, -12,-13, -13,-12, 12,13, -12,13, 13,12, 15,9, 9,15
        db 15,-9, 9,-15, -9,15, -15,9, -15,-9, -9,-15, -16,-7, 4,-17, -7,16, -17,4
        db -4,-17, 16,-7, -17,-4, 16,7, 17,4, 17,-4, 4,17, 7,-16, -4,17, 7,16
        db -16,7, -7,-16, 17,3, 3,-17, 17,-3, -17,3, 3,17, -3,-17, -17,-3, -3,17
        db 14,10, -14,10, 10,-14, -10,14, 14,-10, -14,-10, 10,14, -10,-14, -2,-17, -2,17
        db -17,-2, 2,17, -17,2, 2,-17, 17,-2, 17,2, 16,6, -6,16, 6,-16, -6,-16
        db -16,6, 6,16, 16,-6, -16,-6, -17,-1, -17,1, 1,17, -13,-11, -13,11, 17,-1
        db 17,1, 1,-17, 11,-13, -11,13, 11,13, -1,-17, -1,17, 13,11, -11,-13, 13,-11
        db -15,-8, 15,8, -8,-15, 8,-15, -8,15, 17,0, 15,-8, 8,15, 0,17, -15,8
        db -17,0, 0,-17, 12,-12, -12,12, 12,12, -12,-12, -16,5, -16,-5, 5,-16, -5,16
        db -5,-16, 16,-5, 5,16, 16,5, -14,-9, -9,14, 9,-14, 14,-9, 9,14, -14,9
        db 14,9, -9,-14, 15,-7, -15,7, 7,15, 15,7, -7,15, 7,-15, -7,-15, -15,-7
        db -16,4, -4,16, -4,-16, -16,-4, 4,-16, 4,16, 16,-4, 16,4, -10,13, 13,-10
        db -10,-13, -13,-10, -13,10, 10,-13, 13,10, 10,13, -3,-16, 12,11, 3,16, -11,-12
        db 11,-12, 16,3, 3,-16, 12,-11, -12,11, 11,12, -11,12, -16,-3, -3,16, -16,3
        db -12,-11, 16,-3, -15,-6, 6,15, -15,6, 15,6, -6,-15, 6,-15, 15,-6, -6,15
        db 2,-16, 16,2, -14,8, -16,2, 8,14, -2,-16, 2,16, -8,-14, -14,-8, 16,-2
        db 14,-8, -16,-2, 8,-14, -8,14, 14,8, -2,16, 1,-16, -1,-16, 16,-1, -16,1
        db -16,-1, 16,1, -1,16, 1,16, 16,0, -16,0, 0,16, 0,-16, -13,-9, 15,-5
        db 9,13, 5,-15, 13,9, -9,13, 13,-9, -13,9, -15,-5, -9,-13, 5,15, 15,5
        db -15,5, 9,-13, -5,15, -5,-15, 14,7, -7,-14, -14,-7, 14,-7, -14,7, -7,14
        db 7,-14, 7,14, -12,-10, -12,10, 10,-12, -10,12, 12,-10, 12,10, 10,12, -10,-12
        db 11,11, 11,-11, -11,-11, -11,11, 4,15, -15,-4, 15,-4, 15,4, 4,-15, -15,4
        db -4,-15, -4,15, -15,3, -3,-15, 3,15, 3,-15, 15,3, -3,15, 15,-3, -15,-3
        db 13,8, -13,8, -13,-8, 13,-8, 8,13, 8,-13, -8,13, -8,-13, -6,14, 6,-14
        db -6,-14, -14,-6, -14,6, 14,-6, 14,6, 6,14, 15,2, -2,-15, 2,-15, -2,15
        db -15,-2, 2,15, -15,2, 15,-2, 1,15, -15,-1, 1,-15, 15,-1, -15,1, -1,-15
        db -1,15, 15,1, 12,9, -15,0, 12,-9, 9,-12, -9,-12, -9,12, -12,-9, 9,12
        db 15,0, -12,9, 0,-15, 0,15, -14,5, -11,-10, 14,-5, -5,14, -11,10, 11,10
        db 14,5, 5,-14, 10,-11, 11,-10, 5,14, -5,-14, -10,11, -10,-11, 10,11, -14,-5
        db 7,13, -7,-13, 13,7, 13,-7, 7,-13, -13,7, -13,-7, -7,13, 4,14, 14,4
        db 4,-14, -14,4, 14,-4, -4,-14, -4,14, -14,-4, 8,12, -8,12, -12,8, 12,8
        db 8,-12, 12,-8, -8,-12, -12,-8, -6,13, 14,-3, 13,-6, -14,-3, -3,-14, 6,-13
        db -14,3, 3,-14, -13,6, 3,14, -13,-6, 13,6, 14,3, 6,13, -6,-13, -3,14
        db 11,9, -11,-9, 9,-11, -9,-11, 9,11, -11,9, 11,-9, -9,11, -14,2, -2,-14
        db -10,-10, 10,10, 14,2, 2,14, -2,14, -14,-2, 10,-10, 2,-14, -10,10, 14,-2
        db 1,14, 1,-14, -1,14, -14,-1, -14,1, -1,-14, 14,1, 14,-1, 14,0, -14,0
        db 0,-14, 0,14, -13,5, 13,-5, 5,-13, 5,13, -5,-13, -5,13, -13,-5, 13,5
        db 7,12, 7,-12, 12,7, -7,12, 12,-7, -12,7, -12,-7, -7,-12, 13,-4, -4,-13
        db 11,8, 4,13, 11,-8, 13,4, -13,-4, -13,4, -8,11, -11,8, 8,-11, 8,11
        db -8,-11, -4,13, 4,-13, -11,-8, -10,-9, -9,-10, 10,-9, -10,9, 9,10, 10,9
        db 9,-10, -9,10, 6,12, -12,-6, -12,6, 12,-6, 6,-12, 12,6, -6,-12, -6,12
        db -3,13, -3,-13, 13,-3, -13,3, 3,-13, -13,-3, 13,3, 3,13, -13,2, -2,-13
        db 2,13, -2,13, -13,-2, 2,-13, 13,2, 13,-2, 11,-7, 7,-11, 13,1, 13,-1
        db -13,-1, -7,-11, -11,-7, 1,-13, -11,7, -13,1, 11,7, -1,13, 1,13, -7,11
        db 7,11, -1,-13, 12,-5, -5,-12, -5,12, -12,5, -12,-5, -13,0, 0,-13, 5,-12
        db 12,5, 0,13, 5,12, 13,0, 10,8, -10,-8, -10,8, 8,10, 8,-10, -8,10
        db 10,-8, -8,-10, -9,9, -9,-9, 9,-9, 9,9, -4,12, 4,12, -12,-4, 12,-4
        db -4,-12, 4,-12, 12,4, -12,4, 11,-6, 6,11, 11,6, -6,11, -6,-11, 6,-11
        db -11,6, -11,-6, 3,12, -12,-3, 12,-3, 3,-12, -3,-12, 12,3, -3,12, -12,3
        db -7,-10, -7,10, 7,-10, 7,10, -10,-7, 10,7, 10,-7, -10,7, 12,-2, -2,12
        db 12,2, 2,-12, 2,12, -12,2, -12,-2, -2,-12, 5,11, 5,-11, 11,5, -5,11
        db 11,-5, -5,-11, -11,-5, -11,5, 8,-9, 1,12, -9,-8, 9,8, -9,8, -8,9
        db -8,-9, 8,9, 9,-8, -12,1, 12,-1, -1,-12, 12,1, 1,-12, -1,12, -12,-1
        db 0,-12, 12,0, 0,12, -12,0, -4,11, -4,-11, -11,4, 4,-11, 4,11, -11,-4
        db 11,-4, 11,4, 6,-10, -10,6, -6,-10, 10,-6, -10,-6, -6,10, 6,10, 10,6
        db -9,-7, -9,7, -3,11, 11,-3, 9,7, -7,-9, 3,-11, 9,-7, 11,3, -3,-11
        db 3,11, -7,9, 7,9, -11,3, -11,-3, 7,-9, -8,-8, 8,-8, -8,8, 8,8
        db -11,2, 10,5, -10,-5, -11,-2, 11,2, -2,-11, 11,-2, -2,11, 5,-10, 5,10
        db 2,-11, 2,11, -10,5, -5,10, -5,-10, 10,-5, 11,1, -11,-1, 1,-11, -1,-11
        db 11,-1, -11,1, -1,11, 1,11, 0,-11, -11,0, 0,11, 11,0, 9,-6, 6,9
        db -6,9, -6,-9, -9,6, 9,6, 6,-9, -9,-6, 10,4, 4,-10, 4,10, -10,4
        db 10,-4, -4,10, -10,-4, -4,-10, 8,7, -7,8, 7,-8, 7,8, -8,-7, -8,7
        db 8,-7, -7,-8, -3,10, 10,-3, -3,-10, -10,3, 10,3, -10,-3, 3,10, 3,-10
        db 5,9, -5,-9, 9,-5, 9,5, -5,9, -9,5, 5,-9, -9,-5, 2,10, 10,-2
        db -2,10, -10,-2, -10,2, -2,-10, 10,2, 2,-10, -10,-1, -10,1, 10,1, 10,-1
        db 1,-10, -1,-10, -1,10, 1,10, 8,-6, 0,10, -8,6, -6,-8, -6,8, -8,-6
        db 0,-10, -10,0, 6,-8, 6,8, 10,0, 8,6, -7,-7, 7,7, 7,-7, -7,7
        db 4,-9, 9,4, -9,-4, -9,4, 4,9, 9,-4, -4,9, -4,-9, -3,9, 3,-9
        db 9,3, -9,-3, -9,3, -3,-9, 9,-3, 3,9, 5,-8, 5,8, -5,8, 8,5
        db -5,-8, -8,-5, -8,5, 8,-5, -7,6, -7,-6, -2,-9, -6,7, -6,-7, 9,2
        db 7,-6, -9,2, -9,-2, 9,-2, -2,9, 6,-7, 2,9, 6,7, 2,-9, 7,6
        db -1,9, 9,1, -9,1, -9,-1, 1,9, 1,-9, 9,-1, -1,-9, -9,0, 0,9
        db 0,-9, 9,0, 8,-4, 4,8, -8,-4, 4,-8, -8,4, -4,8, -4,-8, 8,4
        db 5,7, -5,-7, 7,-5, 5,-7, -5,7, -7,-5, 7,5, -7,5, 8,3, -8,3
        db 8,-3, 3,-8, 3,8, -3,8, -3,-8, -8,-3, 6,-6, 6,6, -6,-6, -6,6
        db 8,-2, -2,8, -2,-8, -8,2, 2,-8, -8,-2, 8,2, 2,8, -4,-7, -8,-1
        db -8,1, -7,-4, 4,7, 4,-7, 7,4, -7,4, -4,7, 1,-8, 7,-4, -1,8
        db -1,-8, 8,1, 1,8, 8,-1, 8,0, 0,8, -8,0, 0,-8, -5,6, 5,6
        db 5,-6, -5,-6, 6,5, -6,-5, -6,5, 6,-5, 7,-3, -3,7, 7,3, -7,-3
        db 3,7, -3,-7, -7,3, 3,-7, 7,2, 2,7, -7,2, -2,7, -7,-2, 7,-2
        db 2,-7, -2,-7, -4,-6, 6,-4, -4,6, 4,6, 6,4, -6,-4, -6,4, 4,-6
        db -1,7, 1,-7, -7,1, -5,5, -1,-7, 1,7, 5,5, 5,-5, -5,-5, -7,-1
        db 7,-1, 7,1, 7,0, 0,-7, 0,7, -7,0, 3,6, -6,3, 3,-6, -3,-6
        db 6,-3, -6,-3, -3,6, 6,3, 5,-4, -4,5, -5,4, 4,-5, -5,-4, 4,5
        db 5,4, -4,-5, -6,2, -6,-2, -2,6, 2,6, 6,-2, -2,-6, 6,2, 2,-6
        db -1,6, -6,-1, 6,1, 1,6, 6,-1, -1,-6, -6,1, 1,-6, -6,0, 0,6
        db 6,0, 0,-6, -3,5, 5,3, -5,3, -3,-5, 3,-5, 5,-3, 3,5, -5,-3
        db -4,4, -4,-4, 4,4, 4,-4, 2,5, -2,5, 2,-5, -5,-2, -5,2, 5,2
        db 5,-2, -2,-5, 5,-1, 5,1, -1,-5, 1,5, -5,1, -5,-1, 1,-5, -1,5
        db -4,3, -4,-3, 4,3, 0,5, 0,-5, -3,4, -3,-4, 5,0, -5,0, 3,-4
        db 4,-3, 3,4, 2,-4, 4,-2, -4,2, -4,-2, -2,-4, 4,2, 2,4, -2,4
        db -3,-3, 3,-3, -3,3, 3,3, -1,4, 1,-4, 4,1, 1,4, -1,-4, -4,1
        db -4,-1, 4,-1, 0,4, 0,-4, -4,0, 4,0, -3,2, -2,3, 2,-3, 2,3
        db 3,-2, -2,-3, -3,-2, 3,2, -1,-3, -3,1, 3,1, -1,3, -3,-1, 1,3
        db 1,-3, 3,-1, 0,-3, 0,3, 3,0, -3,0, 2,-2, -2,-2, 2,2, -2,2
        db 2,-1, -1,2, 1,2, 1,-2, 2,1, -2,-1, -1,-2, -2,1, 2,0, 0,-2
        db -2,0, 0,2, -1,-1, 1,1, 1,-1, -1,1, 0,-1, -1,0, 1,0, 0,1
        db 0,0
bschm   dw 0                    ; wall colour scheme index 0..3
wallL   db 0                    ; current lit wall colour (N/S faces)
wallS   db 16                   ; current shaded wall colour (E/W faces)
WSCH    db 0,16, 20,21, 22,23, 24,25 ; scheme pairs: grey/blue/red/white
thmax   dw 0                    ; max raw H of the quad corners (colour pick)
; TRX/TRZ/TWH/TH: per-frame caches, in BSS past the image (see CITY.ASM)

; terrain quad draw order: (di,dj) pairs, di,dj in [-20..19], sorted by
; squared distance of the quad centre DESCENDING (painter, far -> near)
TORD    db -20,19, 19,19, 19,-20, -20,-20, 18,19, -19,19, 19,-19, 19,18, -19,-20, -20,18
        db -20,-19, 18,-20, 19,17, -18,19, -18,-20, -20,-18, -20,17, 19,-18, 17,-20, 17,19
        db 18,18, -19,-19, -19,18, 18,-19, -17,19, -20,16, -20,-17, 19,-17, 16,-20, 19,16
        db -17,-20, 16,19, 17,18, -18,18, -19,-18, -19,17, 17,-19, -18,-19, 18,17, 18,-18
        db 15,19, 19,15, 15,-20, -16,19, -20,15, -20,-16, -16,-20, 19,-16, -17,18, 18,-17
        db 18,16, -19,16, -19,-17, -17,-19, 16,-19, 16,18, 17,17, -18,17, -18,-18, 17,-18
        db 14,19, -15,19, 19,-15, 19,14, 14,-20, -20,14, -20,-15, -15,-20, 18,15, -19,15
        db -19,-16, -16,18, 15,18, -16,-19, 18,-16, 15,-19, -18,16, -17,-18, 16,17, 16,-18
        db -18,-17, 17,16, -17,17, 17,-17, -20,-14, 13,19, -14,19, 19,13, -20,13, -14,-20
        db 19,-14, 13,-20, 18,-15, 14,18, -19,-15, 14,-19, -19,14, -15,18, -15,-19, 18,14
        db 17,15, 17,-16, -18,-16, 15,17, -16,17, 15,-18, -18,15, -16,-18, 16,16, -17,16
        db -17,-17, 16,-17, -20,-13, 12,-20, 19,-13, 12,19, -13,-20, -13,19, -20,12, 19,12
        db 18,-14, 13,18, 18,13, -14,18, -14,-19, -19,13, -19,-14, 13,-19, -18,-15, -18,14
        db -15,-18, 14,17, 17,-15, 17,14, -15,17, 14,-18, -17,-16, 15,-17, 11,19, -16,-17
        db -20,11, -17,15, -20,-12, 19,-12, -16,16, 16,-16, -12,-20, 11,-20, 15,16, -12,19
        db 16,15, 19,11, 18,-13, -13,-19, -19,-13, -19,12, 12,-19, -13,18, 18,12, 12,18
        db -20,10, 19,10, -11,-20, 19,-11, 10,19, -11,19, -20,-11, 10,-20, -14,17, 13,-18
        db -14,-18, 13,17, 17,-14, 17,13, -18,-14, -18,13, 16,-15, -17,-15, 14,16, -17,14
        db 16,14, -15,-17, -15,16, 14,-17, -16,-16, -16,15, 15,-16, 15,15, 11,18, -12,18
        db -12,-19, 11,-19, 18,-12, 18,11, -19,-12, -19,11, -10,19, -20,9, 19,9, 19,-10
        db -10,-20, 9,19, 9,-20, -20,-10, 12,17, -18,12, 12,-18, -13,17, 17,-13, -13,-18
        db 17,12, -18,-13, 13,-17, 13,16, -14,16, -17,13, 16,-14, -14,-17, -17,-14, 16,13
        db -11,18, 19,-9, -19,10, -11,-19, 19,8, -9,19, -9,-20, 8,-20, -20,8, 10,-19
        db 10,18, -20,-9, 18,10, 18,-11, -19,-11, 8,19, 15,-15, 14,-16, -16,14, -15,-16
        db 15,14, -16,-15, 14,15, -15,15, -12,17, -18,-12, 17,11, -12,-18, 11,17, 11,-18
        db 17,-12, -18,11, -8,19, 19,7, -20,7, 7,19, -8,-20, 19,-8, 7,-20, -20,-8
        db -10,18, -19,9, -19,-10, 9,-19, 18,9, 9,18, -10,-19, 18,-10, -13,-17, 16,12
        db 12,16, -13,16, -17,12, 16,-13, 12,-17, -17,-13, -20,-7, -16,13, 13,15, -7,-20
        db -7,19, -16,-14, 6,19, 19,-7, 15,13, 19,6, -14,15, -20,6, 6,-20, 15,-14
        db -14,-16, 13,-16, 14,-15, 14,14, -15,-15, -15,14, -18,-11, -11,-18, 10,17, -11,17
        db -18,10, 10,-18, 17,10, 17,-11, 8,-19, -9,18, 8,18, 18,-9, -19,8, -9,-19
        db -19,-9, 18,8, -6,19, -20,-6, 5,-20, -6,-20, 5,19, -20,5, 19,5, 19,-6
        db 16,11, 11,-17, 11,16, -12,16, -17,11, 16,-12, -12,-17, -17,-12, -5,-20, 19,4
        db 19,-5, 4,19, -20,4, -5,19, 4,-20, -20,-5, -8,18, 18,-8, 18,7, -19,-8
        db 7,-19, 7,18, -8,-19, -19,7, -10,-18, -10,17, -13,-16, 15,-13, -18,9, -16,-13
        db 17,9, 17,-10, 15,12, -16,12, 9,17, -13,15, -18,-10, 12,-16, 9,-18, 12,15
        db 3,19, 3,-20, 19,-4, -15,-14, -4,-20, 19,3, -4,19, -20,-4, -20,3, -14,-15
        db -14,14, -15,13, 13,-15, 14,13, 13,14, 14,-14, -20,-3, -3,19, 19,2, -3,-20
        db 19,-3, 2,19, -20,2, 2,-20, -7,18, 18,-7, -7,-19, 6,18, -19,6, 18,6
        db -19,-7, 6,-19, -20,-2, -20,1, 10,-17, 10,16, 19,-2, 19,1, 16,-11, -2,19
        db -11,-17, 1,-20, 1,19, -2,-20, -11,16, -17,-11, -17,10, 16,10, 0,-20, 19,0
        db 19,-1, -1,-20, 0,19, -1,19, -20,-1, -20,0, -18,8, -18,-9, 17,8, -9,-18
        db 17,-9, 8,-18, 8,17, -9,17, -12,15, 15,11, -6,-19, 15,-12, -19,-6, -12,-16
        db 5,-19, -16,-12, 5,18, 18,-6, 18,5, -6,18, -16,11, 11,-16, -19,5, 11,15
        db -13,-15, 14,12, -13,14, 12,-15, -15,-13, 12,14, -15,12, 14,-13, 13,-14, 13,13
        db -14,-14, -14,13, 16,9, -17,-10, 4,18, 16,-10, 18,-5, -5,18, 7,-18, -18,-8
        db -10,16, 7,17, 17,-8, 18,4, -19,-5, 17,7, -19,4, -17,9, -10,-17, -18,7
        db -5,-19, -8,-18, 9,-17, 9,16, 4,-19, -8,17, -4,18, 3,-19, -4,-19, 18,-4
        db 18,3, 3,18, -19,-4, -19,3, -16,10, 15,10, -11,-16, 15,-11, -16,-11, 10,15
        db 10,-16, -11,15, 17,6, 17,-7, -7,17, -7,-18, 18,2, 18,-3, -3,18, 2,18
        db -19,2, -18,-7, 6,-18, 6,17, -19,-3, -18,6, 2,-19, -3,-19, -9,-17, 1,-19
        db 8,16, -17,8, -19,1, -19,-2, 8,-17, 1,18, 18,-2, 16,-9, -9,16, -2,18
        db -2,-19, 16,8, 18,1, -17,-9, -15,-12, 14,-12, 0,-19, 14,11, 11,-15, 0,18
        db 11,14, -1,18, -1,-19, -12,14, -12,-15, -15,11, 18,0, -19,-1, -19,0, 18,-1
        db -14,-13, 12,13, -14,12, -13,-14, 13,-13, 13,12, 12,-14, -13,13, -18,-6, -18,5
        db 17,-6, -6,-18, 5,17, -6,17, 17,5, 5,-18, -16,-10, 9,-16, 9,15, -16,9
        db 15,9, -10,-16, 15,-10, -10,15, 7,-17, -17,-8, 7,16, 16,-8, -17,7, 16,7
        db -8,16, -8,-17, 4,17, -5,17, -18,4, -5,-18, 4,-18, 17,-5, -18,-5, 17,4
        db -11,14, 14,-11, -15,10, 10,14, 14,10, 10,-15, -15,-11, -11,-15, -18,-4, -4,17
        db -4,-18, 17,-4, 3,17, -18,3, 3,-18, 17,3, -17,-7, -7,16, 11,-14, -17,6
        db 16,6, -14,11, 6,16, 13,-12, -12,13, 13,11, -7,-17, 11,13, -12,-14, 16,-7
        db 6,-17, -14,-12, 15,-9, 8,-16, -3,-18, -18,-3, 15,8, -16,-9, 8,15, 17,-3
        db -9,-16, -3,17, -16,8, -13,-13, 12,12, 2,-18, 17,2, 12,-13, 2,17, -18,2
        db -9,15, -13,12, -2,17, 1,17, 17,-2, 17,1, -18,-2, -18,1, 1,-18, -2,-18
        db 0,17, -18,-1, -1,-18, -18,0, -1,17, 0,-18, 17,-1, 17,0, 16,-6, 16,5
        db -17,-6, -17,5, 5,16, -6,16, -6,-17, 5,-17, -10,-15, -10,14, 9,-15, 14,9
        db -15,9, -15,-10, 14,-10, 9,14, -8,-16, 15,-8, 15,7, -16,7, 7,-16, 7,15
        db -16,-8, -8,15, 4,-17, 13,10, -11,13, -11,-14, -14,10, 13,-11, 16,-5, -5,16
        db -14,-11, 10,13, -5,-17, -17,4, 16,4, 4,16, 10,-14, -17,-5, 11,-13, -13,-12
        db -12,12, 11,12, 12,-12, 12,11, -12,-13, -13,11, -17,3, 3,-17, -4,16, 16,3
        db -17,-4, 16,-4, -4,-17, 3,16, 14,-9, -16,6, -15,-9, 6,-16, -9,14, -7,15
        db -15,8, -7,-16, 6,15, -9,-15, 8,-15, 15,6, 14,8, 8,14, 15,-7, -16,-7
        db 16,2, -3,16, -17,-3, 2,-17, -3,-17, 2,16, 16,-3, -17,2, 16,-2, -17,-2
        db 1,16, 16,1, -2,-17, -17,1, -2,16, 1,-17, -14,-10, -17,-1, -14,9, -10,13
        db -17,0, -1,-17, 9,-14, -10,-14, 16,-1, 0,-17, 16,0, 0,16, 13,9, -1,16
        db 13,-10, 9,13, -6,-16, -16,5, 15,5, -6,15, 5,-16, 5,15, 15,-6, -16,-6
        db -15,7, -13,-11, 14,7, 10,-13, 10,12, -8,14, 14,-8, 12,-11, 7,-15, -11,12
        db -8,-15, -13,10, -15,-8, 12,10, 7,14, -11,-13, -12,-12, -12,11, 11,11, 11,-12
        db -5,15, 4,-16, -5,-16, -16,-5, 15,4, 4,15, -16,4, 15,-5, -9,13, 13,8
        db -14,8, 8,13, -9,-14, -14,-9, 13,-9, 8,-14, 6,-15, 14,-7, 15,3, 6,14
        db 15,-4, -4,15, 14,6, -16,3, 3,-16, -4,-16, -7,14, -16,-4, -7,-15, 3,15
        db -15,6, -15,-7, -10,12, -3,-16, 2,-16, 9,12, 2,15, 15,2, -16,-3, 9,-13
        db -16,2, 15,-3, -13,9, -10,-13, -3,15, -13,-10, 12,-10, 12,9, -11,-12, -12,-11
        db 15,1, 1,-16, 11,-11, -12,10, 11,10, -2,-16, 1,15, 10,-12, -2,15, 10,11
        db -16,-2, -11,11, -16,1, 15,-2, 15,0, -16,0, -1,-16, -16,-1, -1,15, -15,-6
        db -6,-15, -6,14, -15,5, 5,-15, 0,15, 0,-16, 14,-6, 15,-1, 14,5, 5,14
        db 7,-14, -8,-14, -14,7, -8,13, -14,-8, 13,7, 7,13, 13,-8, 14,4, -5,-15
        db 4,14, 14,-5, 4,-15, -15,4, -15,-5, -5,14, 12,8, -9,12, 12,-9, 8,-13
        db -13,8, -9,-13, 8,12, -13,-9, 6,-14, 6,13, -14,-7, 13,6, -14,6, -7,13
        db 13,-7, -7,-14, 3,-15, 3,14, 11,9, -15,3, -12,-10, 11,-10, 14,3, 14,-4
        db -4,-15, -4,14, -15,-4, 9,11, 9,-12, -12,9, -10,11, -10,-12, -11,-11, -11,10
        db 10,10, 10,-11, 14,2, -15,-3, 2,-15, -15,2, -3,-15, 14,-3, 2,14, -3,14
        db -15,-2, -15,1, 12,-8, 12,7, 7,12, 7,-13, 5,-14, 5,13, -13,-8, 13,5
        db 14,-2, 14,1, 13,-6, -13,7, -14,5, -14,-6, 1,-15, -2,14, -8,-13, 1,14
        db -8,12, -2,-15, -6,13, -6,-14, -1,14, -1,-15, -15,0, 14,0, 0,-15, 14,-1
        db -15,-1, 0,14, 8,-12, -9,11, -12,-9, 11,8, 8,11, -9,-12, 11,-9, -12,8
        db 13,4, -14,-5, -14,4, -5,-14, -5,13, 4,13, 4,-14, 13,-5, -11,9, 10,-10
        db -10,-11, 10,9, 9,-11, -11,-10, -10,10, 9,10, -7,12, 6,-13, -7,-13, 12,-7
        db -13,6, 6,12, 12,6, -13,-7, -14,3, -4,13, -4,-14, 3,-14, 13,3, 13,-4
        db 3,13, -14,-4, 11,-8, 13,2, 7,11, 2,-14, 11,7, -12,-8, 7,-12, 13,-3
        db -14,2, -14,-3, -3,-14, -3,13, -12,7, 2,13, -8,-12, -8,11, -6,12, -13,-6
        db 5,12, -6,-13, 5,-13, 12,5, 12,-6, -13,5, 1,-14, 1,13, -14,-2, -2,13
        db -2,-14, -14,1, 13,1, 13,-2, -1,13, -14,-1, 8,10, 0,-14, 10,8, 8,-11
        db -14,0, -1,-14, 13,-1, 10,-9, -11,8, 13,0, -9,-11, 0,13, -9,10, -11,-9
        db -10,-10, 9,9, -10,9, 9,-10, -13,-5, 12,4, -13,4, -5,-13, 4,12, 12,-5
        db -5,12, 4,-13, -7,-12, -12,6, 6,-12, 11,-7, -7,11, 11,6, 6,11, -12,-7
        db -4,-13, 12,-4, -13,3, 3,-13, 3,12, 12,3, -4,12, -13,-4, 7,-11, -8,-11
        db 10,-8, 7,10, -11,7, -8,10, 10,7, -11,-8, 5,11, 11,-6, 2,12, 9,-9
        db -10,8, 5,-12, -13,2, -12,-6, 9,8, -6,-12, -6,11, -9,9, -12,5, 12,2
        db -9,-10, -3,12, 8,-10, 2,-13, 12,-3, -3,-13, 8,9, -10,-9, -13,-3, 11,5
        db 12,-2, 12,1, 1,-13, -2,12, -13,-2, 1,12, -2,-13, -13,1, -1,-13, -13,-1
        db -1,12, 12,-1, 12,0, 0,-13, 0,12, -13,0, 10,-7, -5,-12, 6,-11, -12,4
        db -7,-11, 11,4, 11,-5, -11,-7, 4,11, -12,-5, 10,6, -11,6, -5,11, -7,10
        db 6,10, 4,-12, -8,-10, 7,9, 9,-8, -10,-8, 7,-10, -8,9, 9,7, -10,7
        db -9,8, 11,3, -4,11, 8,8, 8,-9, 11,-4, -12,-4, -4,-12, 3,-12, 3,11
        db -12,3, -9,-9, -11,-6, 10,-6, 5,10, -11,5, -6,10, 5,-11, 10,5, -6,-11
        db -12,2, 11,2, 2,11, 11,-3, -3,11, -3,-12, 2,-12, -12,-3, 1,-12, -2,-12
        db 11,-2, 1,11, 11,1, -12,-2, -12,1, -2,11, -10,6, -1,-12, 9,6, 6,9
        db 0,-12, -12,0, 9,-7, 11,0, -7,-10, -10,-7, -7,9, 11,-1, 0,11, -12,-1
        db 6,-10, -1,11, 10,4, 10,-5, -11,4, -11,-5, -5,10, 4,10, 4,-11, -5,-11
        db -9,7, -8,-9, -8,8, 8,7, -9,-8, 7,-9, 7,8, 8,-8, 10,3, 10,-4
        db 3,-11, 3,10, -4,10, -11,3, -11,-4, -4,-11, -10,5, -10,-6, -6,9, -6,-10
        db 9,5, 5,9, 5,-10, 9,-6, -3,10, 2,-11, -11,-3, 2,10, -11,2, 10,2
        db -3,-11, 10,-3, 8,6, 8,-7, -7,-9, -7,8, -9,-7, 6,-9, -9,6, 6,8
        db -8,-8, 1,-11, -11,-2, 10,1, 7,7, 10,-2, 7,-8, -2,-11, -2,10, -8,7
        db -11,1, 1,10, 4,-10, 0,10, -1,10, -1,-11, -5,9, -5,-10, 10,0, 9,-5
        db 4,9, 0,-11, -10,4, -11,0, -11,-1, 9,4, -10,-5, 10,-1, 3,-10, -10,-4
        db 3,9, 9,3, 5,-9, 5,8, -10,3, -4,-10, -9,5, -4,9, -9,-6, 8,-6
        db -6,8, 9,-4, -6,-9, 8,5, 6,-8, -7,7, -7,-8, -8,-7, 7,-7, 7,6
        db 6,7, -8,6, 2,-10, -10,2, 9,-3, 9,2, -3,9, -10,-3, -3,-10, 2,9
        db 9,-2, -9,-5, -10,-2, 1,9, 4,-9, 4,8, -2,-10, -2,9, -9,4, 9,1
        db -5,-9, -5,8, -10,1, 1,-10, 8,-5, 8,4, -10,0, 9,-1, -1,-10, 0,-10
        db 9,0, 0,9, -1,9, -10,-1, -8,5, -6,7, 5,-8, -8,-6, 7,-6, 7,5
        db -6,-8, 5,7, -7,6, 6,-7, 6,6, 3,-9, -4,8, -7,-7, 8,-4, -9,-4
        db 3,8, -4,-9, 8,3, -9,3, -3,8, -3,-9, 8,-3, -9,-3, -9,2, 2,-9
        db 2,8, 8,2, -5,7, -8,-5, -8,4, 7,4, 7,-5, -5,-8, 4,-8, 4,7
        db -2,-9, -9,1, -9,-2, 8,1, -2,8, 1,8, 8,-2, 1,-9, -6,-7, -7,5
        db -6,6, 6,-6, 5,6, 5,-7, -1,-9, 6,5, 0,8, -7,-6, 0,-9, -1,8
        db -9,-1, -9,0, 8,0, 8,-1, 7,-4, -4,7, -8,-4, 3,-8, -4,-8, 3,7
        db 7,3, -8,3, 7,2, 2,7, 7,-3, -5,6, 4,6, -8,-3, 2,-8, -7,4
        db 6,-5, 6,4, 4,-7, -5,-7, -3,7, -8,2, -3,-8, -7,-5, -6,5, -6,-6
        db 5,-6, 5,5, -8,-2, 7,1, -2,7, -8,1, 7,-2, -2,-8, 1,-8, 1,7
        db 7,-1, 7,0, 0,7, 0,-8, -8,-1, -1,-8, -8,0, -1,7, -7,3, 3,-7
        db 6,-4, 6,3, -4,6, 3,6, -4,-7, -7,-4, -6,-5, -5,5, -6,4, 4,5
        db -5,-6, 5,4, 4,-6, 5,-5, 6,-3, -7,2, 6,2, -7,-3, -3,6, 2,-7
        db 2,6, -3,-7, 6,1, -7,-2, 6,-2, -2,6, -7,1, 1,-7, -2,-7, 1,6
        db -6,-4, 3,-6, -7,0, 0,6, 0,-7, -1,6, 3,5, -6,3, -7,-1, 5,-4
        db 6,0, -1,-7, -4,-6, 5,3, -4,5, 6,-1, 4,-5, 4,4, -5,-5, -5,4
        db 5,2, -6,2, -6,-3, -3,5, 2,5, -3,-6, 5,-3, 2,-6, -2,-6, 4,-4
        db 5,1, -2,5, -4,4, -4,-5, 1,5, 4,3, -5,-4, 3,-5, -6,1, 3,4
        db -5,3, 1,-6, 5,-2, -6,-2, 5,0, 0,-6, -1,-6, -1,5, 0,5, -6,0
        db -6,-1, 5,-1, 2,-5, 4,-3, 4,2, -3,4, -5,2, -5,-3, 2,4, -3,-5
        db 3,3, -4,3, -4,-4, 3,-4, 4,1, 1,-5, 4,-2, 1,4, -2,-5, -5,-2
        db -2,4, -5,1, -1,-5, -1,4, -5,-1, 0,4, -5,0, 0,-5, 4,-1, 4,0
        db 3,2, -3,-4, 3,-3, 2,-4, -3,3, 2,3, -4,2, -4,-3, 3,1, -2,-4
        db 1,-4, -4,-2, 1,3, -2,3, 3,-2, -4,1, 0,3, 2,2, 0,-4, 2,-3
        db 3,-1, 3,0, -1,-4, -1,3, -3,2, -4,0, -4,-1, -3,-3, -2,2, -2,-3
        db -3,-2, 2,1, -3,1, 2,-2, 1,2, 1,-3, -3,-1, -3,0, 0,2, 2,0
        db -1,2, 0,-3, -1,-3, 2,-1, 1,1, 1,-2, -2,1, -2,-2, -2,-1, 0,1
        db 0,-2, -1,1, -1,-2, -2,0, 1,0, 1,-1, -1,-1, 0,0, 0,-1, -1,0


camx    dw 0
camy    dw 120
camz    dw 0

bry0    dw 0                    ; building bottom (camera-relative Y = -camy)
bry1    dw 0                    ; building top (roof, camera-relative Y)

scy     dw 0
scymax  dw 0
scxl    dw 0
scxr    dw 0
ptmp    dw 0

IX      dw 4 dup(0)             ; face input verts (3D, camera-relative)
IY      dw 4 dup(0)
IZ      dw 4 dup(0)
OX      dw 6 dup(0)             ; near-clipped verts (3D)
OY      dw 6 dup(0)
OZ      dw 6 dup(0)
PX      dw 6 dup(0)             ; projected verts (screen)
PY      dw 6 dup(0)
NPOLY   dw 0
oc      dw 0
ci      dw 0
ni      dw 0
pminy   dw 0
pmaxy   dw 0

; ---- free-flight camera / trig ----
heading dw 0                    ; 0..255 = full circle
roll    dw 0                    ; signed bank angle (of 256)
hsin    dw 0                    ; sin(heading)*256
hcos    dw 0                    ; cos(heading)*256
rsin    dw 0                    ; sin(roll)*256
rcos    dw 0                    ; cos(roll)*256
wdx     dw 0
wdz     dw 0
rcx     dw 0
rcz     dw 0
rddx    dw 0
rddy    dw 0
rsxo    dw 0
; per-building work
camgi   dw 0
camgj   dw 0
gi      dw 0
gj      dw 0
cdi     dw 0                    ; cell offset from camera (was 'di' - clashed with reg)
cdj     dw 0
ring    dw 0                    ; current d^2 painter bucket
bstreet dw 0
rlod    dw 0                    ; road detail: 0 = a quad per cell, 1 = per 2x2
bhw     dw 0
bhd     dw 0
bhgt2   dw 0
fa      dw 0
fb      dw 0
wcx     dw 0
wcz     dw 0
bwx0    dw 0
bwx1    dw 0
bwz0    dw 0
bwz1    dw 0
minrz   dw 0
maxrz   dw 0
FRX     dw 4 dup(0)             ; footprint corners (camera-space X)
FRZ     dw 4 dup(0)             ; footprint corners (camera-space Z)
pk      dw 0                    ; polygon/loop counter (ENGINE E_RAST too)
; (wqx/wqy retired 2026-07-27: the glass is interpolated in camera
;  space now, so the projected-corner cache died with the old grid)
; (wfu/wfv/wtc*/wbc*/wg* retired 2026-08-03 with the old WINFACE: the
;  glass is a quad on the wall now, built from a corner lattice in BSS,
;  and none of the old per-pane scratch survived the move to TOWNSEG)
; ---- the new pane geometry (TOWNSEG's WINFACEF). The wall is a
; parallelogram, so a lattice of corners comes out of one row of column
; offsets and one column of row offsets, by addition. These are the two
; edge vectors and the cursors; the lattice itself is in BSS.
wux     dw 0                    ; U: along the wall, in camera space
wuy     dw 0
wuz     dw 0
wvx     dw 0                    ; V: up the wall
wvy     dw 0
wvz     dw 0
wi      dw 0                    ; lattice cursors
wj      dw 0
wlx     dw 0                    ; the lattice point being projected
wly     dw 0
wlz     dw 0
wbase   dw 0                    ; the cell's bottom-left lattice slot
wcxc    dw 0                    ; the pane's centre on screen
wcyc    dw 0
fbx0    dw 0                    ; the WALL's projected box: cull + detail
fbx1    dw 0
fby0    dw 0
fby1    dw 0
wquad   db 0                    ; 1 = this wall gets pane quads, 0 = dots
roofc   db 17                   ; the top face: 17 for a building, its own
                                ; paint for a vehicle
; ---- traffic (TOWNSEG's TRAFFICF). No vehicle list: a vehicle is a
; function of (lane, slot, clock), so all that is kept is the clock.
cartf   dw 0                    ; where we are in the signal cycle
caradv  dw 0                    ; whole blocks the platoons have banked
ctick   dw 0                    ; the traffic clock: last BIOS tick seen,
cfrac   dw 0                    ; where interpolation had got to inside it,
cstep   dw 0                    ; and this frame's share
vcen    dw 0                    ; the avenue's centre line
vcell   dw 0                    ; this cell's start along the lane
vstart  dw 0                    ; the clock step this lane's green begins
voff    dw 0                    ; how far into its cell a vehicle is
vadv    dw 0                    ; cells the platoon has advanced
vlane   dw 0                    ; which lane, for the hash
vslot   dw 0                    ; which vehicle on it
vaxis   dw 0                    ; 0 = length runs along Z, 1 = along X
vdir    dw 1                    ; +1 or -1 along that axis
vtype   dw 0                    ; 0..4 car, 5 bus, 6..7 truck
vh      dw 0                    ; this vehicle's hash
vcx0    dw 0                    ; its centre, before a two-box body moves it
vcz0    dw 0
vmode   dw 0                    ; 0 = the renderer is asking, 1 = a bullet
vhitf   dw 0                    ; ...and the bullet's answer
hitx    dw 0                    ; where the round is, for that question
hity    dw 0
hitz    dw 0
vhl     dw 0                    ; the struck vehicle's half extents
vhw     dw 0
vhh     dw 0
vtx     dw 0                    ; ...resolved onto the world axes
vtz     dw 0
wvk     dw 0                    ; smoke flake: vertex counter
wang    dw 0                    ; ...its angle
wrad    dw 0                    ; ...and this vertex's ragged radius
wprot   dw 0                    ; the flake's own spin
wfi     dw 0                    ; fire: which tongue of the flame
wfh     dw 0                    ; fire/glass: the flicker hash

; quarter sine table: SINT[i] = round(256*sin(i*90/64 deg)), i=0..64
SINT    dw 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115
        dw 121,126,132,137,142,147,153,157,162,167,172,177,181,185,190,194
        dw 198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243
        dw 245,247,248,250,251,252,253,254,255,255,256,256,256

x0      dw 0
y0      dw 0
z0      dw 0
x1      dw 0
y1      dw 0
z1      dw 0

sx0     dw 0
sy0     dw 0
sx1     dw 0
sy1     dw 0

tnum    dw 0
tden    dw 0

tmpi    dw 0                    ; INPUT: turn direction (-1/0/+1)
tmpsx   dw 0
tmpsy   dw 0
wr      db 0                    ; the pane's row and column: the only two
wc      db 0                    ; of the old window scratch still standing

cdx     dw 0
cdy     dw 0
nx      dw 0
ny      dw 0
oc0     db 0
oc1     db 0
ocsel   db 0

lx      dw 0
ly      dw 0
ldx     dw 0
ldy     dw 0
lsx     dw 0
lsy     dw 0
lerr    dw 0

COLOR   db 0
HCOL    db 8

; palette: 12 colors, DAC values 0..63 (R,G,B) - indigo / cornflower
; Two 18-colour palettes (DAC 0..63), toggled with the N key.
; Index map: 0 wall N/S  1 far stroke  2 mid stroke  3 near stroke
;            4 window    5 window amber 6 ground grid 7 sky top
;            8 HUD       9 sky band    10 ground     11 field/ground band
;            12 haze     13 mountains  14 water      15 forest
;            16 wall E/W (shade)       17 roof
NPALC   equ 137                 ; ...+ asphalt + 8 vehicle pairs (120..136)
NPALCOLD equ 120                ; 31 game + 63 cockpit + glow + 2 IFF +
                                ; amber + 7 NEWTON sky (SKYZ..SKYZ+6) +
                                ; ladder dim + HUD cyan + true black
                                ; + 5 PANEL colours (108..112): the cockpit
                                ; legends, deliberately far dimmer than the
                                ; HUD set they used to borrow
; (PALDAY/PALNITE moved to UISEG 2026-07-27 with SETPAL: 648 bytes of
;  once-at-startup DAC data - the stack guard's rent for the SA pages.
;  The tables and the loader live in UI.INC as APPLYPALF.)

STARN   equ 16                  ; stars as DIRECTIONS: azimuth, elevation
STARTAB dw 10,18, 35,40, 60,12, 85,55, 110,30, 135,60, 160,22, 185,45
        dw 210,15, 235,58, 5,35, 50,28, 75,56, 100,10, 200,50, 150,38

MSGTITLE db 'WIRE CITY',0
MSGALT   db 'ALT ',0
MSGHDG   db 'HDG ',0
MSGT     db 'T ',0
MSGSPD   db '  SPD ',0
MSGFUE   db '  FUEL ',0
MSGTHR   db '  THR ',0
MSGSPD2  db 'SPD',0
MSGTHR2  db 'THR',0
MSGFUE2  db 'FUEL',0
MSGHDG2  db 'HDG',0
MSGAB    db '+',0
MSGMIN2  db '-',0              ; VERT is the one readout that goes negative
MSGSTL   db 'STALL',0
MSGTER   db 'TERR',0
MSGAB2   db 'AB',0
MSGD20   db '20',0
MSGD0    db '0',0
MSGRDR   db 'RDR OFF',0
MSGH2    db 'H',0
MSGABON  db 'AB ON',0
MSGTIM   db 'T',0              ; the no-cockpit strip's clock label. It used
                               ;  to borrow MSGT2, the TERR lamp's letter -
                               ;  two unrelated things sharing one byte
; (MSGT2/F2/S2/L2 - the four one-letter caution labels - went with LAMP2.
;  SIDEPNL keeps its words in UISEG, where there is room for whole ones.)
lampx    dw 0                   ; lamp/bar scratch: x or lit-count
lampy    dw 0                   ; lamp y / bar x
lampc    db 0                   ; current lamp/segment colour
lgnd     dw 0                   ; last ground height under the jet (TERR lamp)
MSGHELP  db ' ESC',0
MSGCRASH db '*** CRASH ***',0
MSGREST  db 'SPACE = RESTART',0


