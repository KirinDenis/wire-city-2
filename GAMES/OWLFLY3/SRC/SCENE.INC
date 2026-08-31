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
        cmp  byte [ride],0      ; the turret seat brings its OWN glass, and
        je   .jet              ;  it is not the jet's: the cabin's window
        cmp  byte [rdext],0     ;  runs rows 10..106, so its middle is 58.
        jne  .shd              ;  It held 100 - the bottom edge - and the
        mov  word [horiz],SHCABHZ  ; whole seat was sky. Walking around
        ret                     ;  her is cinema and keeps the screen's own
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
        jne  .day              ; stars only at night
        call STARS
.day:  cmp  byte [qual],2     ; LOW: no weather. The clouds are FILLED
        je   .nowx             ;  shapes, and on a flat field they would be
                               ;  the dearest thing left on the screen -
                               ;  skipped at the call site, so the far call
                               ;  goes with them.
        call SKYSEG:WCLOUDF   ; the weather next: over the stars,
                                ; under the terrain - a cloud behind a
                                ; ridge is painted over, as it should be
.nowx: cmp  byte [qual],2     ; LOW: no relief at all. Not a stroked mesh -
        je   .flat             ;  no mesh: no heightmap walk, no per-node
                               ;  rotate-and-cache, no 1600 quads. A flat
                               ;  lattice instead, about a hundred edges,
                               ;  which is what WIRE CITY drew.
        call TERRPREP           ; rotate + cache the terrain nodes
        call TERRAIN            ; real 3D relief, far -> near
        jmp  .grnd
.flat: call GRID
.grnd:
        call TOWNSEG:AFDRAWF   ; the aerodromes, paved onto it - before the
                                ; buildings, so anything standing goes over
                                ; the concrete rather than under it
        mov  al,1
        call SYMSEG:RMARKF   ; *** TEMP: sky, terrain and concrete done
        call BUILDINGS          ; real buildings to the horizon (BORD walk)
        mov  al,2
        call SYMSEG:RMARKF   ; *** TEMP: the city and its traffic done
        call UISEG:RSTADRAWF   ; the two ground radar stations, dish turning
        call UISEG:SHKDRAWF   ; the six Shilkas, turrets turning
        mov  al,3
        call SYMSEG:RMARKF   ; *** TEMP: the ground furniture done
        call WRECKDRAW          ; fallen jets burn on the ground
        mov  al,4
        call SYMSEG:RMARKF   ; *** TEMP: the wreck pool done
        ; ---- the GHOST: the pilot's own jet, drawn as a world object
        ; while he crews the Shilka - it stands (or flies its trim)
        ; exactly where rsv* says the render borrowed the camera from.
        mov  word [pdlim],NPLANE*2
        cmp  byte [ride],0
        je   .ngh
        cmp  byte [dying],0     ; a wreck already draws itself
        jne  .ngh
        mov  ax,[rsvx]
        mov  [ghpax],ax
        mov  ax,[rsvy]
        mov  [ghpay],ax
        mov  ax,[rsvz]
        mov  [ghpaz],ax
        mov  ax,[rsvh]
        mov  [ghpah],ax
        mov  ax,[netpid]        ; the nameplate wears the pilot's own
        xor  dx,dx              ;  callsign letter
        mov  bx,26
        div  bx
        add  dl,'A'
        mov  [ghplt],dl
        mov  byte [ghpst],0     ; alive for the DRAW alone
        mov  word [pdlim],NPLANE*2+2
        jmp  .ghd
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
        cmp  byte [ride],0      ; the turret seat: the jet's HUD stays in
        je   .hudjet           ;  the jet - the GUNS are the sight here
        cmp  byte [rdext],0     ; from the seat, the barrels on the glass:
        jne  .rdgun            ;  outside, SHKDRAW already draws the real
        call SYMSEG:SHKBRLF   ;  ones on the real vehicle
.rdgun:
        call GUNDRAW            ; ...and the tracers over them
        jmp  .sideview
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
        cmp  byte [ride],0
        je   .njcab
        cmp  byte [rdext],0     ; walking around her: clean cinema, the
        jne  .pdone            ;  cabin stays inside the vehicle
        call SYMSEG:SHPNLF  ; the turret seat: the SHILKA'S cabin and its
        jmp  .pdone            ;  instruments in the jet-panel slot - or,
                                ;  head turned on F6/F7, her side console.
                                ;  The sview test lives with the art in
                                ;  SYMSEG; this slot got five bytes BACK
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

; ----- stars (sky background; horizon is the sky/ground colour split) -------
STARS:  ; a real celestial sphere: each star is a DIRECTION (azimuth,
        ; elevation) projected as an infinitely distant point - it turns
        ; with the heading, pitches, banks and rides the sway like the
        ; world does. Radius ~7000 puts them past everything.
        mov  word [tpi],0
.st:   mov  bx,[tpi]
        add  bx,bx
        add  bx,bx              ; entry = 2 words
        mov  ax,[STARTAB+bx+2]  ; rh = cos(el)*27  (~7000 horizontal)
        add  ax,64
        call SINQ
        mov  cx,27
        imul cx
        mov  [ctx],ax
        mov  bx,[tpi]
        add  bx,bx
        add  bx,bx
        mov  ax,[STARTAB+bx+2]  ; y = sin(el)*27
        call SINQ
        mov  cx,27
        imul cx
        mov  [cty],ax
        mov  bx,[tpi]
        add  bx,bx
        add  bx,bx
        mov  ax,[STARTAB+bx]    ; x = sin(az)*rh/256
        call SINQ
        imul word [ctx]
        mov  bx,256
        idiv bx
        mov  [wdx],ax
        mov  bx,[tpi]
        add  bx,bx
        add  bx,bx
        mov  ax,[STARTAB+bx]    ; z = cos(az)*rh/256
        add  ax,64
        call SINQ
        imul word [ctx]
        mov  bx,256
        idiv bx
        mov  [wdz],ax
        call ROTXZ
        mov  dx,[cty]
        mov  ax,[rc_x]
        mov  cx,[rc_z]
        call PPOINT
        jc   .sn
        cmp  ax,0
        jl   .sn
        cmp  ax,319
        jg   .sn
        cmp  dx,0
        jl   .sn
        cmp  dx,191
        jg   .sn
        mov  [dsx],ax
        mov  ax,dx
        call ROW320
        add  di,[dsx]
        mov  al,8
        mov  [es:di],al
.sn:   inc  word [tpi]
        cmp  word [tpi],STARN
        jb   .st
        ret
; fill the visible vertical faces with the CURRENT colour (no per-side tint)
MEGAFILL:
        mov  ax,[camx]
        cmp  ax,[bwx0]
        jge  .e
        mov  word [fa],3
        mov  word [fb],0
        call FACEV
        call FACEFILL
.e:    mov  ax,[camx]
        cmp  ax,[bwx1]
        jle  .s
        mov  word [fa],1
        mov  word [fb],2
        call FACEV
        call FACEFILL
.s:    mov  ax,[camz]
        cmp  ax,[bwz0]
        jge  .n
        mov  word [fa],0
        mov  word [fb],1
        call FACEV
        call FACEFILL
.n:    mov  ax,[camz]
        cmp  ax,[bwz1]
        jle  .d
        mov  word [fa],2
        mov  word [fb],3
        call FACEV
        call FACEFILL
.d:    ret
