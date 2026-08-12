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
;     SETTRIG must run each frame before RENDER (fills hsin/hcos/rsin/rcos).
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
FUELMAX = 6000                ; full tank (1 unit burned per tick ~ 5.5 min)
VSTALL  = 300                 ; stall airspeed (vel units)
CRUISE  = 736                 ; initial airspeed (= 46 units/tick, old feel)
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
SC_Z    = 2Ch                 ; rudder left
SC_F2   = 3Ch                 ; cockpit view toggle
SC_NP7  = 47h                 ; numpad 7: rudder left
SC_NP9  = 49h                 ; numpad 9: rudder right
SC_NPP  = 4Eh                 ; numpad +: throttle up
SC_NPM  = 4Ah                 ; numpad -: throttle down
SC_EQ   = 0Dh                 ; main-row =/+: throttle up
SC_MIN  = 0Ch                 ; main-row -: throttle down
SC_V    = 2Fh                 ; V: sound mode (all/effects/silence)
WRKSZ   = 300                 ; wreck slot size (see the BSS block)
WCL     = 292                 ; face colours offset inside a slot
BSSCLR  = 2584                ; (BSSEND-WRK)/2 - keep in sync with BSS!
SNDN    = 8000h               ; sound ring length (ENGINE\E_SND.INC contract)
FLBN    = 48                  ; black box: samples (every 2nd tick, ~5.3 s)
FLBSZ   = 576                 ; FLBN * 12 bytes (x,y,z,hdg,pitch,roll)
WFP     = 4                   ; face records offset inside a slot
WCO     = 100                 ; corner offsets offset inside a slot                 ; C: toggle cockpit panel

format binary as 'com'
        org 100h

        ; .8086 in the TASM source. FASM has no such directive - without this
        ; include it silently uses 386 jumps when a target is out of range.
        include '..\..\..\ENGINE\E_8086.INC'

START:  jmp  MAIN
        include 'DATA.INC'   ; variables, palettes, tables
        include 'KEYB.INC'   ; INT 9 keyboard handler

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
        mov  dx,KBINT
        mov  ax,2509h
        int  21h                ; DS=CS already -> vector to CS:KBINT

        ; (no PIT reprogram, no INT 8 hook - we only read the stock BIOS tick)

        ; ---- load CITY.DAT into its own segment (resources: font, ...) ----
        mov  ax,cs
        add  ax,2000h           ; past the back-buffer at CS+1000h
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
        cmp  di,PSPAN+1796 ; keep room for the terminator
        jb   .sc
.sd:   mov  word [di],0FFFFh
.pn:   pop  es

        push es                 ; seed the world from the clock: new map
        mov  ax,40h             ; every run (the map lives in HMAP after this,
        mov  es,ax              ; so everything stays self-consistent)
        mov  ax,[es:6Ch]
        pop  es
        or   ax,1               ; LCG must not start at 0
        mov  [rseed],ax
        mov  ax,cs              ; far scratch: the 64K page right above
        add  ax,4FFFh           ; the sample segment - the minimap lives
        and  ax,0F000h          ; there, not in our crowded 64K
        mov  [scrseg],ax
        call DSGEN              ; build the Diamond-Square world heightmap
        call MMAPGEN            ; bake the minimap from it
        call BRDGEN             ; draw the front line on the war

        ; video mode 13h + palette (day by default; N toggles at runtime)
        mov  ax,0013h
        int  10h
        call APPLYPAL

        ; spawn over a city node (H in 130..160), not out at sea
        mov  word [camx],0
        mov  word [camz],0
        xor  si,si
.seek: mov  al,[HMAP+si]
        cmp  al,130
        jb   .snext
        cmp  al,160
        ja   .snext
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
        jmp  .sdone
.snext:
        inc  si
        cmp  si,4096
        jb   .seek
.sdone:
        mov  word [camy],1450 ; start high above everything (peaks ~1110)
        ; ---- wreck pool lives in BSS: zero it (memory past the image
        ; is not guaranteed clean) ----
        push es
        mov  ax,cs
        mov  es,ax
        mov  di,WRK      ; zero WRK..BSSEND: wrecks, black box,
        xor  ax,ax              ; trails (reseeded anyway) and the ruins
        mov  cx,BSSCLR          ; bitmap
        cld
        rep  stosw
        pop  es

        call SBINIT             ; the engine hums if a Blaster is home

        ; ---- AI traffic: two squadrons scattered around the player ----
        call RESPAWNALL
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

        ; --- render (runs as fast as it can; speed no longer tied to it) ---
        call LERPSET            ; draw BETWEEN the ticks: silk, not jerks
        call CHASESET           ; F3: swap in the chase camera
        call SETTRIG            ; heading/roll -> sin/cos for this frame
        mov  ax,[bufseg]        ; draw into back-buffer
        mov  es,ax
        call CLEARBUF
        call RENDER
        call CHASERST           ; give the pilot's world back to physics
        call LERPRST            ; ...and the true un-lerped state too
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
        call HUD                ; text overlay (BIOS)
        call WAITV              ; tearing guard only (does not gate physics)
        cmp  byte [KEYS+SC_ESC],0
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

; ---- BSS: buffers that live past the .COM image ----------------------------
; A COM program owns the whole segment, and everything below is fully written
; before first read (DSGEN/MMAPGEN at startup, TERRPREP every frame, the font
; copy at load), so shipping ~20K of zeroes in the file was pure waste.
label BSS byte
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
PSPAN   =  BSS+16119              ; 1800 bytes: cockpit blit span table,
                                    ;  (buffer offset, length) pairs, 0FFFFh
                                    ;  terminated (449 spans max; the real
                                    ;  panel uses ~400)
WRK     =  BSS+17919              ; wreck pool: 4 slots of WRKSZ bytes
                                    ;  (+0 wtim, +2 wgy, +WFP faces 8x12b,
                                    ;  +WCO corners 8x4x6b, +WCL colours 8b)
label FLB word at BSS+19119   ; black box ring: FLBN samples of
                                    ;  (camx,camy,camz,heading,pitch,roll)
label TLX word at BSS+19695   ; contrail rings: NPLANE*TLN words each
label TLY word at BSS+20655   ;  (moved out of the image: generated
label TLZ word at BSS+21615   ;  at spawn, never shipped as zeros)
label DSTB byte at BSS+22575   ; ruins bitmap: 1 bit per world cell
                                    ;  (64x64), set = the building is down
BSSEND  =  BSS+23087

