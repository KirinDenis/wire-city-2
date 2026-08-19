; ============================================================================
;  OWLFLY3.ASM  -  OWL FLY III : the third generation, forked from
;  OWL FLY II (GAMES\OWLFLY2) with the game finished and released.
;  VGA mode 13h (320x200x256), 8086 only, integer math.
;
;  Build with FASM (in DOSBox) - MAKE.BAT in this game's folder:
;       FASM SRC\OWLFLY3.ASM INSTALL\OWLFLY3.EXE
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

; ---- world constants -------------------------------------------------------
FOCAL   = 220                 ; projection focal length: ~72 deg horizontal
                                ; FOV (160 was a 90-deg fisheye - the world
                                ; read as a diorama, buildings looked tiny)
CELL    = 256                 ; grid pitch (doc only; code uses shl/shr 8 and 128)
BIAS    = 8192                ; world->cell bias (keeps cell math unsigned)
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
SNDN    = 8000h               ; sound ring length (ENGINE\E_SND.INC contract)
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
        mov  ds,ax
        mov  es,ax

        ; ---- the front step: SELECT VIDEO SYSTEM, in text mode. It runs
        ; BEFORE the INT 9 hook below on purpose - the menu reads keys
        ; through BIOS INT 16h, which the game's own handler silences.
        ; VGA is the default and stays the untouched path; the retro
        ; cards convert the finished frame in VIDSEG (SRC\VID.INC,
        ; plan in Skill\VIDTASK.md).
        call VIDSEG:VMENUF      ; -> AL = the internal card code (VID.INC),
        mov  [vcard],al         ;    AH = the detail level from its second
        mov  [qual],ah          ;    screen: 0 FULL, 1 MEDIUM, 2 LOW
        mov  word [tstart],0    ; FULL and LOW both walk the whole mesh -
        cmp  ah,1               ;  LOW strokes it instead of filling it.
        jne  .qd                ;  MEDIUM starts the walk later, which is
        mov  word [tstart],TMED ;  a nearer horizon and nothing else.
.qd:

        ; back-buffer 64K above the image (maxalloc: we still own it all).
        ; SKYSEG gets a full 8K window (CS+1000h..CS+11FFh) with
        ; its own assemble-time guard, and the far map starts past it.
        mov  ax,cs
        add  ax,2000h           ; past SKYSEG (CS+1000h, 8K), UISEG
        mov  [bufseg],ax        ; (CS+1200h, SIXTEEN K), SYMSEG (CS+1600h,
                                ; 8K), TOWNSEG (CS+1800h, 8K) and VIDSEG
                                ; (CS+1A00h, TWENTY-FOUR K since the second
                                ; CGA palette) - each with its own guard

        ; hook INT 9
        mov  ax,3509h
        int  21h
        mov  [oldoff],bx
        mov  [oldseg],es
        mov  dx,KBINT
        mov  ax,2509h
        int  21h                ; DS=CS already -> vector to CS:KBINT

        ; (no PIT reprogram, no INT 8 hook - we only read the stock BIOS tick)

        ; ---- load CITY.DAT into its own segment (resources: font, ...) ----
        ; PAST THE BACK BUFFER, and mind the arithmetic. The buffer is
        ; 64000 bytes = 0FA0h paragraphs, so it reaches bufseg+0FA0h:
        ;   buffer 2000h .. 2FA0h   ->   this must start at 3000h.
        ;
        ; THIS HAS NOW GONE WRONG TWICE, BOTH TIMES THE SAME WAY. Opening
        ; SYMSEG pushed the buffer up 200h and it ate the front of the
        ; loaded CITY.DAT; opening TOWNSEG on 2026-08-03 pushed it up
        ; another 200h and did it again. The panel is blitted OUT of this
        ; image, so the world drawn into the BOTTOM of the buffer comes
        ; straight back up as the TOP of the cockpit, pixel for pixel -
        ; which looks like a deliberate reflection effect rather than a
        ; fault, and that is exactly why it gets missed.
        ; (VIDSEG, 2026-08-18, moved the pair a THIRD 200h, its window
        ; growing to 16K moved them a FOURTH, and to 24K a FIFTH - each
        ; time with this note read first, both constants in one edit,
        ; and the far map walked: sndseg and everything above it align
        ; from CS+4000h and CS+5000h, and CITY.DAT now ends at
        ; CS+3FB1h - SEVENTY-NINE paragraphs short of sndseg's floor.
        ; THE SHELF IS FULL: the next VIDSEG growth cannot come from
        ; here, it must take a far page instead.)
        ;
        ; THE RULE: opening a far segment moves the back buffer, and
        ; moving the back buffer moves EVERYTHING STACKED ABOVE IT. Walk
        ; the whole map - resseg here, then sndseg (SOUND.INC, 64K
        ; aligned from CS+4000h) and scrseg above it - before believing
        ; the new segment cost nothing.
        mov  ax,cs
        add  ax,3000h           ; past the back buffer at CS+2000h
        mov  [resseg],ax
        mov  dx,FNAME
        mov  ax,3D00h           ; open read-only
        int  21h
        jnc  .ropn
        mov  dx,RESMSG   ; no resource file: say so and exit cleanly
        mov  ah,9
        int  21h
        mov  dx,[oldoff]        ; restore INT 9 before leaving
        mov  ax,[oldseg]
        push ds
        mov  ds,ax
        mov  ax,2509h
        int  21h
        pop  ds
        mov  ax,4C01h
        int  21h
.ropn: mov  bx,ax              ; read the whole file into resseg:0
        mov  ax,[resseg]
        push ds
        mov  ds,ax
        xor  dx,dx
        mov  cx,0FFF0h
        mov  ah,3Fh
        int  21h
        pop  ds
        mov  ah,3Eh             ; close
        int  21h
        ; find resource id 1 (font) in the directory and copy it local
        push es
        mov  ax,[resseg]
        mov  es,ax
        mov  cl,[es:3]          ; entry count
        xor  ch,ch
        mov  bx,4               ; first directory entry
.rfind:
        cmp  byte [es:bx],1 ; font id
        je   .rgot
        add  bx,5
        loop .rfind
        pop  es
        jmp  .rdone            ; no font in file: panel text stays blank
.rgot: mov  si,[es:bx+1]       ; resource offset
        mov  cx,[es:bx+3]       ; resource length
        cmp  cx,256
        jbe  .rcl
        mov  cx,256
.rcl:  push ds
        mov  ax,[resseg]
        mov  ds,ax              ; DS:SI = resource data
        mov  ax,cs
        mov  es,ax
        mov  di,FONTBUF  ; ES:DI = local font buffer
        cld
        rep  movsb
        pop  ds
        pop  es
.rdone:
        ; ---- resource 2: the photo cockpit. Remember where it sits and ----
        ; ---- precompute the blit spans (runs of non-transparent bytes) ----
        push es
        mov  ax,[resseg]
        mov  es,ax
        mov  cl,[es:3]          ; entry count
        xor  ch,ch
        mov  bx,4
.pf:   cmp  byte [es:bx],2
        je   .pg
        add  bx,5
        loop .pf
        jmp  .pn               ; no cockpit bitmap: drawn panel fallback
.pg:   mov  ax,[es:bx+1]
        mov  [pimgo],ax
        mov  si,ax              ; walk the 64000 image bytes once
        xor  bx,bx              ; pixel index
        mov  di,PSPAN
.sc:   cmp  bx,64000
        jae  .sd
        cmp  byte [es:si],255
        jne  .sr
        inc  si
        inc  bx
        jmp  .sc
.sr:   mov  [di],bx            ; span start = buffer offset
        xor  cx,cx
.s2:   cmp  bx,64000
        jae  .se
        cmp  byte [es:si],255
        je   .se
        inc  si
        inc  bx
        inc  cx
        jmp  .s2
.se:   mov  [di+2],cx          ; span length
        add  di,4
        cmp  di,PSPAN+1596 ; keep room for the terminator
        jb   .sc
.sd:   mov  word [di],0FFFFh
.pn:   pop  es

        call SYMSEG:SFXLOADF   ; SFX.DAT: the recorded sounds, one page above
                                ;  the side views. Optional - no file, no bank
        call SYMSEG:CPSLOADF   ; CPSIDE.DAT: the two 90-degree views, into a
                                ; page of their own. It runs once and it is
                                ; all file handling, so it lives in SYMSEG
                                ; next to the code that reads it.

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
        mov  ax,cs              ; far scratch: the 64K page right above
        add  ax,5FFFh           ; the sample segment - the minimap lives
        and  ax,0F000h          ; there, not in our crowded 64K
        mov  [scrseg],ax
        call VIDSEG:VCGLDF   ; CGA only: the baked cockpit page rides
                                ; one page past the two minimap pages
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
        cmp  byte [qual],2
        jne  .dsg
        mov  bx,HMAP
        mov  cx,4096
.dsf:  mov  byte [bx],140
        inc  bx
        loop .dsf
        jmp  .dsd
.dsg:  call DSGEN              ; build the Diamond-Square world heightmap
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
        cmp  byte [qual],2
        jne  .nfl
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
        call SKYSEG:SKYBAKE   ; cut this run's sky: ramp + cloud coats

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
        call UISEG:SHKINITF   ; and the six Shilkas over the lines
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
        ; --- physics: one INPUT step per BIOS tick elapsed since last frame ---
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,[es:6Ch]        ; BIOS tick low word (18.2 Hz)
        pop  es
        mov  bx,ax
        sub  bx,[lasttk]        ; bx = ticks elapsed since last render frame
        mov  [lasttk],ax
        cmp  bx,MAXSTEP         ; clamp catch-up (anti-spiral)
        jbe  .pcl
        mov  bx,MAXSTEP
.pcl:  test bx,bx
        jz   .pdone
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
.ploop:
        push bx                 ; INPUT clobbers BX (leaves BX=256 from idiv)
        call INPUT              ; one fixed physics step
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
        call CHASESET           ; F3: swap in the chase camera
        call TOWNSEG:CCLOCKF   ; advance the traffic clock: the lights run
                                ; on TIME, not on how fast we are drawing
        call SYMSEG:SVIEWF   ; F6/F7 and Ctrl+arrows: look 90 left/right,
                                ; which is a turn of [heading] and nothing
                                ; more - taken back below, before physics
        call SETTRIG            ; heading/roll -> sin/cos for this frame
        mov  ax,[bufseg]        ; draw into back-buffer
        mov  es,ax
        call CLEARBUF
        call RENDER
        call SYMSEG:SVRSTF   ; nose back down the centreline
        call CHASERST           ; give the pilot's world back to physics
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
        include '..\..\..\ENGINE\E_SND.INC'   ; engine: DSP write, DMA beam, ring mix
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

        rb 0FFF0h - $   ; claim the segment clean to SP's perch
        db   14 dup(?)          ; at FFFEh, so the linker parks SKYSEG
                                ; at CS+1000h, clear of this ground


        include 'SKY.INC'   ; the NEWTON sky, in its own segment
        include 'NET.INC'   ; moved up: continues the segment SKY.INC opened
        include 'UI.INC'   ; the front door: splash + sky list
        include 'SYM.INC'   ; the fourth segment: the scope's symbols
        include 'TOWN.INC'   ; the fifth: the windows and the traffic
        include 'VID.INC'   ; the sixth: SELECT VIDEO SYSTEM + retro cards

