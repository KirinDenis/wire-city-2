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
resseg  dw 0                    ; segment CITY.DAT is loaded into (CS+2000h)
pimgo   dw 0                    ; cockpit bitmap offset in resseg (0 = none)
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
; model vertices (x,y,z), nose +Z, wingspan ~104 world units
MVERT   dw   0,  1, 16          ; 0 nose        (quarter scale: the WORLD
        dw  -2,  2,-11          ; 1 rear top L    reads four times as big)
        dw   2,  2,-11          ; 2 rear top R
        dw  -2, -2,-11          ; 3 rear bottom L
        dw   2, -2,-11          ; 4 rear bottom R
        dw -13,  1, -8          ; 5 wing tip L
        dw  13,  1, -8          ; 6 wing tip R
        dw   0,  1,  6          ; 7 wing root fore
        dw  -2,  1,-11          ; 8 wing rear L
        dw   2,  1,-11          ; 9 wing rear R
        dw   0,  2, -5          ; 10 fin base fore
        dw   0,  7,-13          ; 11 fin top rear
        dw   0,  2,-11          ; 12 fin base rear
; faces: 4 corner ids (triangles repeat the first) + colour
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
PVX     dw 13 dup(0)            ; camera-space vertex cache
PVY     dw 13 dup(0)
PVZ     dw 13 dup(0)
FCD     dw NFACE dup(0)         ; face depths for the painter sort
FCO     db NFACE dup(0)         ; face draw order
msin    dw 0                    ; model-vs-camera yaw sin/cos
mcos    dw 0
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
mfdmode db 0                    ; right MFD: 0 = map, 1 = target camera
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
sbok    db 0                    ; Sound Blaster found at 220h?
sbkey   db 0FFh                 ; baked waveform key: mode*8+band
sbra    db 0                    ; brown bass bound
sbwa    dw 0                    ; whine amplitude (grows with the spool)
sbga    dw 0                    ; growl amplitude (the 120..300 Hz hump)
sbwm    db 0                    ; white hiss mask
sbacc   dw 0                    ; sample accumulator (clamped to 8 bits)
sbbr    db 0                    ; brown walker, persists across refills
sbph    db 0                    ; whine phase, persists (no frame clicks)
sbgp    db 0                    ; growl phase, persists
sbmsk   db 0                    ; saved IRQ7 mask bit
sbtc    dw 0                    ; current DSP time constant
sndseg  dw 0                    ; waveform loop segment (CS+3000h)
sndofs  dw 0
sbdma   dw 0                    ; DMA offset within the page
sbpag   dw 0                    ; DMA page
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
ftx     dw 0                    ; font cursor x
fty     dw 0                    ; font cursor y
NB      db 6 dup(0)             ; number->text scratch for FNUM
FNAME   db 'CITY.DAT',0
RESMSG  db 'CITY.DAT not found - keep it next to CITY.COM',13,10,'$'
daymode db 1                    ; 1 = day palette, 0 = night (N key toggles)
prevn   db 0                    ; previous N-key state (edge detect)
bcol    db 0                    ; terrain patch colour chosen by HBLD
; rotated-background helpers (roll-aware sky/ground bands)
bgu     dw 0                    ; corner coordinate along the horizon
bgv     dw 0                    ; corner coordinate across the horizon
bgv0    dw 0                    ; band start (v, perpendicular to horizon)
bgv1    dw 0                    ; band end
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
; HMAP/MMAP live in the BSS block past the file image (see CITY.ASM): they
; are fully generated at startup, so shipping 8K of zeroes was pure waste.

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
pk      dw 0
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
wqx     dw 4 dup(0)             ; window-face projected corners
wqy     dw 4 dup(0)
wfu     dw 0
wfv     dw 0

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

wpx     dw 0
wpy     dw 0
tmpi    dw 0                    ; INPUT: turn direction (-1/0/+1)
tmpsx   dw 0
tmpsy   dw 0
wr      db 0
wc      db 0
wbi     db 0                    ; window-block pixel loop (x)
wbj     db 0                    ; window-block pixel loop (y)
wbsz    db 3                    ; window block size: 3x3 close, 1x1 further

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
NPALC   equ 98                  ; 31 game + 63 cockpit + glow + 2 IFF + amber
PALDAY  db 36,37,40          ;0  wall N/S (light grey)
        db 30,32,36          ;1  far stroke (fades to haze)
        db 22,24,28          ;2  mid stroke
        db 12,13,16          ;3  near stroke (dark on light)
        db 16,22,32          ;4  window (dark glass)
        db 24,28,38          ;5  window (lighter glass)
        db 18,32,16          ;6  ground grid
        db 18,32,58          ;7  sky top (blue)
        db 63,63,63          ;8  HUD / white
        db 34,46,62          ;9  sky band (lighter near horizon)
        db 22,38,18          ;10 ground (green)
        db 32,46,28          ;11 field / ground band near horizon
        db 50,56,63          ;12 haze at the horizon (near white)
        db 26,17,10          ;13 mountains/rock (dark brown)
        db 16,32,54          ;14 water
        db 12,27,10          ;15 forest
        db 28,29,33          ;16 wall E/W (shaded side)
        db 44,45,48          ;17 roof (sun-lit)
        db 33,24,14          ;18 minimap city (brown)
        db 63, 6, 6          ;19 red (map course tick)
        db 30,34,48          ;20 blue wall lit
        db 22,26,40          ;21 blue wall shade
        db 46,28,22          ;22 red wall lit
        db 34,20,16          ;23 red wall shade
        db 52,52,54          ;24 white wall lit
        db 40,40,44          ;25 white wall shade
        db 24,38,60          ;26 sky step 2 (F-15 gradient)
        db 42,51,63          ;27 sky step 4, next to the haze
        db 14,26,12          ;28 dark far ground at the horizon
        db 10,10,12          ;29 cockpit panel (dark)
        db 20,20,23          ;30 cockpit panel trim
        include PALPNL.INC   ; 31..93 photo cockpit (generated)
        db 63,34, 6          ;94 engine glow (GAMELOOP cycles this DAC slot)
        db 16,63,16          ;95 IFF friendly (bright green)
        db 63,63, 8          ;96 IFF hostile (bright yellow)
        db 63,44, 6          ;97 UI amber (index 5 is glass by day)

PALNITE db  2, 3, 9          ;0  wall N/S (dark body)
        db 12,18,40          ;1  far stroke
        db 22,33,58          ;2  mid stroke
        db 40,55,63          ;3  near stroke (bright on dark)
        db 50,60,63          ;4  window (lit cyan)
        db 63,48,20          ;5  window (lit amber)
        db 10,16,34          ;6  ground grid
        db  6, 9,22          ;7  sky top
        db 60,63,63          ;8  HUD / white
        db 12,17,40          ;9  sky band (city glow)
        db  4, 6,16          ;10 ground
        db  7,10,24          ;11 field / ground band
        db 18,24,48          ;12 haze (glow at horizon)
        db 10, 7, 4          ;13 mountains/rock (dark brown)
        db  8,14,38          ;14 water
        db  3, 7,13          ;15 forest
        db  2, 3, 9          ;16 wall E/W (same as body at night)
        db  3, 4,11          ;17 roof
        db 14,10, 6          ;18 minimap city (brown)
        db 52, 5, 5          ;19 red (map course tick)
        db  4, 5,14          ;20 blue wall lit
        db  3, 4,11          ;21 blue wall shade
        db  8, 4, 5          ;22 red wall lit
        db  6, 3, 4          ;23 red wall shade
        db  5, 6,12          ;24 white wall lit
        db  4, 4, 9          ;25 white wall shade
        db  8,12,30          ;26 sky step 2
        db 14,19,44          ;27 sky step 4, next to the haze
        db  2, 4,10          ;28 dark far ground at the horizon
        db  6, 6, 8          ;29 cockpit panel (dark)
        db 12,12,15          ;30 cockpit panel trim
        include PALPNL.INC   ; 31..93 photo cockpit (same lamps at night)
        db 63,34, 6          ;94 engine glow (GAMELOOP cycles this DAC slot)
        db 16,63,16          ;95 IFF friendly (bright green)
        db 63,63, 8          ;96 IFF hostile (bright yellow)
        db 44,30, 4          ;97 UI amber (dimmed for the night)

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
MSGSTL   db 'STALL',0
MSGTER   db 'TERR',0
MSGAB2   db 'AB',0
MSGT2    db 'T',0
MSGF2    db 'F',0
MSGD20   db '20',0
MSGD0    db '0',0
MSGRDR   db 'RDR OFF',0
MSGS2    db 'S',0
MSGH2    db 'H',0
MSGABON  db 'AB ON',0
MSGL2    db 'L',0
lampx    dw 0                   ; lamp/bar scratch: x or lit-count
lampy    dw 0                   ; lamp y / bar x
lampc    db 0                   ; current lamp/segment colour
lgnd     dw 0                   ; last ground height under the jet (TERR lamp)
MSGHELP  db ' ESC',0
MSGCRASH db '*** CRASH ***',0
MSGREST  db 'SPACE = RESTART',0
