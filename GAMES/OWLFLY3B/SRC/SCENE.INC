; SCENE.INC - part of WIRE CITY (included from OWLFLY3.ASM)
; ============================================================================
;  RENDER THE WORLD
; ============================================================================
; ---------------------------------------------------------------------------
;  SETHORIZ - put the view's centre where the pilot can actually SEE.
;  The world was projected about row 100, the middle of the screen. But with
;  the cockpit up the glass ends at row 121, so the horizon sat almost on
;  the panel's edge: nearly all the window was sky and the ground got twenty
;  rows. Centring on the GLASS instead of the screen turns that into sixty.
;  Everything already follows [horiz] - the projection, the roll pivot, the
;  sky bands, the pitch ladder, the gunsight - so this is the only place
;  that has to know. The cinema views (chase, orbit, missile, the death
;  fall) show the whole screen and keep the old centre.
; ---------------------------------------------------------------------------
SETHORIZ:
        mov  word [horiz],100
        cmp  byte [dying],0
        jne  .shd
        cmp  byte [mcact],0
        jne  .shd
        cmp  byte [tgtcam],0
        jne  .shd
        cmp  byte [chsview],0
        jne  .shd
        jmp  .jet   ; the turret seat brings its OWN glass, and
                                ;  it is not the jet's: the cabin's window
.jet:  cmp  word [pimgo],0
        je   .shd              ; no cockpit bitmap: nothing covers the view
        cmp  byte [cockpit],0
        je   .shd
        mov  word [horiz],PZGLASSC
.shd:  ret

RENDER: call SETHORIZ           ; where the glass is, before anything uses it
        ; camera cell (needed by GRID and BUILDINGS)
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
        cmp  byte [daymode],0
        jmp  .day              ; BOND: no stars at all - a flat sky (was jne,
.day:  jmp  .nowx   ; LOW: no weather. The clouds are FILLED
                                ;  shapes, and on a flat field they would be
                               ;  the dearest thing left on the screen -
                               ;  skipped at the call site, so the far call
                               ;  goes with them.
.nowx:  jmp  .flat   ; LOW: no relief at all. Not a stroked mesh -
                                ;  no mesh: no heightmap walk, no per-node
                               ;  rotate-and-cache, no 1600 quads. A flat
                               ;  lattice instead, about a hundred edges,
                               ;  which is what WIRE CITY drew.
.flat: call GRID
.grnd:
        mov  al,22              ; *** BOND PROFILE: the ground lattice
        call SYMSEG:RMARKF
        call TOWNSEG:AFDRAWF   ; the aerodromes, paved onto it - before the
                                ; buildings, so anything standing goes over
                                ; the concrete rather than under it
        mov  al,1
        call SYMSEG:RMARKF   ; *** TEMP: sky, terrain and concrete done
        call BUILDINGS          ; real buildings to the horizon (BORD walk)
        mov  al,2
        call SYMSEG:RMARKF   ; *** TEMP: the city and its traffic done
        call UISEG:RSTADRAWF   ; the two ground radar stations, dish turning
        mov  al,20              ; *** BOND PROFILE: the radars alone
        call SYMSEG:RMARKF
        mov  al,3
        call SYMSEG:RMARKF   ; *** TEMP: the ground furniture done
        call WRECKDRAW          ; fallen jets burn on the ground
        mov  al,4
        call SYMSEG:RMARKF   ; *** TEMP: the wreck pool done
        ; ---- the GHOST: the pilot's own jet, drawn as a world object
        ; while he crews the Shilka - it stands (or flies its trim)
        ; exactly where rsv* says the render borrowed the camera from.
        mov  word [pdlim],NPLANE*2
        jmp  .ngh

.ngh:  mov  byte [ghpst],1
.ghd:  call PLANESDRAW         ; AI jets own the sky (and the ghost)
        mov  al,5
        call SYMSEG:RMARKF   ; *** TEMP: the AI jets done
        cmp  byte [chsview],0
        je   .nochs
        cmp  byte [dying],0
        jne  .nochs            ; the jet IS the wreck now
        cmp  byte [tgtcam],0
        jne  .nochs            ; orbit camera: we are off-frame
        cmp  byte [mcact],0
        jne  .nochs            ; missile camera: same
        call PLAYERDRAW         ; our own jet, banking for real
.nochs:
        call MSLDRAW            ; the missile dot and its puff
        call AMSLDRAW           ; the AI's missiles too
        mov  al,6
        call SYMSEG:RMARKF   ; *** TEMP: the missiles done
        call SYMSEG:HITFLSHF   ; hit: the world flares, and the HUD below
                                ;  draws straight over it so the sight lives
        mov  al,7
        call SYMSEG:RMARKF   ; *** TEMP: the hit flash done
        cmp  byte [sview],0
        jne  .sideview         ; looking out of the side: NO glass HUD. The
                                ; ring, the gunsight and the strips belong to
                                ; the head-up display, and a head-up display
                                ; is bolted to the front of the cockpit
        jmp  .hudjet   ; the turret seat: the jet's HUD stays in
                                ;  the jet - the GUNS are the sight here
.hudjet:
        call LOCKHUD            ; aiming ring, lock pointer, callsign
        call GUNDRAW            ; cannon tracers
        call HUDBARS            ; glass HUD: compass, speed, altitude
        call CROSS              ; levelled gunsight + standby horizon
.sideview:
        mov  al,8
        call SYMSEG:RMARKF   ; *** TEMP: the head-up display done
        mov  word [mapt],123
        cmp  byte [dying],0
        jne  .pdone            ; falling: cinema only
        cmp  byte [mcact],0
        jne  .pdone            ; riding the missile: cinema
        cmp  byte [tgtcam],0
        jne  .pdone            ; orbit view: cinema too
        cmp  byte [chsview],0
        jne  .pdone            ; chase view: clean cinema, no panel
        jmp  .njcab

.njcab:
        cmp  byte [cockpit],0
        je   .nopan
        call PANEL              ; instrument panel over the bottom rows
        cmp  word [pimgo],0
        jne  .pdone            ; photo cockpit has the map on its own MFD
        mov  word [mapt],133 ; minimap sits IN the right tower
.nopan:
        call MINIMAP            ; world map + plane marker
.pdone:
        mov  al,9
        call SYMSEG:RMARKF   ; *** TEMP: the panel and the map done
        ; ---- the pause letter and the debug dial, HERE because every
        ; view runs this tail. They lived on TOPSTRIP first - and
        ; TOPSTRIP is the no-cockpit view's strip alone, so the pilot
        ; flew the photo cockpit and saw neither the P nor the number
        ; (2026-08-23).
        cmp  byte [paused],0
        je   .npl
        mov  byte [COLOR],19
        mov  word [ftx],206
        mov  word [fty],2
        mov  si,MSGP2
        call CODE:FDRAWF
.npl:  cmp  byte [dbgm],0     ; Ctrl+D: the frame counter, top right -
        je   .nfd              ;  the 486 asked for a number, not an
        mov  byte [COLOR],8    ;  adjective
        mov  word [ftx],296
        mov  word [fty],2
        mov  ax,[fpsv]
        cmp  ax,99             ; two digits is what the corner holds
        jbe  .nf1
        mov  ax,99
.nf1:  mov  cx,2
        call CODE:FNUMZF
.nfd:
        call DEATHTXT           ; CRASH - PRESS SPACE while falling
        call SYMSEG:RAMPTXTF   ; ...and what is holding her, while parked
        call UISEG:SPECTXTF   ; ...and the invitation, while watching
        ret

