; SCENE.INC - part of WIRE CITY (included from CITY.ASM)
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
        call BUILDINGS          ; real buildings to the horizon (BORD walk)
        call WRECKDRAW          ; fallen jets burn on the ground
        call PLANESDRAW         ; AI jets own the sky
        call BOMBDRAW           ; and the bombs hang under it
        cmp  byte ptr [chsview],0
        je   @@nochs
        cmp  byte ptr [dying],0
        jne  @@nochs            ; the jet IS the wreck now
        cmp  byte ptr [tgtcam],0
        jne  @@nochs            ; orbit camera: we are off-frame
        cmp  byte ptr [mcact],0
        jne  @@nochs            ; missile camera: same
        call PLAYERDRAW         ; our own jet, banking for real
@@nochs:
        call MSLDRAW            ; the missile dot and its puff
        call AMSLDRAW           ; the AI's missiles too
        call LOCKHUD            ; aiming ring, lock pointer, callsign
        call GUNDRAW            ; cannon tracers
        call HUDBARS            ; glass HUD: compass, speed, altitude
        call CROSS              ; levelled gunsight + standby horizon
        mov  word ptr [mapt],123
        cmp  byte ptr [dying],0
        jne  @@pdone            ; falling: cinema only
        cmp  byte ptr [mcact],0
        jne  @@pdone            ; riding the missile: cinema
        cmp  byte ptr [tgtcam],0
        jne  @@pdone            ; orbit view: cinema too
        cmp  byte ptr [chsview],0
        jne  @@pdone            ; chase view: clean cinema, no panel
        cmp  byte ptr [cockpit],0
        je   @@nopan
        call PANEL              ; instrument panel over the bottom rows
        cmp  word ptr [pimgo],0
        jne  @@pdone            ; photo cockpit has the map on its own MFD
        mov  word ptr [mapt],133 ; minimap sits IN the right tower
@@nopan:
        call MINIMAP            ; world map + plane marker
@@pdone:
        call DEATHTXT           ; CRASH - PRESS SPACE while falling
        ret

; ----- stars (sky background; horizon is the sky/ground colour split) -------
STARS:  ; a real celestial sphere: each star is a DIRECTION (azimuth,
        ; elevation) projected as an infinitely distant point - it turns
        ; with the heading, pitches, banks and rides the sway like the
        ; world does. Radius ~7000 puts them past everything.
        mov  word ptr [tpi],0
@@st:   mov  bx,[tpi]
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
        imul word ptr [ctx]
        mov  bx,256
        idiv bx
        mov  [wdx],ax
        mov  bx,[tpi]
        add  bx,bx
        add  bx,bx
        mov  ax,[STARTAB+bx]    ; z = cos(az)*rh/256
        add  ax,64
        call SINQ
        imul word ptr [ctx]
        mov  bx,256
        idiv bx
        mov  [wdz],ax
        call ROTXZ
        mov  dx,[cty]
        mov  ax,[rcx]
        mov  cx,[rcz]
        call PPOINT
        jc   @@sn
        cmp  ax,0
        jl   @@sn
        cmp  ax,319
        jg   @@sn
        cmp  dx,0
        jl   @@sn
        cmp  dx,191
        jg   @@sn
        mov  [dsx],ax
        mov  ax,dx
        call ROW320
        add  di,[dsx]
        mov  al,8
        mov  es:[di],al
@@sn:   inc  word ptr [tpi]
        cmp  word ptr [tpi],STARN
        jb   @@st
        ret
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
