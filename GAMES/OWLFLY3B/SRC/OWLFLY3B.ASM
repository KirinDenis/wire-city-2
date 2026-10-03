; ============================================================================
;  OWLFLY3B.ASM  -  OWL FLY III BOND : OWL FLY III cut down for the
;  Bondwell Model 8 class of machine - an 8088 at 4.77 MHz, 512K, a CGA
;  or Hercules screen and a PC speaker. Forked 2026-10-02 from
;  GAMES\OWLFLY3, which stays as it is. What the BOND drops:
;    - the EGA, MCGA and VGA cards: the front step offers CGA and Hercules
;    - FULL and MEDIUM detail: it always flies LOW
;    - the Sound Blaster and its sample bank: speaker or silence
;    - the 64K-aligned far map the Blaster's DMA needed: the pages are
;      packed (BONDSCR), and the game ends at CS+3000h, 192K past its
;      code, so it fits a 512K machine with room to spare. The door
;      checks it (BONDTOP). (448K at the fork; the drawn cockpit, the
;      Shilkas, CITY.DAT and the far windows each took a page away.)
;  The wire is v3's, byte for byte: a BOND flies in the same sky.
;
;  Build with FASM (in DOSBox) - MAKE.BAT in this game's folder:
;       FASM SRC\OWLFLY3B.ASM INSTALL\OWLFLY3B.EXE
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
;       -> ROTXZ (yaw)        : (rc_x,rc_z)  rotate by heading
;       -> NEARCLIP           : clip polygon/edge to camera-space rc_z >= NEARZ
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
;     SETTRIG must run each frame before RENDER (fills hsin/hcos/rsin/rcos)
;     AND AGAIN AFTER IT, because INPUT flies the jet on those same sines
;     and never computes them itself. Anything that moves the camera for
;     the length of a render - the chase, the orbit, the pilot's head -
;     must leave the trig belonging to the AIRCRAFT, not to the view.
;
;  COORDS: PROJPT returns sx in AX, sy in DX. SINQ returns sin*256 in AX.
;  DEAD CODE (assembled but never called) is tagged "DEAD" in its banner.
; ----------------------------------------------------------------------------

                                ;   (emits jcc short + jmp near; pure 8086)

; ---- THE BOND'S FAR MAP, in paragraphs from CS. v3 aligned these pages
; to 64K boundaries, from (CS+5FFFh) AND F000h, because the Blaster's DMA
; ring could not cross one - and that alignment alone could cost 60K and
; pushed the top to the 640K line. Without a Blaster nothing needs it:
;   below CS  SKYSEG UISEG SYMSEG TOWNSEG VIDSEG, packed (see the note
;             beside their includes: the far segments come first)
;   CS+0000h  CODE, its data, BSS and stack - 64K
;   CS+1000h  bufseg, the back buffer
;   CS+2000h  scrseg: the minimap (0..1FFFh) and the radar phosphor
;             (RDRMAP, F000h) - shcabsg points here too, see SHCABLDF.
;             It was resseg's page, CITY.DAT's, until the font was built
;             into the program (VFONTF, 2026-10-03)
;   CS+3000h  the end - BONDTOP, what the door asks DOS for.
; The F6/F7 side views had a page of their own (cpsseg, CPSIDE.DAT) until
; the cockpit was drawn instead of photographed - VPSIDEF in VID.INC - and
; the Shilka's cabin had one (BONDCAB) until the Shilkas went.
BONDBUF = 1000h
BONDSCR = 2000h
BONDTOP = 3000h

; ---- world constants -------------------------------------------------------
FOCAL   = 220                 ; projection focal length: ~72 deg horizontal
                                ; FOV (160 was a 90-deg fisheye - the world
                                ; read as a diorama, buildings looked tiny)
CELL    = 256                 ; grid pitch (doc only; code uses shl/shr 8 and 128)
BIAS    = 8192                ; world->cell bias (keeps cell math unsigned)
BONDLSH = 6000                ; BOND: how far a Shilka or a radar station
                                ;  is drawn (v3: 13000). Each one is two to
                                ;  four MODELDRAWs, ~60 ms apiece on an 8088
                                ;  - measured, 2026-10-02: six Shilkas were
                                ;  1.6 s of a 3.7 s frame
BONDDET = 2500                ; ...and past this a Shilka is hull and
                                ;  turret only: no barrels, no dish
BONDJLOD = 3000               ; BOND: past this an AI jet is its IFF marker
                                ;  alone - square or diamond, no model
BONDCELLS = 200               ; BOND: the city is walked over the nearest
                                ;  200 cells of BORD (about radius 8),
                                ;  not all 2401 (radius 24); 441 first,
                                ;  200 since 2026-10-03
RAD     = 9                   ; building render radius (cells)
MAXD2   = RAD*RAD*2           ; max squared cell distance (painter buckets)
GR      = 7                   ; ground-grid radius (cells)
NEARZ   = 40                  ; near clip plane
NCOL    = 4                   ; window panes across a wall...
NROW    = 8                   ; ...and down it. Both went up when a
                                ; building grew to own a 2x2 plot: 3x5 on a
                                ; wall twice the size is not windows, it is
                                ; garage doors.
NSTR    = 8                   ; lattice row stride - a POWER OF TWO, kept
                                ; separate from NCOL+1 so the index stays a
                                ; shift. NCOL may be anything under it.
NLAT    = NSTR*(NROW+1)       ; the corner lattice the panes share
WMINPX  = 6                   ; a wall thinner than this carries no glass
WQUADPX = 5                   ; ...and below this many pixels per CELL the
                                ; whole facade drops to lit dots
; ---- the streets, and what drives on them (developed in LAB\HOUSE.COM).
; CARV*CARG = 2048 = eight cells = ONE BLOCK per green, and that identity
; is what the whole traffic scheme rests on - see TRAFFICF in TOWN.INC.
TKSUB   = 12                  ; traffic-clock steps per BIOS tick
CARV    = 1                   ; units per clock step while moving
CARG    = 2048                ; clock steps of green
CARCLR  = 256                 ; all-red clearance between the two greens
CART    = 2*(CARG+CARCLR)     ; the whole signal cycle (~21 s)
CARRST  = 200                 ; how far into its cell a stopped vehicle
                                ; waits - just short of the next crossing
LANEOF  = 96                  ; lane centre from the avenue centre
; ---- HOW FAR THE ROAD REACHES, and this is a BUDGET, not a taste.
; The buildings walk is 2401 cells and nearly half of a city block is
; street. At ROADZ 5200 every one of those streets inside twenty cells ran
; a full ROTCUL - four rotations - and then filled a large ground quad,
; hundreds of them a frame. That is what a frozen web build looks like.
; ROADR culls by CELL first, before any of that arithmetic happens.
;
; 2026-08-04, on the pilot's word that the streets show up far too late:
; the reach went from 9 cells to the WHOLE WALK, 24 - which is as far as
; the road can ever go without lengthening the walk itself, and 2.7x what
; it was. It is paid for by LEVEL OF DETAIL rather than by cost. Past
; ROADLOD the quad is not one cell but a 2x2 GROUP of them: an avenue is
; two cells wide and every road cell falls in an even/even 2x2 group that
; is road all the way through, so the merge is EXACT, not an approximation
; - one quad in four, and only the group's anchor cell draws it. Net: the
; road reaches 2.7x further for about 2.4x the fills, and the far ones are
; a few pixels each.
ROADR   = 24                  ; cells: the cheap cull, done on cdi/cdj
ROADLOD = 9                   ; cells: inside this a quad per CELL, outside
                                ; it a quad per 2x2 group
ROADZ   = 7200                ; units: the fine cull, after ROTCUL
CARZ    = 2200                ; the traffic stops nearer still - past this
                                ; a car is one pixel and costs a whole box.
                                ; It also never runs in grouped detail, and
                                ; CARZ < ROADLOD*256 keeps that automatic.
ROADLIFT = 2                  ; how far the tarmac sits above the ground
ASPHALT = 120                 ; DAC: the road surface
VCOL0   = 121                 ; DAC: first vehicle colour (8 lit/shade)
NKILL   = 8                   ; vehicles that can be dead at once
KRESP   = 90                  ; ticks before a fresh one takes the slot
FARZ    = 21600               ; far clip distance
MEGR    = 20                  ; far-belt radius in 4x4-cell megablocks
CEIL    = 3000                ; flight ceiling (loops need headroom)

; ---- jet flight model (all per 18.2 Hz physics tick) ------------------------
; Forces: thrust vs drag decide airspeed; climb/dive trade speed <-> altitude
; (energy management); air density (rho) falls with altitude, cutting both jet
; thrust and drag -> higher up = faster top speed. Fuel burns while the engine
; runs; mass = MEMPTY + fuel/3, and acceleration = force/mass. Wind drifts the
; plane in world space. Below VSTALL the nose drops and climb is impossible.
; vel is airspeed *16 fixed point; forward motion per tick = vel/16 units.
THRUST  = 720                 ; engine thrust (force units)
DRAGK   = 256                 ; drag divisor: drag = vel*rho/DRAGK
MEMPTY  = 4000                ; empty mass
FUELMAX = 12000               ; full tank (1 unit burned per tick ~ 11 min).
                                ; Doubled 2026-08-05 on the pilot's word: at
                                ; 5.5 minutes a sortie was over before you
                                ; had crossed the front line and come back.
VSTALL  = 300                 ; stall airspeed (vel units)
CRUISE  = 736                 ; initial airspeed (= 46 units/tick, old feel)
VNE     = 2600                ; never-exceed: the airframe's own top end,
                                ;  about Mach 2.2 in this world's units and
                                ;  three and a half times CRUISE. See the
                                ;  clamp in FLIGHT.INC - it exists because the
                                ;  x4 burner can otherwise push vel past 7000
                                ;  at altitude, three times anything this
                                ;  program's arithmetic was written for
; ---- THE GROUND SCHOOL (GNDSCH, out in UISEG) ------------------------------
; Ported from the TRAINER's F_PHYS.INC, whose own header says it came from
; OWL FLY in the first place - so these are not foreign numbers, they are
; this family's numbers coming home. THRUST, DRAGK, VSTALL, TURNDRG and CEIL
; are already identical between the two programs, and vel means the same
; thing in both: airspeed x16, advancing vel/32 world units a tick. That
; shared scale is what lets the sink-rate limits below transfer as written
; instead of being re-guessed.
; THE ROTATION SPEEDS ARE OURS, NOT THE TRAINER'S, and this is the one place
; the port could not be transcribed. The trainer rotates at 330 because its
; drag is QUADRATIC (V*V/680); ours is LINEAR (vel*rho/256) and the gear and
; flaps add three quarters again on top, so a jet on the deck at full DRY
; thrust settles at 254 and can never see 330 at all. Measured, not reasoned:
; the model was re-implemented in C# and run, which is how this was caught
; before anybody sat on a runway wondering why the aeroplane would not fly.
;
; So VR is hung off what this jet can actually reach, and the answer that
; falls out is worth having: SHE GOES OFF THE DECK IN BURNER. Dry, with the
; flaps out, the nose comes up at 250 and the speed then DECAYS to 226 - the
; rotation spends energy the dry engine cannot replace - and she sits there
; with her nose in the air going nowhere. Light the burner and she is off in
; three seconds. That is a mechanic, not a fault: the failure states its own
; cause, which is the most a cockpit can do without a caption.
VRSPD   = 290                 ; rotation speed, clean: below this the nose
                                ;  stays on the deck whatever the stick says
VRFLAP  = 40                  ; ...and what the flaps take off it, which is
                                ;  what makes them worth selecting for a
                                ;  takeoff and not only for a landing
VLOFD   = 45                  ; VLOF = VR + this. Past it lift wins and she
                                ;  floats off whether or not you asked
VLOFP   = 5                   ; ...at THIS much nose-up, where the trainer
                                ;  uses 2. Ours has to be bigger for an
                                ;  arithmetic reason: the climb is
                                ;  (vel/32)*sin(pitch)/256 in WHOLE units, and
                                ;  at these speeds two units of pitch
                                ;  truncates to zero climb - she would be
                                ;  "flying" and still pinned to the concrete
TDSLAM  = -700                ; sink at touchdown, in 8.8 units a tick:
TDFIRM  = -300                ;  past TDSLAM she is wrecked, past TDFIRM it
                                ;  was firm, and inside it she is greased on.
                                ;  8.8 AND NOT WHOLE UNITS ON PURPOSE - one
                                ;  whole unit a tick is nine metres a second,
                                ;  which cannot tell a landing from an
                                ;  accident. See vsp8.
GNDDIRT = 160                 ; meeting the grass above this speed is a
                                ;  wreck; below it she is merely being ground
GNDGRND = 90                  ; ...and this much grinding finishes the job
AFSTART = 240                 ; how far up from the threshold the first jet
AFSPACE = 420                 ;  is towed out, and how far apart they stand
AFIDLE  = 24                  ; the throttle she is handed over at, of 64.
                                ;  Chosen so the two forces on a parked jet
                                ;  come out the right way round: idle thrust
                                ;  makes 2 a tick, the brakes take 3 and the
                                ;  wheels 1, so she holds absolutely - and
                                ;  the moment the brakes come off the same
                                ;  idle makes +1 and she rolls
TURNDRG = 2                   ; induced drag per tick while turning
WINDX   = 2                   ; wind drift, world units per tick
WINDZ   = -1
TURNV   = 4                   ; heading change per tick
BANKMAX = 30                  ; max bank/roll angle (of 256) - an angle, not a rate
BANKSTP = 12                  ; bank approach/decay per tick

; ---- fixed-timestep physics clock ------------------------------------------
; We touch NOTHING in the hardware: no INT 8 hook, no PIT reprogram (both hung
; in this emulator). We just READ the stock BIOS timer tick at 0040:006C, which
; advances at its native 18.2 Hz in real time. Physics runs one INPUT step per
; elapsed tick -> constant real-world speed at any render rate. Coarse but
; rock-solid: nothing to install, nothing to restore, nothing to hang.
MAXSTEP = 6                   ; max physics steps per render (anti-spiral)

; ---- the NEWTON sky's palette block (see SKY.INC and the palettes) ---------
SKYZ    = 98                  ; ramp SKYZ..SKYZ+4 zenith->haze, then
                                ; SKYZ+4..SKYZ+6 the cloud light
LDIM    = 105                 ; the pitch ladder's dim grey
LCYN    = 106                 ; the IVV caret's cyan
UBLACK  = 107                 ; the front door's true black

; ---- keyboard scan codes ---------------------------------------------------
SC_ESC  = 01h
SC_TAB  = 0Fh                 ; Tab: change seats - the jet or the Shilka
SC_F8   = 42h                 ; F8: change seats too - F2..F7 are the
                                ;  views, F8 is the next SEAT; and the
                                ;  browser's key map swallows Tab whole,
                                ;  so the F-row carries the day there
SC_0    = 0Bh                 ; 0: the seat's third door - the one key
                                ;  measured to arrive in EVERY browser
SC_UP   = 48h
SC_DN   = 50h
SC_LF   = 4Bh
SC_RT   = 4Dh
SC_SP   = 39h
SC_N    = 31h                 ; N key: toggle day/night palette
SC_W    = 11h                 ; W: throttle up
SC_S    = 1Fh                 ; S: throttle down
SC_A    = 1Eh                 ; A: afterburner (hold)
SC_C    = 2Eh
SC_Q    = 10h                 ; rudder left
SC_E    = 12h                 ; rudder right
SC_ENT  = 1Ch                 ; target lock
SC_M    = 32h                 ; right MFD mode toggle
SC_BS   = 0Eh                 ; missile launch (Backspace, above Enter)
SC_F3   = 3Dh                 ; chase camera toggle
SC_F4   = 3Eh                 ; orbit camera around the locked target
SC_F5   = 3Fh                 ; missile camera arm/disarm
SC_F6   = 40h                 ; LOOK LEFT  - 90 degrees, inside the cockpit
SC_F7   = 41h                 ; LOOK RIGHT - and Ctrl+arrows do the same
SC_CTL  = 1Dh                 ; the Ctrl of Ctrl+left / Ctrl+right
SC_Z    = 2Ch                 ; rudder left
SC_F2   = 3Ch                 ; cockpit view toggle
SC_NP7  = 47h                 ; numpad 7: rudder left
SC_NP9  = 49h                 ; numpad 9: rudder right
SC_NPP  = 4Eh                 ; numpad +: throttle up
SC_NPM  = 4Ah                 ; numpad -: throttle down
SC_EQ   = 0Dh                 ; main-row =/+: throttle up
SC_MIN  = 0Ch                 ; main-row -: throttle down
SC_V    = 2Fh                 ; V: sound mode (all/effects/silence)
SC_D    = 20h                 ; Ctrl+D: the diagnostic marks on/off
SC_1    = 02h                 ; top-row 1: rudder left  (the F-15 way)
SC_3    = 04h                 ; top-row 3: rudder right
SC_LSH  = 2Ah                 ; the shifts, for the throttle gates
SC_RSH  = 36h
SC_ALT  = 38h                 ; Alt: the Alt-Q exit chord
SC_X    = 2Dh                 ; X: radar unzoom (Z zooms - the manual)
SC_K    = 25h                 ; K: map zoom (PROVISIONAL - the keyboard
                                ;  layout is still open; K is free and sits
                                ;  next to M, which pages the same screen)
SC_F    = 21h                 ; F: flaps
SC_L    = 26h                 ; L: landing gear
SC_B    = 30h                 ; B: airbrake
SC_G    = 22h                 ; G: ground comms  (VHF-FM, the army net)
SC_U    = 16h                 ; U: air comms     (UHF, the squadron net)
SC_I    = 17h                 ; I: IFF transponder
SC_T    = 14h                 ; T: TACAN
SC_O    = 18h                 ; O: master mode, A-A <-> A-G
SC_P    = 19h                 ; P: autopilot
SC_R    = 13h                 ; R: emissions (transmit / receive)
SC_J    = 24h                 ; J: ECM
SC_Y    = 15h                 ; Y: noise jammer
WRKSZ   = 300                 ; wreck slot size (see the BSS block)
WCL     = 292                 ; face colours inside a slot
BSSCLR  = 2488                ; (BSSEND-WRK)/2 - keep in sync with BSS!
FLBN    = 32                  ; black box: samples (every 2nd tick, ~3.5 s)
FLBSZ   = 384                 ; FLBN * 12 bytes (x,y,z,hdg,pitch,roll)
WFP     = 4                   ; face records inside a slot
WCO     = 100                 ; corner offsets inside a slot                 ; C: toggle cockpit panel

format MZ
entry CODE:START
stack CODE:0

; .8086 in the TASM source. FASM has no such directive - without this
; include it silently uses 386 jumps when a target is out of range.
; It goes before the first segment: the macros have to be defined
; before anything can use them.
include '..\..\..\ENGINE\E_8086.INC'

; ---- BOND: THE FAR SEGMENTS COME FIRST. v3 put CODE first and gave each
; far segment a fixed window (8K, 16K, 8K, 8K, 24K) at CS+1000h..1FFFh,
; padded out with zeros, and CODE itself was stored whole - its 22K of
; BSS and stack included. Here the far segments are packed below CODE,
; each as long as its code and no longer, and CODE goes last so that its
; BSS and stack are not in the file at all. Calls between segments are
; relocated by DOS, so nothing addresses a far segment by arithmetic.
        include 'SKY.INC'   ; the NEWTON sky, in its own segment
        include 'NET.INC'   ; continues the segment SKY.INC opened
        include 'UI.INC'   ; the front door: splash + sky list
        include 'SYM.INC'   ; the scope's symbols, the profiler
        include 'TOWN.INC'   ; the aerodrome
        include 'VID.INC'   ; SELECT VIDEO SYSTEM, the CGA/HGC converters

segment CODE
        ; (the COM-era ORG 100h gap is gone: the segment got tight and
        ; those 256 bytes belong to the STACK now - see the BSS guard)

START:  jmp  MAIN
        include 'DATA.INC'   ; variables, palettes, tables
        include 'KEYB.INC'   ; INT 9 keyboard handler

; ============================================================================
;  MAIN PROGRAM
; ============================================================================
MAIN:
        ; EXE prologue: the COM loader gave us CS=DS=ES=SS and SP at the
        ; segment top for free; the EXE loader points DS/ES at the PSP
        ; and SS wherever the linker guessed. Rebuild the old world by
        ; hand - SS first, there is no usable stack until it lands.
        mov  ax,cs
        cli
        mov  ss,ax
        mov  sp,0FFFEh
        sti
        ; ---- BOND: IS THE MACHINE BIG ENOUGH? v3 never asked and simply
        ; wrote where it pleased; on a 512K machine, or under a shell,
        ; that is memory that is not there. ES is still the PSP here, and
        ; PSP:2 is the first paragraph past what DOS gave us.
        mov  bx,[es:2]
        mov  ds,ax
        mov  es,ax
        add  ax,BONDTOP         ; where the far map ends
        jc   .nomem             ; wrapped 20 bits: certainly not
        cmp  ax,bx
        jbe  .memok
.nomem: mov  dx,BONDMEM
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h
.memok:
        ; ---- BOND: CLEAR THE BSS. It is no longer in the file (CODE is
        ; the last segment), so it arrives as whatever the last program
        ; left in that memory, and v3 was written against the zeros its
        ; EXE used to carry.
        mov  di,BSS
        mov  cx,(BSSEND-BSS+1)/2
        xor  ax,ax
        cld
        rep  stosw

        ; ---- the front step: SELECT VIDEO SYSTEM, in text mode. It runs
        ; BEFORE the INT 9 hook below on purpose - the menu reads keys
        ; through BIOS INT 16h, which the game's own handler silences.
        ; VGA is the default and stays the untouched path; the retro
        ; cards convert the finished frame in VIDSEG (SRC\VID.INC,
        ; plan in Skill\VIDTASK.md).
        call VIDSEG:VMENUF      ; -> AL = the internal card code (VID.INC),
        mov  [vcard],al         ;    AH = the detail level from its second
        mov  [sndsel],dl        ;    DL = its sound screen: 1 PC SPEAKER,
                                ;    2 NO SOUND - SBINIT reads it. (AH is
                                ;    always LOW: the BOND has no other
                                ;    detail, so every v3 "qual" test is
                                ;    gone and only the LOW road is left.)

        ; the back buffer, straight past CODE's 64K: the far segments
        ; sit below CS now, so nothing stands between (see BONDBUF)
        mov  ax,cs
        add  ax,BONDBUF
        mov  [bufseg],ax

        ; hook INT 9
        mov  ax,3509h
        int  21h
        mov  [oldoff],bx
        mov  [oldseg],es
        mov  dx,KBINT
        mov  ax,2509h
        int  21h                ; DS=CS already -> vector to CS:KBINT

        ; (no PIT reprogram, no INT 8 hook - we only read the stock BIOS tick)

        ; ---- BOND: THE GAME OPENS NO FILES. v3 read CITY.DAT (font and
        ; photo cockpit), CPSIDE.DAT (side views), SFX.DAT (the Blaster's
        ; samples) and the Shilka's cabin. The cockpit is drawn, there is
        ; no Blaster and no Shilka, and the 4x6 font is built in: VFONTF
        ; copies it from VIDSEG into FONTBUF. sfxseg and cpsseg stay 0,
        ; which their readers take as "none". resseg is pointed at scrseg
        ; for the retired bake paths that still name it.
        mov  ax,cs
        add  ax,BONDSCR
        mov  [resseg],ax
        call VIDSEG:VFONTF
        call SYMSEG:SHCABLDF  ; the radar phosphor's page (see SHCABLDF)

        ; ---- THE FRONT DOOR: video and sound up FIRST, then the wire,
        ; then the splash and the sky list. The world is minted only
        ; after the pilot picks one - its seed comes from the clock
        ; (create) or from the chosen sky's ad (join).
        call VIDSEG:VSETMDF   ; the picked card's mode up (13h on VGA/MCGA)
        call UISEG:APPLYPALF
        push es                 ; wreck pool etc: BSS is not guaranteed
        mov  ax,cs              ; clean, and the menu era runs long
        mov  es,ax
        mov  di,WRK
        xor  ax,ax
        mov  cx,BSSCLR
        cld
        rep  stosw
        pop  es
        call SBINIT             ; the splash roar wants a voice
        call SKYSEG:NETINITF
        mov  [netup],al
        mov  [netpid],dx        ; 0 when the wire is dark
        call UISEG:UISPLASH
        call UISEG:UIMENU   ; blocks until a sky is picked
        ; ---- EVERY arrival watches first, joined or created alike, and
        ; Enter is what takes a jet. There is no "empty sky" case to except:
        ; the bot war is running before anybody gets here, which is the whole
        ; reason this screen has something on it. Gating this on "somebody
        ; else is already flying" made it impossible to see alone, which is
        ; a poor way to build a thing that has to be judged by eye.
        mov  byte [spect],1
        mov  byte [KHIT+SC_ENT],0 ; the splash's Enter latched KHIT, and
                                ;  SPECTUPF now reads that latch - stale
                                ;  history must not take a jet by itself
        mov  byte [tgtcam],1 ; UP FROM HERE, not from the first physics
                                ;  tick. SPECTUPF raises it, but INPUT runs
                                ;  AFTER the first frame is drawn - so the
                                ;  cockpit got one frame on the glass before
                                ;  the camera took over, and it read as the
                                ;  panel flashing past on the way in
        cmp  byte [gact],2
        je   .gjn              ; join: the menu set rseed/wseed/ggid
        push es                 ; create: mint a fresh seed NOW (the
        mov  ax,40h             ; menu ran for human seconds - good
        mov  es,ax              ; entropy)
        mov  ax,[es:6Ch]
        pop  es
        or   ax,1
        mov  [rseed],ax
        mov  [wseed],ax
        mov  ax,[netpid]
        mov  [ggid],ax          ; our sky flies under our wire name
        call SKYSEG:NETHOSTF
.gjn:
        mov  ax,cs              ; far scratch - the minimap lives there,
        add  ax,BONDSCR         ; not in our crowded 64K. BOND: packed,
        mov  [scrseg],ax        ; no longer 64K-aligned (see BONDSCR)
        call DSTCLR             ; a new world stands up whole
        ; ---- LOW: NO DIAMOND-SQUARE. The pilot's fix, and the right one:
        ; flatten the MAP, not the readers. WORLDH was overridden first and
        ; it was not enough, because the far segments carry their own inline
        ; copies of its arithmetic - TOWNSEG's NODEH bends the roads onto
        ; HMAP directly, comment "...WORLDH" and all - so the roads followed
        ; a landscape the rest of LOW no longer had. One constant across the
        ; whole heightmap and every reader agrees, including the copies
        ; nobody remembers. 140 sits mid city band (120..167): towns still
        ; zone (by hash alone now - the whole map is eligible), no water,
        ; and AFINITF's plains clamp becomes a no-op, so the aerodromes sit
        ; on the same plane as everything else. The world stands at
        ; (140-88)*5 = 260 units, everywhere, for everyone.

        mov  bx,HMAP
        mov  cx,4096
.dsf:  mov  byte [bx],140
        inc  bx
        loop .dsf
        jmp  .dsd
.dsd:
        call UISEG:AFINITF   ; ...then IRON THE AERODROMES INTO IT, before
                                ; anything is baked off it. The block table
                                ; and the minimap below both read HMAP, and
                                ; both have to see flat concrete: that is what
                                ; keeps the mesh, TERRH, the streets and the
                                ; collision test agreeing about a runway
                                ; without one special case between them.
        call TOWNSEG:BLKTABF   ; zone the 32x32 blocks off it, ONCE - the
                                ; streets and the buildings both read that
                                ; table and must not re-derive it per cell
        ; ---- LOW, the second constant. AFINITF clamps the strips to
        ; AFHLO..AFHHI (96..116) so no block can zone built-up on a runway -
        ; which on the flat 140 map put the aerodromes at 140 world units
        ; under a world at 260, and the pilot, taking off from one, watched
        ; the whole city hover 120 units above the grid. "Two constants:
        ; the grid-ground level and the generated map's" - exactly.
        ;
        ; The clamp cannot simply go: it is the ONLY thing keeping houses
        ; off the strip. So the ORDER does the work instead - the block
        ; table above was zoned while the aprons still read 116 and the
        ; city land 140, so the runways are already refused for good. NOW
        ; the map is flattened back to one number, aprons included, and
        ; afy - the world height of each strip's concrete, measured off the
        ; 116 ground a moment ago - is restamped to match. One plane,
        ; 260 units, for absolutely everything.

        mov  bx,HMAP
        mov  cx,4096
.rfl:  mov  byte [bx],140
        inc  bx
        loop .rfl
        mov  bx,afy
        mov  cx,NAF
.rfy:  mov  word [bx],(140-88)*5
        add  bx,2
        loop .rfy
.nfl:
        call SYMSEG:MMAPGENF   ; bake the minimap from it
        call BRDGEN             ; draw the front line on the war

        ; (video mode went up before the menu - the world just draws)

        ; ---- A SORTIE STARTS ON THE STRIP: fuelled, towed out, made ready.
        ; This used to hunt the heightmap for a city node in H 130..160 and
        ; drop the jet over it at 1450 doing cruise speed, with the pilots of
        ; one wire fanned 128 units apart to the east so they did not share a
        ; cockpit. All of it is gone: AFSPAWN puts her on the concrete of
        ; field 0 facing up the runway, and the wire's pilots line up ALONG
        ; the strip instead of abreast of it - four jets 128 apart across a
        ; runway 150 half-wide would have been three of them in the grass.
        ;
        ; It needs the aerodromes sited, which AFINITF did above, and it
        ; needs the ground school to be there to receive her - standing still
        ; on the deck is a state the old model had no way to express.
        ; Forty-odd bytes of this segment came back with the search.
        call UISEG:AFSPAWNF
        ; (the BSS wipe and SBINIT went up before the menu; the F15
        ; model is BAKED into the image by Obj2Inc at build time)

        call UISEG:RSTAINITF   ; plant the two ground radar stations
        ; ---- AI traffic: two squadrons scattered around the player ----
        call RESPAWNALL
        cmp  byte [gbots],0 ; a botless sky is a clean arena:
        jne  .bots1            ; the 20v20 war stays home, only real
        xor  bx,bx              ; pilots fly (CS manners)
.bk:   inc  bx
        mov  byte [pst+bx],1
        cmp  bx,39
        jb   .bk
.bots1:
        mov  word [heading],0
        mov  word [roll],0
        call FLBSEED            ; the black box starts at the spawn point
        call SETTRIG            ; seed hsin/hcos before the first physics tick
        push es                 ; seed lasttk from the BIOS tick
        mov  ax,40h
        mov  es,ax
        mov  ax,[es:6Ch]
        pop  es
        mov  [lasttk],ax

GAMELOOP:
        ; --- the pause latch, frame-side. ESC was deliberately DEAD
        ; (players kept quitting sorties with it, 2026-07-23); now the
        ; reflex key does the SAFE thing: the world stands still. The
        ; glass stays alive - UIKEYS below runs paused or not.
        cmp  byte [KHIT+SC_ESC],0
        je   .npz
        mov  byte [KHIT+SC_ESC],0
        xor  byte [paused],1
        call PAUSND             ; quiet going in, the voice back out
.npz:
        ; (BOND: no TAB seat change - there is no Shilka to crew, so
        ; [ride] is always 0 and every turret-seat road is gone)
        call UIKEYS             ; cameras, zooms, pages - every frame
        ; --- physics: one INPUT step per BIOS tick elapsed since last frame ---
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,[es:6Ch]        ; BIOS tick low word (18.2 Hz)
        pop  es
        mov  bx,ax
        sub  bx,[lasttk]        ; bx = ticks elapsed since last render frame
        mov  [lasttk],ax
        inc  word [fpsn]        ; the debug frame counter: frames
        mov  dx,ax              ;  per BIOS second, shown by the
        sub  dx,[fpst]          ;  glass when Ctrl+D is up - the
        cmp  dx,18              ;  486 report asked for a number,
        jb   .nfps              ;  not an adjective
        mov  [fpst],ax
        mov  dx,[fpsn]
        mov  [fpsv],dx
        mov  word [fpsn],0
.nfps:
        cmp  byte [paused],0    ; frozen: no steps, and fcnt pinned
        je   .nfz               ;  past fprev so LERPSET shows the
        xor  bx,bx              ;  real state - no wrap, no drift.
        mov  word [fcnt],8      ;  lasttk kept fresh above = no
.nfz:                           ;  catch-up burst on resume
        cmp  bx,MAXSTEP         ; clamp catch-up (anti-spiral)
        jbe  .pcl
        mov  bx,MAXSTEP
.pcl:  test bx,bx
        jz   .pdone
        ; ---- the tap rescue (the 486 report, 2026-08-22; refined
        ; 2026-08-23): a flight key pressed AND released between two
        ; frames never shows in KEYS - at real-iron frame rates that
        ; was every quick tap. KHIT caught it; grant it exactly one
        ; tick. BUT ONLY a true between-frames tap: typematic re-arms
        ; KHIT for the whole length of a hold, so a plain KHIT grant
        ; fired a phantom tick at every RELEASE - it kept qramp alive
        ; between stick pulses and the fine touch went with it (the
        ; pilot: the smoothness is broken, worst in yaw). A tap is
        ; KHIT with no hold in sight: not held NOW, not held at the
        ; last frame either.
        push bx                 ; BX carries the burst count
        xor  si,si
.tg:   mov  bl,[TAPSC+si]
        xor  bh,bh
        mov  al,[KHIT+bx]       ; the latch...
        mov  byte [KHIT+bx],0   ; ...taken either way
        mov  ah,[KEYS+bx]
        mov  cl,ah              ; the live state, kept for pvk
        or   ah,[pvk+si]        ; held now, or held a frame ago?
        jz   .tg1
        xor  al,al              ; ...then the latch is typematic
.tg1:  mov  [tapup+si],al      ;  echo, not a tap - swallow it
        mov  [pvk+si],cl
        inc  si
        cmp  si,7
        jb   .tg
        pop  bx
        mov  ax,[camx]          ; interpolation: keep the pre-burst state
        mov  [ocx],ax
        mov  ax,[camy]
        mov  [ocy],ax
        mov  ax,[camz]
        mov  [ocz],ax
        mov  ax,[heading]
        mov  [ohd],ax
        mov  ax,[pitch]
        mov  [opt],ax
        mov  ax,[roll]
        mov  [orl],ax
        mov  ax,[fcnt]          ; how many frames the last interval took
        cmp  ax,8
        jbe  .fp1
        mov  ax,8
.fp1:  mov  [fprev],ax
        mov  word [fcnt],0
        mov  ax,bx              ; BOND: how long each flight key was really
        call VIDSEG:KBURSTF     ;  held, as steps of this burst (VID.INC)
.ploop:
        push bx                 ; INPUT clobbers BX (leaves BX=256 from idiv)
        call VIDSEG:KHOLDF      ; BOND: the keys owed this step, down
        call INPUT              ; one fixed physics step
        call TapClr             ; the taps are one-tick coin: spent
        call VIDSEG:KRESTF      ; BOND: ...and the keyboard's truth back
        pop  bx
        dec  bx
        jnz  .ploop
.pdone:
        inc  word [fcnt]
        call COLLIDE
        call SYMSEG:STG0F   ; *** TEMP marker: physics done ***
        call SKYSEG:NETPOSF   ; tell the wire where we are (1/tick)...
        call SKYSEG:NETPOLLF   ; ...and learn where everyone else is
        call NETAPPLY           ; deaths and hits the wire brought us
        call SYMSEG:STG1F   ; *** TEMP marker: the wire is done ***

        ; --- render (runs as fast as it can; speed no longer tied to it) ---
        call LERPSET            ; draw BETWEEN the ticks: silk, not jerks
                                ; the chase rig is the jet's: while the
                                ;  turret owns the camera it stays folded
        call CHASESET           ; F3: swap in the chase camera
.nchs:
        cmp  byte [paused],0    ; a frozen world: the lights hold and
        jne  .nck               ;  the wrecks stop burning - lasttk is
        call TOWNSEG:CCLOCKF   ;  kept fresh through a pause, so left
                                ;  alone the traffic drove on through it
.nck:                           ; advance the traffic clock: the lights
                                ; run on TIME, not on how fast we draw
        ; --- the turret seat: the render borrows the camera. The jet's
        ; six are parked in rsv* and handed back right after CHASERST -
        ; LERPRST cannot be trusted with it, it only restores on the
        ; frames it interpolated. SVIEWF comes AFTER the borrow, so
        ; F6/F7 turn the TURRET's head, exactly as they turn the jet's.
        jmp  .ncam

.ncam:
        call SYMSEG:SVIEWF   ; F6/F7 and Ctrl+arrows: look 90 left/right,
                                ; which is a turn of [heading] and nothing
                                ; more - taken back below, before physics
        call SETTRIG            ; heading/roll -> sin/cos for this frame
        mov  ax,[bufseg]        ; draw into back-buffer
        mov  es,ax
        call CLEARBUF
        mov  al,21              ; *** BOND PROFILE: the sky and ground fill
        call SYMSEG:RMARKF
        call RENDER
        call SYMSEG:SVRSTF   ; nose back down the centreline
                                ; CHASESET was folded away above, so its
                                ;  restore must stay folded too
        call CHASERST           ; give the pilot's world back to physics
.nchr:
        jmp  .ncam2

.ncam2:
        call LERPRST            ; ...and the true un-lerped state too
        call SETTRIG            ; ...AND THE TRIG THAT GOES WITH IT. INPUT
                                ; integrates the flight path straight off
                                ; hsin/hcos/psin/pcos and never recomputes
                                ; them - it trusts whatever the render left.
                                ; That was fine while the render only ever
                                ; drew the pilot's own attitude. It stopped
                                ; being fine when the head could turn: the
                                ; angles were put back but the SINES were
                                ; not, so the jet flew off down the line of
                                ; sight. CHASERST and LERPRST each call
                                ; SETTRIG for exactly this reason, and both
                                ; are CONDITIONAL - in ordinary flight
                                ; neither fires. One unconditional call
                                ; here makes the contract unconditional
                                ; too, which is what it should always have
                                ; been.
        call SYMSEG:STG2F   ; *** TEMP marker: the render is done ***
        call HUD                ; the no-cockpit readouts, in OUR font - so
                                ; they go in BEFORE the blit now, not after
                                ; it through the BIOS
        call BLIT               ; to video memory
        ; nozzle fire: re-write DAC entry 94 (the F-15 SE II trick - the
        ; engines burn by palette cycling, not by drawing anything)
        mov  ax,[lasttk]
        shr  ax,1
        and  ax,3
        mov  bx,ax
        add  bx,bx
        add  bx,ax              ; *3
        mov  dx,3C8h
        mov  al,94
        out  dx,al
        inc  dx
        mov  al,[GLOWT+bx]
        out  dx,al
        mov  al,[GLOWT+bx+1]
        out  dx,al
        mov  al,[GLOWT+bx+2]
        out  dx,al
        call SYMSEG:STG3F   ; *** TEMP marker: the frame closed ***
        call SNDENG             ; the engine follows the throttle
        call WAITV              ; tearing guard only (does not gate physics)
        ; the exit is Alt-Q, the MicroProse way (F-15 SE II manual).
        ; ESC is deliberately DEAD: players kept quitting whole sorties
        ; by accident with it (user feedback 2026-07-23)
        cmp  byte [KEYS+SC_ALT],0
        je   GAMELOOP
        cmp  byte [KEYS+SC_Q],0
        je   GAMELOOP

QUIT:
        call SBOFF              ; silence before we leave
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

        include '..\..\..\ENGINE\E_MATH.INC'   ; engine: LCG random
        include '..\..\..\ENGINE\E_TERR.INC'   ; engine: Diamond-Square world
        include 'VIDEO.INC'   ; palette DAC, background bands, blit
        include 'M3D.INC'   ; the 3D-edge pipeline (game side)
        include '..\..\..\ENGINE\E_M3D.INC'   ; engine: trig, rotation, projection
        include 'RASTER.INC'   ; the gunsight (game side)
        include '..\..\..\ENGINE\E_RAST.INC'   ; engine: polygon/line rasterizer
        include 'TERRAIN.INC'   ; Diamond-Square map, 3D mesh, minimap bake
        include 'SCENE.INC'   ; frame render: sky, far belt megablocks
        include 'WORLD.INC'   ; near cells: buildings, faces, windows
        include 'WORLD2.INC'   ; face builders, city plan, window glyphs
        include 'FLIGHT.INC'   ; physics, collisions, crash screen
        include 'HUD.INC'   ; text HUD and world minimap blit
        include 'PLANES.INC'   ; AI jets in the sky
        include 'SOUND.INC'   ; Sound Blaster engine noise

; ============================================================================
;  Key-state table (at the very end)
; ============================================================================
KEYS    db 128 dup(0)

; ---- and the LATCH, which is what makes the switches work on a slow machine
;  KEYS says what is held RIGHT NOW, and that was enough while a frame took
;  a fiftieth of a second. On a machine drawing at one frame a second - which
;  is exactly what LOW exists for - a player presses the brake and lets go
;  again BETWEEN two polls: KEYS is back to zero by the time SWKEYS looks,
;  its compare against swprev never sees the 1, and the switch never throws.
;  Reported from a Hercules take as "the keys hardly press at all, you cannot
;  even get the brake off", and it was not the keyboard: it was the frame.
;
;  KHIT[scan] is set by the interrupt on every key-DOWN and cleared by
;  whoever consumes it. A tap of any length survives until it is read.
;  Held keys - the stick, the throttle - go on reading KEYS and are
;  untouched by any of this.
KHIT    db 128 dup(0)

; ---- BSS: buffers that live past the initialized image ---------------------
; Everything below is fully written before first read (DSGEN/MMAPGEN at
; startup, TERRPREP every frame, the font copy at load). In the COM years
; this was invisible 'equ' arithmetic - a COM owns its whole segment. The
; EXE's linker knows no such custom: the ground has to be CLAIMED with
; real uninitialized bytes, or it settles SKYSEG right on top of it.
label BSS byte
        db  22695 dup(?)        ; the buffers (see the equ map below)
        ; HOW MUCH ROOM IS LEFT: this label costs the image nothing (it is
        ; a name in the OBJ, not a byte in the EXE) and BUILDQ links OWLFLY2
        ; with /m, so SRC\CITY.MAP prints its address - and that address IS
        ; BSSEND-START. Free bytes = 0FDEEh - that. Beats the %OUT ladder
        ; the radar work used, which had to be written and then deleted.
label BSSMARK byte
label HMAP byte at BSS   ; 4096 bytes: world heightmap
; (the baked minimap lives at [scrseg]:0 - a far 64K page - not here)
label TRX word at BSS+4096   ; 1681 words: rotated node X
label TRZ word at BSS+7458   ; 1681 words: rotated node Z
label TWH word at BSS+10820   ; 1681 words: node world heights
label TH byte at BSS+14182   ; 1681 bytes: node raw heights
FONTBUF =  BSS+15863              ; 246 bytes: font from CITY.DAT (untyped:
                                    ;  used as an immediate address only)
; NB: the COM image + this BSS + the stack ALL share one 64K segment.
; Keep BSSEND + image size under ~63.5K or the black box eats the stack
; (that was the grey-screen hang of 2026-07-09).
PSPAN   =  BSS+16119              ; 1600 bytes: cockpit blit span table,
                                    ;  (buffer offset, length) pairs, 0FFFFh
                                    ;  terminated (399 spans max; the real
                                    ;  panel uses 382 - mkpanel prints it)
WRK     =  BSS+17719              ; wreck pool: 4 slots of WRKSZ bytes
                                    ;  (+0 wtim, +2 wgy, +WFP faces 8x12b,
                                    ;  +WCO corners 8x4x6b, +WCL colours 8b)
label FLB word at BSS+18919   ; black box ring: FLBN samples of
                                    ;  (camx,camy,camz,heading,pitch,roll)
label TLX word at BSS+19303   ; contrail rings: NPLANE*TLN words each
label TLY word at BSS+20263   ;  (moved out of the image: generated
label TLZ word at BSS+21223   ;  at spawn, never shipped as zeros)
DSTBA   =  22183                  ; (as a plain number too: DSTCLR needs it
                                    ;  as an immediate, not as an address)
label DSTB byte at BSS+DSTBA   ; ruins bitmap: 1 bit per world cell
                                    ;  (64x64), set = the building is down
; (the window lattice went to TOWNSEG on 2026-08-03, reached with CS:
;  overrides. It is WINFACEF's private scratch - nothing in the main
;  segment has ever read a byte of it - and 180 bytes of the main
;  segment is 180 bytes, which is what the stack guard here trades in.)
BSSEND  =  BSS+22695

; ---- THE STACK GUARD -------------------------------------------------------
; The 2026-07-23 lesson: the stack starts at FFFEh and grows DOWN into
; whatever sits at the top of BSS. When features pushed BSSEND close to
; the top, SP quietly shredded the model tables and the jets tore into
; giant shards. The build now REFUSES to get that tight: BSSEND must
; leave the stack at least 512 bytes of clean fall (typical depth is
; under 300). Under pressure again? Evict cold code/data to SKYSEG the
; way GENBED went, or open a third segment for the model tables.
if (BSSEND-START) > 0FDEEh
        %OUT *** BSS has eaten the stack: move data out of CODE ***
        .ERR
end if

        rb 0FFF0h - $   ; claim the segment clean to SP's perch at FFFEh.
        db   14 dup(?)          ; BOND: CODE is the LAST segment in the file,
                                ; so all of this - BSS and stack, 22K and
                                ; more - is reserved, not stored: FASM puts
                                ; it in the header's minimum allocation and
                                ; DOS hands it over at load.

