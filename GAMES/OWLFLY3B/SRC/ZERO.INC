; ZERO.INC - part of OWL FLY III BOND (included from OWLFLY3B.ASM, at the
; very end of CODE, between the key tables and the BSS)
;
; Every variable of the main segment that v3 declared as a plain zero
; ("dw 0", "db N dup(0)") lives here now, RESERVED rather than stored:
; CODE is the last segment of the EXE, so reserved space at its end costs
; the file nothing - DOS hands it over at load, and MAIN clears it, KEYS
; through BSSEND, before anything reads it. 2K out of the file.
;
; Moved by order, so neighbours stay neighbours: an array and the ghost
; slot after it (pax, ghpax) arrive together. A variable whose start value
; is NOT zero stays in DATA.INC - declare new zero variables here.
bufseg  rw 1
oldoff  rw 1                    ; saved INT 9 vector (keyboard)
oldseg  rw 1
gndy    rw 1                    ; where GRID's plane sits: the ground height
lasttk  rw 1                    ; BIOS tick (0040:006C low word) at previous frame
flaps   rb 1                    ; F: high lift, high drag, low stall
gear    rb 1                    ; L: three legs in the wind
gearp   rb 1
abrk    rb 1                    ; B: the airbrake
onrwy   rb 1                    ; 1 = on her wheels. LANDF sets it at the
                                ;  moment of arrival, GNDSCH clears it when
                                ;  the advance carries her clear again, and
                                ;  it is what stops a TAKEOFF being ruled a
                                ;  crash: a roll accelerates straight through
                                ;  VAPP, which is exactly what LANDF refuses
hdgr    rw 1                    ; nose-wheel steering, 8.8 residue. Whole
                                ;  units of heading are far too coarse at
                                ;  taxi speed - truncating per tick rounds
                                ;  every slow turn to nothing at all
vsp8    rw 1                    ; SINK RATE in 8.8 units a tick. vvy beside
                                ;  it is this same number rounded to whole
                                ;  units for the IVV caret, and a whole unit
                                ;  a tick is about nine metres a second -
                                ;  three times a gear-collapsing arrival. A
                                ;  landing cannot be judged on it, so the
                                ;  school keeps the fraction the trainer
                                ;  keeps, and TDSLAM/TDFIRM are the trainer's
                                ;  own numbers unchanged
dirtd   rb 1                    ; how long she has been grinding through the
                                ;  grass; GNDGRND of it and she is finished
swtac   rb 1                    ; T: TACAN - the steer home on the glass
swmode  rb 1                    ; O: master mode. 0 = air-to-air, 1 = air-
                                ;  to-ground. ONE state on TWO buttons, the
                                ;  way a real mode switch is: A-A lit or
                                ;  A-G lit, never both and never neither
swap    rb 1                    ; P: autopilot
swecm   rb 1                    ; J: ECM
swjmr   rb 1                    ; Y: noise jammer
teff    rw 1                    ; effective thrust this tick (scratch)
fwd     rw 1                    ; forward units this tick = vel/16 (scratch)
pitch   rw 1                    ; pitch angle, signed -64..64 (64 = straight up)
psin    rw 1                    ; sin(pitch)*256
pofs    rw 1                    ; background horizon shift = tan(pitch)*FOCAL
abon    rb 1                    ; afterburner active this tick
mmzs    rb 1                    ; map zoom as a SHIFT: 0/1/2 = 1/2/4 px a node
mmcol0  rw 1                    ; the window's top-left node, column...
mmrow0  rw 1                    ;  ...and row (row 0 is the world's north)
mmspx   rw 1                    ; how many nodes fit across at this zoom...
mmspy   rw 1                    ;  ...and down. Both change with mmzs.
resseg  rw 1                    ; segment CITY.DAT is loaded into (CS+2C00h)
sview   rb 1                    ; 0 forward, 1 looking left, 2 looking right.
                                ; The saved heading and the four key edges
                                ; that go with it are CS-relative in SYMSEG:
                                ; only SVIEWF ever touches them, and this
                                ; segment is down to its last dozen bytes
swph    rw 1                    ; sway: phase, full circle = 65536
swayx   rw 1                    ; sway: this tick's X shift (screen px)
swayy   rw 1                    ; sway: this tick's Y shift (screen px)
pax     rw NPLANE        ; world position
ghpax   rw 1
pay     rw NPLANE
ghpay   rw 1
paz     rw NPLANE
ghpaz   rw 1
pah     rw NPLANE        ; heading 0..255
ghpah   rw 1
ptype   rb NPLANE        ; 0 fighter / 1 bomber / 2 radar /
ghptp   rb 1                    ;  3 transport / 4 tanker (FORMATION)
pltr    rb NPLANE        ; callsign letter of the human in the
ghplt   rb 1                    ;  slot (ASCII, from pid; 0 = none)
netboom rb 1                    ; 1 = this BOOM is the wire's, let it pass
nethdm  rb 1                    ; damage points that arrived for US
nethby  rw 1                    ; who dealt them (pid)
lastklr rw 1                    ; who shot us down (rides our death POS)
wseed   rw 1                    ; the seed the world was built from
netup   rb 1                    ; 1 = IPX answered at startup
netpid  rw 1                    ; our name on the wire (spawn fan-out)
gact    rb 1                    ; the front door's verdict: 1 create, 2 join
uidl    rw 1                    ; ...and the tick it stops listening at
ggid    rw 1                    ; which sky we are in (the host's pid)
gname   rb 9             ; our sky's name (8 + NUL)
rgk     rw 1                    ; the radar grid's walkers
rgj     rw 1
bordz   rw 17            ; the front line: jagged z offsets (BRDGEN)
hbslp   rw 1                    ; the lean in force: -HBLEAN on the left
                                ;  tape, +HBLEAN on the right, 0 with the
                                ;  cockpit down (no bows to follow)
afx    rw NAF          ; where each strip ended up: its centre,
afy    rw NAF          ;  the flattened ground under it,
afz    rw NAF
afi    rw 1                    ; the strip being sited or drawn
rspin   rw 1                    ; the dish angle 0..255 - both dishes turn
rs_i     rw 1                    ; the station being ticked or drawn
rhx     rw 1                    ; RSHIT's question: did anything of ours
rhy     rw 1                    ;  reach this point in the world...
rhz     rw 1
rhdmg   rb 1                    ;  ...and how hard (1 a shell, 4 a missile)
tgyc    rw 1                    ;  of the model on the glass
lkx     rw 1                    ; LKPOS: where the locked target actually is,
lky     rw 1                    ;  jet or radar station - every reader of
lkz     rw 1                    ;  the lock goes through here now
rsnet   rb 1                    ; a station fell HERE: tell the wire (idx+1)
rsboom  rb 1                    ; the wire says one fell THERE: light the
                                ;  fire in the main segment (idx+1)
TYPN0   rb 1                    ; fighters wear no tag
PVX     rw 25            ; camera-space vertex cache (max: bomber)
PVY     rw 25
PVZ     rw 25
FCD     rw 16            ; face depths for the painter sort
FCO     rb 16            ; face draw order (16: the F15.DAT cap)
msin    rw 1                    ; model-vs-camera yaw sin/cos
mcos    rw 1
mpon    rb 1                    ; 1 = this model pitches at its trunnion
mpsn    rw 1                    ; the pitch, sin/cos *256
trnpy    rw 1                    ; where the trunnion is, in model space
trnpz    rw 1
trnvy    rw 1                    ; the vertex being turned, y and z
trnvz    rw 1
trnvy2   rw 1                    ; ...relative to the trunnion
trnvz2   rw 1
pdx     rw 1                    ; plane centre in camera space
pdy     rw 1
pdz     rw 1
pidx    rw 1                    ; draw loop: plane offset
pfc     rw 1                    ; draw loop: face counter
tpi     rw 1                    ; draw loop: trail point counter
tlh     rw 1                    ; shared ring head (byte offset, step 2)
lockd   rw 1                    ; lock scan: best distance so far
mfdmode rb 1                    ; centre MFD page: 0 MAP / 1 SIT / 2 TGT
rbcx    rw 1                    ; RBLIPS: scope centre column
rbcy    rw 1                    ; RBLIPS: scope centre row
rbsh    rb 1                    ; RBLIPS: zoom shift for this scope
bqcr    rw 1                    ; BQCITY: how many cells the glass reaches
bqci    rw 1                    ;  ...the cell we stand in...
bqcj    rw 1
bqcu    rw 1                    ;  ...and the walk across the box
bqcv    rw 1
gmkn    rw 1                    ; GNDMARK: the size numerator for this kind
gmks    rb 1                    ;  ...and 0 = square (ours), 1 = diamond
bqx     rw 1                    ; symbol centre on the glass
bqy     rw 1
bqa     rw 1                    ; its heading, 0..255, relative to ours
bqsn    rw 1                    ; sin/cos of that, *256
bqcs    rw 1
bqal    rw 1                    ; BQPT's arguments: along the nose...
bqac    rw 1                    ;  ...and out to the right, in symbol units
pcs     rb NPLANE        ; callsign: name table index (0..3)
pnum    rb NPLANE        ; callsign: number 1..32
msact   rb 1                    ; missile in flight?
msx     rw 1                    ; missile world position
msy     rw 1
msz     rw 1
mpx     rw 1                    ; previous position (smoke puff)
mpy     rw 1
mpz     rw 1
mvx     rw 1                    ; straight-flight velocity (no lock)
mvy     rw 1
mvz     rw 1
mlife   rw 1                    ; ticks to self-destruct
msi     rw 1                    ; the slot in the working set, as a WORD index
mcsl    rw 1                    ; ...and the one the missile camera rides
wnext   rw 1                    ; wreck pool: next slot byte offset
amact   rb NAMSL         ; slot in flight?
amx     rw NAMSL         ; position
amy     rw NAMSL
amz     rw NAMSL
ampx    rw NAMSL         ; previous position (exhaust puff)
ampy    rw NAMSL
ampz    rw NAMSL
amtgt   rw NAMSL         ; target plane offset
amlife  rw NAMSL         ; self-destruct timer
pdam    rb 1                    ; player damage taken (8 = shot down)
ocx     rw 1                    ; camera state before the physics burst
ocy     rw 1
ocz     rw 1
ohd     rw 1
opt     rw 1
orl     rw 1
lvx     rw 1                    ; true state parked during the lerped frame
lvy     rw 1
lvz     rw 1
lvh     rw 1
lvp     rw 1
lvr     rw 1
fcnt    rw 1                    ; frames since the last physics burst
fprev   rw 1                    ; frames the previous interval lasted
chsview rb 1                    ; F3 chase camera on?
tgtcam  rb 1                    ; F4 orbit camera on the locked target
mslcam  rb 1                    ; F5: ride the next missile?
mcact   rb 1                    ; 0 off, 1 riding, 2 watching the kill
mcret   rw 1                    ; aftermath timer (~3 s)
mch     rw 1                    ; camera course (servo-follows the missile)
mimx    rw 1                    ; where the missile ended (the grave)
mimy    rw 1
mimz    rw 1
sndsel  rb 1                    ; the third front-step screen: 0 Blaster,
                                ;  1 PC speaker, 2 no sound at all
spkon   rb 1                    ; the speaker path is live (sndsel said 1)
spkfx   rb 1                    ; speaker effect playing now - 0 none, else
                                ;  its id, and the id IS its priority
spkfn   rb 1                    ; ...frames it has left to run
spkdv   rw 1                    ; ...its current PIT divisor
paused  rb 1                    ; ESC: the world stands still, the glass
shcabsg rw 1                    ; where the Shilka cabin blob sits (0 =
                                ;  none). In the MAIN segment because two
                                ;  far segments share it: SYMSEG loads it
                                ;  (SHCABLDF picks the file by card),
                                ;  UISEG draws it (SHCABDRW)
tapup   rb 1                    ; the tap rescue (the 486 report): a
tapdn   rb 1                    ;  flight key pressed AND released
taplf   rb 1                    ;  between two frames never shows in
taprt   rb 1                    ;  KEYS - KHIT catches it, GAMELOOP
tapw    rb 1                    ;  grants it exactly ONE physics tick
tapsd   rb 1                    ;  through these six (W and S too)
tapsp   rb 1                    ; ...and SPACE: the death screen said
                                ;  PRESS SPACE and a tap said nothing
pvk     rb 7             ; was each held at the LAST frame's look?
                                ;  typematic re-arms KHIT the whole hold,
                                ;  so a release left a phantom tap that
                                ;  kept qramp alive - the v10 jerk
fpsn    rw 1                    ; frames counted this second...
fpst    rw 1                    ; ...since this BIOS tick...
fpsv    rw 1                    ; ...and the number the glass shows
mlvl    rw 1                    ; manoeuvre loading (smoothed, 0..48)
lastbp  rw 1                    ; last tick a lamp beeped on
mprvp   rw 1                    ; previous pitch (for the delta)
mprvr   rw 1                    ; previous roll
qramp   rw 1                    ; elevator ramp: a tap is a feather (2/8
                                ;  unit), a hold builds to 16/8 in ~0.4 s
gq      rw 1                    ; the ramp SIGNED, for the HUD's G meter
                                ;  (+pull, -push, 0 hands-off)
vvy     rw 1                    ; climb per tick, world units (the IVV)
pfrac   rw 1                    ; pitch fraction accumulator (eighths)
hfrac   rw 1                    ; heading fraction accumulator (eighths)
scrseg  rw 1                    ; far scratch segment (holds the minimap)                    ; sample loop segment (64K-aligned)
sbn2    rw 1                    ; the audio spool: the note chases the
                                ;  lever from 0 - startup whine for free
spect   rb 1                    ; 1 = watching, not flying
sptmr   rw 1                    ; ticks until it moves on by itself
prevsp  rb 1                    ; Space's own edge, while spectating
tgti    rw 1                    ; orbited plane (kept past the lock)
tcws    rw 1                    ; wreck slot the camera follows (mode 2)
tgaz    rw 1                    ; orbit azimuth (0..255)
dying   rb 1                    ; player down: cinematic fall running
dytick  rw 1                    ; ...for how long (Space works after 1 s)
flbh    rw 1                    ; black box: ring head (next write)
flbc    rw 1                    ; flashback: playback cursor
flbcnt  rw 1                    ; flashback: samples left to play
svh     rw 1                    ; saved heading (flashback swaps it too)
dcx     rw 1                    ; frozen death-camera position
dcy     rw 1
dcz     rw 1
bpx     rw 1                    ; WRKFILL input: breakup position
bpy     rw 1
bpz     rw 1
bph     rw 1                    ; WRKFILL input: breakup heading
svx     rw 1                    ; pilot's world, saved during the chase
svy     rw 1
svz     rw 1
svp     rw 1                    ; saved pitch
svr     rw 1                    ; saved roll
rndovr  rw 1                    ; round-over countdown (0 = fighting)
rwin    rb 1                    ; who wiped whom: 0 = friendlies won
bhph    rb 4             ; ...and their remaining hits
bhnext  rw 1                    ; round robin for fresh victims
phit    rw 1                    ; player hit flash timer. Set to 9 at all
                                ;  THREE places the player can be hit - a
                                ;  cannon round, the flak, and the wire -
                                ;  which is why every part of the hit
                                ;  reaction hangs off it and none of them
                                ;  needed a call site of their own
phitp   rw 1                    ; ...and what it was last tick. A hit is the
                                ;  EDGE, and it has to be caught by comparing
                                ;  rather than by testing for 9: the three
                                ;  damage sites do not all run before the
                                ;  tick that counts phit down, so "it equals
                                ;  9 now" is true on different ticks
                                ;  depending on who shot you
tscf    rw 1                    ; team score: hostiles downed
tsch    rw 1                    ; team score: friendlies downed
psc     rw 1                    ; personal kills
guntik  rb 1                    ; tracers on screen while > 0
hitft   rw 1                    ; ...and for how many ticks
trcact  rb NTRC          ; round in flight?
tcx     rw NTRC          ; position
tcy     rw NTRC
tcz     rw NTRC
trvx    rw NTRC          ; velocity (150/tick + spread, droops)
trvy    rw NTRC
trvz    rw NTRC
trlif   rw NTRC          ; ticks to burn out
trnext  rw 1                    ; ring: next slot to fire from
ctx     rw 1                    ; BOOM scratch: face centroid
cty     rw 1
ctz     rw 1
wcc     rw 1                    ; BOOM scratch: corner counter
hbsx    rw 1                    ; HUD tapes: speed spine x
hbslb   rw 1                    ; speed labels/value x
hbst1   rw 1                    ; speed major tick x
hbst2   rw 1                    ; speed minor tick x
hbcx    rw 1                    ; speed critical mark x
hbax    rw 1                    ; altitude spine x
hbalb   rw 1                    ; altitude labels/value x
hbat1   rw 1                    ; altitude major tick x
hbat2   rw 1                    ; altitude minor tick x
hbacx   rw 1                    ; altitude critical mark x
hbscur  rw 1                    ; speed CURRENT value x (outboard side)
hbacur  rw 1                    ; altitude CURRENT value x (outboard)
ftx     rw 1                    ; font cursor x
fty     rw 1                    ; font cursor y
NB      rb 6             ; number->text scratch for FNUM
clipx0  rw 1
clipy0  rw 1
dbgm    rb 1                    ; 1 = the marks are drawn
bcol    rb 1                    ; terrain patch colour chosen by HBLD
wdith   rb 1                    ; 1 = spans get the per-pixel world grain
sinr    rw 1
wdx2    rw 1                    ; WCAM2: world delta in, camera pair out
wdz2    rw 1
cldu    rw 1
cldd    rw 1
lp      rw 1                    ; rung index, tens of degrees
lfc     rw 1                    ; f of the screen centre
lke     rw 1                    ; last rung of this frame's four
lcx     rw 1                    ; the rung's centre on screen
lcy     rw 1
lx8     rw 1                    ; the walk along the line, 8.8
ly8     rw 1
li      rw 1                    ; which pixel of the walk
lpx     rw 1                    ; the pixel's column
lsn     rw 1                    ; sin scratch for the tangent
dss     rw 1                    ; DS: current side length  (E_TERR's DSGEN
dsh     rw 1                    ; DS: half side            assembles, never runs)
dsx     rw 1                    ; DS: loop x / scratch
dsy     rw 1                    ; DS: loop y / scratch
dsamp   rw 1                    ; DS: noise amplitude (power of two)
dsac    rw 1                    ; DS: accumulator
tta     rw 1                    ; node-grid loop a (0..NSIDE-1)
ttb     rw 1                    ; node-grid loop b
gbase   rw 1                    ; ground height under the current cell (world)
btype   rw 1                    ; building type: 0 box 1 spire 2 tower 3 arch 4 factory
boxb    rw 1                    ; current box: bottom, relative to gbase
boxt    rw 1                    ; current box: top, relative to gbase
pwcx    rw 1                    ; saved cell centre (composite buildings move wcx)
pwcz    rw 1
puffk   rw 1                    ; smoke puff loop counter
sbh     rw 1                    ; superblock hash (district decisions)
bdist   rw 1                    ; district: 0/3 residential, 1 downtown, 2 industry
bschm   rw 1                    ; wall colour scheme index 0..3
wallL   rb 1                    ; current lit wall colour (N/S faces)
camx    rw 1
camz    rw 1
bry0    rw 1                    ; building bottom (camera-relative Y = -camy)
bry1    rw 1                    ; building top (roof, camera-relative Y)
scy     rw 1
scymax  rw 1
scxl    rw 1
scxr    rw 1
ptmp    rw 1
IX      rw 4             ; face input verts (3D, camera-relative)
IY      rw 4
IZ      rw 4
OX      rw 6             ; near-clipped verts (3D)
OY      rw 6
OZ      rw 6
PX      rw 6             ; projected verts (screen)
PY      rw 6
NPOLY   rw 1
oc      rw 1
ci      rw 1
ni      rw 1
pminy   rw 1
pmaxy   rw 1
heading rw 1                    ; 0..255 = full circle
roll    rw 1                    ; signed bank angle (of 256)
hsin    rw 1                    ; sin(heading)*256
hcos    rw 1                    ; cos(heading)*256
rsin    rw 1                    ; sin(roll)*256
rcos    rw 1                    ; cos(roll)*256
wdx     rw 1
wdz     rw 1
rc_x     rw 1
rc_z     rw 1
rddx    rw 1
rddy    rw 1
rsxo    rw 1
camgi   rw 1
camgj   rw 1
gi      rw 1
gj      rw 1
cdi     rw 1                    ; cell from camera (was 'di' - clashed with reg)
cdj     rw 1
ring    rw 1                    ; current d^2 painter bucket
bstreet rw 1
bhw     rw 1
bhd     rw 1
bhgt2   rw 1
fa      rw 1
fb      rw 1
wcx     rw 1
wcz     rw 1
bwx0    rw 1
bwx1    rw 1
bwz0    rw 1
bwz1    rw 1
minrz   rw 1
maxrz   rw 1
FRX     rw 4             ; footprint corners (camera-space X)
FRZ     rw 4             ; footprint corners (camera-space Z)
pk      rw 1                    ; polygon/loop counter (ENGINE E_RAST too)
cartf   rw 1                    ; where we are in the signal cycle
caradv  rw 1                    ; whole blocks the platoons have banked
ctick   rw 1                    ; the traffic clock: last BIOS tick seen,
cfrac   rw 1                    ; where interpolation had got to inside it,
cstep   rw 1                    ; and this frame's share
x0      rw 1
y0      rw 1
z0      rw 1
x1      rw 1
y1      rw 1
z1      rw 1
sx0     rw 1
sy0     rw 1
sx1     rw 1
sy1     rw 1
tnum    rw 1
tden    rw 1
tmpi    rw 1                    ; INPUT: turn direction (-1/0/+1)
cdx     rw 1
cdy     rw 1
nx      rw 1
ny      rw 1
oc0     rb 1
oc1     rb 1
ocsel   rb 1
lx      rw 1
ly      rw 1
ldx     rw 1
ldy     rw 1
lsx     rw 1
lsy     rw 1
lerr    rw 1
COLOR   rb 1
lampc    rb 1                   ; current lamp/segment colour
lgnd     rw 1                   ; last ground height under the jet (TERR lamp)
