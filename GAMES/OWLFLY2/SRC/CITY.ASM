; ============================================================================
;  CITY.ASM  -  "WIRE CITY" : night flight over a wireframe city
;  VGA mode 13h (320x200x256), 8086 only, integer math,
;  wireframe graphics, near-Z clipping + screen line clipping.
;
;  Build with TASM (in DOSBox):
;       TASM CITY.ASM
;       TLINK CITY.OBJ             ->  CITY.EXE
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
;     SETTRIG must run each frame before RENDER (fills hsin/hcos/rsin/rcos)
;     AND AGAIN AFTER IT, because INPUT flies the jet on those same sines
;     and never computes them itself. Anything that moves the camera for
;     the length of a render - the chase, the orbit, the pilot's head -
;     must leave the trig belonging to the AIRCRAFT, not to the view.
;
;  COORDS: PROJPT returns sx in AX, sy in DX. SINQ returns sin*256 in AX.
;  DEAD CODE (assembled but never called) is tagged "DEAD" in its banner.
; ----------------------------------------------------------------------------

        .8086
        LOCALS
        JUMPS                   ; auto-extend out-of-range conditional jumps
                                ;   (emits jcc short + jmp near; pure 8086)

; ---- world constants -------------------------------------------------------
FOCAL   equ 220                 ; projection focal length: ~72 deg horizontal
                                ; FOV (160 was a 90-deg fisheye - the world
                                ; read as a diorama, buildings looked tiny)
CELL    equ 256                 ; grid pitch (doc only; code uses shl/shr 8 and 128)
BIAS    equ 8192                ; world->cell bias (keeps cell math unsigned)
RAD     equ 9                   ; building render radius (cells)
MAXD2   equ RAD*RAD*2           ; max squared cell distance (painter buckets)
GR      equ 7                   ; ground-grid radius (cells)
NEARZ   equ 40                  ; near clip plane
NCOL    equ 4                   ; window panes across a wall...
NROW    equ 8                   ; ...and down it. Both went up when a
                                ; building grew to own a 2x2 plot: 3x5 on a
                                ; wall twice the size is not windows, it is
                                ; garage doors.
NSTR    equ 8                   ; lattice row stride - a POWER OF TWO, kept
                                ; separate from NCOL+1 so the index stays a
                                ; shift. NCOL may be anything under it.
NLAT    equ NSTR*(NROW+1)       ; the corner lattice the panes share
WMINPX  equ 6                   ; a wall thinner than this carries no glass
WQUADPX equ 5                   ; ...and below this many pixels per CELL the
                                ; whole facade drops to lit dots
; ---- the streets, and what drives on them (developed in LAB\HOUSE.COM).
; CARV*CARG = 2048 = eight cells = ONE BLOCK per green, and that identity
; is what the whole traffic scheme rests on - see TRAFFICF in TOWN.INC.
TKSUB   equ 12                  ; traffic-clock steps per BIOS tick
CARV    equ 1                   ; units per clock step while moving
CARG    equ 2048                ; clock steps of green
CARCLR  equ 256                 ; all-red clearance between the two greens
CART    equ 2*(CARG+CARCLR)     ; the whole signal cycle (~21 s)
CARRST  equ 200                 ; how far into its cell a stopped vehicle
                                ; waits - just short of the next crossing
LANEOF  equ 96                  ; lane centre from the avenue centre
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
ROADR   equ 24                  ; cells: the cheap cull, done on cdi/cdj
ROADLOD equ 9                   ; cells: inside this a quad per CELL, outside
                                ; it a quad per 2x2 group
ROADZ   equ 7200                ; units: the fine cull, after ROTCUL
CARZ    equ 2200                ; the traffic stops nearer still - past this
                                ; a car is one pixel and costs a whole box.
                                ; It also never runs in grouped detail, and
                                ; CARZ < ROADLOD*256 keeps that automatic.
ROADLIFT equ 2                  ; how far the tarmac sits above the ground
ASPHALT equ 120                 ; DAC: the road surface
VCOL0   equ 121                 ; DAC: first vehicle colour (8 lit/shade)
NKILL   equ 8                   ; vehicles that can be dead at once
KRESP   equ 90                  ; ticks before a fresh one takes the slot
FARZ    equ 21600               ; far clip distance
MEGR    equ 20                  ; far-belt radius in 4x4-cell megablocks
CEIL    equ 3000                ; flight ceiling (loops need headroom)

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
FUELMAX equ 12000               ; full tank (1 unit burned per tick ~ 11 min).
                                ; Doubled 2026-08-05 on the pilot's word: at
                                ; 5.5 minutes a sortie was over before you
                                ; had crossed the front line and come back.
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

; ---- the NEWTON sky's palette block (see SKY.INC and the palettes) ---------
SKYZ    equ 98                  ; ramp SKYZ..SKYZ+4 zenith->haze, then
                                ; SKYZ+4..SKYZ+6 the cloud light
LDIM    equ 105                 ; the pitch ladder's dim grey
LCYN    equ 106                 ; the IVV caret's cyan
UBLACK  equ 107                 ; the front door's true black

; ---- keyboard scan codes ---------------------------------------------------
SC_ESC  equ 01h
SC_UP   equ 48h
SC_DN   equ 50h
SC_LF   equ 4Bh
SC_RT   equ 4Dh
SC_SP   equ 39h
SC_N    equ 31h                 ; N key: toggle day/night palette
SC_W    equ 11h                 ; W: throttle up
SC_S    equ 1Fh                 ; S: throttle down
SC_A    equ 1Eh                 ; A: afterburner (hold)
SC_C    equ 2Eh
SC_Q    equ 10h                 ; rudder left
SC_E    equ 12h                 ; rudder right
SC_ENT  equ 1Ch                 ; target lock
SC_M    equ 32h                 ; right MFD mode toggle
SC_BS   equ 0Eh                 ; missile launch (Backspace, above Enter)
SC_F3   equ 3Dh                 ; chase camera toggle
SC_F4   equ 3Eh                 ; orbit camera around the locked target
SC_F5   equ 3Fh                 ; missile camera arm/disarm
SC_F6   equ 40h                 ; LOOK LEFT  - 90 degrees, inside the cockpit
SC_F7   equ 41h                 ; LOOK RIGHT - and Ctrl+arrows do the same
SC_CTL  equ 1Dh                 ; the Ctrl of Ctrl+left / Ctrl+right
SC_Z    equ 2Ch                 ; rudder left
SC_F2   equ 3Ch                 ; cockpit view toggle
SC_NP7  equ 47h                 ; numpad 7: rudder left
SC_NP9  equ 49h                 ; numpad 9: rudder right
SC_NPP  equ 4Eh                 ; numpad +: throttle up
SC_NPM  equ 4Ah                 ; numpad -: throttle down
SC_EQ   equ 0Dh                 ; main-row =/+: throttle up
SC_MIN  equ 0Ch                 ; main-row -: throttle down
SC_V    equ 2Fh                 ; V: sound mode (all/effects/silence)
SC_1    equ 02h                 ; top-row 1: rudder left  (the F-15 way)
SC_3    equ 04h                 ; top-row 3: rudder right
SC_LSH  equ 2Ah                 ; the shifts, for the throttle gates
SC_RSH  equ 36h
SC_ALT  equ 38h                 ; Alt: the Alt-Q exit chord
SC_X    equ 2Dh                 ; X: radar unzoom (Z zooms - the manual)
SC_K    equ 25h                 ; K: map zoom (PROVISIONAL - the keyboard
                                ;  layout is still open; K is free and sits
                                ;  next to M, which pages the same screen)
SC_F    equ 21h                 ; F: flaps
SC_L    equ 26h                 ; L: landing gear
SC_B    equ 30h                 ; B: airbrake
SC_G    equ 22h                 ; G: ground comms  (VHF-FM, the army net)
SC_U    equ 16h                 ; U: air comms     (UHF, the squadron net)
SC_I    equ 17h                 ; I: IFF transponder
SC_T    equ 14h                 ; T: TACAN
SC_O    equ 18h                 ; O: master mode, A-A <-> A-G
SC_P    equ 19h                 ; P: autopilot
SC_R    equ 13h                 ; R: emissions (transmit / receive)
SC_J    equ 24h                 ; J: ECM
SC_Y    equ 15h                 ; Y: noise jammer
WRKSZ   equ 300                 ; wreck slot size (see the BSS block)
WCL     equ 292                 ; face colours offset inside a slot
BSSCLR  equ 2488                ; (BSSEND-WRK)/2 - keep in sync with BSS!
SNDN    equ 8000h               ; sound ring length (ENGINE\E_SND.INC contract)
FLBN    equ 32                  ; black box: samples (every 2nd tick, ~3.5 s)
FLBSZ   equ 384                 ; FLBN * 12 bytes (x,y,z,hdg,pitch,roll)
WFP     equ 4                   ; face records offset inside a slot
WCO     equ 100                 ; corner offsets offset inside a slot                 ; C: toggle cockpit panel

CODE    SEGMENT PARA PUBLIC 'CODE'
        ASSUME  CS:CODE, DS:CODE, ES:CODE, SS:CODE
        ; (the COM-era ORG 100h gap is gone: the segment got tight and
        ; those 256 bytes belong to the STACK now - see the BSS guard)

START:  jmp  MAIN
        INCLUDE DATA.INC        ; variables, palettes, tables
        INCLUDE KEYB.INC        ; INT 9 keyboard handler

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

        ; back-buffer 64K above the image (maxalloc: we still own it all).
        ; The EXE carries TWO segments - CODE and SKYSEG right behind
        ; it. SKYSEG gets a full 8K window (CS+1000h..CS+11FFh) with
        ; its own assemble-time guard, and the far map starts past it.
        mov  ax,cs
        add  ax,1A00h           ; past SKYSEG (CS+1000h, 8K), UISEG
        mov  [bufseg],ax        ; (CS+1200h, SIXTEEN K), SYMSEG (CS+1600h,
                                ; 8K) and TOWNSEG (CS+1800h, 8K) - each
                                ; with its own guard

        ; hook INT 9
        mov  ax,3509h
        int  21h
        mov  [oldoff],bx
        mov  [oldseg],es
        mov  dx,offset KBINT
        mov  ax,2509h
        int  21h                ; DS=CS already -> vector to CS:KBINT

        ; (no PIT reprogram, no INT 8 hook - we only read the stock BIOS tick)

        ; ---- load CITY.DAT into its own segment (resources: font, ...) ----
        ; PAST THE BACK BUFFER, and mind the arithmetic. The buffer is
        ; 64000 bytes = 0FA0h paragraphs, so it reaches bufseg+0FA0h:
        ;   buffer 1A00h .. 29A0h   ->   this must start at 2A00h.
        ;
        ; THIS HAS NOW GONE WRONG TWICE, BOTH TIMES THE SAME WAY. Opening
        ; SYMSEG pushed the buffer up 200h and it ate the front of the
        ; loaded CITY.DAT; opening TOWNSEG on 2026-08-03 pushed it up
        ; another 200h and did it again. The panel is blitted OUT of this
        ; image, so the world drawn into the BOTTOM of the buffer comes
        ; straight back up as the TOP of the cockpit, pixel for pixel -
        ; which looks like a deliberate reflection effect rather than a
        ; fault, and that is exactly why it gets missed.
        ;
        ; THE RULE: opening a far segment moves the back buffer, and
        ; moving the back buffer moves EVERYTHING STACKED ABOVE IT. Walk
        ; the whole map - resseg here, then sndseg (SOUND.INC, 64K
        ; aligned from CS+4000h) and scrseg above it - before believing
        ; the new segment cost nothing.
        mov  ax,cs
        add  ax,2A00h           ; past the back buffer at CS+1A00h
        mov  [resseg],ax
        mov  dx,offset FNAME
        mov  ax,3D00h           ; open read-only
        int  21h
        jnc  @@ropn
        mov  dx,offset RESMSG   ; no resource file: say so and exit cleanly
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
@@ropn: mov  bx,ax              ; read the whole file into resseg:0
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
        mov  cl,es:[3]          ; entry count
        xor  ch,ch
        mov  bx,4               ; first directory entry
@@rfind:
        cmp  byte ptr es:[bx],1 ; font id
        je   @@rgot
        add  bx,5
        loop @@rfind
        pop  es
        jmp  @@rdone            ; no font in file: panel text stays blank
@@rgot: mov  si,es:[bx+1]       ; resource offset
        mov  cx,es:[bx+3]       ; resource length
        cmp  cx,256
        jbe  @@rcl
        mov  cx,256
@@rcl:  push ds
        mov  ax,[resseg]
        mov  ds,ax              ; DS:SI = resource data
        mov  ax,cs
        mov  es,ax
        mov  di,offset FONTBUF  ; ES:DI = local font buffer
        cld
        rep  movsb
        pop  ds
        pop  es
@@rdone:
        ; ---- resource 2: the photo cockpit. Remember where it sits and ----
        ; ---- precompute the blit spans (runs of non-transparent bytes) ----
        push es
        mov  ax,[resseg]
        mov  es,ax
        mov  cl,es:[3]          ; entry count
        xor  ch,ch
        mov  bx,4
@@pf:   cmp  byte ptr es:[bx],2
        je   @@pg
        add  bx,5
        loop @@pf
        jmp  @@pn               ; no cockpit bitmap: drawn panel fallback
@@pg:   mov  ax,es:[bx+1]
        mov  [pimgo],ax
        mov  si,ax              ; walk the 64000 image bytes once
        xor  bx,bx              ; pixel index
        mov  di,offset PSPAN
@@sc:   cmp  bx,64000
        jae  @@sd
        cmp  byte ptr es:[si],255
        jne  @@sr
        inc  si
        inc  bx
        jmp  @@sc
@@sr:   mov  [di],bx            ; span start = buffer offset
        xor  cx,cx
@@s2:   cmp  bx,64000
        jae  @@se
        cmp  byte ptr es:[si],255
        je   @@se
        inc  si
        inc  bx
        inc  cx
        jmp  @@s2
@@se:   mov  [di+2],cx          ; span length
        add  di,4
        cmp  di,offset PSPAN+1596 ; keep room for the terminator
        jb   @@sc
@@sd:   mov  word ptr [di],0FFFFh
@@pn:   pop  es

        call FAR PTR CPSLOADF   ; CPSIDE.DAT: the two 90-degree views, into a
                                ; page of their own. It runs once and it is
                                ; all file handling, so it lives in SYMSEG
                                ; next to the code that reads it.

        ; ---- THE FRONT DOOR: video and sound up FIRST, then the wire,
        ; then the splash and the sky list. The world is minted only
        ; after the pilot picks one - its seed comes from the clock
        ; (create) or from the chosen sky's ad (join).
        mov  ax,0013h
        int  10h
        call FAR PTR APPLYPALF
        push es                 ; wreck pool etc: BSS is not guaranteed
        mov  ax,cs              ; clean, and the menu era runs long
        mov  es,ax
        mov  di,offset WRK
        xor  ax,ax
        mov  cx,BSSCLR
        cld
        rep  stosw
        pop  es
        call SBINIT             ; the splash roar wants a voice
        call FAR PTR NETINITF
        mov  [netup],al
        mov  [netpid],dx        ; 0 when the wire is dark
        call FAR PTR UISPLASH
        call FAR PTR UIMENU     ; blocks until a sky is picked
        cmp  byte ptr [gact],2
        je   @@gjn              ; join: the menu set rseed/wseed/ggid
        push es                 ; create: mint a fresh seed NOW (the
        mov  ax,40h             ; menu ran for human seconds - good
        mov  es,ax              ; entropy)
        mov  ax,es:[6Ch]
        pop  es
        or   ax,1
        mov  [rseed],ax
        mov  [wseed],ax
        mov  ax,[netpid]
        mov  [ggid],ax          ; our sky flies under our wire name
        call FAR PTR NETHOSTF
@@gjn:
        mov  ax,cs              ; far scratch: the 64K page right above
        add  ax,5FFFh           ; the sample segment - the minimap lives
        and  ax,0F000h          ; there, not in our crowded 64K
        mov  [scrseg],ax
        call DSTCLR             ; a new world stands up whole
        call DSGEN              ; build the Diamond-Square world heightmap
        call FAR PTR AFINITF   ; ...then IRON THE AERODROMES INTO IT, before
                                ; anything is baked off it. The block table
                                ; and the minimap below both read HMAP, and
                                ; both have to see flat concrete: that is what
                                ; keeps the mesh, TERRH, the streets and the
                                ; collision test agreeing about a runway
                                ; without one special case between them.
        call FAR PTR BLKTABF    ; zone the 32x32 blocks off it, ONCE - the
                                ; streets and the buildings both read that
                                ; table and must not re-derive it per cell
        call FAR PTR MMAPGENF   ; bake the minimap from it
        call BRDGEN             ; draw the front line on the war
        call FAR PTR SKYBAKE    ; cut this run's sky: ramp + cloud coats

        ; (video mode went up before the menu - the world just draws)

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
        mov  ax,[netpid]        ; pilots of one wire must not share a
        and  ax,3               ; cockpit: fan the spawns out east
        mov  cl,7
        shl  ax,cl              ; 0/128/256/384
        add  [camx],ax
        mov  word ptr [camy],1450 ; start high above everything (peaks ~1110)
        ; (the BSS wipe and SBINIT went up before the menu; the F15
        ; model is BAKED into the image by Obj2Inc at build time)

        call FAR PTR RSTAINITF  ; plant the two ground radar stations
        call FAR PTR SHKINITF   ; and the six Shilkas over the lines
        ; ---- AI traffic: two squadrons scattered around the player ----
        call RESPAWNALL
        cmp  byte ptr [gbots],0 ; a botless sky is a clean arena:
        jne  @@bots1            ; the 20v20 war stays home, only real
        xor  bx,bx              ; pilots fly (CS manners)
@@bk:   inc  bx
        mov  byte ptr [pst+bx],1
        cmp  bx,39
        jb   @@bk
@@bots1:
        mov  word ptr [heading],0
        mov  word ptr [roll],0
        call FLBSEED            ; the black box starts at the spawn point
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
        jbe  @@fp1
        mov  ax,8
@@fp1:  mov  [fprev],ax
        mov  word ptr [fcnt],0
@@ploop:
        push bx                 ; INPUT clobbers BX (leaves BX=256 from idiv)
        call INPUT              ; one fixed physics step
        pop  bx
        dec  bx
        jnz  @@ploop
@@pdone:
        inc  word ptr [fcnt]
        call COLLIDE
        call FAR PTR NETPOSF    ; tell the wire where we are (1/tick)...
        call FAR PTR NETPOLLF   ; ...and learn where everyone else is
        call NETAPPLY           ; deaths and hits the wire brought us

        ; --- render (runs as fast as it can; speed no longer tied to it) ---
        call LERPSET            ; draw BETWEEN the ticks: silk, not jerks
        call CHASESET           ; F3: swap in the chase camera
        call FAR PTR CCLOCKF    ; advance the traffic clock: the lights run
                                ; on TIME, not on how fast we are drawing
        call FAR PTR SVIEWF     ; F6/F7 and Ctrl+arrows: look 90 left/right,
                                ; which is a turn of [heading] and nothing
                                ; more - taken back below, before physics
        call SETTRIG            ; heading/roll -> sin/cos for this frame
        mov  ax,[bufseg]        ; draw into back-buffer
        mov  es,ax
        call CLEARBUF
        call RENDER
        call FAR PTR SVRSTF     ; nose back down the centreline
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
        call SNDENG             ; the engine follows the throttle
        call WAITV              ; tearing guard only (does not gate physics)
        ; the exit is Alt-Q, the MicroProse way (F-15 SE II manual).
        ; ESC is deliberately DEAD: players kept quitting whole sorties
        ; by accident with it (user feedback 2026-07-23)
        cmp  byte ptr [KEYS+SC_ALT],0
        je   GAMELOOP
        cmp  byte ptr [KEYS+SC_Q],0
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

        INCLUDE ..\..\..\ENGINE\E_MATH.INC ; engine: LCG random
        INCLUDE ..\..\..\ENGINE\E_TERR.INC ; engine: Diamond-Square world
        INCLUDE ..\..\..\ENGINE\E_SND.INC  ; engine: DSP write, DMA beam, ring mix
        INCLUDE VIDEO.INC       ; palette DAC, background bands, blit
        INCLUDE M3D.INC         ; the 3D-edge pipeline (game side)
        INCLUDE ..\..\..\ENGINE\E_M3D.INC  ; engine: trig, rotation, projection
        INCLUDE RASTER.INC      ; the gunsight (game side)
        INCLUDE ..\..\..\ENGINE\E_RAST.INC ; engine: polygon/line rasterizer
        INCLUDE TERRAIN.INC     ; Diamond-Square map, 3D mesh, minimap bake
        INCLUDE SCENE.INC       ; frame render: sky, far belt megablocks
        INCLUDE WORLD.INC       ; near cells: buildings, faces, windows
        INCLUDE WORLD2.INC      ; face builders, city plan, window glyphs
        INCLUDE FLIGHT.INC      ; physics, collisions, crash screen
        INCLUDE HUD.INC         ; text HUD and world minimap blit
        INCLUDE PLANES.INC      ; AI jets in the sky
        INCLUDE SOUND.INC       ; Sound Blaster engine noise


; ============================================================================
;  Key-state table (at the very end)
; ============================================================================
KEYS    db 128 dup(0)

; ---- BSS: buffers that live past the initialized image ---------------------
; Everything below is fully written before first read (DSGEN/MMAPGEN at
; startup, TERRPREP every frame, the font copy at load). In the COM years
; this was invisible 'equ' arithmetic - a COM owns its whole segment. The
; EXE's linker knows no such custom: the ground has to be CLAIMED with
; real uninitialized bytes, or it settles SKYSEG right on top of it.
BSS     label byte
        db  22695 dup(?)        ; the buffers (see the equ map below)
        ; HOW MUCH ROOM IS LEFT: this label costs the image nothing (it is
        ; a name in the OBJ, not a byte in the EXE) and BUILDQ links OWLFLY2
        ; with /m, so SRC\CITY.MAP prints its address - and that address IS
        ; BSSEND-START. Free bytes = 0FDEEh - that. Beats the %OUT ladder
        ; the radar work used, which had to be written and then deleted.
        PUBLIC BSSMARK
BSSMARK label byte
HMAP    equ  byte ptr BSS           ; 4096 bytes: world heightmap
; (the baked minimap lives at [scrseg]:0 - a far 64K page - not here)
TRX     equ  word ptr BSS+4096      ; 1681 words: rotated node X
TRZ     equ  word ptr BSS+7458      ; 1681 words: rotated node Z
TWH     equ  word ptr BSS+10820     ; 1681 words: node world heights
TH      equ  byte ptr BSS+14182     ; 1681 bytes: node raw heights
FONTBUF equ  BSS+15863              ; 246 bytes: font from CITY.DAT (untyped:
                                    ;  used as an immediate address only)
; NB: the COM image + this BSS + the stack ALL share one 64K segment.
; Keep BSSEND + image size under ~63.5K or the black box eats the stack
; (that was the grey-screen hang of 2026-07-09).
PSPAN   equ  BSS+16119              ; 1600 bytes: cockpit blit span table,
                                    ;  (buffer offset, length) pairs, 0FFFFh
                                    ;  terminated (399 spans max; the real
                                    ;  panel uses 382 - mkpanel prints it)
WRK     equ  BSS+17719              ; wreck pool: 4 slots of WRKSZ bytes
                                    ;  (+0 wtim, +2 wgy, +WFP faces 8x12b,
                                    ;  +WCO corners 8x4x6b, +WCL colours 8b)
FLB     equ  word ptr BSS+18919     ; black box ring: FLBN samples of
                                    ;  (camx,camy,camz,heading,pitch,roll)
TLX     equ  word ptr BSS+19303     ; contrail rings: NPLANE*TLN words each
TLY     equ  word ptr BSS+20263     ;  (moved out of the image: generated
TLZ     equ  word ptr BSS+21223     ;  at spawn, never shipped as zeros)
DSTBA   equ  22183                  ; (as a plain number too: DSTCLR needs it
                                    ;  as an immediate, not as an address)
DSTB    equ  byte ptr BSS+DSTBA     ; ruins bitmap: 1 bit per world cell
                                    ;  (64x64), set = the building is down
; (the window lattice went to TOWNSEG on 2026-08-03, reached with CS:
;  overrides. It is WINFACEF's private scratch - nothing in the main
;  segment has ever read a byte of it - and 180 bytes of the main
;  segment is 180 bytes, which is what the stack guard here trades in.)
BSSEND  equ  BSS+22695

; ---- THE STACK GUARD -------------------------------------------------------
; The 2026-07-23 lesson: the stack starts at FFFEh and grows DOWN into
; whatever sits at the top of BSS. When features pushed BSSEND close to
; the top, SP quietly shredded the model tables and the jets tore into
; giant shards. The build now REFUSES to get that tight: BSSEND must
; leave the stack at least 512 bytes of clean fall (typical depth is
; under 300). Under pressure again? Evict cold code/data to SKYSEG the
; way GENBED went, or open a third segment for the model tables.
IF (BSSEND-START) GT 0FDEEh
        %OUT *** BSS has eaten the stack: move data out of CODE ***
        .ERR
ENDIF

        ORG  0FFF0h             ; claim the segment clean to SP's perch
        db   14 dup(?)          ; at FFFEh, so the linker parks SKYSEG
                                ; at CS+1000h, clear of this ground

CODE    ENDS

        INCLUDE SKY.INC         ; the NEWTON sky, in its own segment
        INCLUDE UI.INC          ; the front door: splash + sky list
        INCLUDE SYM.INC         ; the fourth segment: the scope's symbols
        INCLUDE TOWN.INC        ; the fifth: the windows and the traffic
        INCLUDE NET.INC         ; the wire (appends SKYSEG; writes GLIST)

        END START
