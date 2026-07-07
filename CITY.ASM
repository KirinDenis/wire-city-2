; ============================================================================
;  CITY.ASM  -  "WIRE CITY" : night flight over a wireframe city
;  VGA mode 13h (320x200x256), 8086 only, integer math,
;  wireframe graphics, near-Z clipping + screen line clipping.
;
;  Build with TASM (in DOSBox):
;       TASM CITY.ASM
;       TLINK /T CITY.OBJ          ->  CITY.COM
;
;  Controls:    arrows  - left/right/up/down (maneuver)
;               ESC     - quit
;               SPACE   - restart after a crash
;
;  Fly forward down the corridor. Skyscrapers (with windows) stand on
;  both sides. Drift sideways into a building (below its roof) -> CRASH.
; ============================================================================

; ----------------------------------------------------------------------------
;  ARCHITECTURE / CONVENTIONS  (read this before touching the rendering code)
;
;  Render pipeline for every world vertex:
;     world (wx,wz)
;       -> camera-relative   : dx=wx-camx, dz=wz-camz
;       -> ROTXZ (yaw)        : (rcx,rcz)  rotate by heading
;       -> NEARCLIP           : clip polygon/edge to camera-space rcz >= NEARZ
;       -> PROJPT (perspective): sx=160+rx*FOCAL/rz, sy=100-ry*FOCAL/rz
;       -> APPLYROLL (bank)    : rotate (sx,sy) about screen centre (160,100)
;       -> CLIPLINE / SCANPOLY : 2D clip to 320x200, then draw
;     HUD text + crosshair are drawn in raw screen space (NOT rolled).
;
;  FIXED-POINT: all trig is sin/cos * 256 (see SINT/SINQ). A rotate is
;     therefore  (a*cos +/- b*sin) / 256 , done as imul (->DX:AX) then
;     idiv 256. Per-term division is used (good to +/-1 lsb) to avoid 32-bit
;     adds. Products stay < ~500k so they fit DX:AX; quotients fit 16-bit.
;
;  16-BIT WRAP: camx/camz are signed 16-bit and may wrap as you fly far.
;     This is fine: every position is used only as a *relative* offset
;     (worldX - camx) computed mod 65536, which is exact for small offsets,
;     so the city stays consistent through wrap (period 65536 units).
;
;  GLOBAL REGISTER/STATE CONTRACTS (held across the whole render):
;     DS = CS (all variables live in the code segment).
;     ES = bufseg during RENDER/CROSS (pixel writes go to the back-buffer);
;          ES = A000h only inside BLIT and CRASHHANDLE.
;     COLOR (byte) = current draw colour (palette index) for LINE/SCANPOLY.
;     SETTRIG must run each frame before RENDER (fills hsin/hcos/rsin/rcos).
;
;  COORDS: PROJPT returns sx in AX, sy in DX. SINQ returns sin*256 in AX.
;  DEAD CODE (assembled but never called) is tagged "DEAD" in its banner.
; ----------------------------------------------------------------------------

        .8086
        LOCALS
        JUMPS                   ; auto-extend out-of-range conditional jumps
                                ;   (emits jcc short + jmp near; pure 8086)

; ---- world constants -------------------------------------------------------
FOCAL   equ 160                 ; projection focal length
CELL    equ 256                 ; grid pitch (doc only; code uses shl/shr 8 and 128)
BIAS    equ 8192                ; world->cell bias (keeps cell math unsigned)
RAD     equ 9                   ; building render radius (cells)
MAXD2   equ RAD*RAD*2           ; max squared cell distance (painter buckets)
GR      equ 7                   ; ground-grid radius (cells)
NEARZ   equ 40                  ; near clip plane
FARZ    equ 21600               ; far clip distance
MEGR    equ 20                  ; far-belt radius in 4x4-cell megablocks
CEIL    equ 1500                ; flight ceiling (max camy)

; ---- jet flight model (all per 18.2 Hz physics tick) ------------------------
; Forces: thrust vs drag decide airspeed; climb/dive trade speed <-> altitude
; (energy management); air density (rho) falls with altitude, cutting both jet
; thrust and drag -> higher up = faster top speed. Fuel burns while the engine
; runs; mass = MEMPTY + fuel/3, and acceleration = force/mass. Wind drifts the
; plane in world space. Below VSTALL the nose drops and climb is impossible.
; vel is airspeed *16 fixed point; forward motion per tick = vel/16 units.
THRUST  equ 720                 ; engine thrust (force units)
DRAGK   equ 256                 ; drag divisor: drag = vel*rho/DRAGK
MEMPTY  equ 4000                ; empty mass
FUELMAX equ 6000                ; full tank (1 unit burned per tick ~ 5.5 min)
VSTALL  equ 300                 ; stall airspeed (vel units)
CRUISE  equ 736                 ; initial airspeed (= 46 units/tick, old feel)
TURNDRG equ 2                   ; induced drag per tick while turning
WINDX   equ 2                   ; wind drift, world units per tick
WINDZ   equ -1
TURNV   equ 4                   ; heading change per tick
BANKMAX equ 30                  ; max bank/roll angle (of 256) - an angle, not a rate
BANKSTP equ 12                  ; bank approach/decay per tick

; ---- fixed-timestep physics clock ------------------------------------------
; We touch NOTHING in the hardware: no INT 8 hook, no PIT reprogram (both hung
; in this emulator). We just READ the stock BIOS timer tick at 0040:006C, which
; advances at its native 18.2 Hz in real time. Physics runs one INPUT step per
; elapsed tick -> constant real-world speed at any render rate. Coarse but
; rock-solid: nothing to install, nothing to restore, nothing to hang.
MAXSTEP equ 6                   ; max physics steps per render (anti-spiral)

; ---- keyboard scan codes ---------------------------------------------------
SC_ESC  equ 01h
SC_UP   equ 48h
SC_DN   equ 50h
SC_LF   equ 4Bh
SC_RT   equ 4Dh
SC_SP   equ 39h
SC_N    equ 31h                 ; N key: toggle day/night palette

CODE    SEGMENT
        ASSUME  CS:CODE, DS:CODE, ES:CODE, SS:CODE
        ORG 100h

START:  jmp  MAIN

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
horiz   dw 100                  ; screen horizon row: pitch visual (78..122);
                                ; nose up -> world slides down (horiz > 100)
daymode db 1                    ; 1 = day palette, 0 = night (N key toggles)
prevn   db 0                    ; previous N-key state (edge detect)
bcol    db 0                    ; terrain patch colour chosen by HBLD
; rotated-background helpers (roll-aware sky/ground bands)
bgu     dw 0                    ; corner coordinate along the horizon
bgv     dw 0                    ; corner coordinate across the horizon
bgv0    dw 0                    ; band start (v, perpendicular to horizon)
bgv1    dw 0                    ; band end
; mountain / megablock work
cammgi  dw 0                    ; camera megablock (cell>>2)
cammgj  dw 0
mring   dw 0                    ; current megablock ring

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
HMAP    db 4096 dup(0)          ; heights 0..255, addr = (x&63)*64 + (y&63)
MMAP    db 4096 dup(0)          ; minimap pixels, baked once from HMAP; row-
                                ; major screen layout, row = 63-nodeZ (north up)

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
thmax   dw 0                    ; max raw H of the quad corners (colour pick)
TRX     dw 1681 dup(0)          ; rotated node X (camera space), a*41+b
TRZ     dw 1681 dup(0)          ; rotated node Z
TWH     dw 1681 dup(0)          ; world height of node (after WORLDH mapping)
TH      db 1681 dup(0)          ; raw map height of node (for colours/water)

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
NPALC   equ 20
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

STARN   equ 16                  ; star coords as words (X can exceed 255)
STARTAB dw 20,18, 60,30, 110,12, 150,40, 200,22, 250,15, 300,35, 40,52
        dw 90,60, 175,55, 230,48, 285,58, 130,70, 70,8, 260,70, 310,28

MSGTITLE db 'WIRE CITY',0
MSGALT   db 'ALT ',0
MSGHDG   db 'HDG ',0
MSGT     db 'T ',0
MSGSPD   db '  SPD ',0
MSGFUE   db '  FUEL ',0
MSGHELP  db '  ESC:QUIT',0
MSGCRASH db '*** CRASH ***',0
MSGREST  db 'SPACE = RESTART',0

; ============================================================================
;  KEYBOARD INTERRUPT HANDLER (INT 9)
;  Own key-state table KEYS[scancode] = 1 pressed / 0 released
; ============================================================================
KBINT:  push ax
        push bx
        push di
        push ds
        mov  ax,cs
        mov  ds,ax
        in   al,60h
        mov  ah,al
        and  al,7Fh
        mov  bl,al
        xor  bh,bh
        mov  di,offset KEYS
        add  di,bx
        test ah,80h
        jnz  @@brk
        mov  byte ptr [di],1
        jmp  @@eoi
@@brk:  mov  byte ptr [di],0
@@eoi:  mov  al,20h
        out  20h,al
        pop  ds
        pop  di
        pop  bx
        pop  ax
        iret

; ============================================================================
;  MAIN PROGRAM
; ============================================================================
MAIN:
        ; back-buffer 64K above the PSP (a COM program owns all memory)
        mov  ax,cs
        add  ax,1000h
        mov  [bufseg],ax

        ; hook INT 9
        mov  ax,3509h
        int  21h
        mov  [oldoff],bx
        mov  [oldseg],es
        mov  dx,offset KBINT
        mov  ax,2509h
        int  21h                ; DS=CS already -> vector to CS:KBINT

        ; (no PIT reprogram, no INT 8 hook - we only read the stock BIOS tick)

        push es                 ; seed the world from the clock: new map
        mov  ax,40h             ; every run (the map lives in HMAP after this,
        mov  es,ax              ; so everything stays self-consistent)
        mov  ax,es:[6Ch]
        pop  es
        or   ax,1               ; LCG must not start at 0
        mov  [rseed],ax
        call DSGEN              ; build the Diamond-Square world heightmap
        call MMAPGEN            ; bake the minimap from it

        ; video mode 13h + palette (day by default; N toggles at runtime)
        mov  ax,0013h
        int  10h
        call APPLYPAL

        ; spawn over a city node (H in 130..160), not out at sea
        mov  word ptr [camx],0
        mov  word ptr [camz],0
        xor  si,si
@@seek: mov  al,[HMAP+si]
        cmp  al,130
        jb   @@snext
        cmp  al,160
        ja   @@snext
        mov  ax,si              ; node x = si>>6 -> world centre of that node
        mov  cl,6
        shr  ax,cl
        mov  cl,2
        shl  ax,cl
        mov  cl,8
        shl  ax,cl              ; *1024
        add  ax,512
        sub  ax,BIAS
        mov  [camx],ax
        mov  ax,si
        and  ax,63
        mov  cl,2
        shl  ax,cl
        mov  cl,8
        shl  ax,cl
        add  ax,512
        sub  ax,BIAS
        mov  [camz],ax
        jmp  @@sdone
@@snext:
        inc  si
        cmp  si,4096
        jb   @@seek
@@sdone:
        mov  word ptr [camy],1450 ; start high above everything (peaks ~1110)
        mov  word ptr [heading],0
        mov  word ptr [roll],0
        call SETTRIG            ; seed hsin/hcos before the first physics tick
        push es                 ; seed lasttk from the BIOS tick
        mov  ax,40h
        mov  es,ax
        mov  ax,es:[6Ch]
        pop  es
        mov  [lasttk],ax

GAMELOOP:
        ; --- physics: one INPUT step per BIOS tick elapsed since last frame ---
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,es:[6Ch]        ; BIOS tick low word (18.2 Hz)
        pop  es
        mov  bx,ax
        sub  bx,[lasttk]        ; bx = ticks elapsed since last render frame
        mov  [lasttk],ax
        cmp  bx,MAXSTEP         ; clamp catch-up (anti-spiral)
        jbe  @@pcl
        mov  bx,MAXSTEP
@@pcl:  test bx,bx
        jz   @@pdone
@@ploop:
        push bx                 ; INPUT clobbers BX (leaves BX=256 from idiv)
        call INPUT              ; one fixed physics step
        pop  bx
        dec  bx
        jnz  @@ploop
@@pdone:
        call COLLIDE

        ; --- render (runs as fast as it can; speed no longer tied to it) ---
        call SETTRIG            ; heading/roll -> sin/cos for this frame
        mov  ax,[bufseg]        ; draw into back-buffer
        mov  es,ax
        call CLEARBUF
        call RENDER
        call CROSS
        call BLIT               ; to video memory
        call HUD                ; text overlay (BIOS)
        call WAITV              ; tearing guard only (does not gate physics)
        cmp  byte ptr [KEYS+SC_ESC],0
        je   GAMELOOP

QUIT:
        mov  ax,0003h
        int  10h
        ; restore INT 9 vector
        mov  dx,[oldoff]
        mov  ax,[oldseg]
        push ds
        mov  ds,ax
        mov  ax,2509h
        int  21h
        pop  ds
        mov  ax,4C00h
        int  21h

; ============================================================================
;  SET PALETTE
; ============================================================================
SETPAL: mov  dx,3C8h            ; in: SI -> palette table (NPALC colours)
        xor  al,al
        out  dx,al
        mov  dx,3C9h
        mov  cx,NPALC*3
        cld                     ; lodsb must walk forward
@@pl:   lodsb
        out  dx,al
        loop @@pl
        ret

; pick the palette that matches [daymode] and load it
APPLYPAL:
        cmp  byte ptr [daymode],0
        je   @@nit
        mov  si,offset PALDAY
        jmp  @@go
@@nit:  mov  si,offset PALNITE
@@go:   call SETPAL
        ret

; ============================================================================
;  CLEAR BACK-BUFFER  (top = sky, bottom = ground)   ES=bufseg
; ============================================================================
; F-15 style banded horizon, now ROLL-AWARE: the five bands are drawn as
; rotated parallelograms (SCANPOLY) about (160,horiz), so banking the plane
; banks the sky/ground split with the rest of the scene. Bands overlap by 2
; v-units so integer rounding can't leave unpainted seams.
CLEARBUF:
        mov  byte ptr [COLOR],7 ; upper sky
        mov  word ptr [bgv0],-400
        mov  word ptr [bgv1],-15
        call BGBAND
        mov  byte ptr [COLOR],9 ; lighter sky band near the horizon
        mov  word ptr [bgv0],-17
        mov  word ptr [bgv1],-5
        call BGBAND
        mov  byte ptr [COLOR],12 ; haze strip on the horizon
        mov  word ptr [bgv0],-7
        mov  word ptr [bgv1],1
        call BGBAND
        mov  byte ptr [COLOR],11 ; washed-out distant ground
        mov  word ptr [bgv0],-1
        mov  word ptr [bgv1],11
        call BGBAND
        mov  byte ptr [COLOR],10 ; ground
        mov  word ptr [bgv0],9
        mov  word ptr [bgv1],400
        call BGBAND
        ret

; one background band: a parallelogram spanning u=-600..600 along the horizon
; direction, v=[bgv0..bgv1] across it, rotated by roll about (160,horiz).
BGBAND: mov  word ptr [NPOLY],4
        mov  ax,-600
        mov  bx,[bgv0]
        xor  si,si
        call BGCORN
        mov  ax,600
        mov  bx,[bgv0]
        mov  si,2
        call BGCORN
        mov  ax,600
        mov  bx,[bgv1]
        mov  si,4
        call BGCORN
        mov  ax,-600
        mov  bx,[bgv1]
        mov  si,6
        call BGCORN
        call SCANPOLY
        ret

; corner: PX[si] = 160 + (u*rcos - v*rsin)/256 ; PY[si] = horiz + (u*rsin + v*rcos)/256
BGCORN: mov  [bgu],ax
        mov  [bgv],bx
        mov  ax,[bgu]
        imul word ptr [rcos]
        mov  cx,256
        idiv cx
        mov  bx,ax
        mov  ax,[bgv]
        imul word ptr [rsin]
        mov  cx,256
        idiv cx
        sub  bx,ax
        add  bx,160
        mov  [PX+si],bx
        mov  ax,[bgu]
        imul word ptr [rsin]
        mov  cx,256
        idiv cx
        mov  bx,ax
        mov  ax,[bgv]
        imul word ptr [rcos]
        mov  cx,256
        idiv cx
        add  bx,ax
        add  bx,[horiz]
        mov  [PY+si],bx
        ret

; ============================================================================
;  COPY BACK-BUFFER -> A000:0000
; ============================================================================
BLIT:   push ds
        mov  ax,[bufseg]
        mov  ds,ax
        mov  ax,0A000h
        mov  es,ax
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  ds
        ret

; ============================================================================
;  WAIT FOR VERTICAL RETRACE (sync)
; ============================================================================
WAITV:  mov  dx,3DAh
@@w1:   in   al,dx
        test al,8
        jnz  @@w1
@@w2:   in   al,dx
        test al,8
        jz   @@w2
        ret

; ============================================================================
;  RENDER THE WORLD
; ============================================================================
RENDER: ; camera cell (needed by GRID and BUILDINGS)
        mov  ax,[camx]
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  [camgi],ax
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  [camgj],ax
        cmp  byte ptr [daymode],0
        jne  @@day              ; stars only at night
        call STARS
@@day:  call TERRPREP           ; rotate + cache the terrain nodes
        call TERRAIN            ; real 3D relief, far -> near
        call RENDERMEGAS        ; distant city blocks on the lowlands
        call BUILDINGS
        call MINIMAP            ; bottom-right world map + plane marker
        ret

; ----- stars (sky background; horizon is the sky/ground colour split) -------
STARS:  mov  byte ptr [COLOR],8
        mov  si,offset STARTAB
        mov  cx,STARN
@@s:    push cx
        mov  ax,[si]            ; star X (word)
        mov  [tmpsx],ax
        mov  ax,[si+2]          ; star Y (word)
        mov  [tmpsy],ax
        mov  bx,[tmpsy]
        cmp  bx,[horiz]         ; skip stars below the pitched horizon
        jge  @@sk
        mov  ax,[tmpsx]
        call PUTPIXEL
@@sk:   pop  cx
        add  si,4
        loop @@s
        ret

; ============================================================================
;  FAR BELT - megablocks and REAL mountains, world objects at 4x4-cell scale.
;  Painter order: Chebyshev rings from MEGR in to ring 2 (cells inside ring 2
;  are covered by the near per-cell pass). City-zone megas draw as one grey
;  block the size of a whole quarter; mountain-zone megas draw as pyramids.
; ============================================================================
RENDERMEGAS:
        mov  ax,[camgi]
        mov  cl,2
        shr  ax,cl
        mov  [cammgi],ax
        mov  ax,[camgj]
        mov  cl,2
        shr  ax,cl
        mov  [cammgj],ax
        mov  word ptr [mring],MEGR
@@rl:   call MEGARING
        dec  word ptr [mring]
        cmp  word ptr [mring],1 ; ring 1 too: near-pass misses its mountains
        jge  @@rl
        ret

; walk the perimeter of Chebyshev ring [mring], calling MEGACELL per cell
MEGARING:
        mov  ax,[mring]
        neg  ax
        mov  [cdi],ax
@@trow: mov  ax,[mring]         ; top & bottom edges
        neg  ax
        mov  [cdj],ax
        call MEGACELL
        mov  ax,[mring]
        mov  [cdj],ax
        call MEGACELL
        mov  ax,[cdi]
        inc  ax
        mov  [cdi],ax
        cmp  ax,[mring]
        jle  @@trow
        mov  ax,[mring]         ; left & right edges (corners already done)
        neg  ax
        inc  ax
        mov  [cdj],ax
@@lcol: mov  ax,[cdj]
        mov  bx,[mring]
        dec  bx
        cmp  ax,bx
        jg   @@done
        mov  ax,[mring]
        neg  ax
        mov  [cdi],ax
        call MEGACELL
        mov  ax,[mring]
        mov  [cdi],ax
        call MEGACELL
        mov  ax,[cdj]
        inc  ax
        mov  [cdj],ax
        jmp  @@lcol
@@done: ret

; ----- one megablock at (cammgi+cdi, cammgj+cdj) -----------------------------
MEGACELL:
        mov  ax,[cammgi]
        add  ax,[cdi]
        mov  bx,ax              ; mi
        mov  cl,2
        shl  ax,cl
        add  ax,2               ; centre cell gi = mi*4+2
        mov  [gi],ax
        mov  ax,[cammgj]
        add  ax,[cdj]
        mov  cl,2
        shl  ax,cl
        add  ax,2
        mov  [gj],ax
        mov  ax,[gi]
        mov  bx,[gj]
        call GETZONE            ; 0 city / 1 plain / 2 mnt / 3 water / 4 foothills
        test ax,ax
        jnz  @@ret              ; only city megas here: terrain draws the rest
        push ax                 ; keep stack shape (zone, always 0 now)
        ; world centre of the mega (centre cell's centre)
        mov  ax,[gi]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        sub  ax,BIAS
        mov  [wcx],ax
        mov  ax,[gj]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        sub  ax,BIAS
        mov  [wcz],ax
        ; mega hash for heights
        mov  ax,[gi]
        mov  bx,1973
        imul bx
        mov  si,ax
        mov  ax,[gj]
        mov  bx,9277
        imul bx
        add  ax,si
        mov  bx,ax
        mov  cl,7
        shr  bx,cl
        xor  ax,bx              ; ax = hash
        pop  bx                 ; (zone, always city here)
        ; --- city mega: one block covering the whole quarter ---
        cmp  word ptr [mring],3 ; rings 1-2 city covered by real buildings
        jl   @@ret
        mov  word ptr [bhw],350
        mov  word ptr [bhd],350
        and  ax,255
        add  ax,80              ; height 80..335 (approximates the quarter)
        mov  [bhgt2],ax
        call ROTCUL
        jc   @@ret
        mov  ax,[gi]            ; sit the block on the local terrain
        mov  bx,[gj]
        call GETH
        call WORLDH
        mov  [gbase],ax
        sub  ax,[camy]
        mov  [bry0],ax
        mov  ax,[gbase]
        add  ax,[bhgt2]
        sub  ax,[camy]
        mov  [bry1],ax
        ; solid haze-coloured silhouette; nearer rings get shade + outline
        mov  byte ptr [COLOR],1
        cmp  word ptr [mring],12
        jge  @@mfill
        mov  byte ptr [COLOR],16
@@mfill:
        mov  ax,[gbase]
        add  ax,[bhgt2]
        cmp  [camy],ax
        jle  @@mnr
        call FACETOPC
        call FACEFILL
@@mnr:  call MEGAFILL
        cmp  word ptr [mring],12
        jge  @@ret              ; distant rings: silhouette only
        mov  al,1               ; distant stroke colour, and VISSTROKE's
        mov  [COLOR],al         ; per-face restore value (scol) must match
        mov  [scol],al
        call VISSTROKE
@@ret:  ret

; fill the visible vertical faces with the CURRENT colour (no per-side tint)
MEGAFILL:
        mov  ax,[camx]
        cmp  ax,[bwx0]
        jge  @@e
        mov  word ptr [fa],3
        mov  word ptr [fb],0
        call FACEV
        call FACEFILL
@@e:    mov  ax,[camx]
        cmp  ax,[bwx1]
        jle  @@s
        mov  word ptr [fa],1
        mov  word ptr [fb],2
        call FACEV
        call FACEFILL
@@s:    mov  ax,[camz]
        cmp  ax,[bwz0]
        jge  @@n
        mov  word ptr [fa],0
        mov  word ptr [fb],1
        call FACEV
        call FACEFILL
@@n:    mov  ax,[camz]
        cmp  ax,[bwz1]
        jle  @@d
        mov  word ptr [fa],2
        mov  word ptr [fb],3
        call FACEV
        call FACEFILL
@@d:    ret

; ============================================================================
;  RND16 - LCG pseudo-random.  out: AX. preserves BX,DX (MUL clobbers DX!).
; ============================================================================
RND16:  push bx
        push dx
        mov  ax,[rseed]
        mov  bx,25173
        mul  bx
        add  ax,13849
        mov  [rseed],ax
        pop  dx
        pop  bx
        ret

; ---- heightmap access: node (BX=x, DX=y), toroidal --------------------------
HGET:   push bx                 ; out: AL = height ; preserves BX,DX
        push dx
        and  bx,63
        mov  cl,6
        shl  bx,cl
        and  dx,63
        add  bx,dx
        mov  al,[HMAP+bx]
        pop  dx
        pop  bx
        ret
HPUT:   push bx                 ; in: AL = height ; preserves BX,DX,AX
        push dx
        and  bx,63
        mov  cl,6
        shl  bx,cl
        and  dx,63
        add  bx,dx
        mov  [HMAP+bx],al
        pop  dx
        pop  bx
        ret

; ============================================================================
;  DSGEN - Diamond-Square heightmap on a 64x64 TORUS (from CityGame's integer
;  terrain generator), then a histogram stretch to the full 0..255 range
;  (plain DS averaging squeezes everything toward the middle, flattening it).
; ============================================================================
DSGEN:  mov  word ptr [dss],32  ; seed anchors on the coarsest grid
        mov  word ptr [dsamp],128
        xor  bx,bx
        xor  dx,dx
        call RND16
        and  al,127
        add  al,64              ; anchors 64..191 (mid range)
        call HPUT
        mov  bx,32
        call RND16
        and  al,127
        add  al,64
        call HPUT
        xor  bx,bx
        mov  dx,32
        call RND16
        and  al,127
        add  al,64
        call HPUT
        mov  bx,32
        call RND16
        and  al,127
        add  al,64
        call HPUT
@@pass: ; ---- diamond step ----
        mov  ax,[dss]
        shr  ax,1
        mov  [dsh],ax
        mov  word ptr [dsx],0
@@dx:   mov  word ptr [dsy],0
@@dy:   mov  bx,[dsx]
        mov  dx,[dsy]
        call HGET
        xor  ah,ah
        mov  [dsac],ax
        mov  bx,[dsx]
        add  bx,[dss]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        mov  dx,[dsy]
        add  dx,[dss]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        mov  bx,[dsx]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        call @@noise            ; AX = avg4 + noise, clamped 0..255
        mov  bx,[dsx]
        add  bx,[dsh]
        mov  dx,[dsy]
        add  dx,[dsh]
        call HPUT
        mov  ax,[dsy]
        add  ax,[dss]
        mov  [dsy],ax
        cmp  ax,64
        jb   @@dy
        mov  ax,[dsx]
        add  ax,[dss]
        mov  [dsx],ax
        cmp  ax,64
        jb   @@dx
        ; ---- square step: the two edge midpoints of every square ----
        mov  word ptr [dsx],0
@@sx:   mov  word ptr [dsy],0
@@sy:   ; point (dsx+h, dsy): neighbours (x,y) (x+s,y) (x+h,y-h) (x+h,y+h)
        mov  bx,[dsx]
        mov  dx,[dsy]
        call HGET
        xor  ah,ah
        mov  [dsac],ax
        mov  bx,[dsx]
        add  bx,[dss]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        mov  bx,[dsx]
        add  bx,[dsh]
        mov  dx,[dsy]
        sub  dx,[dsh]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        mov  dx,[dsy]
        add  dx,[dsh]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        call @@noise
        mov  bx,[dsx]
        add  bx,[dsh]
        mov  dx,[dsy]
        call HPUT
        ; point (dsx, dsy+h): neighbours (x,y) (x,y+s) (x-h,y+h) (x+h,y+h)
        mov  bx,[dsx]
        mov  dx,[dsy]
        call HGET
        xor  ah,ah
        mov  [dsac],ax
        mov  dx,[dsy]
        add  dx,[dss]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        mov  bx,[dsx]
        sub  bx,[dsh]
        mov  dx,[dsy]
        add  dx,[dsh]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        mov  bx,[dsx]
        add  bx,[dsh]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        call @@noise
        mov  bx,[dsx]
        mov  dx,[dsy]
        add  dx,[dsh]
        call HPUT
        mov  ax,[dsy]
        add  ax,[dss]
        mov  [dsy],ax
        cmp  ax,64
        jb   @@sy
        mov  ax,[dsx]
        add  ax,[dss]
        mov  [dsx],ax
        cmp  ax,64
        jb   @@sx
        ; ---- next octave: halve side and amplitude ----
        mov  ax,[dsh]
        mov  [dss],ax
        mov  ax,[dsamp]
        shr  ax,1
        cmp  ax,4
        jge  @@a4
        mov  ax,4
@@a4:   mov  [dsamp],ax
        cmp  word ptr [dss],1
        jg   @@pass
        ; ---- histogram stretch: min..max -> 0..255 ----
        mov  al,255             ; al = min so far
        mov  ah,0               ; ah = max so far
        xor  si,si
@@mm:   mov  bl,[HMAP+si]
        cmp  bl,al
        jae  @@m1
        mov  al,bl
@@m1:   cmp  bl,ah
        jbe  @@m2
        mov  ah,bl
@@m2:   inc  si
        cmp  si,4096
        jb   @@mm
        mov  bl,ah
        sub  bl,al              ; range = max - min
        jz   @@sdone            ; degenerate map: leave as is
        mov  bh,0
        mov  [dsy],bx           ; dsy = range (word)
        mov  ah,0
        mov  [dsx],ax           ; dsx = min (word)
        xor  si,si
@@sc:   mov  al,[HMAP+si]
        mov  ah,0
        sub  ax,[dsx]           ; v - min
        mov  cx,255
        mul  cx                 ; DX:AX = (v-min)*255 ; DX=0 (fits 16 bits)
        div  word ptr [dsy]     ; AX = scaled 0..255
        mov  [HMAP+si],al
        inc  si
        cmp  si,4096
        jb   @@sc
@@sdone:
        ret
@@noise:                        ; AX = dsac/4 + (rnd & (amp-1)) - amp/2, 0..255
        call RND16
        mov  bx,[dsamp]
        dec  bx
        and  ax,bx              ; 0..amp-1
        mov  bx,[dsamp]
        shr  bx,1
        sub  ax,bx              ; -amp/2 .. amp/2-1
        mov  bx,[dsac]
        shr  bx,1
        shr  bx,1               ; avg of 4
        add  ax,bx
        jns  @@n1
        xor  ax,ax
@@n1:   cmp  ax,255
        jle  @@n2
        mov  ax,255
@@n2:   ret

; ============================================================================
;  GETH - world height for cell (AX=gi, BX=gj) from the DS map (1 node = 4x4
;  cells, toroidal). out: AX = height 0..255.
; ============================================================================
GETH:   mov  cl,2
        shr  ax,cl              ; node x = gi>>2 (wraps in HGET)
        push bx
        mov  bx,ax
        pop  dx
        mov  cl,2
        shr  dx,cl              ; node y
        call HGET
        xor  ah,ah
        ret

; ============================================================================
;  GETZONE - world zoning from the Diamond-Square heightmap.
;   in: AX=cell gi, BX=cell gj
;   out: AX = 0 city / 1 plains / 2 mountains / 3 water / 4 foothills
;  Height bands: <88 sea, 88..119 plains, 120..167 city (lowlands),
;  168..199 foothills (dense woods), >=200 mountains.
; ============================================================================
GETZONE:
        call GETH
        cmp  ax,88
        jb   @@water
        cmp  ax,120
        jb   @@plain
        cmp  ax,168
        jb   @@city
        cmp  ax,200
        jb   @@foot
        mov  ax,2               ; mountains
        ret
@@water:
        mov  ax,3
        ret
@@foot: mov  ax,4
        ret
@@plain:
        mov  ax,1
        ret
@@city: xor  ax,ax
        ret

; ============================================================================
;  WORLDH - map height H (0..255) -> world height.  Sea floor clamps to 0,
;  land rises 5/unit, mountains (H>200) climb twice as fast -> peaks ~1110.
;   in: AX = raw H   out: AX = world height
; ============================================================================
WORLDH: sub  ax,88
        jns  @@w0
        xor  ax,ax              ; below sea level -> 0 (water surface)
        ret
@@w0:   mov  bx,5
        imul bx                 ; (H-88)*5   (max 835)
        cmp  ax,560             ; H=200 -> 560: steepen above this (mountains)
        jle  @@w1
        mov  bx,ax
        sub  bx,560
        add  ax,bx              ; doubled slope above 560 -> peaks ~1110
@@w1:   ret

; ============================================================================
;  TERRPREP - once per frame: rotate all NSIDE^2 nodes around the camera into
;  camera space (TRX/TRZ) and cache their heights (TWH world, TH raw).
; ============================================================================
TERRPREP:
        mov  ax,[camx]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl              ; (camx+BIAS)>>10 = camera node x
        mov  [tnx],ax
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        mov  [tnz],ax
        mov  word ptr [tta],0
@@al:   mov  word ptr [ttb],0
@@bl:   ; world position of node (tnx+tta-NR, tnz+ttb-NR)
        mov  ax,[tnx]
        add  ax,[tta]
        sub  ax,NR
        mov  bx,ax              ; node x (for HGET, wraps)
        mov  cl,2
        shl  ax,cl
        mov  cl,8
        shl  ax,cl              ; node*1024
        sub  ax,BIAS
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[tnz]
        add  ax,[ttb]
        sub  ax,NR
        mov  dx,ax              ; node z
        mov  cl,2
        shl  ax,cl
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        sub  ax,[camz]
        mov  [wdz],ax
        push bx
        push dx
        call ROTXZ
        pop  dx
        pop  bx
        ; cache index si = tta*41 + ttb   (41 = 32 + 8 + 1)
        mov  ax,[tta]
        mov  cl,5
        shl  ax,cl              ; *32
        push bx
        mov  bx,[tta]
        mov  cl,3
        shl  bx,cl              ; *8
        add  ax,bx
        pop  bx
        add  ax,[tta]           ; *41
        add  ax,[ttb]
        mov  si,ax
        add  si,si              ; word offset
        mov  ax,[rcx]
        mov  [TRX+si],ax
        mov  ax,[rcz]
        mov  [TRZ+si],ax
        call HGET               ; AL = raw H of node (BX,DX preserved inside)
        mov  di,si
        shr  di,1
        mov  [TH+di],al
        xor  ah,ah
        push si
        call WORLDH
        pop  si
        mov  [TWH+si],ax
        inc  word ptr [ttb]
        cmp  word ptr [ttb],NSIDE
        jl   @@bl
        inc  word ptr [tta]
        cmp  word ptr [tta],NSIDE
        jl   @@al
        ret

; ============================================================================
;  TERRAIN - draw the 3D landscape: 1600 heightmap quads far -> near (TORD).
;  Colours by the max raw H of the quad corners: water, grass, woods, rock,
;  snow. Near quads also get a grid stroke. Buildings draw after this.
; ============================================================================
TERRAIN:
        mov  word ptr [tidx],0
@@tl:   mov  si,[tidx]
        add  si,si
        mov  al,[TORD+si]       ; di (signed)
        cbw
        add  ax,NR              ; a = di+NR
        mov  [tta],ax
        mov  al,[TORD+si+1]
        cbw
        add  ax,NR
        mov  [ttb],ax
        ; base cache index = a*41+b   (41 = 32 + 8 + 1)
        mov  ax,[tta]
        mov  cl,5
        shl  ax,cl              ; *32
        mov  bx,[tta]
        mov  cl,3
        shl  bx,cl              ; *8
        add  ax,bx
        add  ax,[tta]           ; *41
        add  ax,[ttb]
        mov  si,ax
        add  si,si              ; word index of node (a,b)
        ; corners: n0=(a,b) n1=(a+1,b) n2=(a+1,b+1) n3=(a,b+1)
        mov  ax,[TRX+si]
        mov  [IX],ax
        mov  ax,[TRZ+si]
        mov  [IZ],ax
        mov  ax,[TWH+si]
        sub  ax,[camy]
        mov  [IY],ax
        mov  ax,[TRX+si+82]     ; +41 nodes = +82 bytes -> (a+1,b)
        mov  [IX+2],ax
        mov  ax,[TRZ+si+82]
        mov  [IZ+2],ax
        mov  ax,[TWH+si+82]
        sub  ax,[camy]
        mov  [IY+2],ax
        mov  ax,[TRX+si+84]     ; (a+1,b+1)
        mov  [IX+4],ax
        mov  ax,[TRZ+si+84]
        mov  [IZ+4],ax
        mov  ax,[TWH+si+84]
        sub  ax,[camy]
        mov  [IY+4],ax
        mov  ax,[TRX+si+2]      ; (a,b+1)
        mov  [IX+6],ax
        mov  ax,[TRZ+si+2]
        mov  [IZ+6],ax
        mov  ax,[TWH+si+2]
        sub  ax,[camy]
        mov  [IY+6],ax
        ; quick cull: all corners behind, or all beyond FARZ
        mov  ax,[IZ]
        cmp  ax,[IZ+2]
        jge  @@z1
        mov  ax,[IZ+2]
@@z1:   cmp  ax,[IZ+4]
        jge  @@z2
        mov  ax,[IZ+4]
@@z2:   cmp  ax,[IZ+6]
        jge  @@z3
        mov  ax,[IZ+6]
@@z3:   cmp  ax,NEARZ
        jl   @@next             ; max z < NEARZ -> fully behind
        mov  ax,[IZ]
        cmp  ax,[IZ+2]
        jle  @@n1
        mov  ax,[IZ+2]
@@n1:   cmp  ax,[IZ+4]
        jle  @@n2
        mov  ax,[IZ+4]
@@n2:   cmp  ax,[IZ+6]
        jle  @@n3
        mov  ax,[IZ+6]
@@n3:   cmp  ax,FARZ
        jg   @@next             ; min z beyond far -> skip
        ; colour from the max raw H of the 4 corners
        mov  di,si
        shr  di,1               ; byte index
        mov  al,[TH+di]
        mov  ah,[TH+di+41]
        cmp  al,ah
        jae  @@c1
        mov  al,ah
@@c1:   mov  ah,[TH+di+42]
        cmp  al,ah
        jae  @@c2
        mov  al,ah
@@c2:   mov  ah,[TH+di+1]
        cmp  al,ah
        jae  @@c3
        mov  al,ah
@@c3:   ; al = max H
        cmp  al,88
        jb   @@water
        cmp  al,168
        jb   @@grass
        cmp  al,200
        jb   @@woods
        cmp  al,230
        jb   @@rock
        mov  byte ptr [COLOR],8 ; snow caps
        jmp  @@fill
@@water:
        mov  byte ptr [COLOR],14
        jmp  @@fill
@@grass:
        mov  byte ptr [COLOR],10
        jmp  @@fill
@@woods:
        mov  byte ptr [COLOR],15
        jmp  @@fill
@@rock: mov  byte ptr [COLOR],13
@@fill: call FACEFILL
        ; near quads: subtle grid stroke so low flight reads speed
        mov  ax,[tta]
        sub  ax,NR
        cmp  ax,-3
        jl   @@next
        cmp  ax,2
        jg   @@next
        mov  ax,[ttb]
        sub  ax,NR
        cmp  ax,-3
        jl   @@next
        cmp  ax,2
        jg   @@next
        mov  byte ptr [COLOR],6
        call FACESTROKE
@@next: inc  word ptr [tidx]
        cmp  word ptr [tidx],1600
        jl   @@tl
        ret

; ============================================================================
;  MMAPGEN - bake the 64x64 world minimap from HMAP (once, after DSGEN).
;  Colours: water/plain/CITY-BROWN/woods/rock/snow. North (+Z) is up.
; ============================================================================
MMAPGEN:
        mov  word ptr [dsx],0   ; node i (world X)
@@i:    mov  word ptr [dsy],0   ; node j (world Z)
@@j:    mov  bx,[dsx]
        mov  dx,[dsy]
        call HGET               ; AL = H
        mov  ah,14              ; water
        cmp  al,88
        jb   @@put
        mov  ah,10              ; plains green
        cmp  al,120
        jb   @@put
        mov  ah,18              ; CITY -> brown blocks
        cmp  al,168
        jb   @@put
        mov  ah,15              ; woods
        cmp  al,200
        jb   @@put
        mov  ah,13              ; rock
        cmp  al,230
        jb   @@put
        mov  ah,8               ; snow
@@put:  mov  bx,63              ; screen row = 63 - j (north up)
        sub  bx,[dsy]
        mov  cl,6
        shl  bx,cl
        add  bx,[dsx]
        mov  [MMAP+bx],ah
        inc  word ptr [dsy]
        cmp  word ptr [dsy],64
        jl   @@j
        inc  word ptr [dsx]
        cmp  word ptr [dsx],64
        jl   @@i
        ret

; ============================================================================
;  MINIMAP - blit the baked map to the bottom-right corner (rows 123..186)
;  with a white frame, and stamp the plane: white 2x2 blip + red course tick.
;  ES=bufseg. Our shared debug eye on what DSGEN actually built.
; ============================================================================
MINIMAP:
        cld
        ; white frame so the map does not blend into the terrain
        mov  al,8
        mov  di,122*320+251     ; top edge
        mov  cx,66
        rep  stosb
        mov  di,187*320+251     ; bottom edge (clear of the HUD text row)
        mov  cx,66
        rep  stosb
        mov  di,122*320+251     ; side edges
        mov  cx,66
@@fr:   mov  es:[di],al
        mov  es:[di+65],al
        add  di,320
        loop @@fr
        ; blit the baked map
        mov  si,offset MMAP
        mov  di,123*320+252
        mov  cx,64
@@row:  push cx
        mov  cx,32
        rep  movsw              ; one 64-byte map row
        pop  cx
        add  di,320-64
        loop @@row
        ; plane blip at node (camx,camz)
        mov  ax,[camx]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        and  ax,63
        mov  bx,ax              ; col = node x
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        and  ax,63
        mov  dx,63
        sub  dx,ax              ; row = 63 - node z
        mov  ax,dx
        add  ax,123
        mov  di,ax              ; di = row*320 (=*256+*64)
        mov  cl,8
        shl  di,cl
        mov  cl,6
        shl  ax,cl
        add  di,ax
        add  di,252
        add  di,bx
        mov  al,8               ; white 2x2 blip
        mov  es:[di],al
        mov  es:[di+1],al
        mov  es:[di+320],al
        mov  es:[di+321],al
        ; heading tick: 3 map pixels ahead of the blip
        mov  ax,[hsin]
        add  ax,ax
        add  ax,[hsin]          ; hsin*3
        mov  bx,256
        cwd
        idiv bx                 ; dxn = -3..3
        mov  si,ax
        mov  ax,[hcos]
        add  ax,ax
        add  ax,[hcos]
        cwd
        idiv bx                 ; dzn
        mov  cx,320             ; +Z is up on the map -> minus one row per node
        imul cx                 ; DX:AX = dzn*320
        mov  cx,ax
        mov  ax,si
        sub  ax,cx              ; pixel offset = dxn - dzn*320
        add  di,ax
        mov  al,19              ; red course tick
        mov  es:[di],al
        ret

; ============================================================================
;  TERRH - bilinear terrain height at world (camx,camz).  out: AX (>=0).
;  Node grid pitch is 1024; fractions are taken in 1/64 of a node.
;  NB: WORLDH's imul clobbers DX, so BX/DX are re-set before every HGET.
; ============================================================================
TERRH:  mov  ax,[camx]
        add  ax,BIAS            ; unsigned world coordinate
        mov  bx,ax
        mov  cl,2
        shr  bx,cl
        mov  cl,8
        shr  bx,cl              ; node x
        mov  cl,4
        shr  ax,cl
        and  ax,63              ; fx = fraction across the node, 0..63
        mov  [tta],bx           ; node x
        mov  [dsx],ax           ; fx
        mov  ax,[camz]
        add  ax,BIAS
        mov  dx,ax
        mov  cl,2
        shr  dx,cl
        mov  cl,8
        shr  dx,cl              ; node z
        mov  cl,4
        shr  ax,cl
        and  ax,63              ; fz
        mov  [ttb],dx
        mov  [dsy],ax
        ; world heights of the 4 surrounding nodes
        mov  bx,[tta]
        mov  dx,[ttb]
        call HGET
        xor  ah,ah
        call WORLDH
        mov  [x0],ax            ; h00 (reuse edge scratch vars)
        mov  bx,[tta]
        inc  bx
        mov  dx,[ttb]
        call HGET
        xor  ah,ah
        call WORLDH
        mov  [x1],ax            ; h10
        mov  bx,[tta]
        mov  dx,[ttb]
        inc  dx
        call HGET
        xor  ah,ah
        call WORLDH
        mov  [y0],ax            ; h01
        mov  bx,[tta]
        inc  bx
        mov  dx,[ttb]
        inc  dx
        call HGET
        xor  ah,ah
        call WORLDH
        mov  [y1],ax            ; h11
        ; ha = h00 + (h10-h00)*fx/64 ; hb = h01 + (h11-h01)*fx/64
        mov  ax,[x1]
        sub  ax,[x0]
        imul word ptr [dsx]
        mov  bx,64
        idiv bx
        add  ax,[x0]
        mov  [x0],ax            ; ha
        mov  ax,[y1]
        sub  ax,[y0]
        imul word ptr [dsx]
        mov  bx,64
        idiv bx
        add  ax,[y0]            ; hb
        ; h = ha + (hb-ha)*fz/64
        sub  ax,[x0]
        imul word ptr [dsy]
        mov  bx,64
        idiv bx
        add  ax,[x0]
        ret

; DEAD (flat-ground era; replaced by the TERRAIN mesh, no callers) -----------
; ----- ground grid: world-aligned lines around the camera (rotate with view)
GRID:   mov  byte ptr [COLOR],6
        ; lines parallel to world-Z (fixed X = gi)
        mov  ax,[camgi]
        sub  ax,GR
        mov  [gi],ax
@@gx:   mov  ax,[gi]            ; worldX = gi*256 - BIAS
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        mov  [wcx],ax
        ; endpoint A (worldX, Zmin)
        mov  ax,[wcx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[camgj]
        sub  ax,GR
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rcx]
        mov  [x0],ax
        mov  ax,[rcz]
        mov  [z0],ax
        ; endpoint B (worldX, Zmax)
        mov  ax,[wcx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[camgj]
        add  ax,GR
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rcx]
        mov  [x1],ax
        mov  ax,[rcz]
        mov  [z1],ax
        mov  ax,[camy]
        neg  ax
        mov  [y0],ax
        mov  [y1],ax
        call DRAWEDGE3D
        mov  ax,[gi]
        inc  ax
        mov  [gi],ax
        mov  bx,[camgi]
        add  bx,GR
        cmp  ax,bx
        jle  @@gx
        ; lines parallel to world-X (fixed Z = gj)
        mov  ax,[camgj]
        sub  ax,GR
        mov  [gj],ax
@@gz:   mov  ax,[gj]
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        sub  ax,[camz]
        mov  [wdz],ax
        ; endpoint A (Xmin, worldZ)
        mov  ax,[camgi]
        sub  ax,GR
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        sub  ax,[camx]
        mov  [wdx],ax
        call ROTXZ
        mov  ax,[rcx]
        mov  [x0],ax
        mov  ax,[rcz]
        mov  [z0],ax
        ; endpoint B (Xmax, worldZ)
        mov  ax,[camgi]
        add  ax,GR
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        sub  ax,[camx]
        mov  [wdx],ax
        call ROTXZ
        mov  ax,[rcx]
        mov  [x1],ax
        mov  ax,[rcz]
        mov  [z1],ax
        mov  ax,[camy]
        neg  ax
        mov  [y0],ax
        mov  [y1],ax
        call DRAWEDGE3D
        mov  ax,[gj]
        inc  ax
        mov  [gj],ax
        mov  bx,[camgj]
        add  bx,GR
        cmp  ax,bx
        jle  @@gz
        ret

; ----- buildings: painter's algorithm, far -> near by squared cell distance --
;  Outer loop walks the d^2 bucket from MAXD2 down to 0; inner scan renders the
;  cells whose cdi*cdi+cdj*cdj matches the current bucket. [ring] = bucket.
;  (camgi/camgj are also set in RENDER before GRID; recomputed here too.)
BUILDINGS:
        mov  ax,[camx]          ; camera cell = (pos+BIAS)>>8  (shr = floor /CELL)
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  [camgi],ax
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  [camgj],ax
        mov  word ptr [ring],MAXD2
@@d2:   mov  word ptr [cdi],-RAD
@@iloop:
        mov  word ptr [cdj],-RAD
@@jloop:
        mov  ax,[cdi]           ; cdi^2 + cdj^2
        imul ax
        mov  bx,ax
        mov  ax,[cdj]
        imul ax
        add  ax,bx
        cmp  ax,[ring]
        jne  @@jnext
        call RENDERCELL         ; this cell is in the current distance bucket
@@jnext:
        mov  ax,[cdj]
        inc  ax
        mov  [cdj],ax
        cmp  ax,RAD
        jle  @@jloop
        mov  ax,[cdi]
        inc  ax
        mov  [cdi],ax
        cmp  ax,RAD
        jle  @@iloop
        dec  word ptr [ring]
        mov  ax,[ring]
        cmp  ax,0
        jge  @@d2
        ret

; ----- render one city cell (cdi,cdj relative to camera cell) ---------------
;  Looks up the building for cell (camgi+cdi, camgj+cdj), rotates its 4
;  footprint corners into camera space (FRX/FRZ + min/maxrz), culls if all
;  behind/too far, then fills+strokes only the box faces facing the camera
;  (chosen by world-space camx/camz vs the footprint, so yaw-independent).
;  Visible vertical faces are drawn via FACEV; roof via FACETOPC.
RENDERCELL:
        mov  ax,[camgi]
        add  ax,[cdi]
        mov  [gi],ax
        mov  ax,[camgj]
        add  ax,[cdj]
        mov  [gj],ax
        call HBLD
        mov  ax,[bstreet]
        cmp  ax,1
        je   @@ret              ; plain street cell -> nothing to draw
        ; cell centre world coords:  gi*256 + 128 - BIAS   (shl = *CELL)
        mov  ax,[gi]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        sub  ax,BIAS
        mov  [wcx],ax
        mov  ax,[gj]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        sub  ax,BIAS
        mov  [wcz],ax
        call ROTCUL             ; bounds -> rotate corners -> cull
        jc   @@ret
        ; ground height under this cell (terrain-aware)
        mov  ax,[gi]
        mov  bx,[gj]
        call GETH
        call WORLDH
        mov  [gbase],ax
        ; flat terrain patch (forest/water/field)? fill it on the local ground
        mov  ax,[bstreet]
        cmp  ax,2
        jne  @@solid
        mov  ax,[gbase]
        add  ax,2               ; a hair above the terrain quad (paint order)
        sub  ax,[camy]
        mov  [bry1],ax
        mov  al,[bcol]
        mov  [COLOR],al
        call FACETOPC
        call FACEFILL
        jmp  @@ret
@@solid:
        ; heights (camera-relative Y), building sits on the terrain
        mov  ax,[gbase]
        sub  ax,[camy]
        mov  [bry0],ax
        mov  ax,[gbase]
        add  ax,[bhgt2]
        sub  ax,[camy]
        mov  [bry1],ax

        ; ---- FILL visible faces ----
        mov  byte ptr [COLOR],17 ; sun-lit roof
        mov  ax,[gbase]         ; roof, if camera above gbase+bhgt2
        add  ax,[bhgt2]
        cmp  [camy],ax
        jle  @@nf0
        call FACETOPC
        call FACEFILL
@@nf0:  call VISFILL            ; walls (VISFILL picks lit/shaded per side)
        ; ---- stroke color by distance ----
        mov  ax,[minrz]
        cmp  ax,500
        jg   @@nn
        mov  byte ptr [COLOR],3
        jmp  @@cc
@@nn:   cmp  ax,1200
        jg   @@ff
        mov  byte ptr [COLOR],2
        jmp  @@cc
@@ff:   mov  byte ptr [COLOR],1
@@cc:
        ; ---- STROKE visible faces ----
        mov  al,[COLOR]         ; remember the stroke colour: windows repaint
        mov  [scol],al          ; COLOR, VISSTROKE must restore it per face
        mov  ax,[gbase]
        add  ax,[bhgt2]
        cmp  [camy],ax
        jle  @@ns0
        call FACETOPC
        call FACESTROKE
@@ns0:  call VISSTROKE
@@ret:  ret

; ============================================================================
;  ROTCUL - shared box setup: world bounds from (wcx,wcz,bhw,bhd), rotate the
;  4 footprint corners into camera space (FRX/FRZ), track min/max rz, and
;  cull. out: CF=1 -> box entirely behind/beyond, skip drawing.
; ============================================================================
ROTCUL:
        mov  ax,[wcx]
        sub  ax,[bhw]
        mov  [bwx0],ax
        mov  ax,[wcx]
        add  ax,[bhw]
        mov  [bwx1],ax
        mov  ax,[wcz]
        sub  ax,[bhd]
        mov  [bwz0],ax
        mov  ax,[wcz]
        add  ax,[bhd]
        mov  [bwz1],ax
        mov  word ptr [minrz],32767
        mov  word ptr [maxrz],-32768
        mov  ax,[bwx0]          ; corner 0 = (bwx0,bwz0)
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[bwz0]
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rcx]
        mov  [FRX],ax
        mov  ax,[rcz]
        mov  [FRZ],ax
        call @@trk
        mov  ax,[bwx1]          ; corner 1 = (bwx1,bwz0)
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[bwz0]
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rcx]
        mov  [FRX+2],ax
        mov  ax,[rcz]
        mov  [FRZ+2],ax
        call @@trk
        mov  ax,[bwx1]          ; corner 2 = (bwx1,bwz1)
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[bwz1]
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rcx]
        mov  [FRX+4],ax
        mov  ax,[rcz]
        mov  [FRZ+4],ax
        call @@trk
        mov  ax,[bwx0]          ; corner 3 = (bwx0,bwz1)
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[bwz1]
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rcx]
        mov  [FRX+6],ax
        mov  ax,[rcz]
        mov  [FRZ+6],ax
        call @@trk
        mov  ax,[maxrz]         ; cull
        cmp  ax,NEARZ
        jl   @@rej              ; entirely behind
        mov  ax,[minrz]
        cmp  ax,FARZ
        jg   @@rej              ; entirely too far
        clc
        ret
@@rej:  stc
        ret
@@trk:  mov  ax,[rcz]           ; update minrz/maxrz with rcz
        cmp  ax,[minrz]
        jge  @@t1
        mov  [minrz],ax
@@t1:   cmp  ax,[maxrz]
        jle  @@t2
        mov  [maxrz],ax
@@t2:   ret

; iterate visible vertical faces, calling FACEV+FACEFILL for each
VISFILL:
        ; west  (camx < bwx0): corners 3,0  - E/W faces get the shaded colour
        mov  ax,[camx]
        cmp  ax,[bwx0]
        jge  @@e
        mov  byte ptr [COLOR],16
        mov  word ptr [fa],3
        mov  word ptr [fb],0
        call FACEV
        call FACEFILL
@@e:    mov  ax,[camx]          ; east (camx > bwx1): 1,2
        cmp  ax,[bwx1]
        jle  @@s
        mov  byte ptr [COLOR],16
        mov  word ptr [fa],1
        mov  word ptr [fb],2
        call FACEV
        call FACEFILL
@@s:    mov  ax,[camz]          ; south (camz < bwz0): 0,1 - sun-facing sides
        cmp  ax,[bwz0]
        jge  @@n
        mov  byte ptr [COLOR],0
        mov  word ptr [fa],0
        mov  word ptr [fb],1
        call FACEV
        call FACEFILL
@@n:    mov  ax,[camz]          ; north (camz > bwz1): 2,3
        cmp  ax,[bwz1]
        jle  @@d
        mov  byte ptr [COLOR],0
        mov  word ptr [fa],2
        mov  word ptr [fb],3
        call FACEV
        call FACEFILL
@@d:    ret

; iterate visible vertical faces, stroking + windows on near ones
VISSTROKE:
        mov  ax,[camx]
        cmp  ax,[bwx0]
        jge  @@e
        mov  al,[scol]          ; windows change COLOR - restore per face
        mov  [COLOR],al
        mov  word ptr [fa],3
        mov  word ptr [fb],0
        call FACEV
        call FACESTROKE
        call WINMAYBE
@@e:    mov  ax,[camx]
        cmp  ax,[bwx1]
        jle  @@s
        mov  al,[scol]
        mov  [COLOR],al
        mov  word ptr [fa],1
        mov  word ptr [fb],2
        call FACEV
        call FACESTROKE
        call WINMAYBE
@@s:    mov  ax,[camz]
        cmp  ax,[bwz0]
        jge  @@n
        mov  al,[scol]
        mov  [COLOR],al
        mov  word ptr [fa],0
        mov  word ptr [fb],1
        call FACEV
        call FACESTROKE
        call WINMAYBE
@@n:    mov  ax,[camz]
        cmp  ax,[bwz1]
        jle  @@d
        mov  al,[scol]
        mov  [COLOR],al
        mov  word ptr [fa],2
        mov  word ptr [fb],3
        call FACEV
        call FACESTROKE
        call WINMAYBE
@@d:    ret

; windows only on near faces
WINMAYBE:
        mov  ax,[minrz]
        cmp  ax,1200
        jg   @@x
        call WINFACE
@@x:    ret

; ============================================================================
;  DRAW A 3D EDGE: near clip -> project -> line clip -> draw
; ============================================================================
DRAWEDGE3D:
        call NEARCLIP
        jc   @@skip
        call PROJ2
        call CLIPLINE
        jc   @@skip
        call LINE
@@skip: ret

; ----- near Z-plane clipping ------------------------------------------------
NEARCLIP:
        mov  ax,[z0]
        cmp  ax,NEARZ
        jge  @@p0in
        mov  bx,[z1]
        cmp  bx,NEARZ
        jl   @@rej
        call CLIPP0
        clc
        ret
@@p0in: mov  bx,[z1]
        cmp  bx,NEARZ
        jge  @@both
        call CLIPP1
        clc
        ret
@@both: clc
        ret
@@rej:  stc
        ret

CLIPP0: mov  bx,[z1]
        sub  bx,[z0]
        mov  ax,NEARZ
        sub  ax,[z0]
        mov  [tnum],ax
        mov  [tden],bx
        mov  ax,[x1]
        sub  ax,[x0]
        imul word ptr [tnum]
        idiv word ptr [tden]
        add  ax,[x0]
        mov  [x0],ax
        mov  ax,[y1]
        sub  ax,[y0]
        imul word ptr [tnum]
        idiv word ptr [tden]
        add  ax,[y0]
        mov  [y0],ax
        mov  word ptr [z0],NEARZ
        ret

CLIPP1: mov  bx,[z0]
        sub  bx,[z1]
        mov  ax,NEARZ
        sub  ax,[z1]
        mov  [tnum],ax
        mov  [tden],bx
        mov  ax,[x0]
        sub  ax,[x1]
        imul word ptr [tnum]
        idiv word ptr [tden]
        add  ax,[x1]
        mov  [x1],ax
        mov  ax,[y0]
        sub  ax,[y1]
        imul word ptr [tnum]
        idiv word ptr [tden]
        add  ax,[y1]
        mov  [y1],ax
        mov  word ptr [z1],NEARZ
        ret

; ----- project both points --------------------------------------------------
PROJ2:  mov  ax,[x0]
        mov  dx,[y0]
        mov  cx,[z0]
        call PROJPT
        mov  [sx0],ax
        mov  [sy0],dx
        mov  ax,[x1]
        mov  dx,[y1]
        mov  cx,[z1]
        call PROJPT
        mov  [sx1],ax
        mov  [sy1],dx
        ret

CLAMPAX:
        cmp  ax,4000
        jle  @@a1
        mov  ax,4000
@@a1:   cmp  ax,-4000
        jge  @@a2
        mov  ax,-4000
@@a2:   ret

; ============================================================================
;  SINQ  in: AX=angle (any, wrapped to 0..255 = full circle)
;        out: AX = sin(angle)*256  (range -256..256);  clobbers BX,CX,SI
;  Quarter table SINT[0..64] + symmetry: q0=+T[idx] q1=+T[64-idx]
;  q2=-T[idx] q3=-T[64-idx].  cos(a) = SINQ(a+64).
; ============================================================================
SINQ:   and  ax,255             ; wrap to one circle
        mov  bx,ax
        mov  cl,6
        shr  bx,cl              ; bx = quadrant 0..3  (angle/64)
        and  ax,63              ; ax = idx within quadrant 0..63
        cmp  bx,0
        je   @@q0
        cmp  bx,1
        je   @@q1
        cmp  bx,2
        je   @@q2
        ; q3: -SINT[64-idx]
        mov  bx,64
        sub  bx,ax
        add  bx,bx
        mov  si,bx
        mov  ax,[SINT+si]
        neg  ax
        ret
@@q0:   add  ax,ax
        mov  si,ax
        mov  ax,[SINT+si]
        ret
@@q1:   mov  bx,64              ; SINT[64-idx]
        sub  bx,ax
        add  bx,bx
        mov  si,bx
        mov  ax,[SINT+si]
        ret
@@q2:   add  ax,ax              ; -SINT[idx]
        mov  si,ax
        mov  ax,[SINT+si]
        neg  ax
        ret

; ============================================================================
;  SETTRIG  heading -> hsin/hcos, roll -> rsin/rcos (all *256).
;  Call ONCE per frame before RENDER. Clobbers AX,BX,CX,SI.
; ============================================================================
SETTRIG:
        mov  ax,[heading]
        call SINQ
        mov  [hsin],ax
        mov  ax,[heading]
        add  ax,64
        call SINQ
        mov  [hcos],ax
        mov  ax,[roll]
        call SINQ
        neg  ax                 ; flip roll direction (bank into the turn)
        mov  [rsin],ax
        mov  ax,[roll]
        add  ax,64
        call SINQ
        mov  [rcos],ax
        ret

; ============================================================================
;  ROTXZ  yaw-rotate world-relative (wdx,wdz) -> camera-space (rcx,rcz)
;   in:  wdx,wdz (mem)   out: rcx,rcz (mem)   clobbers AX,BX,DX
;   rcx = (wdx*hcos - wdz*hsin)/256 ;  rcz = (wdx*hsin + wdz*hcos)/256
;   Each term: imul (->DX:AX) then idiv 256. Inputs are small view offsets
;   so |product| < ~500k (fits DX:AX) and |quotient| < ~3000 (fits 16-bit).
; ============================================================================
ROTXZ:  mov  ax,[wdx]
        imul word ptr [hcos]    ; DX:AX = wdx*cos*256
        mov  bx,256
        idiv bx                 ; AX = wdx*cos   (the *256 cancels)
        mov  [rcx],ax
        mov  ax,[wdz]
        imul word ptr [hsin]
        mov  bx,256
        idiv bx
        mov  bx,[rcx]
        sub  bx,ax
        mov  [rcx],bx
        mov  ax,[wdx]
        imul word ptr [hsin]
        mov  bx,256
        idiv bx
        mov  [rcz],ax
        mov  ax,[wdz]
        imul word ptr [hcos]
        mov  bx,256
        idiv bx
        mov  bx,[rcz]
        add  bx,ax
        mov  [rcz],bx
        ret

; ============================================================================
;  APPLYROLL  bank the scene: rotate a projected point about screen (160,100)
;   in: AX=sx_raw, DX=sy_raw   out: AX=sx, DX=sy   clobbers BX,SI,rddx/rddy/rsxo
;   Same *256 / idiv 256 fixed-point rotate as ROTXZ. Applied per vertex
;   inside PROJPT so all world geometry tilts; HUD/crosshair bypass it.
; ============================================================================
APPLYROLL:
        sub  ax,160             ; rddx,rddy = offset from the view centre
        mov  [rddx],ax
        sub  dx,[horiz]         ; roll pivots on the pitch horizon
        mov  [rddy],dx
        ; sx = 160 + (rddx*rcos - rddy*rsin)/256
        mov  ax,[rddx]
        imul word ptr [rcos]
        mov  bx,256
        idiv bx
        mov  si,ax
        mov  ax,[rddy]
        imul word ptr [rsin]
        mov  bx,256
        idiv bx
        mov  bx,si
        sub  bx,ax
        add  bx,160
        mov  [rsxo],bx
        ; sy = 100 + (rddx*rsin + rddy*rcos)/256
        mov  ax,[rddx]
        imul word ptr [rsin]
        mov  bx,256
        idiv bx
        mov  si,ax
        mov  ax,[rddy]
        imul word ptr [rcos]
        mov  bx,256
        idiv bx
        mov  bx,si
        add  bx,ax
        add  bx,[horiz]
        mov  ax,[rsxo]
        mov  dx,bx
        ret

; ============================================================================
;  PROJPT  perspective-project one camera-space point, then bank + clamp.
;   in: AX=rx, DX=ry, CX=rz (>0)   out: AX=sx, DX=sy   clobbers BX,CX,SI,ptmp
;   sx = 160 + rx*FOCAL/rz ;  sy = 100 - ry*FOCAL/rz ;  then APPLYROLL.
;   rz must already be >= NEARZ (caller/NEARCLIP guarantees it) so the
;   divide can't overflow. CLAMPAX bounds results to +/-4000 for safe 2D clip.
; ============================================================================
PROJPT: push dx                 ; save ry
        ; guard: at FARZ=10800 a side point can have |rx| up to ~15000 while
        ; rz is small; rx*160/rz would then overflow a 16-bit quotient (INT 0).
        ; overflow needs rz < |rx|*160/32767 ~ |rx|/204, i.e. only rz < 74.
        cmp  cx,160
        jge  @@sxok
        mov  bx,ax
        or   bx,bx
        jns  @@g1
        neg  bx                 ; bx = |rx|
@@g1:   push ax
        mov  ax,cx
        mov  dx,204
        mul  dx                 ; ax = rz*204 (rz<74 -> fits 16-bit)
        cmp  bx,ax
        pop  ax
        jbe  @@sxok             ; |rx| <= rz*204 -> divide is safe
        mov  bx,4000            ; would overflow: clamp offscreen, keep sign
        or   ax,ax
        jns  @@g2
        neg  bx
@@g2:   mov  ax,bx
        jmp  @@sxadd
@@sxok: mov  bx,FOCAL
        imul bx                 ; DX:AX = rx*FOCAL
        idiv cx                 ; AX = rx*FOCAL/rz
@@sxadd:
        add  ax,160             ; sx_raw (screen centre x = 160)
        call CLAMPAX            ; clamp BEFORE roll so APPLYROLL can't overflow
        mov  [ptmp],ax
        pop  ax                 ; ry
        mov  bx,FOCAL
        imul bx
        idiv cx
        mov  bx,[horiz]
        sub  bx,ax              ; sy_raw = horiz - ry*FOCAL/rz (pitch shifts view)
        mov  ax,bx
        call CLAMPAX
        mov  dx,ax
        mov  ax,[ptmp]          ; AX=sx_raw, DX=sy_raw (both clamped)
        call APPLYROLL          ; bank the whole scene about (160,horiz)
        call CLAMPAX            ; final clamp for the 2D clipper
        mov  [ptmp],ax
        mov  ax,dx
        call CLAMPAX
        mov  dx,ax
        mov  ax,[ptmp]
        ret

; ============================================================================
;  FACEV  build a vertical face quad from footprint corners [fa],[fb]
;  using camera-space corners FRX/FRZ and heights bry0(bottom)/bry1(top)
;  quad order: A_bottom, A_top, B_top, B_bottom
; ============================================================================
FACEV:  mov  si,[fa]
        add  si,si
        mov  ax,[FRX+si]
        mov  [IX],ax
        mov  [IX+2],ax
        mov  ax,[FRZ+si]
        mov  [IZ],ax
        mov  [IZ+2],ax
        mov  si,[fb]
        add  si,si
        mov  ax,[FRX+si]
        mov  [IX+4],ax
        mov  [IX+6],ax
        mov  ax,[FRZ+si]
        mov  [IZ+4],ax
        mov  [IZ+6],ax
        mov  ax,[bry0]
        mov  [IY],ax
        mov  [IY+6],ax
        mov  ax,[bry1]
        mov  [IY+2],ax
        mov  [IY+4],ax
        ret

; ============================================================================
;  FACETOPC  build the roof quad from all 4 footprint corners at bry1
; ============================================================================
FACETOPC:
        mov  ax,[FRX]
        mov  [IX],ax
        mov  ax,[FRZ]
        mov  [IZ],ax
        mov  ax,[FRX+2]
        mov  [IX+2],ax
        mov  ax,[FRZ+2]
        mov  [IZ+2],ax
        mov  ax,[FRX+4]
        mov  [IX+4],ax
        mov  ax,[FRZ+4]
        mov  [IZ+4],ax
        mov  ax,[FRX+6]
        mov  [IX+6],ax
        mov  ax,[FRZ+6]
        mov  [IZ+6],ax
        mov  ax,[bry1]
        mov  [IY],ax
        mov  [IY+2],ax
        mov  [IY+4],ax
        mov  [IY+6],ax
        ret

; ============================================================================
;  HBLD  deterministic building descriptor for grid cell [gi],[gj]
;   out: bstreet (1 = empty avenue cell), and if 0: bhw,bhd (half-size 84..115)
;        and bhgt2 (height 100..355).  Clobbers AX,BX,CX,SI.
;   Streets: any cell with gi&3==0 or gj&3==0 is empty -> 3x3 blocks + wide
;   avenues. Otherwise a cheap integer hash of (gi,gj) picks the dimensions;
;   bit-fields of the hash give width / depth / height (deterministic, so the
;   same cell always looks identical - no per-frame flicker, no storage).
; ============================================================================
HBLD:   mov  ax,[gi]            ; world zoning first: city / plains / mountains
        mov  bx,[gj]
        call GETZONE
        cmp  ax,1
        je   @@st               ; plains: the terrain mesh paints the land
        cmp  ax,2
        je   @@st               ; mountains: the terrain mesh IS the mountain
        cmp  ax,3
        je   @@st               ; water: the terrain mesh paints the sea
        cmp  ax,4
        je   @@st               ; foothills: terrain paints the woods
        mov  ax,[gi]
        and  ax,3
        jz   @@st              ; gi on an avenue -> street
        mov  ax,[gj]
        and  ax,3
        jz   @@st              ; gj on an avenue -> street
        call CELLHASH          ; ax = hash of (gi,gj)
        mov  bx,ax
        and  bx,31              ; hash 7/8/9 of 32 -> flat terrain patches
        cmp  bx,7
        je   @@forest
        cmp  bx,8
        je   @@water
        cmp  bx,9
        je   @@field
        mov  bx,ax
        and  bx,31              ; bits[0..4]  -> half width  84..115
        add  bx,84
        mov  [bhw],bx
        mov  bx,ax
        mov  cl,5
        shr  bx,cl
        and  bx,31              ; bits[5..9]  -> half depth  84..115
        add  bx,84
        mov  [bhd],bx
        ; downtown composition: towers cluster toward the centre of each 8x8
        ; superblock. dist = |gi&7 - 4| + |gj&7 - 4| (0..8); centre -> +288.
        push ax
        mov  bx,[gi]
        and  bx,7
        sub  bx,4
        jns  @@a1
        neg  bx
@@a1:   mov  si,bx              ; |gi&7 - 4|
        mov  bx,[gj]
        and  bx,7
        sub  bx,4
        jns  @@a2
        neg  bx
@@a2:   add  si,bx              ; manhattan dist to superblock centre, 0..8
        mov  ax,8
        sub  ax,si
        mov  bx,36
        imul bx                 ; downtown bonus 0..288
        mov  si,ax
        pop  ax
        mov  bx,ax
        and  bx,63              ; per-building variation 0..63
        add  bx,50
        add  bx,si              ; height 50..401 (respawn 420 clears all)
        mov  [bhgt2],bx
        mov  word ptr [bstreet],0
        ret
@@st:   mov  word ptr [bstreet],1
        ret
@@forest:
        mov  byte ptr [bcol],15
        jmp  @@patch
@@water:
        mov  byte ptr [bcol],14
        jmp  @@patch
@@field:
        mov  byte ptr [bcol],11
@@patch:                        ; flat ground patch fills most of the cell
        mov  word ptr [bhw],116
        mov  word ptr [bhd],116
        mov  word ptr [bstreet],2
        ret

; hash = mix(gi*1973 + gj*9277) - shared by buildings, patches and mountains
CELLHASH:
        mov  ax,[gi]
        mov  bx,1973
        imul bx
        mov  si,ax
        mov  ax,[gj]
        mov  bx,9277
        imul bx
        add  ax,si
        mov  bx,ax
        mov  cl,7
        shr  bx,cl
        xor  ax,bx
        ret

; ============================================================================
;  WINFACE  draw lit windows on the current vertical face (IX/IY/IZ[0..3])
;  corner order: 0=A_bot 1=A_top 2=B_top 3=B_bot ; needs all IZ>=NEARZ
; ============================================================================
WINFACE:
        ; require all 4 corners in front of near plane
        mov  ax,[IZ]
        cmp  ax,NEARZ
        jl   @@ret
        mov  ax,[IZ+2]
        cmp  ax,NEARZ
        jl   @@ret
        mov  ax,[IZ+4]
        cmp  ax,NEARZ
        jl   @@ret
        mov  ax,[IZ+6]
        cmp  ax,NEARZ
        jl   @@ret
        ; project 4 corners -> wqx/wqy
        mov  word ptr [pk],0
@@pj:   mov  si,[pk]
        add  si,si
        mov  ax,[IX+si]
        mov  dx,[IY+si]
        mov  cx,[IZ+si]
        call PROJPT
        mov  si,[pk]
        add  si,si
        mov  [wqx+si],ax
        mov  [wqy+si],dx
        inc  word ptr [pk]
        mov  ax,[pk]
        cmp  ax,4
        jl   @@pj
        ; grid 3 cols x 5 rows, bilinear in screen space; each window = 3x3 px
        mov  byte ptr [wr],0
@@rl:   mov  byte ptr [wc],0
@@cl:
        ; u = (2*wc+1)/6  -> work with numerator wfu over 6
        mov  al,[wc]
        cbw
        add  ax,ax
        inc  ax
        mov  [wfu],ax
        ; v numerator over 8
        mov  al,[wr]
        cbw
        add  ax,ax
        inc  ax
        mov  [wfv],ax
        ; top point = wq1 + (wq2-wq1)*u/6
        mov  ax,[wqx+4]
        sub  ax,[wqx+2]
        imul word ptr [wfu]
        mov  bx,6
        idiv bx
        add  ax,[wqx+2]
        mov  [sx0],ax           ; reuse sx0/sy0 = top
        mov  ax,[wqy+4]
        sub  ax,[wqy+2]
        imul word ptr [wfu]
        mov  bx,6
        idiv bx
        add  ax,[wqy+2]
        mov  [sy0],ax
        ; bottom point = wq0 + (wq3-wq0)*u/6
        mov  ax,[wqx+6]
        sub  ax,[wqx]
        imul word ptr [wfu]
        mov  bx,6
        idiv bx
        add  ax,[wqx]
        mov  [sx1],ax           ; reuse sx1/sy1 = bottom
        mov  ax,[wqy+6]
        sub  ax,[wqy]
        imul word ptr [wfu]
        mov  bx,6
        idiv bx
        add  ax,[wqy]
        mov  [sy1],ax
        ; px = top + (bottom-top)*v/8
        mov  ax,[sx1]
        sub  ax,[sx0]
        imul word ptr [wfv]
        mov  bx,10
        idiv bx
        add  ax,[sx0]
        mov  [wpx],ax
        mov  ax,[sy1]
        sub  ax,[sy0]
        imul word ptr [wfv]
        mov  bx,10
        idiv bx
        add  ax,[sy0]
        mov  [wpy],ax
        ; bounds
        mov  ax,[wpx]
        cmp  ax,2
        jl   @@wn
        cmp  ax,317
        jg   @@wn
        mov  ax,[wpy]
        cmp  ax,2
        jl   @@wn
        cmp  ax,197
        jg   @@wn
        call WLIT2
        jz   @@wn
        mov  al,3                   ; window block: 3x3 near, 1x1 mid-range
        cmp  word ptr [minrz],600
        jle  @@wsz
        mov  al,1
@@wsz:  mov  [wbsz],al
        mov  byte ptr [wbj],0
@@wby:  mov  byte ptr [wbi],0
@@wbx:  mov  al,[wbi]
        cbw
        add  ax,[wpx]
        mov  bl,[wbj]
        xor  bh,bh
        add  bx,[wpy]
        call PUTPIXEL
        inc  byte ptr [wbi]
        mov  al,[wbi]
        cmp  al,[wbsz]
        jl   @@wbx
        inc  byte ptr [wbj]
        mov  al,[wbj]
        cmp  al,[wbsz]
        jl   @@wby
@@wn:   inc  byte ptr [wc]
        cmp  byte ptr [wc],3
        jl   @@cl
        inc  byte ptr [wr]
        cmp  byte ptr [wr],5
        jl   @@rl
@@ret:  ret

; lit? hash from gi,gj,fa,wr,wc -> ZF=1 not lit else COLOR set
WLIT2:  mov  ax,[gi]
        mov  bx,131
        imul bx
        mov  si,ax
        mov  ax,[gj]
        mov  bx,977
        imul bx
        add  ax,si
        mov  bx,[fa]
        add  ax,bx
        mov  bl,[wr]
        xor  bh,bh
        mov  cx,101
        push ax
        mov  ax,bx
        mul  cx
        mov  bx,ax
        pop  ax
        add  ax,bx
        mov  bl,[wc]
        xor  bh,bh
        mov  cx,57
        push ax
        mov  ax,bx
        mul  cx
        mov  bx,ax
        pop  ax
        add  ax,bx
        mov  bx,ax
        mov  cl,5
        shr  bx,cl
        xor  ax,bx
        mov  bx,ax
        and  bx,7
        cmp  bx,3
        jl   @@lit
        xor  al,al
        ret
@@lit:  mov  bx,ax
        and  bx,31
        jnz  @@cy
        mov  byte ptr [COLOR],5
        jmp  @@d
@@cy:   mov  byte ptr [COLOR],4
@@d:    mov  al,1
        or   al,al
        ret

; ============================================================================
;  CLIPNEAR: Sutherland-Hodgman clip of the face IX/IY/IZ[0..3] to Z >= NEARZ.
;  Output polygon -> OX/OY/OZ[0..NPOLY-1] (3..5 verts). Walks the 4 edges;
;  keeps in-front vertices and, on each in/out crossing, inserts the edge's
;  intersection with the Z=NEARZ plane (APPENDISECT). This is what lets a
;  building you fly past get sliced cleanly instead of popping out of view.
; ============================================================================
CLIPNEAR:
        mov  word ptr [oc],0
        mov  word ptr [ci],0
@@cl:   mov  ax,[ci]
        add  ax,2
        cmp  ax,8
        jl   @@nw
        xor  ax,ax
@@nw:   mov  [ni],ax
        ; curIn -> dl, nextIn -> dh
        mov  si,[ci]
        mov  ax,[IZ+si]
        mov  dl,0
        cmp  ax,NEARZ
        jl   @@a
        mov  dl,1
@@a:    mov  si,[ni]
        mov  ax,[IZ+si]
        mov  dh,0
        cmp  ax,NEARZ
        jl   @@b
        mov  dh,1
@@b:    test dl,dl
        jz   @@nocur
        mov  si,[ci]
        call APPENDV
@@nocur:
        cmp  dl,dh
        je   @@nois
        call APPENDISECT
@@nois:
        mov  ax,[ci]
        add  ax,2
        cmp  ax,8
        jge  @@end
        mov  [ci],ax
        jmp  @@cl
@@end:  mov  ax,[oc]
        mov  [NPOLY],ax
        ret

; append vertex IX/IY/IZ[si] to O*[oc]; oc++
APPENDV:
        mov  di,[oc]
        add  di,di
        mov  ax,[IX+si]
        mov  [OX+di],ax
        mov  ax,[IY+si]
        mov  [OY+di],ax
        mov  ax,[IZ+si]
        mov  [OZ+di],ax
        inc  word ptr [oc]
        ret

; append intersection of edge ci->ni with plane Z=NEARZ
APPENDISECT:
        mov  si,[ci]
        mov  di,[ni]
        mov  ax,NEARZ
        sub  ax,[IZ+si]
        mov  [tnum],ax          ; num = NEARZ - z0
        mov  ax,[IZ+di]
        sub  ax,[IZ+si]
        mov  [tden],ax          ; den = z1 - z0  (nonzero)
        mov  ax,[IX+di]
        sub  ax,[IX+si]
        imul word ptr [tnum]
        idiv word ptr [tden]
        add  ax,[IX+si]
        push ax                 ; ox
        mov  ax,[IY+di]
        sub  ax,[IY+si]
        imul word ptr [tnum]
        idiv word ptr [tden]
        add  ax,[IY+si]
        push ax                 ; oy
        mov  di,[oc]
        add  di,di
        pop  ax
        mov  [OY+di],ax
        pop  ax
        mov  [OX+di],ax
        mov  word ptr [OZ+di],NEARZ
        inc  word ptr [oc]
        ret

; project OX/OY/OZ[0..NPOLY-1] -> PX/PY
PROJPOLY:
        mov  word ptr [pk],0
@@p:    mov  si,[pk]
        add  si,si
        mov  ax,[OX+si]
        mov  dx,[OY+si]
        mov  cx,[OZ+si]
        call PROJPT
        mov  si,[pk]
        add  si,si
        mov  [PX+si],ax
        mov  [PY+si],dx
        inc  word ptr [pk]
        mov  ax,[pk]
        cmp  ax,[NPOLY]
        jl   @@p
        ret

; ============================================================================
;  SCANPOLY: solid-fill convex polygon PX/PY[0..NPOLY-1] in COLOR (ES=bufseg).
;  Scanline fill: for each y in [minY,maxY] (clamped to screen), intersect the
;  y line with every edge (half-open lo<=y<hi so each scanline hits exactly 2
;  edges), take min/max x, clamp to [0,319], and rep-stosb the span. The
;  fills (drawn far->near) are what hide buildings behind nearer ones.
; ============================================================================
SCANPOLY:
        mov  ax,[PY]
        mov  [pminy],ax
        mov  [pmaxy],ax
        mov  cx,[NPOLY]
        dec  cx
        mov  si,2
@@mm:   mov  ax,[PY+si]
        cmp  ax,[pminy]
        jge  @@mm1
        mov  [pminy],ax
@@mm1:  cmp  ax,[pmaxy]
        jle  @@mm2
        mov  [pmaxy],ax
@@mm2:  add  si,2
        loop @@mm
        mov  ax,[pminy]
        cmp  ax,0
        jge  @@y0
        xor  ax,ax
@@y0:   mov  [scy],ax
        mov  ax,[pmaxy]
        cmp  ax,199
        jle  @@y1
        mov  ax,199
@@y1:   mov  [scymax],ax
        mov  ax,[scy]
        cmp  ax,[scymax]
        jg   @@done
@@yloop:
        mov  word ptr [scxl],32767
        mov  word ptr [scxr],-32768
        mov  cx,[NPOLY]
        xor  si,si
@@eloop:
        mov  di,si
        add  di,2
        mov  ax,[NPOLY]
        add  ax,ax
        cmp  di,ax
        jl   @@nw2
        xor  di,di
@@nw2:  mov  ax,[PY+si]
        mov  bx,[PY+di]
        cmp  ax,bx
        jle  @@io
        xchg ax,bx
@@io:   mov  dx,[scy]
        cmp  dx,ax
        jl   @@enext
        cmp  dx,bx
        jge  @@enext
        mov  ax,[PX+di]
        sub  ax,[PX+si]
        mov  bx,[scy]
        sub  bx,[PY+si]
        imul bx
        mov  bx,[PY+di]
        sub  bx,[PY+si]
        idiv bx
        add  ax,[PX+si]
        cmp  ax,[scxl]
        jge  @@nxl
        mov  [scxl],ax
@@nxl:  cmp  ax,[scxr]
        jle  @@enext
        mov  [scxr],ax
@@enext:
        add  si,2
        loop @@eloop
        mov  ax,[scxl]
        cmp  ax,[scxr]
        jg   @@nextY
        cmp  ax,0
        jge  @@fxl
        xor  ax,ax
@@fxl:  mov  [scxl],ax
        mov  ax,[scxr]
        cmp  ax,319
        jle  @@fxr
        mov  ax,319
@@fxr:  mov  [scxr],ax
        mov  ax,[scxl]
        cmp  ax,[scxr]
        jg   @@nextY
        mov  di,[scy]
        mov  cl,8
        shl  di,cl
        mov  bx,[scy]
        mov  cl,6
        shl  bx,cl
        add  di,bx
        add  di,[scxl]
        mov  cx,[scxr]
        sub  cx,[scxl]
        inc  cx
        mov  al,[COLOR]
        rep  stosb
@@nextY:
        mov  ax,[scy]
        inc  ax
        mov  [scy],ax
        cmp  ax,[scymax]
        jle  @@yloop
@@done: ret

; ============================================================================
;  STROKEPOLY: outline polygon PX/PY[0..NPOLY-1] with COLOR  (ES=bufseg)
; ============================================================================
STROKEPOLY:
        mov  word ptr [pk],0
@@s:    mov  si,[pk]
        add  si,si
        mov  ax,[PX+si]
        mov  [sx0],ax
        mov  ax,[PY+si]
        mov  [sy0],ax
        mov  ax,[pk]
        inc  ax
        cmp  ax,[NPOLY]
        jl   @@nj
        xor  ax,ax
@@nj:   add  ax,ax
        mov  si,ax
        mov  ax,[PX+si]
        mov  [sx1],ax
        mov  ax,[PY+si]
        mov  [sy1],ax
        call CLIPLINE
        jc   @@sk
        call LINE
@@sk:   inc  word ptr [pk]
        mov  ax,[pk]
        cmp  ax,[NPOLY]
        jl   @@s
        ret

; ============================================================================
;  FACEFILL / FACESTROKE: clip current IX/IY/IZ face, then fill / stroke
; ============================================================================
FACEFILL:
        call CLIPNEAR
        mov  ax,[NPOLY]
        cmp  ax,3
        jl   @@x
        call PROJPOLY
        call SCANPOLY
@@x:    ret

FACESTROKE:
        call CLIPNEAR
        mov  ax,[NPOLY]
        cmp  ax,2
        jl   @@x
        call PROJPOLY
        call STROKEPOLY
@@x:    ret

; ============================================================================
;  SCREEN LINE CLIPPING (Cohen-Sutherland), rect 0..319 x 0..199
;  in/out: sx0,sy0,sx1,sy1   ; CF=1 if the line is fully rejected
; ============================================================================
OUTCODE:                        ; in: AX=x, BX=y -> AL=code
        push cx
        xor  cl,cl
        cmp  ax,0
        jge  @@c1
        or   cl,1
        jmp  @@c2
@@c1:   cmp  ax,319
        jle  @@c2
        or   cl,2
@@c2:   cmp  bx,0
        jge  @@c3
        or   cl,8
        jmp  @@c4
@@c3:   cmp  bx,199
        jle  @@c4
        or   cl,4
@@c4:   mov  al,cl
        pop  cx
        ret

CLIPLINE:
        mov  ax,[sx0]
        mov  bx,[sy0]
        call OUTCODE
        mov  [oc0],al
        mov  ax,[sx1]
        mov  bx,[sy1]
        call OUTCODE
        mov  [oc1],al
@@iter: mov  al,[oc0]
        or   al,[oc1]
        jnz  @@nacc
        clc
        ret
@@nacc: mov  al,[oc0]
        and  al,[oc1]
        jz   @@clip
        stc
        ret
@@clip: mov  al,[oc0]
        test al,al
        jnz  @@use0
        mov  al,[oc1]
@@use0: mov  [ocsel],al
        mov  ax,[sx1]
        sub  ax,[sx0]
        mov  [cdx],ax
        mov  ax,[sy1]
        sub  ax,[sy0]
        mov  [cdy],ax
        mov  al,[ocsel]
        test al,8
        jnz  @@top
        test al,4
        jnz  @@bot
        test al,2
        jnz  @@right
        ; LEFT: x=0
        mov  ax,[sx0]
        neg  ax
        imul word ptr [cdy]
        idiv word ptr [cdx]
        add  ax,[sy0]
        mov  [ny],ax
        mov  word ptr [nx],0
        jmp  @@apply
@@right:                        ; x=319
        mov  ax,319
        sub  ax,[sx0]
        imul word ptr [cdy]
        idiv word ptr [cdx]
        add  ax,[sy0]
        mov  [ny],ax
        mov  word ptr [nx],319
        jmp  @@apply
@@top:                          ; y=0
        mov  ax,[sy0]
        neg  ax
        imul word ptr [cdx]
        idiv word ptr [cdy]
        add  ax,[sx0]
        mov  [nx],ax
        mov  word ptr [ny],0
        jmp  @@apply
@@bot:                          ; y=199
        mov  ax,199
        sub  ax,[sy0]
        imul word ptr [cdx]
        idiv word ptr [cdy]
        add  ax,[sx0]
        mov  [nx],ax
        mov  word ptr [ny],199
@@apply:
        mov  al,[oc0]
        test al,al
        jz   @@setp1
        mov  ax,[nx]
        mov  [sx0],ax
        mov  ax,[ny]
        mov  [sy0],ax
        mov  ax,[sx0]
        mov  bx,[sy0]
        call OUTCODE
        mov  [oc0],al
        jmp  @@iter
@@setp1:
        mov  ax,[nx]
        mov  [sx1],ax
        mov  ax,[ny]
        mov  [sy1],ax
        mov  ax,[sx1]
        mov  bx,[sy1]
        call OUTCODE
        mov  [oc1],al
        jmp  @@iter

; ============================================================================
;  LINE (Bresenham)   in: sx0,sy0,sx1,sy1, COLOR   ; ES=bufseg
; ============================================================================
LINE:
        mov  ax,[sx1]
        sub  ax,[sx0]
        mov  word ptr [lsx],1
        jns  @@dxp
        neg  ax
        mov  word ptr [lsx],-1
@@dxp:  mov  [ldx],ax
        mov  ax,[sy1]
        sub  ax,[sy0]
        mov  word ptr [lsy],1
        jns  @@dyp
        neg  ax
        mov  word ptr [lsy],-1
@@dyp:  neg  ax
        mov  [ldy],ax
        mov  ax,[ldx]
        add  ax,[ldy]
        mov  [lerr],ax
        mov  ax,[sx0]
        mov  [lx],ax
        mov  ax,[sy0]
        mov  [ly],ax
@@loop:
        mov  ax,[lx]
        mov  bx,[ly]
        call PUTPIXEL
        mov  ax,[lx]
        cmp  ax,[sx1]
        jne  @@cont
        mov  ax,[ly]
        cmp  ax,[sy1]
        jne  @@cont
        ret
@@cont: mov  ax,[lerr]
        add  ax,ax
        mov  bx,ax              ; e2
        cmp  bx,[ldy]
        jl   @@sx
        mov  ax,[lerr]
        add  ax,[ldy]
        mov  [lerr],ax
        mov  ax,[lx]
        add  ax,[lsx]
        mov  [lx],ax
@@sx:   cmp  bx,[ldx]
        jg   @@sy
        mov  ax,[lerr]
        add  ax,[ldx]
        mov  [lerr],ax
        mov  ax,[ly]
        add  ax,[lsy]
        mov  [ly],ax
@@sy:   jmp  @@loop

; ============================================================================
;  PUTPIXEL  in: AX=x, BX=y, COLOR   ; ES=bufseg   (preserves registers)
; ============================================================================
PUTPIXEL:
        push ax
        push bx
        push cx
        push dx
        push di
        mov  di,bx
        mov  cl,8
        shl  di,cl              ; y*256
        mov  dx,bx
        mov  cl,6
        shl  dx,cl              ; y*64
        add  di,dx
        add  di,ax              ; +x
        mov  dl,[COLOR]
        mov  es:[di],dl
        pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ============================================================================
;  CROSSHAIR in screen center  ; ES=bufseg
; ============================================================================
CROSS:  mov  byte ptr [COLOR],8
        mov  word ptr [sx0],150
        mov  word ptr [sy0],100
        mov  word ptr [sx1],157
        mov  word ptr [sy1],100
        call LINE
        mov  word ptr [sx0],163
        mov  word ptr [sy0],100
        mov  word ptr [sx1],170
        mov  word ptr [sy1],100
        call LINE
        mov  word ptr [sx0],160
        mov  word ptr [sy0],92
        mov  word ptr [sx1],160
        mov  word ptr [sy1],98
        call LINE
        ret

; ============================================================================
;  INPUT  (via KEYS table) -> update camera
; ============================================================================
; turn (yaw) + bank (roll) + climb + auto-advance along heading
; ============================================================================
;  INPUT - one physics tick of the jet flight model (see constants block).
;  Order: air density -> engine (fuel burn, thrust) -> drag -> F=ma airspeed
;  -> turn + bank (induced drag) -> pitch/energy (dive gains speed, climb
;  costs it) -> stall -> altitude clamp -> wind drift -> advance along heading.
; ============================================================================
INPUT:
        ; --- air density: rho = 256 - camy/8, clamped to 64..256 ---
        mov  ax,[camy]
        mov  bx,ax
        mov  cl,3
        shr  bx,cl
        mov  ax,256
        sub  ax,bx
        cmp  ax,64
        jge  @@r1
        mov  ax,64
@@r1:   mov  [rho],ax

        ; --- engine: burn fuel; jet thrust breathes air: T*(rho+256)/512 ---
        xor  cx,cx              ; default thrust 0 (flame-out)
        mov  ax,[fuel]
        test ax,ax
        jz   @@noth
        dec  ax
        mov  [fuel],ax
        mov  ax,[rho]
        add  ax,256
        mov  bx,ax
        mov  ax,THRUST
        imul bx                 ; DX:AX = THRUST*(rho+256)
        mov  bx,512
        idiv bx
        mov  cx,ax              ; cx = effective thrust
@@noth: mov  [teff],cx

        ; --- drag = vel*rho/DRAGK ; net force = thrust - drag ---
        mov  ax,[vel]
        imul word ptr [rho]     ; DX:AX = vel*rho
        mov  bx,DRAGK
        idiv bx
        mov  bx,ax              ; bx = drag
        mov  ax,[teff]
        sub  ax,bx              ; ax = net force (+/-)

        ; --- accel = force*64/mass ; mass = MEMPTY + fuel/3 ---
        mov  cx,64
        imul cx                 ; DX:AX = force*64 (32-bit)
        push ax
        push dx
        mov  ax,[fuel]
        xor  dx,dx
        mov  bx,3
        div  bx
        add  ax,MEMPTY
        mov  bx,ax              ; bx = mass (4000..6000)
        pop  dx
        pop  ax
        idiv bx                 ; ax = accel this tick
        add  ax,[vel]
        jns  @@v0
        xor  ax,ax              ; airspeed never negative
@@v0:   mov  [vel],ax

        ; --- turn (yaw) ---
        mov  word ptr [tmpi],0  ; tmpi = turn direction (-1/0/+1)
        cmp  byte ptr [KEYS+SC_LF],0
        je   @@nl
        mov  ax,[heading]       ; turn left
        sub  ax,TURNV
        and  ax,255
        mov  [heading],ax
        mov  word ptr [tmpi],-1
@@nl:   cmp  byte ptr [KEYS+SC_RT],0
        je   @@nr
        mov  ax,[heading]       ; turn right
        add  ax,TURNV
        and  ax,255
        mov  [heading],ax
        mov  word ptr [tmpi],1
@@nr:   ; induced drag: turning bleeds a little airspeed
        mov  ax,[tmpi]
        test ax,ax
        jz   @@ntd
        mov  ax,[vel]
        sub  ax,TURNDRG
        jns  @@td1
        xor  ax,ax
@@td1:  mov  [vel],ax
@@ntd:  ; bank toward target (roll follows turn, decays to 0)
        mov  ax,[tmpi]
        test ax,ax
        jz   @@decay
        jg   @@bankr
        ; bank left: roll -> -BANKMAX
        mov  ax,[roll]
        sub  ax,BANKSTP
        cmp  ax,-BANKMAX
        jge  @@bset
        mov  ax,-BANKMAX
        jmp  @@bset
@@bankr:
        mov  ax,[roll]
        add  ax,BANKSTP
        cmp  ax,BANKMAX
        jle  @@bset
        mov  ax,BANKMAX
        jmp  @@bset
@@decay:
        mov  ax,[roll]          ; return roll toward 0
        test ax,ax
        jz   @@bset
        jg   @@dpos
        add  ax,BANKSTP
        cmp  ax,0
        jle  @@bset
        xor  ax,ax
        jmp  @@bset
@@dpos: sub  ax,BANKSTP
        cmp  ax,0
        jge  @@bset
        xor  ax,ax
@@bset: mov  [roll],ax

        ; --- pitch & energy (yoke convention: UP = nose down = dive) ---
        ; vertical rate scales with airspeed: vrate = vel/40
        mov  ax,[vel]
        xor  dx,dx
        mov  bx,40
        div  bx
        mov  [vrate],ax
        cmp  byte ptr [KEYS+SC_UP],0
        je   @@nu
        mov  ax,[camy]          ; dive: lose altitude...
        sub  ax,[vrate]
        mov  [camy],ax
        mov  ax,[vrate]         ; ...and trade it for airspeed (energy)
        mov  cl,2
        shr  ax,cl
        add  [vel],ax
@@nu:   cmp  byte ptr [KEYS+SC_DN],0
        je   @@nd
        mov  ax,[vel]           ; climb only above stall speed
        cmp  ax,VSTALL
        jl   @@nd
        mov  ax,[camy]          ; climb: gain altitude...
        add  ax,[vrate]
        mov  [camy],ax
        mov  ax,[vrate]         ; ...paying with airspeed (energy)
        shr  ax,1
        sub  [vel],ax
@@nd:
        ; --- pitch visual: horizon eases toward 78 (dive) / 122 (climb) /100 ---
        mov  cx,100             ; neutral
        cmp  byte ptr [KEYS+SC_UP],0
        je   @@h1
        mov  cx,78              ; nose down -> horizon rises on screen
@@h1:   cmp  byte ptr [KEYS+SC_DN],0
        je   @@h2
        mov  cx,122             ; nose up -> horizon sinks on screen
@@h2:   mov  ax,[horiz]
        cmp  ax,cx
        je   @@hd
        jl   @@hup
        sub  ax,3               ; ease down toward target
        cmp  ax,cx
        jge  @@hs
        mov  ax,cx
        jmp  @@hs
@@hup:  add  ax,3               ; ease up toward target
        cmp  ax,cx
        jle  @@hs
        mov  ax,cx
@@hs:   mov  [horiz],ax
@@hd:
        ; --- stall: below VSTALL the nose drops on its own ---
        mov  ax,[vel]
        cmp  ax,VSTALL
        jge  @@nst
        mov  bx,VSTALL
        sub  bx,ax
        mov  cl,3
        shr  bx,cl              ; sink = (VSTALL-vel)/8
        mov  ax,[camy]
        sub  ax,bx
        mov  [camy],ax
@@nst:
        ; --- altitude clamp [24, CEIL] ---
        mov  ax,[camy]
        cmp  ax,24
        jge  @@y1
        mov  ax,24
@@y1:   cmp  ax,CEIL
        jle  @@y2
        mov  ax,CEIL
@@y2:   mov  [camy],ax

        ; --- N key: toggle day/night palette (on key-down edge only) ---
        mov  al,[KEYS+SC_N]
        cmp  al,[prevn]
        je   @@nn
        mov  [prevn],al
        test al,al
        jz   @@nn
        xor  byte ptr [daymode],1
        call APPLYPAL
@@nn:
        ; --- wind drift (world space, constant breeze) ---
        mov  ax,[camx]
        add  ax,WINDX
        mov  [camx],ax
        mov  ax,[camz]
        add  ax,WINDZ
        mov  [camz],ax

        ; --- advance along heading at vel/16 units per tick ---
        mov  ax,[vel]
        mov  cl,4
        shr  ax,cl
        mov  [fwd],ax
        mov  ax,[hsin]
        imul word ptr [fwd]     ; DX:AX = hsin * fwd
        mov  bx,256
        idiv bx                 ; AX = fwd * sin(heading)
        add  [camx],ax
        mov  ax,[hcos]
        imul word ptr [fwd]
        mov  bx,256
        idiv bx
        add  [camz],ax
        ret

; ============================================================================
;  COLLISION
; ============================================================================
COLLIDE:
        mov  ax,[camx]          ; camera cell
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  [gi],ax
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  [gj],ax
        ; --- terrain collision first: bilinear ground height under camera ---
        call TERRH              ; AX = ground height at (camx,camz)
        add  ax,14              ; hull clearance above the slope
        cmp  [camy],ax
        jge  @@terok
        call CRASHHANDLE        ; flew into the hillside
        ret
@@terok:
        call HBLD
        mov  ax,[bstreet]
        cmp  ax,0
        jne  @@nocol            ; street / patch -> free air
        ; --- building: inside footprint AND below rooftop (base+height)? ---
        mov  ax,[gi]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        sub  ax,BIAS
        mov  [wcx],ax
        mov  ax,[gj]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        sub  ax,BIAS
        mov  [wcz],ax
        mov  ax,[camx]
        sub  ax,[wcx]
        cmp  ax,0
        jge  @@a1
        neg  ax
@@a1:   cmp  ax,[bhw]
        jge  @@nocol
        mov  ax,[camz]
        sub  ax,[wcz]
        cmp  ax,0
        jge  @@a2
        neg  ax
@@a2:   cmp  ax,[bhd]
        jge  @@nocol
        mov  ax,[gi]            ; rooftop = terrain base + building height
        mov  bx,[gj]
        call GETH
        call WORLDH
        add  ax,[bhgt2]
        cmp  [camy],ax
        jge  @@nocol            ; above roof -> safe
        call CRASHHANDLE
@@nocol:
        ret

CRASHHANDLE:
        ; fill screen dark (index 1) -> white BIOS text renders cleanly on it
        mov  ax,0A000h
        mov  es,ax
        xor  di,di
        mov  ax,0101h
        mov  cx,32000
        rep  stosw
        ; messages (white text)
        mov  byte ptr [HCOL],8
        mov  ah,02h
        mov  bh,0
        mov  dh,11
        mov  dl,13
        int  10h
        mov  si,offset MSGCRASH
        call PRSTR
        mov  ah,02h
        mov  bh,0
        mov  dh,13
        mov  dl,12
        int  10h
        mov  si,offset MSGREST
        call PRSTR
@@w1:   cmp  byte ptr [KEYS+SC_SP],0
        je   @@w1
        mov  word ptr [camy],1450   ; respawn above everything (peaks ~1110)
        mov  word ptr [roll],0      ; so we don't reappear inside the same tower
        mov  word ptr [vel],CRUISE  ; fresh jet: cruise speed + full tank
        mov  word ptr [fuel],FUELMAX
        mov  word ptr [horiz],100   ; level pitch
@@w2:   cmp  byte ptr [KEYS+SC_SP],0
        jne  @@w2
        ret

; ============================================================================
;  HUD (BIOS text overlay on top of the frame)
; ============================================================================
HUD:    mov  byte ptr [HCOL],8
        mov  ah,02h
        mov  bh,0
        mov  dh,0
        mov  dl,0
        int  10h
        mov  si,offset MSGTITLE
        call PRSTR
        mov  ah,02h
        mov  bh,0
        mov  dh,0
        mov  dl,28
        int  10h
        mov  si,offset MSGALT
        call PRSTR
        mov  ax,[camy]
        call PRNUM
        mov  ah,02h
        mov  bh,0
        mov  dh,24
        mov  dl,0
        int  10h
        mov  si,offset MSGHDG
        call PRSTR
        mov  ax,[heading]
        call PRNUM
        mov  si,offset MSGSPD   ; airspeed (vel units, jet-style number)
        call PRSTR
        mov  ax,[vel]
        call PRNUM
        mov  si,offset MSGFUE   ; fuel as 0..100 percent
        call PRSTR
        mov  ax,[fuel]
        xor  dx,dx
        mov  bx,60
        div  bx
        call PRNUM
        mov  si,offset MSGHELP
        call PRSTR
        ; real-time seconds (BIOS tick, 18.2 Hz) - compare against a stopwatch
        mov  ah,02h
        mov  bh,0
        mov  dh,0
        mov  dl,15
        int  10h
        mov  si,offset MSGT
        call PRSTR
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,es:[6Ch]       ; BIOS tick low word (18.2 Hz)
        pop  es
        xor  dx,dx
        mov  bx,18
        div  bx                ; ax ~= seconds
        call PRNUM
        ret

PRSTR:  lodsb
        test al,al
        jz   @@e
        call PRCH
        jmp  PRSTR
@@e:    ret

PRCH:   mov  ah,0Eh
        mov  bl,[HCOL]
        mov  bh,0
        int  10h
        ret

PRNUM:  mov  cx,0
        mov  bx,10
@@d:    xor  dx,dx
        div  bx
        push dx
        inc  cx
        test ax,ax
        jnz  @@d
@@p:    pop  dx
        add  dl,'0'
        mov  al,dl
        call PRCH
        loop @@p
        ret

; ============================================================================
;  Key-state table (at the very end)
; ============================================================================
KEYS    db 128 dup(0)

CODE    ENDS
        END START
